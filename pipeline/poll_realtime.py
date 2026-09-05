"""Design doc §8 — GTFS realtime poll, proximity-based delay computation
(Option B). Run every 15-30 min during commute hours via GitHub Actions.

The confirmed feed only has trip.trip_id, position.{latitude,longitude,
bearing,speed}, timestamp, and vehicle.{id,label} — no stop_id or
current_status, and no route_id, so a vehicle reading doesn't say which
line it's on. That's resolved here by matching each arrival to whichever
timetable_entries row (across all lines at that station) has the closest
scheduled_time to the actual arrival — that row's `line` is used for both
the match and the train_status write.

GTFS static times are local wall-clock (Asia/Kuala_Lumpur, KTMB's
timezone) with no date, so scheduled times are projected onto the
vehicle's local calendar day before comparing against its UTC timestamp.
"""

import math
import os
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import requests
from google.transit import gtfs_realtime_pb2

GTFS_REALTIME_URL = "https://api.data.gov.my/gtfs-realtime/vehicle-position/ktmb"
ARRIVAL_RADIUS_METERS = 200
MYT = ZoneInfo("Asia/Kuala_Lumpur")


def supabase_url():
    return os.environ["SUPABASE_URL"].rstrip("/")


def headers():
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


def get_json(path, params=None):
    resp = requests.get(f"{supabase_url()}{path}", headers=headers(), params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


def insert_train_status(row):
    resp = requests.post(f"{supabase_url()}/rest/v1/train_status", headers=headers(), json=row, timeout=30)
    resp.raise_for_status()


def haversine_meters(lat1, lon1, lat2, lon2):
    r = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def fetch_vehicles():
    resp = requests.get(GTFS_REALTIME_URL, timeout=30)
    resp.raise_for_status()
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(resp.content)

    vehicles = []
    for entity in feed.entity:
        if not entity.HasField("vehicle"):
            continue
        v = entity.vehicle
        if not v.trip.trip_id:
            continue
        vehicles.append({
            "trip_id": v.trip.trip_id,
            "lat": v.position.latitude,
            "lng": v.position.longitude,
            "timestamp": v.timestamp,
        })
    return vehicles


def scheduled_time_to_datetime(hms, local_date):
    h, m, s = (int(x) for x in hms.split(":"))
    return datetime(local_date.year, local_date.month, local_date.day, h % 24, m, s, tzinfo=MYT)


def closest_timetable_match(candidates, actual_dt, local_date):
    """candidates: timetable_entries rows for one station. Returns
    (line, scheduled_dt) for whichever has the smallest time difference
    from actual_dt, or None if there are no candidates."""
    best = None
    best_diff = None
    for row in candidates:
        scheduled_dt = scheduled_time_to_datetime(row["scheduled_time"], local_date)
        diff = abs((actual_dt - scheduled_dt).total_seconds())
        if best_diff is None or diff < best_diff:
            best, best_diff = (row["line"], scheduled_dt), diff
    return best


def main():
    stations = get_json("/rest/v1/stations", {"select": "id,lat,lng"})
    timetable = get_json("/rest/v1/timetable_entries", {"select": "station_id,line,scheduled_time"})

    timetable_by_station = {}
    for row in timetable:
        timetable_by_station.setdefault(row["station_id"], []).append(row)

    # Bound the dedup lookup to the last 24h (comfortably covers a single
    # commute window even where it crosses UTC midnight) instead of
    # scanning all of train_status every poll.
    since = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
    already_logged = {
        (row["trip_id"], row["station_id"])
        for row in get_json("/rest/v1/train_status", {"select": "trip_id,station_id", "recorded_at": f"gte.{since}"})
    }

    logged_count = 0
    for vehicle in fetch_vehicles():
        trip_id = vehicle["trip_id"]
        actual_dt = datetime.fromtimestamp(vehicle["timestamp"], tz=timezone.utc)
        local_date = actual_dt.astimezone(MYT).date()

        for station in stations:
            distance = haversine_meters(vehicle["lat"], vehicle["lng"], station["lat"], station["lng"])
            if distance > ARRIVAL_RADIUS_METERS:
                continue

            station_id = station["id"]
            if (trip_id, station_id) in already_logged:
                break  # already logged this trip's arrival here — skip (§8 step 4)

            candidates = timetable_by_station.get(station_id, [])
            match = closest_timetable_match(candidates, actual_dt, local_date)
            if match is None:
                break  # no schedule to compare against — can't compute a delay

            line, scheduled_dt = match
            delay_minutes = round((actual_dt - scheduled_dt).total_seconds() / 60)

            insert_train_status({
                "station_id": station_id,
                "line": line,
                "trip_id": trip_id,
                "scheduled_time": scheduled_dt.isoformat(),
                "actual_time": actual_dt.isoformat(),
                "delay_minutes": delay_minutes,
            })
            already_logged.add((trip_id, station_id))
            logged_count += 1
            break  # a vehicle can only be arriving at one station at a time

    print(f"Logged {logged_count} arrival(s).")


if __name__ == "__main__":
    main()
