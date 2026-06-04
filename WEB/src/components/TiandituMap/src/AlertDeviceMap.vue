<script setup lang="ts">
import { Spin } from 'ant-design-vue';
import { computed, nextTick, ref, watch } from 'vue';
import BasicTiandituMap from './BasicTiandituMap.vue';
import MapFloatToolbar from './components/MapFloatToolbar.vue';
import MapToolbarStat from './components/MapToolbarStat.vue';
import { useMapMarkers } from '../composables/useMapMarkers';
import { useAlertMapData, type AlertMapQuery } from '../business/useAlertMapData';
import type { MapMarkerData, TiandituBaseMapType } from '../types';

const props = withDefaults(defineProps<{
  query?: AlertMapQuery;
  showCameras?: boolean;
  showAlerts?: boolean;
  height?: string;
  enableCluster?: boolean;
  /** 嵌入全屏弹窗：去掉 Card 外壳，铺满地图区域 */
  embedded?: boolean;
}>(), {
  showCameras: true,
  showAlerts: true,
  height: '100%',
  enableCluster: true,
  embedded: false,
});

const cardBodyStyle = computed(() => ({
  padding: 0,
  height: props.height,
  minHeight: 0,
}));

const emit = defineEmits<{
  (e: 'marker-click', marker: MapMarkerData): void;
  (e: 'alert-click', alert: Record<string, unknown>): void;
}>();

const mapRef = ref<InstanceType<typeof BasicTiandituMap> | null>(null);
const baseMapType = ref<TiandituBaseMapType>('vec');
const alertData = useAlertMapData();

const markers = useMapMarkers({
  map: computed(() => mapRef.value?.map ?? null),
  onMarkerClick: (m) => {
    emit('marker-click', m);
    if (m.kind === 'alert') emit('alert-click', m.payload || {});
  },
  enableCluster: computed(() => props.enableCluster),
});

const markerList = computed(() => {
  if (props.showCameras && props.showAlerts) return alertData.toCombinedMarkers();
  if (props.showAlerts) return alertData.toAlertMarkers();
  if (props.showCameras) return alertData.toCameraMarkers();
  return [];
});

async function refresh() {
  await alertData.loadAlerts(props.query);
  markers.setMarkers(markerList.value);
  markers.fitToMarkers();
  await nextTick();
  mapRef.value?.tryInitMap?.();
  mapRef.value?.updateSize?.();
  requestAnimationFrame(() => {
    mapRef.value?.tryInitMap?.();
    mapRef.value?.updateSize?.();
  });
}

async function onMapReady() {
  await nextTick();
  mapRef.value?.updateSize?.();
  void refresh();
  requestAnimationFrame(() => mapRef.value?.updateSize?.());
  window.setTimeout(() => mapRef.value?.updateSize?.(), 200);
  window.setTimeout(() => mapRef.value?.updateSize?.(), 500);
}

function updateMapSize() {
  mapRef.value?.tryInitMap?.();
  mapRef.value?.updateSize?.();
}

watch(baseMapType, (type) => {
  mapRef.value?.switchBaseMap(type);
});

watch(() => props.query, refresh, { deep: true });
watch(() => [props.showCameras, props.showAlerts], () => {
  markers.setMarkers(markerList.value);
});

function flyTo(lng: number, lat: number, zoom = 16) {
  mapRef.value?.flyTo(lng, lat, zoom);
}

function handleFitAll() {
  markers.fitToMarkers();
}

defineExpose({ refresh, alerts: alertData.alertsWithLocation, flyTo, updateMapSize, alertData });
</script>

<template>
  <div
    class="alert-device-map"
    :class="{ 'alert-device-map--embedded': embedded }"
    :style="embedded ? { height } : undefined"
  >
    <Spin
      :spinning="alertData.loading.value"
      :wrapper-class-name="embedded ? 'alert-device-map__spin' : undefined"
    >
      <a-card
        v-if="!embedded"
        :bordered="false"
        :body-style="cardBodyStyle"
        class="alert-device-map__card"
      >
        <BasicTiandituMap ref="mapRef" :show-toolbar="false" @ready="onMapReady">
          <MapFloatToolbar
            v-model:base-map-type="baseMapType"
            :loading="alertData.loading.value"
            @refresh="refresh"
            @fit="handleFitAll"
          >
            <template #tags>
              <MapToolbarStat variant="camera" label="摄像头" :count="alertData.deviceData.devices.value.length" />
              <MapToolbarStat variant="alert" label="告警" :count="alertData.alertsWithLocation.value.length" />
            </template>
          </MapFloatToolbar>
        </BasicTiandituMap>
      </a-card>
      <div v-else class="alert-device-map__map" :style="{ height }">
        <BasicTiandituMap ref="mapRef" :show-toolbar="false" @ready="onMapReady">
          <MapFloatToolbar
            v-model:base-map-type="baseMapType"
            :loading="alertData.loading.value"
            @refresh="refresh"
            @fit="handleFitAll"
          >
            <template #tags>
              <MapToolbarStat variant="camera" label="摄像头" :count="alertData.deviceData.devices.value.length" />
              <MapToolbarStat variant="alert" label="告警" :count="alertData.alertsWithLocation.value.length" />
            </template>
          </MapFloatToolbar>
        </BasicTiandituMap>
      </div>
    </Spin>
  </div>
</template>

<style scoped lang="less">
.alert-device-map {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgb(0 0 0 / 4%);

  &--embedded {
    width: 100%;
    height: 100%;
    min-height: 0;
    border-radius: 0;
    box-shadow: none;
    background: transparent;
  }

  &__map {
    flex: 1;
    width: 100%;
    min-width: 0;
    min-height: 0;
    padding: 0;
    background: #e8ebf2;
    position: relative;
    overflow: hidden;

    :deep(.basic-tianditu-map) {
      position: absolute;
      inset: 0;
      width: 100%;
      height: auto;
      min-height: 0;
      border-radius: 0;
    }
  }

  &__card:deep(.ant-card) {
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  &__card:deep(.ant-card-body) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  &--embedded :deep(.alert-device-map__spin),
  &--embedded :deep(.ant-spin-nested-loading),
  &--embedded :deep(.ant-spin-container) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  :deep(.ant-spin-nested-loading),
  :deep(.ant-spin-container) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  &--embedded :deep(.basic-tianditu-map) {
    position: absolute;
    inset: 0;
    width: 100%;
    height: auto;
    min-height: 0;
  }

  :deep(.basic-tianditu-map) {
    flex: 1;
    width: 100%;
    min-height: 0;
    height: 100%;
  }

  &--embedded :deep(.basic-tianditu-map__canvas) {
    width: 100%;
    height: 100%;
  }
}
</style>
