package com.basiclab.iot.sink.domain.model;

import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.Data;

import java.util.List;

/**
 * 车牌匹配 Kafka 消息 DTO
 */
@Data
public class PlateMatchingMessage {

    @JsonAlias("task_id")
    private Integer taskId;

    @JsonAlias("task_name")
    private String taskName;

    @JsonAlias("task_type")
    private String taskType;

    @JsonAlias("device_id")
    private String deviceId;

    @JsonAlias("device_name")
    private String deviceName;

    @JsonAlias("library_id")
    private Integer libraryId;

    @JsonAlias("library_name")
    private String libraryName;

    @JsonAlias("plate_no")
    private String plateNo;

    @JsonAlias("plate_color")
    private String plateColor;

    @JsonAlias("plate_image_path")
    private String plateImagePath;

    @JsonAlias("detect_conf")
    private Double detectConf;

    @JsonAlias("alert_id")
    private Integer alertId;

    private List<Integer> rect;

    private List<List<Double>> landmarks;

    private String timestamp;
}
