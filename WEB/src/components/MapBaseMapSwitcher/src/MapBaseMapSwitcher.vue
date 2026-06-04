<script setup lang="ts">
import { Checkbox } from 'ant-design-vue';
import type { TiandituBaseMapType } from '@/components/TiandituMap';

defineOptions({ name: 'MapBaseMapSwitcher' });

withDefaults(
  defineProps<{
    /** 左侧说明文字 */
    label?: string;
    /** 布局：inline 横排，block 纵向 */
    layout?: 'inline' | 'block';
  }>(),
  {
    label: '底图',
    layout: 'inline',
  },
);

const baseMapType = defineModel<TiandituBaseMapType>('baseMapType', { default: 'vec' });

function onVecChange(e: { target: { checked: boolean } }) {
  baseMapType.value = e.target.checked ? 'vec' : 'img';
}

function onImgChange(e: { target: { checked: boolean } }) {
  baseMapType.value = e.target.checked ? 'img' : 'vec';
}
</script>

<template>
  <div class="map-base-map-switcher" :class="`map-base-map-switcher--${layout}`">
    <span v-if="label" class="map-base-map-switcher__label">{{ label }}</span>
    <div class="map-base-map-switcher__options">
      <Checkbox :checked="baseMapType === 'vec'" @change="onVecChange">
        矢量
      </Checkbox>
      <Checkbox :checked="baseMapType === 'img'" @change="onImgChange">
        影像
      </Checkbox>
      <slot />
    </div>
  </div>
</template>

<style scoped lang="less">
.map-base-map-switcher {
  display: inline-flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  max-width: 100%;

  &--block {
    flex-direction: column;
    align-items: flex-start;
  }

  &__label {
    font-size: 12px;
    color: rgba(0, 0, 0, 0.45);
    flex-shrink: 0;
    line-height: 24px;
  }

  &__options {
    display: inline-flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 12px;
    min-width: 0;
  }
}
</style>
