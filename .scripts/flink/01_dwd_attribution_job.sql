-- ============================================================
-- Flink SQL Job 1：Kafka -> DWD（人脸/车牌归因明细）
-- 运行方式示例：
-- sql-client.sh embedded -f .scripts/flink/01_dwd_attribution_job.sql
--
-- 请先替换以下占位参数：
--   ${KAFKA_BROKERS}  例：localhost:9092
--   ${DORIS_FENODES}  例：localhost:8030
--   ${DORIS_USER}     例：root
--   ${DORIS_PASSWORD} 例：空字符串或真实密码
-- ============================================================

SET 'pipeline.name' = 'job_dwd_attribution_person_vehicle';
SET 'execution.checkpointing.interval' = '30 s';
SET 'table.local-time-zone' = 'Asia/Shanghai';
SET 'parallelism.default' = '2';

-- ----------------------------
-- 1) Kafka 源：人脸原始事件
-- ----------------------------
CREATE TABLE ods_face_raw_kafka (
    event_id        STRING,
    event_type      STRING,
    device_id       STRING,
    ts              BIGINT,
    track_id        STRING,
    bbox_x          INT,
    bbox_y          INT,
    bbox_w          INT,
    bbox_h          INT,
    score           DOUBLE,
    feature_id      STRING,
    feature_score   DOUBLE,
    feature_version STRING,
    face_gender     STRING,
    face_age        INT,
    face_glasses    BOOLEAN,
    face_mask       BOOLEAN,
    face_quality    DOUBLE,

    kafka_partition INT METADATA FROM 'partition' VIRTUAL,
    kafka_offset    BIGINT METADATA FROM 'offset' VIRTUAL,
    ingest_ts       AS CAST(UNIX_TIMESTAMP() * 1000 AS BIGINT),
    event_time      AS TO_TIMESTAMP_LTZ(ts, 3),
    WATERMARK FOR event_time AS event_time - INTERVAL '2' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods.face.raw',
    'properties.bootstrap.servers' = '${KAFKA_BROKERS}',
    'properties.group.id' = 'flink_dwd_face',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

-- ----------------------------
-- 2) Kafka 源：车牌原始事件
-- ----------------------------
CREATE TABLE ods_plate_raw_kafka (
    event_id        STRING,
    event_type      STRING,
    device_id       STRING,
    ts              BIGINT,
    track_id        STRING,
    bbox_x          INT,
    bbox_y          INT,
    bbox_w          INT,
    bbox_h          INT,
    score           DOUBLE,
    plate_no        STRING,
    plate_score     DOUBLE,
    plate_color     STRING,
    vehicle_type    STRING,
    vehicle_color   STRING,
    vehicle_brand   STRING,

    kafka_partition INT METADATA FROM 'partition' VIRTUAL,
    kafka_offset    BIGINT METADATA FROM 'offset' VIRTUAL,
    ingest_ts       AS CAST(UNIX_TIMESTAMP() * 1000 AS BIGINT),
    event_time      AS TO_TIMESTAMP_LTZ(ts, 3),
    WATERMARK FOR event_time AS event_time - INTERVAL '2' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ods.plate.raw',
    'properties.bootstrap.servers' = '${KAFKA_BROKERS}',
    'properties.group.id' = 'flink_dwd_plate',
    'scan.startup.mode' = 'group-offsets',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

-- ----------------------------
-- 3) Doris Sink：dwd_face_detail
-- ----------------------------
CREATE TABLE dwd_face_detail_sink (
    event_id            STRING,
    event_type          STRING,
    device_id           STRING,
    ts                  BIGINT,
    track_id            STRING,
    global_face_id      STRING,
    bbox_x              INT,
    bbox_y              INT,
    bbox_w              INT,
    bbox_h              INT,
    center_x            INT,
    center_y            INT,
    score               DOUBLE,
    feature_id          STRING,
    feature_score       DOUBLE,
    feature_version     STRING,
    face_gender         STRING,
    face_age            INT,
    face_glasses        BOOLEAN,
    face_mask           BOOLEAN,
    face_quality        DOUBLE,
    attrs               STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = '${DORIS_FENODES}',
    'table.identifier' = 'easyaiot_video_dw.dwd_face_detail',
    'username' = '${DORIS_USER}',
    'password' = '${DORIS_PASSWORD}',
    'sink.label-prefix' = 'dwd_face_attr',
    'sink.enable-2pc' = 'false',
    'sink.properties.format' = 'json',
    'sink.properties.read_json_by_line' = 'true'
);

-- ----------------------------
-- 4) Doris Sink：dwd_plate_detail
-- ----------------------------
CREATE TABLE dwd_plate_detail_sink (
    event_id            STRING,
    event_type          STRING,
    device_id           STRING,
    ts                  BIGINT,
    track_id            STRING,
    global_plate_id     STRING,
    bbox_x              INT,
    bbox_y              INT,
    bbox_w              INT,
    bbox_h              INT,
    center_x            INT,
    center_y            INT,
    score               DOUBLE,
    plate_no            STRING,
    plate_score         DOUBLE,
    plate_color         STRING,
    vehicle_type        STRING,
    vehicle_color       STRING,
    vehicle_brand       STRING,
    attrs               STRING
) WITH (
    'connector' = 'doris',
    'fenodes' = '${DORIS_FENODES}',
    'table.identifier' = 'easyaiot_video_dw.dwd_plate_detail',
    'username' = '${DORIS_USER}',
    'password' = '${DORIS_PASSWORD}',
    'sink.label-prefix' = 'dwd_plate_attr',
    'sink.enable-2pc' = 'false',
    'sink.properties.format' = 'json',
    'sink.properties.read_json_by_line' = 'true'
);

-- ----------------------------
-- 5) Kafka Sink：DWD 中间 Topic（供后续 DWS/ADS 作业实时消费）
-- ----------------------------
CREATE TABLE dwd_face_detail_kafka_sink (
    event_id            STRING,
    event_type          STRING,
    device_id           STRING,
    ts                  BIGINT,
    track_id            STRING,
    global_face_id      STRING,
    bbox_x              INT,
    bbox_y              INT,
    bbox_w              INT,
    bbox_h              INT,
    center_x            INT,
    center_y            INT,
    score               DOUBLE,
    feature_id          STRING,
    feature_score       DOUBLE,
    feature_version     STRING,
    face_gender         STRING,
    face_age            INT,
    face_glasses        BOOLEAN,
    face_mask           BOOLEAN,
    face_quality        DOUBLE,
    attrs               STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'dwd.face.detail',
    'properties.bootstrap.servers' = '${KAFKA_BROKERS}',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

CREATE TABLE dwd_plate_detail_kafka_sink (
    event_id            STRING,
    event_type          STRING,
    device_id           STRING,
    ts                  BIGINT,
    track_id            STRING,
    global_plate_id     STRING,
    bbox_x              INT,
    bbox_y              INT,
    bbox_w              INT,
    bbox_h              INT,
    center_x            INT,
    center_y            INT,
    score               DOUBLE,
    plate_no            STRING,
    plate_score         DOUBLE,
    plate_color         STRING,
    vehicle_type        STRING,
    vehicle_color       STRING,
    vehicle_brand       STRING,
    attrs               STRING
) WITH (
    'connector' = 'kafka',
    'topic' = 'dwd.plate.detail',
    'properties.bootstrap.servers' = '${KAFKA_BROKERS}',
    'format' = 'json',
    'json.fail-on-missing-field' = 'false',
    'json.ignore-parse-errors' = 'true'
);

CREATE TEMPORARY VIEW face_dwd_enriched AS
SELECT
    event_id,
    event_type,
    device_id,
    ts,
    track_id,
    CASE
        WHEN feature_id IS NOT NULL AND CHAR_LENGTH(TRIM(feature_id)) > 0
             AND COALESCE(feature_score, 0.0) >= 0.80
            THEN feature_id
        ELSE MD5(
            CONCAT_WS(
                '|',
                COALESCE(device_id, ''),
                COALESCE(track_id, ''),
                COALESCE(face_gender, 'unknown'),
                CAST(COALESCE(face_age, -1) AS STRING),
                CAST(COALESCE(face_glasses, FALSE) AS STRING),
                CAST(COALESCE(face_mask, FALSE) AS STRING)
            )
        )
    END AS global_face_id,
    bbox_x,
    bbox_y,
    bbox_w,
    bbox_h,
    CAST(COALESCE(bbox_x, 0) + COALESCE(bbox_w, 0) / 2 AS INT) AS center_x,
    CAST(COALESCE(bbox_y, 0) + COALESCE(bbox_h, 0) / 2 AS INT) AS center_y,
    score,
    feature_id,
    feature_score,
    feature_version,
    COALESCE(face_gender, 'unknown') AS face_gender,
    face_age,
    COALESCE(face_glasses, FALSE) AS face_glasses,
    COALESCE(face_mask, FALSE) AS face_mask,
    face_quality,
    CONCAT(
        '{"kafka_partition":', CAST(kafka_partition AS STRING),
        ',"kafka_offset":', CAST(kafka_offset AS STRING),
        ',"ingest_ts":', CAST(ingest_ts AS STRING),
        '}'
    ) AS attrs
FROM ods_face_raw_kafka
WHERE event_id IS NOT NULL AND CHAR_LENGTH(TRIM(event_id)) > 0;

CREATE TEMPORARY VIEW plate_dwd_enriched AS
SELECT
    event_id,
    event_type,
    device_id,
    ts,
    track_id,
    CASE
        WHEN plate_no IS NOT NULL AND CHAR_LENGTH(TRIM(plate_no)) > 0
             AND COALESCE(plate_score, 0.0) >= 0.80
            THEN MD5(plate_no)
        ELSE MD5(
            CONCAT_WS(
                '|',
                COALESCE(device_id, ''),
                COALESCE(track_id, ''),
                COALESCE(vehicle_type, ''),
                COALESCE(vehicle_color, '')
            )
        )
    END AS global_plate_id,
    bbox_x,
    bbox_y,
    bbox_w,
    bbox_h,
    CAST(COALESCE(bbox_x, 0) + COALESCE(bbox_w, 0) / 2 AS INT) AS center_x,
    CAST(COALESCE(bbox_y, 0) + COALESCE(bbox_h, 0) / 2 AS INT) AS center_y,
    score,
    plate_no,
    plate_score,
    plate_color,
    vehicle_type,
    vehicle_color,
    vehicle_brand,
    CONCAT(
        '{"kafka_partition":', CAST(kafka_partition AS STRING),
        ',"kafka_offset":', CAST(kafka_offset AS STRING),
        ',"ingest_ts":', CAST(ingest_ts AS STRING),
        '}'
    ) AS attrs
FROM ods_plate_raw_kafka
WHERE event_id IS NOT NULL AND CHAR_LENGTH(TRIM(event_id)) > 0;

-- ----------------------------
-- 6) 四路写入（Doris + Kafka）
-- 规则：
--   人脸强ID: feature_id 非空且 feature_score >= 0.80
--   车牌强ID: plate_no 非空且 plate_score >= 0.80 -> MD5(plate_no)
--   弱ID按文档规则拼接后 MD5
-- ----------------------------
EXECUTE STATEMENT SET
BEGIN
INSERT INTO dwd_face_detail_sink
SELECT * FROM face_dwd_enriched;

INSERT INTO dwd_face_detail_kafka_sink
SELECT * FROM face_dwd_enriched;

INSERT INTO dwd_plate_detail_sink
SELECT * FROM plate_dwd_enriched;

INSERT INTO dwd_plate_detail_kafka_sink
SELECT * FROM plate_dwd_enriched;
END;
