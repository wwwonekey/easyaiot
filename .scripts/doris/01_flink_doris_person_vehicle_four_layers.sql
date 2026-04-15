-- ============================================================
-- Flink + Doris 人/车四层宽表落地脚本
-- 说明：
-- 1) 执行前请确认 Doris 版本 >= 2.0
-- 2) 默认按单副本(replication_num=1)编写，便于本地/测试环境直接跑通
-- 3) 生产环境请按集群规模调整副本数、分桶数、动态分区策略
-- ============================================================

CREATE DATABASE IF NOT EXISTS easyaiot_video_dw;
USE easyaiot_video_dw;

-- ----------------------------
-- 0. 维度表：设备拓扑
-- ----------------------------
CREATE TABLE IF NOT EXISTS dim_device_topo (
    from_device_id  VARCHAR(64),
    to_device_id    VARCHAR(64),
    relation        VARCHAR(16) DEFAULT 'adjacent',
    avg_transit_sec INT
)
UNIQUE KEY(from_device_id, to_device_id)
DISTRIBUTED BY HASH(from_device_id) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);

-- ----------------------------
-- 1. ODS 层
-- ----------------------------
CREATE TABLE IF NOT EXISTS ods_face_event (
    event_id            VARCHAR(64),
    event_type          VARCHAR(32),
    device_id           VARCHAR(64),
    ts                  BIGINT,
    ingest_ts           BIGINT,
    kafka_partition     INT,
    kafka_offset        BIGINT,

    track_id            VARCHAR(64),
    bbox_x              INT,
    bbox_y              INT,
    bbox_w              INT,
    bbox_h              INT,
    score               DOUBLE,

    feature_id          VARCHAR(64),
    feature_score       DOUBLE,
    feature_version     VARCHAR(16),

    face_gender         VARCHAR(8),
    face_age            INT,
    face_glasses        BOOLEAN,
    face_mask           BOOLEAN,
    face_quality        DOUBLE
)
DUPLICATE KEY(event_id)
DISTRIBUTED BY HASH(device_id) BUCKETS 32
PROPERTIES (
    "replication_num" = "1"
);

CREATE TABLE IF NOT EXISTS ods_plate_event (
    event_id            VARCHAR(64),
    event_type          VARCHAR(32),
    device_id           VARCHAR(64),
    ts                  BIGINT,
    ingest_ts           BIGINT,
    kafka_partition     INT,
    kafka_offset        BIGINT,

    track_id            VARCHAR(64),
    bbox_x              INT,
    bbox_y              INT,
    bbox_w              INT,
    bbox_h              INT,
    score               DOUBLE,

    plate_no            VARCHAR(16),
    plate_score         DOUBLE,
    plate_color         VARCHAR(16),

    vehicle_type        VARCHAR(16),
    vehicle_color       VARCHAR(16),
    vehicle_brand       VARCHAR(32)
)
DUPLICATE KEY(event_id)
DISTRIBUTED BY HASH(device_id) BUCKETS 32
PROPERTIES (
    "replication_num" = "1"
);

-- ----------------------------
-- 2. DWD 层
-- ----------------------------
CREATE TABLE IF NOT EXISTS dwd_face_detail (
    event_id            VARCHAR(64),
    event_type          VARCHAR(32),
    device_id           VARCHAR(64),
    ts                  BIGINT,
    track_id            VARCHAR(64),

    global_face_id      VARCHAR(64),

    bbox_x              INT,
    bbox_y              INT,
    bbox_w              INT,
    bbox_h              INT,
    center_x            INT,
    center_y            INT,
    score               DOUBLE,

    feature_id          VARCHAR(64),
    feature_score       DOUBLE,
    feature_version     VARCHAR(16),

    face_gender         VARCHAR(8),
    face_age            INT,
    face_glasses        BOOLEAN,
    face_mask           BOOLEAN,
    face_quality        DOUBLE,

    attrs               JSON
)
UNIQUE KEY(event_id)
DISTRIBUTED BY HASH(device_id) BUCKETS 32
PROPERTIES (
    "enable_unique_key_merge_on_write" = "true",
    "replication_num" = "1"
);

CREATE TABLE IF NOT EXISTS dwd_plate_detail (
    event_id            VARCHAR(64),
    event_type          VARCHAR(32),
    device_id           VARCHAR(64),
    ts                  BIGINT,
    track_id            VARCHAR(64),

    global_plate_id     VARCHAR(64),

    bbox_x              INT,
    bbox_y              INT,
    bbox_w              INT,
    bbox_h              INT,
    center_x            INT,
    center_y            INT,
    score               DOUBLE,

    plate_no            VARCHAR(16),
    plate_score         DOUBLE,
    plate_color         VARCHAR(16),

    vehicle_type        VARCHAR(16),
    vehicle_color       VARCHAR(16),
    vehicle_brand       VARCHAR(32),

    attrs               JSON
)
UNIQUE KEY(event_id)
DISTRIBUTED BY HASH(device_id) BUCKETS 32
PROPERTIES (
    "enable_unique_key_merge_on_write" = "true",
    "replication_num" = "1"
);

-- ----------------------------
-- 3. DWS 层
-- ----------------------------
CREATE TABLE IF NOT EXISTS dws_face_trace_1h (
    stat_date           DATE,
    stat_hour           TINYINT,
    global_face_id      VARCHAR(64),
    device_id           VARCHAR(64),

    first_ts            BIGINT,
    last_ts             BIGINT,
    appear_cnt          BIGINT,

    avg_center_x        DOUBLE,
    avg_center_y        DOUBLE,

    face_gender         VARCHAR(8),
    face_age            INT,
    face_glasses        BOOLEAN,
    face_mask           BOOLEAN,

    session_id          VARCHAR(64)
)
DUPLICATE KEY(stat_date, stat_hour, global_face_id, device_id)
DISTRIBUTED BY HASH(global_face_id) BUCKETS 32
PROPERTIES (
    "replication_num" = "1"
);

CREATE TABLE IF NOT EXISTS dws_plate_trace_1h (
    stat_date           DATE,
    stat_hour           TINYINT,
    global_plate_id     VARCHAR(64),
    device_id           VARCHAR(64),

    first_ts            BIGINT,
    last_ts             BIGINT,
    appear_cnt          BIGINT,

    avg_center_x        DOUBLE,
    avg_center_y        DOUBLE,

    plate_no            VARCHAR(16),
    vehicle_type        VARCHAR(16),
    vehicle_color       VARCHAR(16),
    vehicle_brand       VARCHAR(32),

    session_id          VARCHAR(64)
)
DUPLICATE KEY(stat_date, stat_hour, global_plate_id, device_id)
DISTRIBUTED BY HASH(global_plate_id) BUCKETS 32
PROPERTIES (
    "replication_num" = "1"
);

-- ----------------------------
-- 4. ADS 层
-- ----------------------------
CREATE TABLE IF NOT EXISTS ads_face_app (
    ts                  BIGINT,
    date                DATE,
    global_face_id      VARCHAR(64),
    device_id           VARCHAR(64),

    face_gender         VARCHAR(8),
    face_age            INT,
    face_glasses        BOOLEAN,
    face_mask           BOOLEAN,

    session_id          VARCHAR(64),
    session_start_ts    BIGINT,
    session_end_ts      BIGINT,

    companion_face_id   VARCHAR(64)
)
DUPLICATE KEY(global_face_id, ts)
DISTRIBUTED BY HASH(global_face_id) BUCKETS 16
PROPERTIES (
    "replication_num" = "1"
);

CREATE TABLE IF NOT EXISTS ads_plate_app (
    ts                  BIGINT,
    date                DATE,
    global_plate_id     VARCHAR(64),
    plate_no            VARCHAR(16),
    device_id           VARCHAR(64),

    vehicle_type        VARCHAR(16),
    vehicle_color       VARCHAR(16),
    vehicle_brand       VARCHAR(32),

    session_id          VARCHAR(64),
    session_start_ts    BIGINT,
    session_end_ts      BIGINT,

    companion_plate     VARCHAR(16),
    companion_global_id VARCHAR(64)
)
DUPLICATE KEY(global_plate_id, ts)
DISTRIBUTED BY HASH(global_plate_id) BUCKETS 16
PROPERTIES (
    "replication_num" = "1"
);

-- ----------------------------
-- 5. ODS 直接导入（可选）
-- ----------------------------
-- 注意：
-- 1) 若你使用 Flink 先写 ODS，则无需创建下述 Routine Load
-- 2) 若你选择 Doris 直连 Kafka 入 ODS，请先将 broker/topic 替换成真实地址
-- 3) CREATE ROUTINE LOAD 不支持 IF NOT EXISTS，重复执行前请先 STOP/PAUSE/DROP

-- 人脸 ODS Routine Load 模板
-- CREATE ROUTINE LOAD ods_face_load ON ods_face_event
-- COLUMNS(
--     event_id, event_type, device_id, ts, track_id, bbox_x, bbox_y, bbox_w, bbox_h, score,
--     feature_id, feature_score, feature_version, face_gender, face_age, face_glasses, face_mask, face_quality,
--     ingest_ts = UNIX_TIMESTAMP() * 1000, kafka_partition, kafka_offset
-- )
-- PROPERTIES(
--     "desired_concurrent_number" = "3",
--     "format" = "json",
--     "strict_mode" = "false"
-- )
-- FROM KAFKA(
--     "kafka_broker_list" = "kafka:9092",
--     "kafka_topic" = "ods.face.raw",
--     "property.group.id" = "doris_ods_face"
-- );

-- 车牌 ODS Routine Load 模板
-- CREATE ROUTINE LOAD ods_plate_load ON ods_plate_event
-- COLUMNS(
--     event_id, event_type, device_id, ts, track_id, bbox_x, bbox_y, bbox_w, bbox_h, score,
--     plate_no, plate_score, plate_color, vehicle_type, vehicle_color, vehicle_brand,
--     ingest_ts = UNIX_TIMESTAMP() * 1000, kafka_partition, kafka_offset
-- )
-- PROPERTIES(
--     "desired_concurrent_number" = "3",
--     "format" = "json",
--     "strict_mode" = "false"
-- )
-- FROM KAFKA(
--     "kafka_broker_list" = "kafka:9092",
--     "kafka_topic" = "ods.plate.raw",
--     "property.group.id" = "doris_ods_plate"
-- );
