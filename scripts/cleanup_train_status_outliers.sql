-- One-off cleanup for rows logged before poll_realtime.py had a match window.
--
-- Before MAX_MATCH_WINDOW_MINUTES existed, an arrival was matched to the
-- nearest timetable entry no matter how far away it was, so a train could be
-- recorded against a departure hours apart and stored as a huge delay (or a
-- large negative one, which then counted as "on time").
--
-- Run the SELECT first to see what would go, then the DELETE.

select count(*) as outlier_rows,
       min(delay_minutes) as min_delay,
       max(delay_minutes) as max_delay
from public.train_status
where delay_minutes < -30
   or delay_minutes > 30;

-- delete from public.train_status
-- where delay_minutes < -30
--    or delay_minutes > 30;
