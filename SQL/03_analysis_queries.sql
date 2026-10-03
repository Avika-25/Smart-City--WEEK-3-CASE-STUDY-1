-- =====================================================================
-- Analysis queries (MySQL 8) - plain table joins, no views.
-- Run in the terminal:  mysql -u root -p --table < sql\03_analysis_queries.sql
-- Save output:          ... > output\reports\sql_results.txt
-- Aliases: a=fact_accident f=fact_traffic d=dim_date t=dim_time l=dim_location
--          w=dim_weather r=dim_road v=dim_vehicle s=dim_severity
-- =====================================================================
USE smart_city_dw;

SELECT '=== 0. ROW COUNTS ===' AS section;
SELECT 'fact_accident' AS tbl, COUNT(*) AS row_count FROM fact_accident
UNION ALL SELECT 'fact_traffic', COUNT(*) FROM fact_traffic
UNION ALL SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL SELECT 'dim_location', COUNT(*) FROM dim_location;

-- ------------------------------------------------------------- TRAFFIC ANALYSIS
SELECT '=== 1. HOURLY TRAFFIC PROFILE ===' AS section;
SELECT f.hour, ROUND(AVG(f.vehicle_count),1) AS avg_vehicles, ROUND(AVG(f.average_speed),1) AS avg_speed_kmh,
       ROUND(AVG(f.congestion_index),1) AS avg_congestion_index, COUNT(*) AS readings
FROM fact_traffic f
GROUP BY f.hour ORDER BY f.hour;

SELECT '=== 2. PEAK vs OFF-PEAK BY LOCATION ===' AS section;
SELECT l.location_name, t.peak_period, ROUND(AVG(f.vehicle_count),1) AS avg_vehicles,
       ROUND(AVG(f.average_speed),1) AS avg_speed_kmh, ROUND(AVG(f.congestion_index),1) AS avg_congestion_index,
       ROUND(100*AVG(f.is_high_congestion),1) AS pct_high_congestion, COUNT(*) AS readings
FROM fact_traffic f
JOIN dim_location l ON l.location_key = f.location_key
JOIN dim_time t ON t.hour = f.hour
GROUP BY l.location_name, t.peak_period ORDER BY l.location_name, t.peak_period;

SELECT '=== 3. TOP 10 CONGESTION BOTTLENECKS (location x hour, min 2 readings) ===' AS section;
SELECT l.location_name, f.hour, ROUND(AVG(f.congestion_index),1) AS avg_congestion_index,
       ROUND(AVG(f.average_speed),1) AS avg_speed_kmh, ROUND(AVG(f.vehicle_count),0) AS avg_vehicles, COUNT(*) AS readings
FROM fact_traffic f
JOIN dim_location l ON l.location_key = f.location_key
GROUP BY l.location_name, f.hour HAVING COUNT(*) >= 2
ORDER BY avg_congestion_index DESC LIMIT 10;

SELECT '=== 4. LOCATION CONGESTION RANKING ===' AS section;
SELECT l.location_name, COUNT(*) AS readings, ROUND(AVG(f.vehicle_count),1) AS avg_vehicles,
       ROUND(AVG(f.average_speed),1) AS avg_speed_kmh, ROUND(AVG(f.congestion_index),1) AS avg_congestion_index,
       ROUND(100*AVG(f.is_high_congestion),1) AS pct_high_congestion,
       RANK() OVER (ORDER BY AVG(f.congestion_index) DESC) AS congestion_rank
FROM fact_traffic f
JOIN dim_location l ON l.location_key = f.location_key
GROUP BY l.location_name ORDER BY congestion_rank;

SELECT '=== 5. REPORTED Congestion_Level vs LEVEL DERIVED FROM VOLUME+SPEED ===' AS section;
SELECT f.reported_congestion, f.congestion_band AS derived_band, COUNT(*) AS readings,
       ROUND(AVG(f.vehicle_count),1) AS avg_vehicles, ROUND(AVG(f.average_speed),1) AS avg_speed_kmh
FROM fact_traffic f
GROUP BY f.reported_congestion, f.congestion_band ORDER BY f.reported_congestion, f.congestion_band;

-- ------------------------------------------------------------- ACCIDENT ANALYSIS
SELECT '=== 6. ACCIDENT-PRONE LOCATIONS (ranked by total severity score) ===' AS section;
SELECT l.location_name, COUNT(*) AS accidents, SUM(a.casualties) AS casualties,
       SUM(s.severity = 'Fatal') AS fatal, ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal,
       ROUND(SUM(a.severity_score),0) AS total_severity_score,
       RANK() OVER (ORDER BY SUM(a.severity_score) DESC) AS risk_rank
FROM fact_accident a
JOIN dim_location l ON l.location_key = a.location_key
JOIN dim_severity s ON s.severity_key = a.severity_key
GROUP BY l.location_name ORDER BY risk_rank;

SELECT '=== 7. ACCIDENTS BY HOUR OF DAY ===' AS section;
SELECT a.hour, t.peak_period, COUNT(*) AS accidents, ROUND(AVG(a.casualties),2) AS avg_casualties,
       ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal
FROM fact_accident a
JOIN dim_time t ON t.hour = a.hour
GROUP BY a.hour, t.peak_period ORDER BY a.hour;

SELECT '=== 8. PEAK vs OFF-PEAK ACCIDENTS (per hour of the day) ===' AS section;
SELECT t.peak_period, COUNT(*) AS accidents, COUNT(DISTINCT a.hour) AS hours_in_group,
       ROUND(COUNT(*)/COUNT(DISTINCT a.hour),1) AS accidents_per_hour_of_day,
       ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal
FROM fact_accident a
JOIN dim_time t ON t.hour = a.hour
GROUP BY t.peak_period;

SELECT '=== 9. WEATHER IMPACT ===' AS section;
SELECT w.weather, COUNT(*) AS accidents, ROUND(AVG(a.casualties),2) AS avg_casualties,
       ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal, ROUND(AVG(a.severity_score),2) AS avg_severity_score
FROM fact_accident a
JOIN dim_weather w ON w.weather_key = a.weather_key
GROUP BY w.weather ORDER BY pct_severe_or_fatal DESC;

SELECT '=== 10. WEATHER x ROAD CONDITION (cells with >= 20 accidents) ===' AS section;
SELECT w.weather, r.road_condition, COUNT(*) AS accidents, ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal,
       ROUND(AVG(a.casualties),2) AS avg_casualties
FROM fact_accident a
JOIN dim_weather w ON w.weather_key = a.weather_key
JOIN dim_road r ON r.road_key = a.road_key
GROUP BY w.weather, r.road_condition HAVING COUNT(*) >= 20 ORDER BY pct_severe_or_fatal DESC;

SELECT '=== 11. VEHICLE TYPE RISK ===' AS section;
SELECT v.vehicle_type, COUNT(*) AS accidents, ROUND(AVG(a.casualties),2) AS avg_casualties,
       ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal, SUM(s.severity = 'Fatal') AS fatal
FROM fact_accident a
JOIN dim_vehicle v ON v.vehicle_key = a.vehicle_key
JOIN dim_severity s ON s.severity_key = a.severity_key
GROUP BY v.vehicle_type ORDER BY pct_severe_or_fatal DESC;

SELECT '=== 12. TRAFFIC DENSITY vs SEVERITY ===' AS section;
SELECT a.traffic_density, COUNT(*) AS accidents, ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal,
       ROUND(AVG(a.casualties),2) AS avg_casualties
FROM fact_accident a
GROUP BY a.traffic_density ORDER BY FIELD(a.traffic_density, 'Low', 'Moderate', 'High');

SELECT '=== 13. MONTHLY TREND (last month is partial) ===' AS section;
WITH m AS (
  SELECT d.month_label, COUNT(*) AS accidents, SUM(a.casualties) AS casualties, COUNT(DISTINCT d.full_date) AS days_covered
  FROM fact_accident a
  JOIN dim_date d ON d.date_key = a.date_key
  GROUP BY d.month_label)
SELECT month_label, accidents, casualties, days_covered, ROUND(accidents/days_covered,2) AS accidents_per_day,
       accidents - LAG(accidents) OVER (ORDER BY month_label) AS change_vs_prev_month
FROM m ORDER BY month_label;

SELECT '=== 14. WEEKDAY: accidents and severity ===' AS section;
SELECT d.dow_name, COUNT(*) AS accidents, ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal
FROM fact_accident a
JOIN dim_date d ON d.date_key = a.date_key
GROUP BY d.dow_num, d.dow_name ORDER BY d.dow_num;

SELECT '=== 15. HIGH-RISK LOCATION x TIME BAND (>= 30 accidents) ===' AS section;
SELECT l.location_name, t.time_band, COUNT(*) AS accidents, ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal,
       ROUND(AVG(a.severity_score),2) AS avg_severity_score
FROM fact_accident a
JOIN dim_location l ON l.location_key = a.location_key
JOIN dim_time t ON t.hour = a.hour
GROUP BY l.location_name, t.time_band HAVING COUNT(*) >= 30
ORDER BY pct_severe_or_fatal DESC LIMIT 15;

SELECT '=== 16. ACCIDENTS vs SAME-HOUR CONGESTION (only dates covered by sensor file) ===' AS section;
-- Both facts joined through the shared date + hour keys. If several sensor readings exist in one hour,
-- an accident appears once per reading.
SELECT f.congestion_band, COUNT(*) AS accidents, ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal,
       ROUND(AVG(a.casualties),2) AS avg_casualties
FROM fact_accident a
JOIN fact_traffic f ON f.date_key = a.date_key AND f.hour = a.hour
GROUP BY f.congestion_band ORDER BY f.congestion_band;

-- ------------------------------------------------------------- DATA QUALITY
SELECT '=== 17. DATA-QUALITY NOTES ON LOADED ACCIDENT DATA ===' AS section;
SELECT COUNT(*) AS accidents,
       SUM(dq_note LIKE '%fatal_no_casualty%') AS fatal_no_casualty,
       SUM(dq_note LIKE '%casualties_over_capacity%') AS casualties_over_capacity,
       SUM(dq_note LIKE '%weather_road_conflict%') AS weather_road_conflict,
       SUM(dq_note LIKE '%snow_ice_in_summer%') AS snow_ice_in_summer,
       SUM(dq_note = 'OK') AS fully_clean_rows
FROM fact_accident;

SELECT '=== 18. SEVERITY BY LOCATION USING ONLY FULLY CLEAN ROWS ===' AS section;
SELECT l.location_name, COUNT(*) AS accidents, ROUND(100*AVG(a.is_high_severity),1) AS pct_severe_or_fatal
FROM fact_accident a
JOIN dim_location l ON l.location_key = a.location_key
WHERE a.dq_note = 'OK'
GROUP BY l.location_name ORDER BY pct_severe_or_fatal DESC;

SELECT '=== 19. SENSOR READINGS: DATA-QUALITY NOTES ===' AS section;
SELECT dq_note, COUNT(*) AS readings FROM fact_traffic GROUP BY dq_note;
