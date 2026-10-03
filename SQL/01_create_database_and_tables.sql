-- Smart City data warehouse: 8 dimensions + 2 facts (10 tables total, no views)
-- MySQL 8+. Run:  mysql -u root -p < sql\01_create_database_and_tables.sql
DROP DATABASE IF EXISTS smart_city_dw;
CREATE DATABASE smart_city_dw CHARACTER SET utf8mb4;
USE smart_city_dw;

-- ---------- 8 DIMENSIONS ----------
CREATE TABLE dim_date (
  date_key INT PRIMARY KEY, full_date DATE NOT NULL, year SMALLINT, month TINYINT,
  month_name VARCHAR(10), month_label CHAR(7), day TINYINT,
  dow_num TINYINT, dow_name VARCHAR(10), is_weekend TINYINT
);
CREATE TABLE dim_time (
  hour TINYINT PRIMARY KEY, time_band VARCHAR(20),
  peak_period VARCHAR(20), is_peak_hour TINYINT
);
CREATE TABLE dim_location (location_key INT PRIMARY KEY, location_name VARCHAR(50) NOT NULL UNIQUE);
CREATE TABLE dim_weather  (weather_key INT PRIMARY KEY, weather VARCHAR(30) NOT NULL UNIQUE);
CREATE TABLE dim_road     (road_key INT PRIMARY KEY, road_condition VARCHAR(30) NOT NULL UNIQUE);
CREATE TABLE dim_vehicle  (vehicle_key INT PRIMARY KEY, vehicle_type VARCHAR(30) NOT NULL UNIQUE);
CREATE TABLE dim_severity (severity_key INT PRIMARY KEY, severity VARCHAR(20) NOT NULL UNIQUE, severity_weight TINYINT);
CREATE TABLE dim_congestion_level (congestion_key INT PRIMARY KEY, congestion_level VARCHAR(10) NOT NULL UNIQUE);

-- ---------- 2 FACTS ----------
CREATE TABLE fact_accident (
  accident_id VARCHAR(20) PRIMARY KEY, event_ts DATETIME NOT NULL,
  date_key INT NOT NULL, hour TINYINT NOT NULL,
  location_key INT NOT NULL, weather_key INT NOT NULL, road_key INT NOT NULL,
  vehicle_key INT NOT NULL, severity_key INT NOT NULL,
  number_of_vehicles INT, casualties INT, traffic_density VARCHAR(10),
  severity_score DECIMAL(8,2), is_high_severity TINYINT, dq_note VARCHAR(150),
  FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
  FOREIGN KEY (hour) REFERENCES dim_time(hour),
  FOREIGN KEY (location_key) REFERENCES dim_location(location_key),
  FOREIGN KEY (weather_key) REFERENCES dim_weather(weather_key),
  FOREIGN KEY (road_key) REFERENCES dim_road(road_key),
  FOREIGN KEY (vehicle_key) REFERENCES dim_vehicle(vehicle_key),
  FOREIGN KEY (severity_key) REFERENCES dim_severity(severity_key),
  INDEX ix_acc_date (date_key), INDEX ix_acc_loc (location_key)
);

CREATE TABLE fact_traffic (
  reading_id VARCHAR(20) PRIMARY KEY, event_ts DATETIME NOT NULL,
  date_key INT NOT NULL, hour TINYINT NOT NULL, location_key INT NOT NULL,
  vehicle_count INT, average_speed DECIMAL(6,1),
  reported_congestion VARCHAR(10), congestion_index DECIMAL(5,1), congestion_key INT, is_high_congestion TINYINT,
  dq_note VARCHAR(50),
  FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
  FOREIGN KEY (hour) REFERENCES dim_time(hour),
  FOREIGN KEY (location_key) REFERENCES dim_location(location_key),
  FOREIGN KEY (congestion_key) REFERENCES dim_congestion_level(congestion_key),
  INDEX ix_trf_loc (location_key, hour)
);

SELECT 'Created 8 dimension tables and 2 fact tables (10 total)' AS status;
SHOW TABLES;
