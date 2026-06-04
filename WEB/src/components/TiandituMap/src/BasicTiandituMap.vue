<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue';
import 'ol/ol.css';
import { useOpenLayersMap } from '../composables/useOpenLayersMap';
import { DEFAULT_MAP_CENTER, DEFAULT_MAP_ZOOM } from '../constants';
import MapToolbar from './MapToolbar.vue';
import type { BasicTiandituMapProps, LngLat } from '../types';

const props = withDefaults(defineProps<BasicTiandituMapProps>(), {
  center: () => DEFAULT_MAP_CENTER,
  zoom: DEFAULT_MAP_ZOOM,
  baseMapType: 'vec',
  showToolbar: true,
  showScaleLine: true,
  clickable: false,
});

const emit = defineEmits<{
  (e: 'map-click', payload: LngLat): void;
  (e: 'ready'): void;
}>();

const containerRef = ref<HTMLElement | null>(null);

const {
  map,
  baseMapType,
  tryInitMap,
  updateSize,
  switchBaseMap,
  flyTo,
  fitExtent,
} = useOpenLayersMap(containerRef, {
  center: props.center,
  zoom: props.zoom,
  baseMapType: props.baseMapType,
  showScaleLine: props.showScaleLine,
  onClick: props.clickable
    ? ({ lng, lat }) => emit('map-click', { lng, lat })
    : undefined,
  onReady: () => emit('ready'),
});

let bootRaf = 0;
let bootAttempts = 0;
const bootTimers: ReturnType<typeof setTimeout>[] = [];
const MAX_BOOT_ATTEMPTS = 200;

function scheduleBoot() {
  if (map.value || bootAttempts >= MAX_BOOT_ATTEMPTS) return;
  bootAttempts += 1;
  cancelAnimationFrame(bootRaf);
  bootRaf = requestAnimationFrame(() => {
    if (!tryInitMap()) scheduleBoot();
  });
}

onMounted(() => {
  scheduleBoot();
  for (const delay of [50, 150, 400, 800]) {
    bootTimers.push(window.setTimeout(() => tryInitMap(), delay));
  }
});

onBeforeUnmount(() => {
  cancelAnimationFrame(bootRaf);
  bootTimers.forEach((id) => clearTimeout(id));
  bootTimers.length = 0;
});

watch(() => props.baseMapType, (t) => switchBaseMap(t));

defineExpose({ map, flyTo, fitExtent, switchBaseMap, baseMapType, updateSize, tryInitMap });
</script>

<template>
  <div class="basic-tianditu-map">
    <div ref="containerRef" class="basic-tianditu-map__canvas" />
    <MapToolbar
      v-if="showToolbar"
      :base-map-type="baseMapType"
      @switch="switchBaseMap"
    />
    <slot />
  </div>
</template>

<style scoped lang="less">
.basic-tianditu-map {
  position: relative;
  flex: 1;
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  border-radius: 8px;
  background: #f0f2f5;

  &__canvas {
    position: absolute;
    inset: 0;
    z-index: 0;
  }
}
</style>

<style lang="less">
.tianditu-map-popup {
  background: #fff;
  border-radius: 10px;
  box-shadow: 0 8px 24px rgb(15 23 42 / 12%);
  padding: 10px 14px;
  min-width: 140px;
  border: 1px solid rgb(66 135 252 / 15%);
  pointer-events: none;

  &__title {
    font-size: 13px;
    font-weight: 600;
    color: #1e293b;
  }

  &__sub {
    margin-top: 4px;
    font-size: 11px;
    color: #64748b;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  }
}
</style>
