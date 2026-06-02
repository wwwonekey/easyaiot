package com.basiclab.iot.sink.service;

import com.basiclab.iot.sink.domain.model.PlateMatchingMessage;

/**
 * 车牌匹配业务服务
 */
public interface PlateMatchingService {

    /**
     * 处理 Kafka 车牌匹配消息：调用 VIDEO 服务完成库内匹配并落库
     */
    void process(PlateMatchingMessage message);
}
