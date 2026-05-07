package com.basiclab.iot.sink.jackson;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonDeserializer;

import java.io.IOException;

/**
 * Kafka 等设备消息 JSON 中 deviceId 可能为数字（IoT 主键）或字符串（如 GB28181 通道复合 ID）。
 */
public class IotDeviceIdDeserializer extends JsonDeserializer<String> {

    @Override
    public String deserialize(JsonParser p, DeserializationContext ctxt) throws IOException {
        JsonToken t = p.currentToken();
        if (t == JsonToken.VALUE_NULL) {
            return null;
        }
        if (t == JsonToken.VALUE_NUMBER_INT || t == JsonToken.VALUE_NUMBER_FLOAT) {
            return p.getValueAsString();
        }
        if (t == JsonToken.VALUE_STRING) {
            return p.getText();
        }
        return p.getValueAsString();
    }
}
