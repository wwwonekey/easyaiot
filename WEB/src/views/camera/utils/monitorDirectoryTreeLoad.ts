import {
  getDirectoryMonitorTree,
  type DeviceInfo,
  type DeviceDirectory,
  type MonitorTreeDeviceNode,
  type MonitorTreeDirectoryNode,
  type NvrInfo,
} from '@/api/device/camera';
import { queryVideoList } from '@/api/device/gb28181';
import type { TreeItem } from '@/components/Tree';
import { buildGbSipNameMap, buildGbSipNameMapFromDirectoryTree } from './monitorGbDisplay';
import {
  buildMonitorDirectoryTreeNodes,
  buildMonitorTreeOptionsFromNvrList,
} from './monitorDeviceTree';
import { fetchNvrListBrief } from './nvrDeviceGroup';
import {
  isGb28181ChannelRecord,
  resolveWvpSipDeviceId,
  wvpDeviceToTableRow,
} from './gb28181DeviceGroup';
import { parseGb28181Source } from './deviceLabel';

export function normalizeMonitorTreePayload(res: unknown): MonitorTreeDirectoryNode[] {
  const payload =
    (res as { code?: number; data?: { tree?: unknown } })?.code !== undefined
      ? (res as { data?: { tree?: unknown } }).data
      : res;
  if (Array.isArray((payload as { tree?: unknown })?.tree)) {
    return (payload as { tree: MonitorTreeDirectoryNode[] }).tree;
  }
  if (Array.isArray(payload)) {
    return payload as MonitorTreeDirectoryNode[];
  }
  return [];
}

export interface MonitorDirectoryTreeBundle {
  rawTree: MonitorTreeDirectoryNode[];
  wvpDevices: Record<string, any>[];
  nvrs: NvrInfo[];
  treeItems: TreeItem[];
  sipNameMap: Map<string, string>;
}

/** 与分屏监控左侧树一致：monitor-tree + WVP 国标列表 + NVR 元数据 */
export async function fetchMonitorDirectoryTreeBundle(): Promise<MonitorDirectoryTreeBundle> {
  const [res, gbRes, nvrs] = await Promise.all([
    getDirectoryMonitorTree(),
    queryVideoList({ page: 1, count: 10000 }).catch(() => ({ data: [] as Record<string, any>[] })),
    fetchNvrListBrief().catch(() => [] as NvrInfo[]),
  ]);
  const rawTree = normalizeMonitorTreePayload(res);
  const wvpDevices = Array.isArray(gbRes?.data) ? gbRes.data : [];
  const nvrList = Array.isArray(nvrs) ? nvrs.filter((n) => n && n.id != null) : [];

  const sipNameMap = buildGbSipNameMap(wvpDevices);
  buildGbSipNameMapFromDirectoryTree(rawTree).forEach((name, sip) => {
    if (!sipNameMap.has(sip)) sipNameMap.set(sip, name);
  });

  const { nvrNameMap, nvrs: nvrArr } = buildMonitorTreeOptionsFromNvrList(nvrList);
  const treeItems = buildMonitorDirectoryTreeNodes(rawTree, {
    sipNameMap,
    nvrNameMap,
    nvrs: nvrArr,
    wvpDevices,
  });

  return { rawTree, wvpDevices, nvrs: nvrArr, treeItems, sipNameMap };
}

export function mapMonitorTreeToDeviceDirectories(
  dirs: MonitorTreeDirectoryNode[],
): DeviceDirectory[] {
  return (dirs || []).map((dir) => ({
    id: dir.id,
    name: dir.name,
    parent_id: dir.parent_id ?? null,
    sort_order: dir.sort_order ?? 0,
    is_default: dir.is_default,
    device_count: dir.device_count ?? dir.devices?.length ?? 0,
    children: mapMonitorTreeToDeviceDirectories(dir.children || []),
  }));
}

export function findMonitorDirectoryNode(
  dirs: MonitorTreeDirectoryNode[],
  directoryId: number,
): MonitorTreeDirectoryNode | null {
  for (const dir of dirs) {
    if (dir.id === directoryId) return dir;
    if (dir.children?.length) {
      const found = findMonitorDirectoryNode(dir.children, directoryId);
      if (found) return found;
    }
  }
  return null;
}

export function monitorTreeDeviceToDeviceInfo(d: MonitorTreeDeviceNode): DeviceInfo {
  return {
    id: d.id,
    name: d.name,
    online: d.online,
    source: d.source ?? undefined,
    device_kind: d.device_kind,
    nvr_id: d.nvr_id ?? undefined,
    nvr_channel: d.nvr_channel,
    nvr_label: d.nvr_label ?? undefined,
    directory_id: d.directory_id ?? undefined,
    http_stream: d.http_stream,
    rtmp_stream: d.rtmp_stream,
    ai_http_stream: d.ai_http_stream,
    ai_rtmp_stream: d.ai_rtmp_stream,
  } as DeviceInfo;
}

/** 目录下设备列表（含默认分组下 WVP 未入库的国标 SIP 行） */
export function buildDirectoryDevicesForTable(
  dirNode: MonitorTreeDirectoryNode,
  wvpDevices: Record<string, any>[] = [],
): DeviceInfo[] {
  const devices = (dirNode.devices || []).map(monitorTreeDeviceToDeviceInfo);
  if (!dirNode.is_default || !wvpDevices.length) {
    return devices;
  }
  const seenSip = new Set<string>();
  for (const d of devices) {
    if (!isGb28181ChannelRecord(d)) continue;
    const parsed = parseGb28181Source(d.source);
    if (parsed?.deviceId) seenSip.add(parsed.deviceId);
  }
  for (const wvp of wvpDevices) {
    const sipId = resolveWvpSipDeviceId(wvp);
    if (!sipId || seenSip.has(sipId)) continue;
    seenSip.add(sipId);
    devices.push(wvpDeviceToTableRow(wvp));
  }
  return devices;
}
