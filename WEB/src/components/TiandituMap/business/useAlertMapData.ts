import { computed, ref } from 'vue';
import { queryAlarmList } from '@/api/device/calculate';
import type { AlertMapItem, MapMarkerData } from '../types';
import { useDeviceMapData } from './useDeviceMapData';

export interface AlertMapQuery {
  pageNo?: number;
  pageSize?: number;
  device_id?: string;
  begin_datetime?: string;
  end_datetime?: string;
  event?: string;
  task_name?: string;
  object?: string;
  business_tags?: string;
}

/** 告警地图：通过 device_id 关联摄像头 WGS84 坐标 */
export function useAlertMapData() {
  const loading = ref(false);
  const alerts = ref<AlertMapItem[]>([]);
  const total = ref(0);
  const error = ref<string | null>(null);
  const deviceData = useDeviceMapData();

  async function loadAlerts(params: AlertMapQuery = {}) {
    loading.value = true;
    error.value = null;
    try {
      const res = await queryAlarmList({
        pageNo: params.pageNo ?? 1,
        pageSize: params.pageSize ?? 100,
        device_id: params.device_id,
        begin_datetime: params.begin_datetime,
        end_datetime: params.end_datetime,
        event: params.event,
        task_name: params.task_name,
        object: params.object,
        business_tags: params.business_tags,
      });
      const list = (res?.alert_list || res?.data?.alert_list || []) as AlertMapItem[];
      alerts.value = list;
      total.value = res?.total ?? res?.data?.total ?? list.length;

      await deviceData.load({ has_location: true });
      enrichAlertsWithLocation();
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : '加载告警失败';
      alerts.value = [];
    } finally {
      loading.value = false;
    }
  }

  function enrichAlertsWithLocation() {
    alerts.value = alerts.value.map((alert) => {
      if (!alert.device_id) return alert;
      const device = deviceData.findById(alert.device_id);
      if (!device) return alert;
      return { ...alert, lng: device.lng, lat: device.lat };
    });
  }

  const alertsWithLocation = computed(() =>
    alerts.value.filter((a) => a.lng != null && a.lat != null),
  );

  function toAlertMarkers(): MapMarkerData[] {
    return alertsWithLocation.value.map((a) => ({
      id: String(a.id),
      lng: Number(a.lng),
      lat: Number(a.lat),
      title: a.event || '告警',
      subtitle: a.device_name || a.device_id,
      kind: 'alert' as const,
      payload: { ...a },
    }));
  }

  function toCameraMarkers(): MapMarkerData[] {
    return deviceData.toMarkers();
  }

  /** 合并摄像头 + 告警（同坐标告警偏移避免重叠） */
  function toCombinedMarkers(): MapMarkerData[] {
    const cameraMarkers = toCameraMarkers();
    const alertMarkers = toAlertMarkers();
    const coordCount = new Map<string, number>();

    return [...cameraMarkers, ...alertMarkers.map((m) => {
      const key = `${m.lng.toFixed(5)},${m.lat.toFixed(5)}`;
      const count = coordCount.get(key) ?? 0;
      coordCount.set(key, count + 1);
      if (count === 0) return m;
      const offset = count * 0.00015;
      return { ...m, lng: m.lng + offset, lat: m.lat + offset };
    })];
  }

  return {
    loading,
    alerts,
    total,
    error,
    alertsWithLocation,
    deviceData,
    loadAlerts,
    toAlertMarkers,
    toCameraMarkers,
    toCombinedMarkers,
  };
}
