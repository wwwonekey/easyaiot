# Flink + Doris 人车四层链路执行说明

## 1. 先创建 Doris 端对象

执行：

```sql
SOURCE .scripts/doris/01_flink_doris_person_vehicle_four_layers.sql;
```

## 2. 执行 Flink DWD 作业

文件：`.scripts/flink/01_dwd_attribution_job.sql`

先替换以下占位符：

- `${KAFKA_BROKERS}`
- `${DORIS_FENODES}`
- `${DORIS_USER}`
- `${DORIS_PASSWORD}`

执行：

```bash
sql-client.sh embedded -f .scripts/flink/01_dwd_attribution_job.sql
```

## 3. 执行 Flink DWS/ADS 作业

文件：`.scripts/flink/02_dws_ads_session_job.sql`

先替换以下占位符：

- `${KAFKA_BROKERS}`
- `${DORIS_FENODES}`
- `${DORIS_USER}`
- `${DORIS_PASSWORD}`

执行：

```bash
sql-client.sh embedded -f .scripts/flink/02_dws_ads_session_job.sql
```

## 4. 快速验收 SQL

```sql
USE easyaiot_video_dw;

SELECT COUNT(*) AS c1 FROM dwd_face_detail;
SELECT COUNT(*) AS c2 FROM dwd_plate_detail;
SELECT COUNT(*) AS c3 FROM dws_face_trace_1h;
SELECT COUNT(*) AS c4 FROM dws_plate_trace_1h;
SELECT COUNT(*) AS c5 FROM ads_face_app;
SELECT COUNT(*) AS c6 FROM ads_plate_app;
```

当 Kafka 持续有 `ods.face.raw` / `ods.plate.raw` 数据输入时，6 张结果表计数会持续增长，即链路打通。

补充：`01_dwd_attribution_job.sql` 会把 DWD 明细同时写入 Kafka `dwd.face.detail` / `dwd.plate.detail`，`02_dws_ads_session_job.sql` 从这两个中间 Topic 实时消费，避免 Doris Source 的有界读取问题。
