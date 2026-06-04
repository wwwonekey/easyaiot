import { ref } from 'vue';
import { getDeviceLocations, type DeviceLocationInfo } from '@/api/device/camera';
import { formatHeadingSummary, hasDeviceLocation } from '@/views/camera/utils/deviceLocation';
import type { DeviceMapItem, MapMarkerData } from '../types';

export function useDeviceMapData() {
  const loading = ref(false);
  const devices = ref<DeviceMapItem[]>([]);
  const error = ref<string | null>(null);

  async function load(params?: { directory_id?: number; has_location?: boolean }) {
    loading.value = true;
    error.value = null;
    try {
      const res = await getDeviceLocations(params) as DeviceLocationInfo[] | { data?: DeviceLocationInfo[] };
      const list = Array.isArray(res) ? res : (res?.data || []);
      devices.value = (list || [])
        .filter((d) => hasDeviceLocation(d) && d.longitude != null && d.latitude != null)
        .map((d) => ({
          id: d.id,
          name: d.name,
          lng: Number(d.longitude),
          lat: Number(d.latitude),
          online: d.online,
          address: d.address,
          altitude: d.altitude,
          heading: d.heading ?? null,
          location_source: d.location_source,
          directory_id: d.directory_id,
        }));
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : '加载摄像头位置失败';
      devices.value = [];
    } finally {
      loading.value = false;
    }
  }

  function toMarkers(filterOnline?: boolean | null): MapMarkerData[] {
    return devices.value
      .filter((d) => filterOnline == null || d.online === filterOnline)
      .map((d) => {
        const subtitleParts = [d.address, formatHeadingSummary(d.heading)].filter(Boolean);
        return {
          id: d.id,
          lng: d.lng,
          lat: d.lat,
          title: d.name,
          subtitle: subtitleParts.length ? subtitleParts.join(' · ') : undefined,
          kind: 'camera' as const,
          online: d.online,
          heading: d.heading ?? null,
          payload: { ...d },
        };
      });
  }

  function findById(deviceId: string): DeviceMapItem | undefined {
    return devices.value.find((d) => d.id === deviceId);
  }

  return { loading, devices, error, load, toMarkers, findById };
}
