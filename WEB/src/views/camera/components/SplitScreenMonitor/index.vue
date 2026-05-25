<template>
  <div class="split-screen-monitor">
    <div class="mode-toolbar">
      <a-radio-group
        v-model:value="viewMode"
        button-style="solid"
        size="middle"
        @change="handleModeChange"
      >
        <a-radio-button value="monitor">
          <Icon icon="ic:sharp-grid-view" />
          分屏监控
        </a-radio-button>
        <a-radio-button value="config">
          <Icon icon="ant-design:folder-outlined" />
          设备目录
        </a-radio-button>
      </a-radio-group>
      <span v-if="viewMode === 'config'" class="mode-hint">管理设备目录并关联摄像头，切换至「分屏监控」即可按目录选点播放</span>
      <span v-else class="mode-hint">从左侧设备目录选择摄像头，添加到右侧多分屏窗口</span>
    </div>

    <DirectoryManage
      v-if="directoryMounted"
      v-show="viewMode === 'config'"
      ref="directoryManageRef"
      embedded
      @play="(record) => emit('play', record)"
    />

    <MonitorPanel v-if="monitorMounted" v-show="viewMode === 'monitor'" ref="monitorPanelRef" />
  </div>
</template>

<script lang="ts" setup>
import { ref, watch } from 'vue';
import { RadioGroup as ARadioGroup, RadioButton as ARadioButton } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import DirectoryManage from '../DirectoryManage/index.vue';
import MonitorPanel from './MonitorPanel.vue';
import type { DeviceInfo } from '@/api/device/camera';

defineOptions({ name: 'SplitScreenMonitor' });

const props = withDefaults(
  defineProps<{
    /** 初始形态：config=设备目录, monitor=分屏监控 */
    initialMode?: 'config' | 'monitor';
  }>(),
  { initialMode: 'monitor' },
);

const emit = defineEmits<{
  play: [record: DeviceInfo];
}>();

const viewMode = ref<'config' | 'monitor'>(props.initialMode);
/** 懒挂载：首次进入对应 Tab 再创建子组件，之后 v-show 保留状态与缓存 */
const directoryMounted = ref(props.initialMode === 'config');
const monitorMounted = ref(props.initialMode !== 'config');
const directoryManageRef = ref<InstanceType<typeof DirectoryManage>>();
const monitorPanelRef = ref<InstanceType<typeof MonitorPanel>>();

watch(viewMode, (mode) => {
  if (mode === 'config') directoryMounted.value = true;
  else monitorMounted.value = true;
});

watch(
  () => props.initialMode,
  (mode) => {
    if (mode) viewMode.value = mode;
  },
);

function handleModeChange() {
  // 两 Tab 共享 session 缓存，切换时不重复拉取（子组件首次挂载时已 load）
}

function refresh() {
  if (viewMode.value === 'config') {
    directoryManageRef.value?.refresh?.();
  } else {
    monitorPanelRef.value?.refresh?.();
  }
}

/** 手动全量同步（含国标入库） */
function forceRefresh() {
  if (viewMode.value === 'monitor') {
    monitorPanelRef.value?.forceRefresh?.();
  } else {
    directoryManageRef.value?.forceRefreshTree?.();
  }
}

function setMode(mode: 'config' | 'monitor') {
  viewMode.value = mode;
  handleModeChange();
}

defineExpose({ refresh, softRefresh: refresh, forceRefresh, setMode });
</script>

<style lang="less" scoped>
.split-screen-monitor {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 192px);
  max-height: calc(100vh - 192px);
  padding-bottom: 4px;
  box-sizing: border-box;
  overflow: hidden;

  :deep(.split-screen-container) {
    flex: 1;
    min-height: 0;
  }
}

.mode-toolbar {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
  padding: 12px 16px;
  margin-bottom: 8px;
  background: #fff;
  border-bottom: 1px solid #f0f0f0;

  :deep(.ant-radio-button-wrapper) {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  .mode-hint {
    color: #6b7280;
    font-size: 13px;
  }
}
</style>
