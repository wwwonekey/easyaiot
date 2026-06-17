<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :width="drawerWidth"
    placement="right"
    :loading="loading"
    :showFooter="true"
    :showOkBtn="false"
    :showCancelBtn="false"
    :maskClosable="false"
    destroy-on-close
    root-class-name="sam-auto-label-drawer"
  >
    <template #title>
      <div class="detail-drawer-header">
        <div class="detail-drawer-header__icon">
          <Icon icon="ant-design:deployment-unit-outlined" :size="18" />
        </div>
        <div class="detail-drawer-header__line">
          <span class="detail-drawer-header__title">{{ COPY.drawerTitle }}</span>
          <span class="detail-drawer-header__sep">·</span>
          <span class="detail-drawer-header__desc">{{ COPY.drawerDesc }}</span>
          <template v-if="taskRunning && taskId">
            <span class="detail-drawer-header__sep">·</span>
            <span class="detail-drawer-header__meta">任务 #{{ taskId }}</span>
          </template>
        </div>
        <div v-if="taskStatus" class="detail-drawer-header__tags">
          <Tag :color="taskStatusTagColor">{{ statusLabel }}</Tag>
          <Tag v-if="currentPhaseLabel" color="processing">{{ currentPhaseLabel }}</Tag>
        </div>
      </div>
    </template>

    <template #footer>
      <div class="footer-buttons">
        <Button @click="handleClose">{{ taskRunning ? COPY.footer.minimize : COPY.footer.close }}</Button>
        <div class="footer-nav">
          <template v-if="activeTab === 'config' && !taskRunning">
            <Button v-if="configStep > 0" @click="handleConfigPrev">{{ COPY.footer.prev }}</Button>
            <Button
              v-if="!isLastConfigStep"
              type="primary"
              :disabled="!canProceedConfigStep"
              @click="handleConfigNext"
            >
              {{ COPY.footer.next }}
            </Button>
            <Button
              v-else
              type="primary"
              :loading="starting"
              :disabled="!canStart"
              @click="startTask"
            >
              {{ COPY.footer.start }}
            </Button>
          </template>
          <template v-else>
            <Button v-if="taskRunning && taskStatus !== 'PAUSED'" @click="handlePause">{{ COPY.footer.pause }}</Button>
            <Button v-if="taskStatus === 'PAUSED'" type="primary" @click="handleResume">{{ COPY.footer.resume }}</Button>
            <PopConfirmButton
              v-if="taskRunning"
              danger
              ghost
              :title="COPY.footer.cancelConfirm"
              @confirm="handleCancel"
            >
              {{ COPY.footer.cancel }}
            </PopConfirmButton>
          </template>
        </div>
      </div>
    </template>

    <div class="detail-drawer-content">
      <Tabs v-model:activeKey="activeTab" class="detail-tabs">
        <Tabs.TabPane key="config" :tab="COPY.tabs.config" :disabled="taskRunning">
          <div class="config-wizard">
            <div class="setup-steps-card">
              <Steps
                class="setup-steps"
                :current="configStep"
                :items="configStepItems"
                @change="handleConfigStepChange"
              />
            </div>

            <div class="setup-content-card">
              <div class="step-panel-head">
                <h3 class="step-panel-title">{{ currentStepCopy.title }}</h3>
              </div>

              <div v-show="activeConfigStepKey === 'basic'" class="step-panel-body">
                <Form
                  :label-col="SETUP_FORM_LABEL_COL"
                  :wrapper-col="SETUP_FORM_WRAPPER_COL"
                  class="setup-resource-form"
                >
                  <FormItem :label="COPY.form.mode">
                    <RadioButtonGroup v-model:value="form.mode" :options="modeOptions" />
                    <p class="form-hint">
                      {{ form.mode === 'pipeline' ? COPY.mode.pipelineHint : COPY.mode.batchHint }}
                    </p>
                  </FormItem>

                  <FormItem :label="COPY.form.classes" required>
                    <Select
                      v-model:value="form.text_prompts"
                      mode="tags"
                      :placeholder="COPY.form.classesPlaceholder"
                      style="width: 100%"
                    />
                    <p class="form-hint">{{ COPY.form.classesHint }}</p>
                  </FormItem>

                  <FormItem :label="COPY.form.annotation">
                    <RadioButtonGroup
                      v-model:value="form.annotation_type"
                      :options="annotationTypeOptions"
                    />
                  </FormItem>
                </Form>
              </div>

              <div v-show="activeConfigStepKey === 'capture'" class="step-panel-body">
                <Form
                  :label-col="SETUP_FORM_LABEL_COL"
                  :wrapper-col="SETUP_FORM_WRAPPER_COL"
                  class="setup-resource-form"
                >
                  <FormItem :label="COPY.form.execution">
                    <RadioButtonGroup
                      v-model:value="form.execution_mode"
                      :options="executionModeOptions"
                    />
                    <p v-if="form.execution_mode === 'cluster'" class="form-hint">
                      {{ COPY.form.executionClusterHint }}
                    </p>
                  </FormItem>

                  <FormItem v-if="form.execution_mode === 'cluster'" :label="COPY.form.nodePrep">
                    <Space :size="12">
                      <Button @click="goNodeManage">{{ COPY.form.nodeSync }}</Button>
                      <Button @click="goNodeBundle">{{ COPY.form.nodeBundle }}</Button>
                    </Space>
                  </FormItem>

                  <FormItem :label="COPY.form.duration">
                    <div class="field-control">
                      <span class="field-value">{{ form.duration_hours }} 小时</span>
                      <Slider v-model:value="form.duration_hours" :min="1" :max="24" :step="1" />
                      <p class="form-hint">{{ COPY.form.durationHint }}</p>
                    </div>
                  </FormItem>

                  <FormItem :label="COPY.form.interval">
                    <div class="field-control">
                      <span class="field-value">{{ form.capture_interval_sec }} 秒</span>
                      <Slider v-model:value="form.capture_interval_sec" :min="5" :max="300" :step="5" />
                      <p class="form-hint">{{ COPY.form.intervalHint }}</p>
                    </div>
                  </FormItem>

                  <FormItem :label="COPY.form.export">
                    <Checkbox v-model:checked="form.auto_export">{{ COPY.form.exportLabel }}</Checkbox>
                  </FormItem>

                  <FormItem :label="COPY.form.frameTasks">
                    <Alert
                      v-if="frameTasks.length === 0"
                      type="warning"
                      show-icon
                      :message="COPY.form.frameTasksEmpty"
                    >
                      <template #description>
                        {{ COPY.form.frameTasksEmptyDesc }}
                        <Button type="link" size="small" @click="emit('open-frame-tasks')">
                          {{ COPY.form.frameTasksGo }}
                        </Button>
                      </template>
                    </Alert>
                    <template v-else>
                      <div class="list-panel-head">
                        <span>{{ COPY.form.frameTasksSelected(selectedCameraCount, frameTasks.length) }}</span>
                        <Button type="link" size="small" @click="toggleAllCameras">
                          {{ allCamerasSelected ? '取消全选' : '全选' }}
                        </Button>
                      </div>
                      <ScrollContainer class="list-panel-scroll">
                        <CheckboxGroup v-model:value="form.frame_task_ids" class="list-panel">
                          <label v-for="ft in frameTasks" :key="ft.id" class="list-panel-row">
                            <Checkbox :value="ft.id" />
                            <span class="list-panel-row__body">
                              <span class="list-panel-row__title">{{ ft.taskName || `摄像头 ${ft.id}` }}</span>
                              <span class="list-panel-row__sub">{{ ft.rtmpUrl || 'GB28181' }}</span>
                            </span>
                          </label>
                        </CheckboxGroup>
                      </ScrollContainer>
                      <p
                        v-if="form.execution_mode === 'cluster' && !form.frame_task_ids.length"
                        class="form-hint form-hint--warn"
                      >
                        {{ COPY.form.clusterCameraWarn }}
                      </p>
                    </template>
                  </FormItem>
                </Form>
              </div>

              <div v-show="activeConfigStepKey === 'strategy'" class="step-panel-body">
                <Form
                  :label-col="SETUP_FORM_LABEL_COL"
                  :wrapper-col="SETUP_FORM_WRAPPER_COL"
                  class="setup-resource-form"
                >
                  <FormItem :label="COPY.form.coldStart">
                    <div class="checkbox-stack">
                      <Checkbox v-model:checked="form.strategy.skip_sam_cold_start">{{ COPY.form.skipSam }}</Checkbox>
                      <Checkbox v-model:checked="form.strategy.auto_train_yolo">{{ COPY.form.autoTrain }}</Checkbox>
                      <Checkbox v-model:checked="form.strategy.sam_supplement_enabled">{{ COPY.form.samSupplement }}</Checkbox>
                    </div>
                    <p class="form-hint">{{ COPY.form.coldStartHint }}</p>
                  </FormItem>

                  <FormItem v-if="!form.strategy.skip_sam_cold_start" :label="COPY.form.samBootstrap">
                    <div class="field-control">
                      <span class="field-value">{{ form.strategy.bootstrap_sam_limit }} 张</span>
                      <Slider v-model:value="form.strategy.bootstrap_sam_limit" :min="50" :max="1000" :step="50" />
                    </div>
                  </FormItem>

                  <FormItem :label="COPY.form.prodModel">
                    <Select
                      v-model:value="form.strategy.initial_model_id"
                      allow-clear
                      :placeholder="COPY.form.prodModelPlaceholder"
                      :options="modelOptions"
                      style="width: 100%"
                    />
                    <p class="form-hint">{{ COPY.form.prodModelHint }}</p>
                  </FormItem>

                  <FormItem :label="COPY.form.yoloIterate">
                    <div class="field-control">
                      <span class="field-value">每 {{ form.strategy.yolo_iterate_every }} 张</span>
                      <Slider v-model:value="form.strategy.yolo_iterate_every" :min="0" :max="2000" :step="100" />
                      <p class="form-hint">{{ COPY.form.yoloIterateHint }}</p>
                    </div>
                  </FormItem>

                  <template v-if="form.strategy.auto_train_yolo">
                    <FormItem :label="COPY.form.finetuneBase">
                      <Select
                        v-model:value="form.strategy.pretrain_model_id"
                        allow-clear
                        :placeholder="COPY.form.finetuneBasePlaceholder"
                        :options="modelOptions"
                        style="width: 100%"
                      />
                    </FormItem>
                    <FormItem :label="COPY.form.officialPretrain">
                      <Select
                        v-model:value="form.strategy.model_arch"
                        :options="OFFICIAL_PRETRAIN_OPTIONS"
                        style="width: 100%"
                      />
                      <p class="form-hint">{{ COPY.form.officialPretrainHint }}</p>
                    </FormItem>
                  </template>

                  <template v-if="form.strategy.sam_supplement_enabled">
                    <FormItem :label="COPY.form.samSupplementUntil">
                      <div class="field-control">
                        <span class="field-value">前 {{ form.strategy.sam_supplement_until_labeled }} 张</span>
                        <Slider
                          v-model:value="form.strategy.sam_supplement_until_labeled"
                          :min="100"
                          :max="5000"
                          :step="100"
                        />
                      </div>
                    </FormItem>
                    <FormItem :label="COPY.form.samSupplementMinDet">
                      <div class="field-control">
                        <span class="field-value">检出数 &lt; {{ form.strategy.sam_supplement_min_detections }}</span>
                        <Slider
                          v-model:value="form.strategy.sam_supplement_min_detections"
                          :min="0"
                          :max="3"
                          :step="1"
                        />
                        <p class="form-hint">{{ COPY.form.samSupplementMinDetHint }}</p>
                      </div>
                    </FormItem>
                    <FormItem :label="COPY.form.samSupplementMap">
                      <div class="field-control">
                        <span class="field-value">
                          {{
                            form.strategy.sam_supplement_stop_map
                              ? `mAP ${(form.strategy.sam_supplement_stop_map * 100).toFixed(0)}%`
                              : '不启用'
                          }}
                        </span>
                        <Slider
                          v-model:value="form.strategy.sam_supplement_stop_map"
                          :min="0"
                          :max="0.9"
                          :step="0.05"
                          :tip-formatter="(v: number) => (v ? `${(v * 100).toFixed(0)}%` : '关闭')"
                        />
                        <p class="form-hint">{{ COPY.form.samSupplementMapHint }}</p>
                      </div>
                    </FormItem>
                  </template>

                  <FormItem :label="COPY.form.modelHistoryMax">
                    <InputNumber
                      v-model:value="form.strategy.model_history_max"
                      :min="1"
                      :max="100"
                      placeholder="服务端默认"
                      allow-clear
                      style="width: 100%"
                    />
                    <p class="form-hint">{{ COPY.form.modelHistoryMaxHint }}</p>
                  </FormItem>
                </Form>
              </div>

              <div v-show="activeConfigStepKey === 'batch'" class="step-panel-body">
                <Form
                  :label-col="SETUP_FORM_LABEL_COL"
                  :wrapper-col="SETUP_FORM_WRAPPER_COL"
                  class="setup-resource-form"
                >
                  <FormItem :label="COPY.form.batchLimit">
                    <div class="field-control">
                      <span class="field-value">{{ form.bootstrap_limit }} 张</span>
                      <Slider v-model:value="form.bootstrap_limit" :min="50" :max="2000" :step="50" />
                    </div>
                  </FormItem>
                  <FormItem :label="COPY.form.batchSelection">
                    <Select v-model:value="form.bootstrap_selection" style="width: 100%">
                      <SelectOption value="unlabeled_first">未标注优先</SelectOption>
                      <SelectOption value="unlabeled_only">仅未标注</SelectOption>
                      <SelectOption value="random">随机抽样</SelectOption>
                    </Select>
                  </FormItem>
                </Form>
              </div>
            </div>
          </div>
        </Tabs.TabPane>

        <Tabs.TabPane key="monitor" :tab="COPY.tabs.monitor">
          <div class="monitor-pane">
            <template v-if="activeTask">
              <Steps :current="pipelineStep" size="small" class="pipeline-steps">
                <Steps.Step title="冷启动" />
                <Steps.Step title="模型训练" />
                <Steps.Step title="批量标注" />
                <Steps.Step title="打包导出" />
              </Steps>

              <section class="monitor-section">
                <div class="monitor-section__head">
                  <span class="monitor-section__title">{{ COPY.monitor.progress }}</span>
                  <div v-if="currentPhaseLabel || currentMapLabel" class="monitor-tags">
                    <Tag v-if="currentPhaseLabel" color="processing">{{ currentPhaseLabel }}</Tag>
                    <Tag v-if="currentMapLabel">{{ currentMapLabel }}</Tag>
                    <Tag v-if="strategyStats.sam_labeled">SAM {{ strategyStats.sam_labeled }}</Tag>
                    <Tag v-if="strategyStats.yolo_labeled">YOLO {{ strategyStats.yolo_labeled }}</Tag>
                    <Tag v-if="strategyStats.sam_supplemented">补充 {{ strategyStats.sam_supplemented }}</Tag>
                  </div>
                </div>
                <Progress
                  :percent="progressPercent"
                  :status="taskStatus === 'FAILED' ? 'exception' : taskStatus === 'COMPLETED' ? 'success' : 'active'"
                />
              </section>

              <section class="monitor-section">
                <div class="monitor-section__title">{{ COPY.monitor.metrics }}</div>
                <Description
                  :use-collapse="false"
                  bordered
                  :column="3"
                  :schema="monitorDescSchema"
                  :data="monitorDescData"
                  class="setup-desc"
                />
              </section>

              <Alert
                v-if="bootstrapQualityAlert"
                :type="bootstrapQualityAlert.type"
                show-icon
                class="monitor-alert sam-quality-alert"
              >
                <template #message>{{ bootstrapQualityAlert.title }}</template>
                <template #description>
                  <p>{{ bootstrapQualityAlert.desc }}</p>
                  <p v-if="bootstrapStatus" class="sam-quality-stats">
                    识别率 {{ bootstrapStatus.recognition_rate_pct ?? 0 }}%
                    （有检出 {{ bootstrapStatus.sam_hit_count ?? 0 }} 张 /
                    空结果 {{ bootstrapStatus.sam_empty_count ?? 0 }} 张，
                    阈值 {{ bootstrapStatus.min_hit_rate_pct ?? 30 }}%）
                  </p>
                  <Space v-if="bootstrapQualityAlert.showActions" class="sam-quality-actions">
                    <Button size="small" :loading="resetLoading" @click="handleResetBootstrap">
                      恢复冷启动标注
                    </Button>
                    <Button size="small" type="primary" @click="emitOpenAutoLabel">
                      改用自动标注（YOLO）
                    </Button>
                  </Space>
                  <Space v-else-if="bootstrapStatus && !bootstrapStatus.review_passed" class="sam-quality-actions">
                    <Button size="small" type="primary" :loading="reviewLoading" @click="handleSubmitReview">
                      抽检通过，继续训练
                    </Button>
                  </Space>
                </template>
              </Alert>

              <Alert
                v-if="taskStatus === 'COMPLETED' && !bootstrapQualityAlert"
                type="success"
                show-icon
                class="monitor-alert"
                :message="pipelineStats.packaged ? COPY.monitor.packaged : COPY.monitor.packagedManual"
              />
              <Alert v-if="taskStatus === 'PAUSED'" type="warning" show-icon class="monitor-alert" :message="COPY.monitor.paused" />
              <Alert v-if="taskStatus === 'CANCELLED'" type="error" show-icon class="monitor-alert" :message="COPY.monitor.cancelled" />
              <Alert
                v-if="taskStatus === 'FAILED'"
                type="error"
                show-icon
                class="monitor-alert"
                :message="activeTask.error_message || COPY.monitor.failed"
              />

              <CollapseContainer v-if="subtasks.length" :title="COPY.monitor.subtasks">
                <BasicTable @register="registerSubtaskTable">
                  <template #bodyCell="{ column, record }">
                    <template v-if="column.key === 'status'">
                      <Tag :color="subtaskStatusColor(record.status)">{{ subtaskStatusLabel(record.status) }}</Tag>
                    </template>
                    <template v-else-if="column.key === 'node'">
                      <span v-if="record.assigned_node_host">{{ record.assigned_node_host }}</span>
                      <span v-else-if="record.status === 'QUEUED'" class="text-muted">等待调度</span>
                      <span v-else class="text-muted">—</span>
                    </template>
                    <template v-else-if="column.key === 'progress'">
                      {{ record.captured_count ?? 0 }} / {{ record.labeled_count ?? 0 }}
                    </template>
                  </template>
                </BasicTable>
              </CollapseContainer>

              <CollapseContainer v-if="pipelineLogs.length" :title="COPY.monitor.logs">
                <CodeEditor class="log-editor" :value="logContent" readonly bordered />
              </CollapseContainer>
            </template>

            <Empty v-else :description="COPY.monitor.empty" />
          </div>
        </Tabs.TabPane>
      </Tabs>
    </div>
  </BasicDrawer>
</template>

<script lang="ts" setup>
import { computed, onUnmounted, reactive, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import {
  Alert,
  Checkbox,
  CheckboxGroup,
  Empty,
  Form,
  FormItem,
  InputNumber,
  Progress,
  Select,
  Slider,
  Space,
  Steps,
  Tabs,
  Tag,
} from 'ant-design-vue';
import { Button, PopConfirmButton } from '@/components/Button';
import { CodeEditor } from '@/components/CodeEditor';
import { CollapseContainer, ScrollContainer } from '@/components/Container';
import { Description } from '@/components/Description';
import type { DescItem } from '@/components/Description';
import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
import { RadioButtonGroup } from '@/components/Form';
import { Icon } from '@/components/Icon';
import { BasicTable, useTable } from '@/components/Table';
import {
  startSamBootstrap,
  startSamPipeline,
  getAutoLabelTask,
  getAutoLabelSubtasks,
  listAutoLabelTasks,
  pauseAutoLabelTask,
  resumeAutoLabelTask,
  cancelAutoLabelTask,
  getAutoLabelModelList,
  getSamBootstrapStatus,
  resetSamBootstrapAnnotations,
  completeSamBootstrapReview,
} from '@/api/device/auto-label';
import type { AutoLabelStrategy, SamBootstrapStatus } from '@/api/device/auto-label';
import { getDatasetFrameTaskPage } from '@/api/device/dataset';
import { useMessage } from '@/hooks/web/useMessage';
import { SETUP_FORM_LABEL_COL, SETUP_FORM_WRAPPER_COL } from '@/views/node/utils/constants';

const SelectOption = Select.Option;

defineOptions({ name: 'SamAutoLabelDrawer' });

const props = defineProps<{
  datasetId: number;
}>();

const emit = defineEmits<{
  success: [payload: { taskId: number }];
  'open-frame-tasks': [];
  'open-auto-label': [];
  register: [];
}>();

const { createMessage } = useMessage();
const router = useRouter();

const drawerWidth = 'calc(100vw - 200px)';

/** 界面文案（术语与节点模块保持一致） */
const COPY = {
  drawerTitle: '智能标注流水线',
  drawerDesc: '摄像头无人值守，自动采集标注',
  tabs: { config: '参数配置', monitor: '运行监控' },
  footer: {
    close: '关闭',
    minimize: '收起',
    prev: '上一步',
    next: '下一步',
    start: '启动任务',
    pause: '暂停',
    resume: '继续',
    cancel: '取消任务',
    cancelConfirm: '确认取消？取消后 Worker 停止，已标注数据保留。',
  },
  steps: {
    basic: { title: '基础配置', desc: '模式与类别' },
    capture: { title: '采集与调度', desc: '执行与视频流' },
    strategy: { title: '标注策略', desc: '冷启动与量产' },
    batch: { title: '批量参数', desc: '规模与选图' },
  },
  mode: {
    pipeline: '无人值守',
    batch: '批量标注',
    pipelineHint: '从视频流持续抽帧，自动完成采集、标注与导出。',
    batchHint: '对数据集中已有图片执行冷启动标注，不涉及视频采集。',
  },
  form: {
    mode: '运行模式',
    classes: '检测类别',
    classesHint: '英文类别名，须与后续 YOLO 训练 class 一致。',
    classesPlaceholder: '例如 helmet, vest, person',
    annotation: '标注格式',
    execution: '执行方式',
    executionClusterHint: '子任务按节点负载分散执行，请提前完成节点纳管。',
    nodeSync: '同步节点环境',
    nodeBundle: '分发标注 Worker',
    nodePrep: '节点准备',
    duration: '采集时长',
    durationHint: '达到设定时长后停止拉流采集。',
    interval: '抽帧间隔',
    intervalHint: '相邻两次抽帧的时间间隔。',
    export: '自动导出',
    exportLabel: '采集结束后自动划分用途并打包',
    frameTasks: '视频流来源',
    frameTasksEmpty: '尚未配置抽帧任务',
    frameTasksEmptyDesc: '请先在「数据源 → 视频流抽帧」中绑定摄像头地址。',
    frameTasksGo: '配置数据源',
    frameTasksSelected: (n: number, total: number) => `已选 ${n} / ${total}`,
    coldStart: '冷启动',
    skipSam: '跳过 SAM 冷启动',
    autoTrain: '冷启动后自动训练 YOLO',
    samSupplement: 'YOLO 漏检时启用 SAM 补充',
    coldStartHint: '跳过后将直接训练或使用量产模型进行 YOLO 标注。',
    samBootstrap: 'SAM 冷启动规模',
    prodModel: '量产模型',
    prodModelHint: '冷启动完成后用于批量推理的 YOLO 模型，可不选。',
    prodModelPlaceholder: '不选则冷启动后自动训练',
    yoloIterate: '迭代训练间隔',
    yoloIterateHint: '设为 0 表示仅首轮训练，不自动迭代。',
    finetuneBase: '微调基座',
    finetuneBasePlaceholder: '不选则使用官方预训练权重',
    officialPretrain: '官方预训练',
    officialPretrainHint: '未指定微调基座时，冷启动训练使用该权重。',
    samSupplementUntil: 'SAM 补充上限',
    samSupplementMinDet: '漏检判定阈值',
    samSupplementMinDetHint: '单张图片检出数低于该值时触发 SAM 补充。',
    samSupplementMap: '精度停止条件',
    samSupplementMapHint: '设为 0 表示不按 mAP 停止 SAM 补充。',
    batchLimit: '首批规模',
    batchSelection: '选图规则',
    modelHistoryMax: '模型历史保留',
    modelHistoryMaxHint: '流水线自动训练后保留的模型版本数；留空则使用服务端配置（环境变量 AUTO_LABEL_MODEL_HISTORY_MAX，默认 15）。',
    clusterCameraWarn: '集群调度须至少选择一路视频流。',
  },
  monitor: {
    empty: '暂无任务记录，完成参数配置后点击「启动任务」。',
    progress: '执行进度',
    metrics: '运行指标',
    subtasks: '子任务明细',
    logs: '运行日志',
    phase: '当前阶段',
    packaged: '任务已完成，数据集已自动打包。',
    packagedManual: '任务已完成，请前往「训练集 → 导出」手动打包。',
    paused: '任务已暂停，点击「继续」恢复。',
    cancelled: '任务已取消。',
    failed: '任务执行失败',
    samQualityLowTitle: 'SAM 识别率偏低，建议改用手动或 YOLO 自动标注',
    samQualityLowDesc:
      '当前行业数据可能不适合 SAM3 零样本识别。请恢复冷启动自动标注到初始状态，改用手动标注或使用已训练的 YOLO 模型进行自动标注。',
    samQualityOkTitle: 'SAM 冷启动识别率正常',
    samQualityOkDesc: '请随机抽查 10–20 张修正明显错误后确认通过，再进入训练。',
  },
} as const;

const modeOptions = [
  { label: COPY.mode.pipeline, value: 'pipeline' },
  { label: COPY.mode.batch, value: 'batch' },
];

const executionModeOptions = [
  { label: '集群调度', value: 'cluster' },
  { label: '本机执行', value: 'local' },
];

const annotationTypeOptions = [
  { label: '检测框', value: 'rectangle' },
  { label: '多边形分割', value: 'polygon' },
];

const OFFICIAL_PRETRAIN_OPTIONS = [
  { label: 'YOLO26n（默认）', value: '@AI/yolo26n.pt' },
  { label: 'YOLO11n', value: '@AI/yolo11n.pt' },
  { label: 'YOLOv8n', value: '@AI/yolov8n.pt' },
];

const defaultStrategy = (): AutoLabelStrategy => ({
  bootstrap_sam_limit: 200,
  skip_sam_cold_start: false,
  yolo_iterate_every: 500,
  auto_train_yolo: true,
  initial_model_id: undefined,
  pretrain_model_id: undefined,
  model_arch: '@AI/yolo26n.pt',
  sam_supplement_enabled: true,
  sam_supplement_until_labeled: 500,
  sam_supplement_stop_map: 0,
  sam_supplement_min_detections: 1,
  yolo_confidence: 0.5,
  sam_confidence: 0.45,
  sam_bootstrap_min_hit_rate: 0.3,
  model_history_max: undefined,
});

const loading = ref(false);
const starting = ref(false);
const activeTab = ref<'config' | 'monitor'>('config');
const configStep = ref(0);
const taskId = ref<number | null>(null);
const activeTask = ref<Record<string, any> | null>(null);
const taskStatus = ref('');
const frameTasks = ref<any[]>([]);
const subtasks = ref<any[]>([]);
const modelOptions = ref<{ label: string; value: number }[]>([]);
const bootstrapStatus = ref<SamBootstrapStatus | null>(null);
const resetLoading = ref(false);
const reviewLoading = ref(false);
let pollTimer: ReturnType<typeof setInterval> | null = null;

const subtaskColumns = [
  { title: '视频流', dataIndex: 'frame_task_name', key: 'name', ellipsis: true },
  { title: '状态', key: 'status', width: 96 },
  { title: '执行节点', key: 'node', width: 148, ellipsis: true },
  { title: '采集/标注', key: 'progress', width: 108, align: 'center' as const },
];

const [registerSubtaskTable, { setTableData: setSubtaskTableData }] = useTable({
  title: '',
  columns: subtaskColumns,
  pagination: false,
  showIndexColumn: false,
  canResize: false,
  useSearchForm: false,
  showTableSetting: false,
  immediate: false,
  maxHeight: 300,
  rowKey: 'id',
});

watch(
  subtasks,
  (list) => {
    setSubtaskTableData(list);
  },
  { deep: true },
);

const form = reactive({
  mode: 'pipeline' as 'pipeline' | 'batch',
  execution_mode: 'cluster' as 'local' | 'cluster',
  frame_task_ids: [] as number[],
  text_prompts: [] as string[],
  duration_hours: 8,
  capture_interval_sec: 30,
  auto_export: true,
  bootstrap_limit: 200,
  bootstrap_selection: 'unlabeled_first' as 'unlabeled_first' | 'unlabeled_only' | 'random',
  annotation_type: 'rectangle' as 'rectangle' | 'polygon',
  confidence_threshold: 0.45,
  strategy: defaultStrategy(),
});

const strategyStats = computed(() => {
  const cfg = activeTask.value?.pipeline_config || {};
  return {
    sam_labeled: cfg.sam_labeled ?? 0,
    yolo_labeled: cfg.yolo_labeled ?? 0,
    sam_supplemented: cfg.sam_supplemented ?? 0,
  };
});

const currentPhaseLabel = computed(() => {
  const phase = activeTask.value?.pipeline_config?.pipeline_phase;
  const map: Record<string, string> = {
    bootstrap_sam: 'SAM 冷启动',
    training: 'YOLO 训练中',
    yolo_label: 'YOLO 量产标注',
    iterate: '迭代优化',
    collecting: '采集中',
    packaging: '打包导出',
    done: '已完成',
    paused: '已暂停',
    cancelled: '已取消',
  };
  return phase ? map[phase] || phase : '';
});

const currentMapLabel = computed(() => {
  const m = activeTask.value?.pipeline_config?.current_map;
  if (m == null || m === 0) return '';
  return `mAP50 ${(Number(m) * 100).toFixed(1)}%`;
});

const selectedCameraCount = computed(() => form.frame_task_ids.length);
const allCamerasSelected = computed(
  () => frameTasks.value.length > 0 && form.frame_task_ids.length === frameTasks.value.length,
);
const isClusterTask = computed(
  () => activeTask.value?.execution_mode === 'cluster' || form.execution_mode === 'cluster',
);

const canStart = computed(() => {
  if (!form.text_prompts.length || starting.value) return false;
  if (form.mode === 'pipeline' && form.execution_mode === 'cluster') {
    return form.frame_task_ids.length > 0;
  }
  return true;
});

type ConfigStepKey = 'basic' | 'capture' | 'strategy' | 'batch';

interface ConfigStepDef {
  key: ConfigStepKey;
  title: string;
  description: string;
}

const configSteps = computed<ConfigStepDef[]>(() => {
  if (form.mode === 'pipeline') {
    return [
      { key: 'basic', title: COPY.steps.basic.title, description: COPY.steps.basic.desc },
      { key: 'capture', title: COPY.steps.capture.title, description: COPY.steps.capture.desc },
      { key: 'strategy', title: COPY.steps.strategy.title, description: COPY.steps.strategy.desc },
    ];
  }
  return [
    { key: 'basic', title: COPY.steps.basic.title, description: COPY.steps.basic.desc },
    { key: 'batch', title: COPY.steps.batch.title, description: COPY.steps.batch.desc },
  ];
});

const currentStepCopy = computed(
  () => configSteps.value[configStep.value] ?? COPY.steps.basic,
);

const activeConfigStepKey = computed(
  () => configSteps.value[configStep.value]?.key ?? 'basic',
);

const isLastConfigStep = computed(
  () => configStep.value >= configSteps.value.length - 1,
);

const configStepItems = computed(() =>
  configSteps.value.map((step, index) => ({
    title: step.title,
    description: step.description,
    status: (index < configStep.value
      ? 'finish'
      : index === configStep.value
        ? 'process'
        : 'wait') as 'wait' | 'process' | 'finish',
  })),
);

const canProceedConfigStep = computed(() => {
  const key = activeConfigStepKey.value;
  if (key === 'basic') return form.text_prompts.length > 0;
  if (key === 'capture') {
    if (form.execution_mode === 'cluster') return form.frame_task_ids.length > 0;
    return true;
  }
  return true;
});

const pipelineStats = computed(() => {
  const cfg = activeTask.value?.pipeline_config;
  return {
    captured_count: cfg?.captured_count ?? 0,
    labeled_count: cfg?.labeled_count ?? activeTask.value?.success_count ?? 0,
    packaged: cfg?.packaged ?? false,
    pipeline_status: cfg?.pipeline_status ?? '',
    active_workers: cfg?.active_workers ?? 0,
    queued_subtasks: cfg?.queued_subtasks ?? 0,
  };
});

const taskRunning = computed(() =>
  ['PENDING', 'PROCESSING', 'PAUSED'].includes(taskStatus.value),
);

const taskStatusTagColor = computed(() => {
  const map: Record<string, string> = {
    PENDING: 'default',
    PROCESSING: 'processing',
    PAUSED: 'warning',
    COMPLETED: 'success',
    FAILED: 'error',
    CANCELLED: 'default',
  };
  return map[taskStatus.value] || 'default';
});

const pipelineLogs = computed(() => {
  const logs = activeTask.value?.pipeline_config?.logs;
  return Array.isArray(logs) ? logs : [];
});

const monitorDescData = computed(() => ({
  captured_count: pipelineStats.value.captured_count,
  labeled_count: activeTask.value?.success_count ?? 0,
  failed_count: activeTask.value?.failed_count ?? 0,
  active_workers: pipelineStats.value.active_workers ?? 0,
  queued_subtasks: pipelineStats.value.queued_subtasks ?? 0,
  status: statusLabel.value,
  is_cluster: isClusterTask.value,
}));

const monitorDescSchema = computed<DescItem[]>(() => {
  const items: DescItem[] = [
    { field: 'captured_count', label: '采集帧数' },
    { field: 'labeled_count', label: '标注完成' },
    { field: 'failed_count', label: '失败帧数' },
    { field: 'status', label: '任务状态' },
  ];
  if (monitorDescData.value.is_cluster) {
    items.splice(3, 0,
      { field: 'active_workers', label: '活跃 Worker' },
      { field: 'queued_subtasks', label: '排队子任务' },
    );
  }
  return items;
});

const logContent = computed(() =>
  pipelineLogs.value
    .map((log) => `${formatLogTime(log.time)}  ${log.message}`)
    .join('\n'),
);

const pipelineStep = computed(() => {
  const phase = activeTask.value?.pipeline_config?.pipeline_phase;
  if (taskStatus.value === 'COMPLETED') return 3;
  if (phase === 'training') return 1;
  if (phase === 'yolo_label' || phase === 'iterate' || phase === 'collecting') return 2;
  if (phase === 'packaging') return 3;
  return 0;
});

const statusLabel = computed(() => {
  const map: Record<string, string> = {
    PENDING: '排队中',
    PROCESSING: '运行中',
    PAUSED: '已暂停',
    COMPLETED: '已完成',
    FAILED: '失败',
    CANCELLED: '已取消',
  };
  return map[taskStatus.value] || taskStatus.value || '-';
});

const progressPercent = computed(() => {
  if (!activeTask.value) return 0;
  if (form.mode === 'pipeline' || activeTask.value.phase === 'PIPELINE') {
    const captured = pipelineStats.value.captured_count || 0;
    const labeled = activeTask.value.success_count || 0;
    const total = Math.max(captured, labeled, 1);
    return Math.min(100, Math.round((labeled / total) * 100));
  }
  const total = activeTask.value.total_images || form.bootstrap_limit;
  const done = activeTask.value.processed_images || 0;
  if (!total) return 0;
  return Math.min(100, Math.round((done / total) * 100));
});

const bootstrapQualityAlert = computed(() => {
  const status = bootstrapStatus.value;
  if (!status?.bootstrap_done && !status?.awaiting_sam_review) return null;
  if (status.review_recommended || status.awaiting_sam_review) {
    return {
      type: 'warning' as const,
      title: COPY.monitor.samQualityLowTitle,
      desc: COPY.monitor.samQualityLowDesc,
      showActions: true,
    };
  }
  if (status.sam_quality_passed && !status.review_passed) {
    return {
      type: 'info' as const,
      title: COPY.monitor.samQualityOkTitle,
      desc: COPY.monitor.samQualityOkDesc,
      showActions: false,
    };
  }
  return null;
});

watch(taskRunning, (running) => {
  if (running) activeTab.value = 'monitor';
});

watch(
  () => form.mode,
  () => {
    configStep.value = 0;
  },
);

function handleConfigPrev(): void {
  if (configStep.value > 0) configStep.value -= 1;
}

function handleConfigNext(): void {
  if (!canProceedConfigStep.value) {
    createMessage.warning('请补全当前步骤必填项');
    return;
  }
  if (!isLastConfigStep.value) configStep.value += 1;
}

function handleConfigStepChange(idx: number): void {
  if (idx <= configStep.value) {
    configStep.value = idx;
    return;
  }
  if (idx === configStep.value + 1 && canProceedConfigStep.value) {
    configStep.value = idx;
  }
}

const [register, { closeDrawer }] = useDrawerInner(async () => {
  activeTab.value = 'config';
  configStep.value = 0;
  await Promise.all([loadFrameTasks(), loadModelList()]);
  await resumeActiveTask();
});

async function loadModelList(): Promise<void> {
  try {
    const res = await getAutoLabelModelList({ pageNo: 1, pageSize: 100 });
    const list = res?.data?.list ?? res?.list ?? [];
    modelOptions.value = list.map((m: any) => ({
      label: `${m.name || '模型'} v${m.version || ''} (#${m.id})`,
      value: m.id,
    }));
  } catch {
    modelOptions.value = [];
  }
}

function goNodeBundle(): void {
  router.push({ path: '/node', query: { tab: '3', bundle: 'auto_label' } });
}

function formatLogTime(iso?: string): string {
  if (!iso) return '';
  try {
    return new Date(iso).toLocaleTimeString('zh-CN', { hour12: false });
  } catch {
    return iso;
  }
}

async function loadFrameTasks(): Promise<void> {
  try {
    const res = await getDatasetFrameTaskPage({
      datasetId: props.datasetId,
      pageNo: 1,
      pageSize: 100,
    });
    const data = res?.data ?? res;
    frameTasks.value = data?.list ?? [];
    if (form.frame_task_ids.length === 0 && frameTasks.value.length) {
      form.frame_task_ids = frameTasks.value.map((ft: any) => ft.id);
    }
  } catch {
    frameTasks.value = [];
  }
}

function toggleAllCameras(): void {
  if (allCamerasSelected.value) {
    form.frame_task_ids = [];
  } else {
    form.frame_task_ids = frameTasks.value.map((ft) => ft.id);
  }
}

function goNodeManage(): void {
  router.push({ path: '/node', query: { tab: '3', bundle: 'auto_label' } });
}

function subtaskStatusLabel(status: string): string {
  const map: Record<string, string> = {
    QUEUED: '排队中',
    DISPATCHING: '调度中',
    RUNNING: '运行中',
    COMPLETED: '已完成',
    FAILED: '失败',
  };
  return map[status] || status;
}

function subtaskStatusColor(status: string): string {
  const map: Record<string, string> = {
    QUEUED: 'default',
    DISPATCHING: 'processing',
    RUNNING: 'blue',
    COMPLETED: 'success',
    FAILED: 'error',
  };
  return map[status] || 'default';
}

async function loadSubtasks(): Promise<void> {
  if (!taskId.value) return;
  try {
    const res = await getAutoLabelSubtasks(props.datasetId, taskId.value);
    const data = res?.data ?? res;
    subtasks.value = data?.subtasks ?? [];
  } catch {
    subtasks.value = [];
  }
}

async function resumeActiveTask(): Promise<void> {
  loading.value = true;
  try {
    const res = await listAutoLabelTasks(props.datasetId, { page: 1, page_size: 5 });
    const data = res?.data ?? res;
    const list = data?.list ?? [];
    const running = list.find((t: any) =>
      ['PENDING', 'PROCESSING', 'PAUSED'].includes(t.status),
    );
    if (running) {
      taskId.value = running.id;
      activeTask.value = running;
      taskStatus.value = running.status;
      activeTab.value = 'monitor';
      if (running.phase === 'PIPELINE') form.mode = 'pipeline';
      const savedStrategy = running.pipeline_config?.strategy;
      if (savedStrategy) Object.assign(form.strategy, savedStrategy);
      startPolling();
    }
  } catch {
    /* ignore */
  } finally {
    loading.value = false;
  }
}

async function startTask(): Promise<void> {
  if (!canStart.value || starting.value) return;
  starting.value = true;
  try {
    let res: any;
    if (form.mode === 'pipeline') {
      res = await startSamPipeline(props.datasetId, {
        text_prompts: form.text_prompts,
        duration_hours: form.duration_hours,
        capture_interval_sec: form.capture_interval_sec,
        annotation_type: form.annotation_type,
        confidence_threshold: form.confidence_threshold,
        return_masks: form.annotation_type === 'polygon',
        auto_export: form.auto_export,
        execution_mode: form.execution_mode,
        frame_task_ids: form.execution_mode === 'cluster' ? form.frame_task_ids : undefined,
        strategy: { ...form.strategy, sam_confidence: form.confidence_threshold },
      });
    } else {
      res = await startSamBootstrap(props.datasetId, {
        text_prompts: form.text_prompts,
        bootstrap_limit: form.bootstrap_limit,
        bootstrap_selection: form.bootstrap_selection,
        annotation_type: form.annotation_type,
        confidence_threshold: form.confidence_threshold,
        return_masks: form.annotation_type === 'polygon',
      });
    }
    const id = res?.task_id ?? res?.data?.task_id;
    if (!id) {
      createMessage.error('启动失败：未返回任务 ID');
      return;
    }
    taskId.value = id;
    taskStatus.value = 'PENDING';
    activeTab.value = 'monitor';
    createMessage.success(
      form.mode === 'pipeline'
        ? form.execution_mode === 'cluster'
          ? `集群流水线已入队（${form.frame_task_ids.length} 路摄像头）`
          : '无人值守流水线已启动'
        : 'SAM 标注任务已启动',
    );
    emit('success', { taskId: id });
    startPolling();
  } catch (e: any) {
    const msg = e?.response?.data?.msg || e?.message || '启动失败';
    if (String(msg).includes('已有进行中')) {
      createMessage.warning(msg);
      await resumeActiveTask();
    } else {
      createMessage.error(msg);
    }
  } finally {
    starting.value = false;
  }
}

async function loadBootstrapStatus(): Promise<void> {
  try {
    const res = await getSamBootstrapStatus(props.datasetId);
    bootstrapStatus.value = (res?.data ?? res) as SamBootstrapStatus;
  } catch {
    bootstrapStatus.value = null;
  }
}

async function handleResetBootstrap(): Promise<void> {
  resetLoading.value = true;
  try {
    const res = await resetSamBootstrapAnnotations(props.datasetId);
    const count = res?.data?.reset_count ?? res?.reset_count ?? 0;
    createMessage.success(`已恢复 ${count} 张图片到未标注状态`);
    bootstrapStatus.value = null;
    await resumeActiveTask();
    emit('success', { taskId: taskId.value ?? 0 });
  } catch (e: any) {
    createMessage.error(e?.response?.data?.msg || e?.message || '恢复失败');
  } finally {
    resetLoading.value = false;
  }
}

async function handleSubmitReview(): Promise<void> {
  reviewLoading.value = true;
  try {
    await completeSamBootstrapReview(props.datasetId, { review_passed: true });
    createMessage.success('抽检已通过');
    await loadBootstrapStatus();
  } catch (e: any) {
    createMessage.error(e?.response?.data?.msg || e?.message || '提交失败');
  } finally {
    reviewLoading.value = false;
  }
}

function emitOpenAutoLabel(): void {
  emit('open-auto-label');
  handleClose();
}

function startPolling(): void {
  if (pollTimer) clearInterval(pollTimer);
  const poll = async () => {
    if (!taskId.value) return;
    try {
      const res = await getAutoLabelTask(props.datasetId, taskId.value);
      const task = res?.data ?? res;
      activeTask.value = task;
      taskStatus.value = task?.status || '';
      if (task?.execution_mode === 'cluster' || (task?.pipeline_config?.mode === 'cluster_pipeline')) {
        await loadSubtasks();
      }
      const phase = task?.pipeline_config?.pipeline_phase;
      const bootstrapDone =
        taskStatus.value === 'COMPLETED'
        || phase === 'bootstrap_sam'
        || task?.phase === 'BOOTSTRAP'
        || task?.pipeline_config?.awaiting_sam_review;
      if (bootstrapDone || task?.pipeline_config?.awaiting_sam_review) {
        await loadBootstrapStatus();
      }
      if (['COMPLETED', 'FAILED', 'CANCELLED'].includes(taskStatus.value)) {
        if (pollTimer) clearInterval(pollTimer);
        pollTimer = null;
        if (taskStatus.value === 'COMPLETED') {
          createMessage.success('智能标注流水线已完成');
          emit('success', { taskId: taskId.value });
        }
      }
    } catch {
      /* 轮询失败不关闭 UI */
    }
  };
  poll();
  pollTimer = setInterval(poll, 2500);
}

function handleClose(): void {
  closeDrawer();
}

async function handlePause(): Promise<void> {
  if (!taskId.value) return;
  try {
    await pauseAutoLabelTask(props.datasetId, taskId.value);
    taskStatus.value = 'PAUSED';
    createMessage.success('任务已暂停');
  } catch (e: any) {
    createMessage.error(e?.message || '暂停失败');
  }
}

async function handleResume(): Promise<void> {
  if (!taskId.value) return;
  try {
    await resumeAutoLabelTask(props.datasetId, taskId.value);
    taskStatus.value = 'PROCESSING';
    createMessage.success('任务已恢复');
    startPolling();
  } catch (e: any) {
    createMessage.error(e?.message || '恢复失败');
  }
}

async function handleCancel(): Promise<void> {
  if (!taskId.value) return;
  try {
    await cancelAutoLabelTask(props.datasetId, taskId.value);
    taskStatus.value = 'CANCELLED';
    if (pollTimer) clearInterval(pollTimer);
    createMessage.success('任务已取消');
  } catch (e: any) {
    createMessage.error(e?.message || '取消失败');
  }
}

onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer);
});
</script>

<style lang="less" scoped>
@import '@/views/node/utils/setup-panel.less';

.detail-drawer-header {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding-right: 32px;
}

.detail-drawer-header__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: linear-gradient(135deg, #eef4ff, #dce8ff);
  color: @node-primary;
  flex-shrink: 0;
}

.detail-drawer-header__line {
  display: flex;
  align-items: center;
  flex: 1;
  min-width: 0;
  white-space: nowrap;
  overflow: hidden;
  font-size: 13px;
  line-height: 20px;
}

.detail-drawer-header__title {
  flex-shrink: 0;
  font-size: 15px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.88);
}

.detail-drawer-header__desc {
  flex-shrink: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  color: rgba(0, 0, 0, 0.55);
}

.detail-drawer-header__meta {
  flex-shrink: 0;
  color: rgba(0, 0, 0, 0.4);
  font-size: 12px;
}

.detail-drawer-header__sep {
  flex-shrink: 0;
  margin: 0 6px;
  color: rgba(0, 0, 0, 0.25);
}

.detail-drawer-header__tags {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;

  :deep(.ant-tag) {
    margin: 0;
    line-height: 18px;
    font-size: 12px;
  }
}

.detail-drawer-content {
  display: flex;
  flex-direction: column;
  min-height: 100%;
}

.config-wizard {
  display: flex;
  flex-direction: column;
  gap: @setup-section-gap;
}

.setup-steps-card {
  padding: @setup-section-header-padding;
  border-radius: @setup-panel-radius;
  background: #fff;
  border: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow: @setup-panel-shadow;
}

.setup-steps {
  :deep(.ant-steps-item) {
    flex: 1;
    min-width: 0;
  }

  :deep(.ant-steps-item-icon) {
    width: 28px;
    height: 28px;
    line-height: 28px;
    font-size: 13px;
    margin-inline-end: 8px !important;
  }

  :deep(.ant-steps-item-title) {
    font-size: 14px;
    font-weight: 500;
    line-height: 1.4;
  }

  :deep(.ant-steps-item-description) {
    font-size: 12px;
    line-height: 1.4;
    max-width: none;
    white-space: nowrap;
    color: rgba(0, 0, 0, 0.45);
  }

  :deep(.ant-steps-item-tail) {
    top: 14px;
  }

  :deep(.ant-steps-item-process .ant-steps-item-icon) {
    background: @node-primary;
    border-color: @node-primary;
  }
}

.setup-content-card {
  .setup-section-card();
  padding: 0;
  overflow: hidden;
}

.step-panel-head {
  padding: @setup-section-header-padding;
  border-bottom: 1px solid #f0f0f0;
}

.step-panel-title {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.88);
  line-height: 1.4;
}

.step-panel-body {
  padding: @setup-section-body-padding;
}

.field-control {
  width: 100%;
}

.field-value {
  display: block;
  margin-bottom: 4px;
  font-size: 14px;
  font-weight: 500;
  color: @node-primary;
  line-height: 1.4;
}

.checkbox-stack {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 10px;
}

.list-panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
  font-size: 13px;
  color: rgba(0, 0, 0, 0.65);
}

.list-panel-scroll {
  max-height: 240px;
}

.list-panel {
  display: flex;
  flex-direction: column;
  border: 1px solid #f0f0f0;
  border-radius: 6px;
  background: #fafafa;
  overflow: hidden;
}

.list-panel-row {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 14px;
  margin: 0;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;

  &:last-child {
    border-bottom: none;
  }
}

.list-panel-row__body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  flex: 1;
}

.list-panel-row__title {
  font-size: 13px;
  font-weight: 500;
  color: rgba(0, 0, 0, 0.88);
  line-height: 1.4;
}

.list-panel-row__sub {
  font-size: 12px;
  color: rgba(0, 0, 0, 0.45);
  word-break: break-all;
  line-height: 1.4;
}

.footer-buttons {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}

.footer-nav {
  display: flex;
  gap: 8px;
}

.detail-tabs {
  :deep(.ant-tabs-nav) {
    margin-bottom: 0;
    padding: 0 4px;
    background: #fff;
    border: 1px solid rgba(0, 0, 0, 0.06);
    border-radius: @setup-panel-radius;
    box-shadow: @setup-panel-shadow;

    &::before {
      border-bottom: none;
    }
  }

  :deep(.ant-tabs-tab) {
    padding: 12px 24px;
    font-size: 14px;
  }

  :deep(.ant-tabs-content-holder) {
    padding-top: @setup-section-gap;
  }
}

.monitor-pane {
  .setup-section-card();
  padding: @setup-section-body-padding;
}

.monitor-section {
  margin-bottom: 20px;

  &:last-child {
    margin-bottom: 0;
  }
}

.monitor-section__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}

.monitor-section__title {
  font-size: 14px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.88);
  line-height: 1.4;
}

.monitor-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.setup-desc {
  .setup-desc();
}

.pipeline-steps {
  margin-bottom: 20px;
}

.monitor-alert {
  margin-bottom: 16px;
}

.sam-quality-stats {
  margin: 8px 0 0;
  color: rgba(0, 0, 0, 0.65);
  font-size: 13px;
}

.sam-quality-actions {
  margin-top: 12px;
}

.log-editor {
  height: 280px;
}

.text-muted {
  color: rgba(0, 0, 0, 0.35);
}

.setup-resource-form {
  :deep(.ant-form-item:last-child) {
    margin-bottom: 0;
  }
}
</style>

<style lang="less">
.sam-auto-label-drawer {
  .ant-drawer-header {
    padding: 10px 20px;
    min-height: auto;
    border-bottom: 1px solid #f0f0f0;
  }

  .ant-drawer-close {
    top: 10px;
    inset-inline-end: 16px;
    width: 32px;
    height: 32px;
    line-height: 32px;
  }

  .ant-drawer-title {
    flex: 1;
    min-width: 0;
    line-height: 1;
  }

  .ant-drawer-body {
    background: linear-gradient(180deg, #f7f9fc 0%, #ffffff 120px);
  }

  .scrollbar__wrap {
    padding: 20px 24px !important;
  }

  .ant-drawer-footer {
    padding: 12px 24px;
    border-top: 1px solid #f0f0f0;
    background: #fff;
  }
}
</style>
