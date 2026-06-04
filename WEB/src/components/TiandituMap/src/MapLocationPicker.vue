<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import BasicTiandituMap from './BasicTiandituMap.vue';
import { useMapPicker } from '../composables/useMapPicker';
import { toMercator } from '../core/coordUtils';
import { createCircleMarkerStyle } from '../core/markerStyles';
import { MAP_LAYER_ZINDEX } from '../constants';
import { Button } from '@/components/Button';
import { CollapseContainer } from '@/components/Container';
import type { MapPickResult } from '../types';

const props = withDefaults(defineProps<{
  modelValue?: MapPickResult | null;
  height?: string;
  /** 嵌入大屏弹窗：精简侧栏，隐藏重复确认区 */
  embedded?: boolean;
}>(), {
  modelValue: null,
  height: '480px',
  embedded: false,
});

const emit = defineEmits<{
  (e: 'update:modelValue', value: MapPickResult | null): void;
  (e: 'confirm', value: MapPickResult): void;
}>();

const mapRef = ref<InstanceType<typeof BasicTiandituMap> | null>(null);
const {
  mode,
  lng,
  lat,
  address,
  keyword,
  results,
  searching,
  page,
  total,
  pageSize,
  pickFromClick,
  search,
  selectPoi,
  reset,
  confirm,
} = useMapPicker();
let pickerLayer: VectorLayer<VectorSource> | null = null;

function ensurePickerLayer() {
  const olMap = mapRef.value?.map;
  if (!olMap || pickerLayer) return;

  pickerLayer = new VectorLayer({
    source: new VectorSource(),
    zIndex: MAP_LAYER_ZINDEX.picker,
    style: createCircleMarkerStyle({ color: '#e63946', radius: 10 }),
  });
  olMap.addLayer(pickerLayer);
}

function setPickerMarker(lngVal: number, latVal: number) {
  ensurePickerLayer();
  const source = pickerLayer?.getSource();
  if (!source) return;
  source.clear();
  source.addFeature(new Feature({ geometry: new Point(toMercator(lngVal, latVal)) }));
  mapRef.value?.flyTo(lngVal, latVal, 15);
}

async function onMapClick({ lng: lngVal, lat: latVal }: { lng: number; lat: number }) {
  if (mode.value !== 'click') return;
  await pickFromClick(lngVal, latVal);
  setPickerMarker(lngVal, latVal);
  emitPick();
}

async function onSelectPoi(item: (typeof results.value)[0]) {
  const result = await selectPoi(item);
  if (!result) return;
  setPickerMarker(result.lng, result.lat);
  emitPick();
}

function emitPick() {
  const val = confirm();
  emit('update:modelValue', val);
}

function handleConfirm() {
  const val = confirm();
  if (val) emit('confirm', val);
}

function handleReset() {
  reset();
  pickerLayer?.getSource()?.clear();
  emit('update:modelValue', null);
}

async function onMapReady() {
  ensurePickerLayer();
  await nextTick();
  mapRef.value?.updateSize?.();
}

onMounted(() => {
  if (props.modelValue?.lng != null && props.modelValue?.lat != null) {
    lng.value = props.modelValue.lng;
    lat.value = props.modelValue.lat;
    address.value = props.modelValue.address || '';
    setPickerMarker(props.modelValue.lng, props.modelValue.lat);
  }
});

watch(() => props.modelValue, (v) => {
  if (v?.lng != null && v?.lat != null) {
    lng.value = v.lng;
    lat.value = v.lat;
    address.value = v.address || '';
    setPickerMarker(v.lng, v.lat);
  }
});
</script>

<template>
  <a-layout
    class="map-location-picker"
    :class="{ 'map-location-picker--embedded': embedded }"
    :style="{ height: props.height }"
  >
    <a-layout-sider
      :width="embedded ? 300 : 320"
      theme="light"
      class="map-location-picker__sider"
    >
      <div v-if="embedded" class="map-location-picker__panel map-location-picker__panel--plain">
        <div class="map-location-picker__panel-title">定位</div>
        <a-tabs v-model:activeKey="mode" size="small" class="map-location-picker__tabs">
          <a-tab-pane key="click" tab="点选" />
          <a-tab-pane key="search" tab="搜索" />
        </a-tabs>

        <template v-if="mode === 'search'">
          <a-input-search
            v-model:value="keyword"
            placeholder="地点、道路、建筑"
            :loading="searching"
            class="map-location-picker__search"
            @search="() => search(1)"
          />
          <a-list
            class="map-location-picker__results"
            size="small"
            :data-source="results"
            :locale="{ emptyText: '无匹配结果' }"
          >
            <template #renderItem="{ item }">
              <a-list-item class="map-location-picker__result" @click="onSelectPoi(item)">
                <a-list-item-meta :title="item.name" :description="item.address" />
              </a-list-item>
            </template>
          </a-list>
          <a-pagination
            v-if="total > pageSize"
            size="small"
            simple
            :current="page"
            :total="total"
            :page-size="pageSize"
            class="map-location-picker__pager"
            @change="search"
          />
        </template>

        <p v-else class="map-location-picker__hint">在地图区域单击放置标记，坐标将写入右侧属性栏</p>
      </div>

      <CollapseContainer v-else title="位置选择" :can-expan="false" class="map-location-picker__panel">
        <a-tabs v-model:activeKey="mode" size="small">
          <a-tab-pane key="click" tab="点击选点" />
          <a-tab-pane key="search" tab="搜索定位" />
        </a-tabs>

        <template v-if="mode === 'search'">
          <a-input-search
            v-model:value="keyword"
            placeholder="搜索地点/企业"
            enter-button="搜索"
            :loading="searching"
            class="map-location-picker__search"
            @search="() => search(1)"
          />
          <a-list
            class="map-location-picker__results"
            size="small"
            :data-source="results"
            :locale="{ emptyText: '暂无结果' }"
          >
            <template #renderItem="{ item }">
              <a-list-item class="map-location-picker__result" @click="onSelectPoi(item)">
                <a-list-item-meta :title="item.name" :description="item.address" />
              </a-list-item>
            </template>
          </a-list>
          <a-pagination
            v-if="total > pageSize"
            size="small"
            :current="page"
            :total="total"
            :page-size="pageSize"
            class="map-location-picker__pager"
            @change="search"
          />
        </template>

        <a-divider class="map-location-picker__divider" />
        <a-descriptions bordered size="small" :column="1">
          <a-descriptions-item label="经度">{{ lng ?? '—' }}</a-descriptions-item>
          <a-descriptions-item label="纬度">{{ lat ?? '—' }}</a-descriptions-item>
          <a-descriptions-item label="地址">{{ address || '—' }}</a-descriptions-item>
        </a-descriptions>

        <a-space class="map-location-picker__actions">
          <Button @click="handleReset">重置</Button>
          <Button type="primary" :disabled="lng == null" @click="handleConfirm">确认</Button>
        </a-space>
      </CollapseContainer>
    </a-layout-sider>

    <a-layout-content class="map-location-picker__map">
      <BasicTiandituMap
        ref="mapRef"
        clickable
        @map-click="onMapClick"
        @ready="onMapReady"
      />
    </a-layout-content>
  </a-layout>
</template>

<style scoped lang="less">
.map-location-picker {
  width: 100%;
  background: #fff;
  border-radius: 8px;
  overflow: hidden;

  &--embedded {
    border-radius: 0;
    background: #fff;
  }

  &--embedded &__sider {
    background: #fafbfd !important;
    border-right: 1px solid #e4e9f2;
  }

  &--embedded &__map {
    background: #e8ebf2;
  }

  &--embedded &__result:hover {
    background: rgba(38, 108, 251, 0.06);
  }

  &--embedded &__results {
    flex: 1;
    max-height: none;
    min-height: 120px;
    border-color: #e4e9f2;
  }

  &--embedded &__panel--plain {
    height: 100%;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  &--embedded &__tabs {
    :deep(.ant-tabs-tab) {
      padding: 6px 0;
      font-size: 13px;
      color: rgba(0, 0, 0, 0.55);
    }

    :deep(.ant-tabs-tab-active .ant-tabs-tab-btn) {
      color: #266cfb;
      font-weight: 500;
    }

    :deep(.ant-tabs-ink-bar) {
      background: #266cfb;
      height: 2px;
    }

    :deep(.ant-tabs-nav::before) {
      border-bottom-color: #eef1f6;
    }
  }

  &--embedded &__search {
    :deep(.ant-input) {
      border-radius: 6px;
      border-color: #e4e9f2;
    }

    :deep(.ant-input-search-button) {
      border-radius: 0 6px 6px 0;
    }
  }

  &__panel--plain {
    height: 100%;
    padding: 20px 18px;
    display: flex;
    flex-direction: column;
    gap: 14px;
  }

  &__panel-title {
    margin: 0;
    font-size: 14px;
    font-weight: 600;
    color: rgba(0, 0, 0, 0.65);
    letter-spacing: -0.01em;
  }

  &__tabs {
    :deep(.ant-tabs-nav) {
      margin-bottom: 0;
    }
  }

  &__hint {
    margin: 0;
    padding: 10px 12px;
    font-size: 12px;
    line-height: 1.55;
    color: rgba(0, 0, 0, 0.45);
    background: #f6f7fb;
    border-radius: 6px;
    border: 1px solid #eef1f6;
  }

  &__sider {
    border-right: 1px solid #f0f0f0;
    background: #fafafa !important;
  }

  &__panel {
    height: 100%;

    :deep(.vben-collapse-container) {
      height: 100%;
      border: none;
      background: transparent;
    }

    :deep(.vben-collapse-container__body) {
      padding: 8px 12px 12px;
    }
  }

  &__search {
    margin: 8px 0;
  }

  &__results {
    max-height: 200px;
    overflow: auto;
    border: 1px solid #e4e9f2;
    border-radius: 6px;
    background: #fff;
  }

  &__result {
    cursor: pointer;
    padding: 6px 12px !important;
    transition: background 0.15s;

    &:hover {
      background: rgba(38, 108, 251, 0.06);
    }

    :deep(.ant-list-item-meta-title) {
      font-size: 13px;
      color: rgba(0, 0, 0, 0.88);
    }

    :deep(.ant-list-item-meta-description) {
      font-size: 12px;
      color: rgba(0, 0, 0, 0.45);
    }
  }

  &__pager {
    margin-top: 8px;
    text-align: center;
  }

  &__divider {
    margin: 12px 0 !important;
  }

  &__actions {
    display: flex;
    justify-content: flex-end;
    width: 100%;
    margin-top: 12px;
  }

  &__map {
    min-width: 0;
    padding: 0;
    background: #f5f5f5;
    position: relative;

    :deep(.basic-tianditu-map) {
      height: 100%;
      min-height: 360px;
    }
  }
}
</style>
