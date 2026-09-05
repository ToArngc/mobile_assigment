"""Design doc §8 — GTFS static sync. Run once daily.

Fetches the KTMB GTFS static feed, and upserts `stations` and refreshes
`timetable_entries` in Supabase using the service role key.

`stations` is upserted by name (the schema has no GTFS stop_id column, and
station ids are foreign-keyed from ride_logs/saved_stations/saved_routes/
fault_reports/train_status/timetable_entries, so existing rows must keep
their id — never delete-and-reinsert stations).

`timetable_entries` has no natural unique key to upsert against, so it is
fully replaced each run: delete everything, then insert fresh from today's
feed. Safe because nothing has a foreign key into timetable_entries.
"""

import csv
import io
import os
import zipfile

import requests

GTFS_STATIC_URL = "https://api.data.gov.my/gtfs-static/ktmb"
TIMETABLE_BATCH_SIZE = 500


def supabase_url():
    return os.environ["SUPABASE_URL"].rstrip("/")


def headers(prefer=None):
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    result = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    if prefer:
        result["Prefer"] = prefer
    return result


def get_json(path, params=None):
    resp = requests.get(f"{supabase_url()}{path}", headers=headers(), params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


def post_json(path, body, return_representation=False):
    prefer = "return=representation" if return_representation else None
    resp = requests.post(f"{supabase_url()}{path}", headers=headers(prefer), json=body, timeout=30)
    resp.raise_for_status()
    return resp.json() if return_representation else None


def patch_json(path, body):
    resp = requests.patch(f"{supabase_url()}{path}", headers=headers(), json=body, timeout=30)
    resp.raise_for_status()


def delete(path):
    resp = requests.delete(f"{supabase_url()}{path}", headers=headers(), timeout=30)
    resp.raise_for_status()


def read_gtfs_csv(zf, filename):
    with zf.open(filename) as f:
        return list(csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig")))


def normalize_time(hms):
    """GTFS allows hours >= 24 for post-midnight trips; `time` columns don't."""
    h, m, s = hms.split(":")
    return f"{int(h) % 24:02d}:{m}:{s}"


def download_feed():
    resp = requests.get(GTFS_STATIC_URL, timeout=60)
    resp.raise_for_status()
    return zipfile.ZipFile(io.BytesIO(resp.content))


def sync_stations(stops_by_id, stop_lines):
    """Upsert `stations` by name. Returns {gtfs_stop_id: supabase_station_id}."""
    existing = {row["name"]: row["id"] for row in get_json("/rest/v1/stations", {"select": "id,name"})}
    stop_to_station_id = {}

    for stop_id, stop in stops_by_id.items():
        name = stop["stop_name"]
        lat = float(stop["stop_lat"])
        lng = float(stop["stop_lon"])
        line = ", ".join(sorted(stop_lines.get(stop_id, [])))

        if name in existing:
            station_id = existing[name]
            patch_json(f"/rest/v1/stations?id=eq.{station_id}", {"line": line, "lat": lat, "lng": lng})
        else:
            created = post_json(
                "/rest/v1/stations",
                {"name": name, "line": line, "lat": lat, "lng": lng},
                return_representation=True,
            )
            station_id = created[0]["id"]
            existing[name] = station_id

        stop_to_station_id[stop_id] = station_id

    return stop_to_station_id


def sync_timetable(stop_times, trip_route, route_name, trip_headsign, trip_direction_id, stop_to_station_id):
    entries = []
    for row in stop_times:
        station_id = stop_to_station_id.get(row["stop_id"])
        if station_id is None:
            continue

        scheduled = row.get("arrival_time") or row.get("departure_time")
        if not scheduled:
            continue

        trip_id = row["trip_id"]
        entries.append({
            "station_id": station_id,
            "line": route_name.get(trip_route.get(trip_id), "Unknown"),
            "scheduled_time": normalize_time(scheduled),
            "direction": trip_headsign.get(trip_id) or trip_direction_id.get(trip_id) or "",
        })

    delete("/rest/v1/timetable_entries?id=not.is.null")
    for i in range(0, len(entries), TIMETABLE_BATCH_SIZE):
        post_json("/rest/v1/timetable_entries", entries[i:i + TIMETABLE_BATCH_SIZE])

    return len(entries)


def main():
    zf = download_feed()

    stops = read_gtfs_csv(zf, "stops.txt")
    routes = read_gtfs_csv(zf, "routes.txt")
    trips = read_gtfs_csv(zf, "trips.txt")
    stop_times = read_gtfs_csv(zf, "stop_times.txt")

    stops_by_id = {s["stop_id"]: s for s in stops}
    route_name = {r["route_id"]: (r.get("route_short_name") or r.get("route_long_name") or r["route_id"]) for r in routes}
    trip_route = {t["trip_id"]: t["route_id"] for t in trips}
    trip_headsign = {t["trip_id"]: t.get("trip_headsign", "") for t in trips}
    trip_direction_id = {t["trip_id"]: t.get("direction_id", "") for t in trips}

    # Which lines serve each stop, for the aggregate `stations.line` field.
    stop_lines = {}
    for row in stop_times:
        line = route_name.get(trip_route.get(row["trip_id"]))
        if line:
            stop_lines.setdefault(row["stop_id"], set()).add(line)

    stop_to_station_id = sync_stations(stops_by_id, stop_lines)
    print(f"Synced {len(stop_to_station_id)} stations.")

    entry_count = sync_timetable(stop_times, trip_route, route_name, trip_headsign, trip_direction_id, stop_to_station_id)
    print(f"Synced {entry_count} timetable entries.")


if __name__ == "__main__":
    main()
