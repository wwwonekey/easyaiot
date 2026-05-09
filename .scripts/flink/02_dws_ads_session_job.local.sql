-- ============================================================
-- Flink SQL Job 2：DWD -> DWS + ADS（会话切割 + 小时聚合）
-- 运行方式示例：
-- sql-client.sh embedded -f .scripts/flink/02_dws_ads_session_job.sql
--
-- 请先替换以下占位参数：
--   Kafka:9092  例：localhost:9092
--   fe:8030  例：localhost:8030
--   root     例：root
--    例：空字符串或真实密码
--
-- 当前会话切割规则（可直接跑通）：
--   仅按 global_id 分组 + 30分钟间隔断开新会话
-- 如需引入设备拓扑(dim_device_topo)做跨摄像头逻辑，可在本脚本基础上扩展。
-- ============================================================

SET 'pipeline.name' = 'job_dws_ads_session_person_vehicle';
SET 'execution.checkpointing.interval' = '30 s';
SET 'table.local-time-zone' = 'Asia/Shanghai';
SET 'parallelism.default' = '2';

-- ----------------------------
-- 1) Kafka Source：DWD 人脸中间 Topic
-- ----------------------------
CREATE TABLE dwd_face_detail_src (
    event_id        STRING,
    event_type      STRING,
    device_id       STRING,
    ts              BIGINT,
    track_id        STRING,
    global_face_id  STRING,
    bbox_x          INT,
    bbox_y          INT,
    bbox_w          INT,
    bbox_h          INT,
    center_x        INT,
    center_y        INT,
    score           DOUBLE,
    feature_id      STRING,
    feature_score   DOUBLE,
    feature_version STRING,
    face_gender     STRING,
    face_age        INT,
    face_glasses    BOOLEAN,
    face_mask       BOOLEAN,
    face_quality    DOUBLE,
    attrs           STRING,
    event_time      AS TO_TIMESTAMP_LTZ(ts, 3),
    WATERMARK FOR event_time AS event_time - INTERVAL '2' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'dwd.face.detail',
    'properties.bootstrap.servers' = 'Kafka:9092',
    'properties.group.id' = 'flink_dws_face',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

-- ----------------------------
-- 2) Kafka Source：DWD 车牌中间 Topic
-- ----------------------------
CREATE TABLE dwd_plate_detail_src (
    event_id         STRING,
    event_type       STRING,
    device_id        STRING,
    ts               BIGINT,
    track_id         STRING,
    global_plate_id  STRING,
    bbox_x           INT,
    bbox_y           INT,
    bbox_w           INT,
    bbox_h           INT,
    center_x         INT,
    center_y         INT,
    score            DOUBLE,
    plate_no         STRING,
    plate_score      DOUBLE,
    plate_color      STRING,
    vehicle_type     STRING,
    vehicle_color    STRING,
    vehicle_brand    STRING,
    attrs            STRING,
    event_time       AS TO_TIMESTAMP_LTZ(ts, 3),
    WATERMARK FOR event_time AS event_time - INTERVAL '2' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'dwd.plate.detail',
    'properties.bootstrap.servers' = 'Kafka:9092',
    'properties.group.id' = 'flink_dws_plate',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

-- ----------------------------
-- 3) Doris Sink：DWS + ADS
-- ----------------------------
CREATE TABLE dws_face_trace_1h_sink (
    stat_date       DATE,
    stat_hour       TINYINT,
    global_face_id  STRING,
    device_id       STRING,
    first_ts        BIGINT,
    last_ts         BIGINT,
    appear_cnt      BIGINT,
    avg_center_x    DOUBLE,
    avg_center_y    DOUBLE,
    face_gender     STRING,
    face_age        INT,
    face_glasses    BOOLEAN,
    face_mask       BOOLEAN,
    session_id      STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = 'fe:8030',
    'table.identifier' = 'easyaiot_person_vehicle_analytics_dw.dws_face_trace_1h',
    'username' = 'root',
    'password' = '',
    'sink.label-prefix' = 'dws_face_1h',
    'sink.enable-2pc' = 'false',
    'sink.properties.format' = 'json',
    'sink.properties.read_json_by_line' = 'true'
);

CREATE TABLE dws_plate_trace_1h_sink (
    stat_date        DATE,
    stat_hour        TINYINT,
    global_plate_id  STRING,
    device_id        STRING,
    first_ts         BIGINT,
    last_ts          BIGINT,
    appear_cnt       BIGINT,
    avg_center_x     DOUBLE,
    avg_center_y     DOUBLE,
    plate_no         STRING,
    vehicle_type     STRING,
    vehicle_color    STRING,
    vehicle_brand    STRING,
    session_id       STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = 'fe:8030',
    'table.identifier' = 'easyaiot_person_vehicle_analytics_dw.dws_plate_trace_1h',
    'username' = 'root',
    'password' = '',
    'sink.label-prefix' = 'dws_plate_1h',
    'sink.enable-2pc' = 'false',
    'sink.properties.format' = 'json',
    'sink.properties.read_json_by_line' = 'true'
);

CREATE TABLE ads_face_app_sink (
    ts                BIGINT,
    `date`            DATE,
    global_face_id    STRING,
    device_id         STRING,
    face_gender       STRING,
    face_age          INT,
    face_glasses      BOOLEAN,
    face_mask         BOOLEAN,
    session_id        STRING,
    session_start_ts  BIGINT,
    session_end_ts    BIGINT,
    companion_face_id STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = 'fe:8030',
    'table.identifier' = 'easyaiot_person_vehicle_analytics_dw.ads_face_app',
    'username' = 'root',
    'password' = '',
    'sink.label-prefix' = 'ads_face_rt',
    'sink.enable-2pc' = 'false',
    'sink.properties.format' = 'json',
    'sink.properties.read_json_by_line' = 'true'
);

CREATE TABLE ads_plate_app_sink (
    ts                  BIGINT,
    `date`              DATE,
    global_plate_id     STRING,
    plate_no            STRING,
    device_id           STRING,
    vehicle_type        STRING,
    vehicle_color       STRING,
    vehicle_brand       STRING,
    session_id          STRING,
    session_start_ts    BIGINT,
    session_end_ts      BIGINT,
    companion_plate     STRING,
    companion_global_id STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = 'fe:8030',
    'table.identifier' = 'easyaiot_person_vehicle_analytics_dw.ads_plate_app',
    'username' = 'root',
    'password' = '',
    'sink.label-prefix' = 'ads_plate_rt',
    'sink.enable-2pc' = 'false',
    'sink.properties.format' = 'json',
    'sink.properties.read_json_by_line' = 'true'
);

-- ----------------------------
-- 4) 人脸：会话编号（30分钟断会）
-- ----------------------------
CREATE TEMPORARY VIEW face_lagged AS
SELECT
    *,
    LAG(ts, 1) OVER (PARTITION BY global_face_id ORDER BY ts) AS prev_ts
FROM dwd_face_detail_src;

CREATE TEMPORARY VIEW face_session_tagged AS
SELECT
    *,
    SUM(
        CASE
            WHEN prev_ts IS NULL OR ts - prev_ts > 1800000 THEN 1
            ELSE 0
        END
    ) OVER (
        PARTITION BY global_face_id
        ORDER BY ts
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS session_seq
FROM face_lagged;

CREATE TEMPORARY VIEW face_session_bounds AS
SELECT
    global_face_id,
    session_seq,
    MIN(ts) AS session_start_ts,
    MAX(ts) AS session_end_ts
FROM face_session_tagged
GROUP BY global_face_id, session_seq;

-- ----------------------------
-- 5) 车牌：会话编号（30分钟断会）
-- ----------------------------
CREATE TEMPORARY VIEW plate_lagged AS
SELECT
    *,
    LAG(ts, 1) OVER (PARTITION BY global_plate_id ORDER BY ts) AS prev_ts
FROM dwd_plate_detail_src;

CREATE TEMPORARY VIEW plate_session_tagged AS
SELECT
    *,
    SUM(
        CASE
            WHEN prev_ts IS NULL OR ts - prev_ts > 1800000 THEN 1
            ELSE 0
        END
    ) OVER (
        PARTITION BY global_plate_id
        ORDER BY ts
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS session_seq
FROM plate_lagged;

CREATE TEMPORARY VIEW plate_session_bounds AS
SELECT
    global_plate_id,
    session_seq,
    MIN(ts) AS session_start_ts,
    MAX(ts) AS session_end_ts
FROM plate_session_tagged
GROUP BY global_plate_id, session_seq;

-- ----------------------------
-- 6) DWS + ADS 四路下沉
-- ----------------------------
EXECUTE STATEMENT SET
BEGIN
INSERT INTO dws_face_trace_1h_sink
SELECT
    CAST(DATE_FORMAT(TO_TIMESTAMP_LTZ(ts, 3), 'yyyy-MM-dd') AS DATE) AS stat_date,
    CAST(EXTRACT(HOUR FROM TO_TIMESTAMP_LTZ(ts, 3)) AS TINYINT) AS stat_hour,
    global_face_id,
    device_id,
    MIN(ts) AS first_ts,
    MAX(ts) AS last_ts,
    COUNT(*) AS appear_cnt,
    AVG(CAST(center_x AS DOUBLE)) AS avg_center_x,
    AVG(CAST(center_y AS DOUBLE)) AS avg_center_y,
    MAX(face_gender) AS face_gender,
    CAST(AVG(CAST(face_age AS DOUBLE)) AS INT) AS face_age,
    MAX(face_glasses) AS face_glasses,
    MAX(face_mask) AS face_mask,
    CONCAT(global_face_id, '_', CAST(session_seq AS STRING)) AS session_id
FROM face_session_tagged
GROUP BY
    CAST(DATE_FORMAT(TO_TIMESTAMP_LTZ(ts, 3), 'yyyy-MM-dd') AS DATE),
    CAST(EXTRACT(HOUR FROM TO_TIMESTAMP_LTZ(ts, 3)) AS TINYINT),
    global_face_id,
    device_id,
    session_seq;

INSERT INTO dws_plate_trace_1h_sink
SELECT
    CAST(DATE_FORMAT(TO_TIMESTAMP_LTZ(ts, 3), 'yyyy-MM-dd') AS DATE) AS stat_date,
    CAST(EXTRACT(HOUR FROM TO_TIMESTAMP_LTZ(ts, 3)) AS TINYINT) AS stat_hour,
    global_plate_id,
    device_id,
    MIN(ts) AS first_ts,
    MAX(ts) AS last_ts,
    COUNT(*) AS appear_cnt,
    AVG(CAST(center_x AS DOUBLE)) AS avg_center_x,
    AVG(CAST(center_y AS DOUBLE)) AS avg_center_y,
    MAX(plate_no) AS plate_no,
    MAX(vehicle_type) AS vehicle_type,
    MAX(vehicle_color) AS vehicle_color,
    MAX(vehicle_brand) AS vehicle_brand,
    CONCAT(global_plate_id, '_', CAST(session_seq AS STRING)) AS session_id
FROM plate_session_tagged
GROUP BY
    CAST(DATE_FORMAT(TO_TIMESTAMP_LTZ(ts, 3), 'yyyy-MM-dd') AS DATE),
    CAST(EXTRACT(HOUR FROM TO_TIMESTAMP_LTZ(ts, 3)) AS TINYINT),
    global_plate_id,
    device_id,
    session_seq;

INSERT INTO ads_face_app_sink
SELECT
    t.ts,
    CAST(DATE_FORMAT(TO_TIMESTAMP_LTZ(t.ts, 3), 'yyyy-MM-dd') AS DATE) AS `date`,
    t.global_face_id,
    t.device_id,
    t.face_gender,
    t.face_age,
    t.face_glasses,
    t.face_mask,
    CONCAT(t.global_face_id, '_', CAST(t.session_seq AS STRING)) AS session_id,
    b.session_start_ts,
    b.session_end_ts,
    CAST(NULL AS STRING) AS companion_face_id
FROM face_session_tagged t
JOIN face_session_bounds b
  ON t.global_face_id = b.global_face_id
 AND t.session_seq = b.session_seq;

INSERT INTO ads_plate_app_sink
SELECT
    t.ts,
    CAST(DATE_FORMAT(TO_TIMESTAMP_LTZ(t.ts, 3), 'yyyy-MM-dd') AS DATE) AS `date`,
    t.global_plate_id,
    t.plate_no,
    t.device_id,
    t.vehicle_type,
    t.vehicle_color,
    t.vehicle_brand,
    CONCAT(t.global_plate_id, '_', CAST(t.session_seq AS STRING)) AS session_id,
    b.session_start_ts,
    b.session_end_ts,
    CAST(NULL AS STRING) AS companion_plate,
    CAST(NULL AS STRING) AS companion_global_id
FROM plate_session_tagged t
JOIN plate_session_bounds b
  ON t.global_plate_id = b.global_plate_id
 AND t.session_seq = b.session_seq;
END;
