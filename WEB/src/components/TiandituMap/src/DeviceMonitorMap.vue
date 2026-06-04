<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import BasicTiandituMap from './BasicTiandituMap.vue';
import MapFloatToolbar from './components/MapFloatToolbar.vue';
import MapToolbarStat from './components/MapToolbarStat.vue';
import { useMapMarkers } from '../composables/useMapMarkers';
import { useDeviceMapData } from '../business/useDeviceMapData';
import type { MapMarkerData, TiandituBaseMapType } from '../types';

const props = withDefaults(defineProps<{
  directoryId?: number;
  filterOnline?: boolean | null;
  height?: string;
  autoFit?: boolean;
  enableCluster?: boolean;
}>(), {
  filterOnline: null,
  height: '100%',
  autoFit: true,
  enableCluster: true,
});

const emit = defineEmits<{
  (e: 'marker-click', marker: MapMarkerData): void;
}>();

const cardBodyStyle = computed(() => ({
  padding: 0,
  height: props.height,
  minHeight: 0,
}));

const mapRef = ref<InstanceType<typeof BasicTiandituMap> | null>(null);
const baseMapType = ref<TiandituBaseMapType>('vec');
const deviceData = useDeviceMapData();

const markers = useMapMarkers({
  map: computed(() => mapRef.value?.map ?? null),
  onMarkerClick: (m) => emit('marker-click', m),
  enableCluster: computed(() => props.enableCluster),
});

const markerCount = computed(() => markers.markers.value.length);

async function refresh() {
  await deviceData.load({
    directory_id: props.directoryId,
    has_location: true,
  });
  markers.setMarkers(deviceData.toMarkers(props.filterOnline));
  if (props.autoFit) markers.fitToMarkers();
  await nextTick();
  mapRef.value?.updateSize?.();
  requestAnimationFrame(() => mapRef.value?.updateSize?.());
}

watch(baseMapType, (type) => {
  mapRef.value?.switchBaseMap(type);
});

onMounted(() => {
  if (mapRef.value?.map) refresh();
});
watch(() => [props.directoryId, props.filterOnline], refresh);

function flyTo(lng: number, lat: number, zoom = 16) {
  mapRef.value?.flyTo(lng, lat, zoom);
}

function updateMapSize() {
  mapRef.value?.tryInitMap?.();
  mapRef.value?.updateSize?.();
}

function handleFitAll() {
  markers.fitToMarkers();
}

defineExpose({
  refresh,
  devices: deviceData.devices,
  flyTo,
  updateMapSize,
  fitToMarkers: () => markers.fitToMarkers(),
  findById: deviceData.findById,
});
</script>

<template>
  <a-card
    :bordered="false"
    :body-style="cardBodyStyle"
    class="device-monitor-map"
  >
    <a-spin :spinning="deviceData.loading.value" wrapper-class-name="device-monitor-map__spin">
      <BasicTiandituMap ref="mapRef" :show-toolbar="false" @ready="refresh">
        <MapFloatToolbar
          v-model:base-map-type="baseMapType"
          :loading="deviceData.loading.value"
          @refresh="refresh"
          @fit="handleFitAll"
        >
          <template #tags>
            <MapToolbarStat variant="camera" label="摄像头" :count="markerCount" />
            <MapToolbarStat v-if="deviceData.error.value" variant="error" :value="deviceData.error.value" />
          </template>
        </MapFloatToolbar>
      </BasicTiandituMap>
    </a-spin>
  </a-card>
</template>

<style scoped lang="less">
.device-monitor-map {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgb(0 0 0 / 4%);

  &:deep(.ant-card) {
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  :deep(.ant-card-body) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  &__spin,
  :deep(.device-monitor-map__spin),
  :deep(.ant-spin-nested-loading),
  :deep(.ant-spin-container) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  :deep(.basic-tianditu-map) {
    flex: 1;
    width: 100%;
    min-height: 0;
    height: 100%;
  }
}
</style>
