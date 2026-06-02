/** 告警列表展示与筛选共用常量 */

export const ALERT_EVENT_OPTIONS = [
  { value: null, label: '全部' },
  { value: '行人检测', label: '行人检测' },
  { value: 'face_library_match', label: '人脸库匹配' },
  { value: 'plate_library_match', label: '车牌库匹配' },
] as const;

const ALERT_EVENT_LABEL_MAP: Record<string, string> = {
  face_library_match: '人脸库匹配',
  plate_library_match: '车牌库匹配',
  行人检测: '行人检测',
};

export function formatAlertEvent(event?: string | null): string {
  if (!event) return '-';
  return ALERT_EVENT_LABEL_MAP[event] || event;
}

export function getAlertEventTagColor(event?: string | null): string {
  if (event === 'face_library_match') return 'purple';
  if (event === 'plate_library_match') return 'cyan';
  if (event === '行人检测') return 'orange';
  return 'default';
}

export function normalizeAlertBusinessTagsParam(tags: unknown): string | undefined {
  if (Array.isArray(tags)) {
    const normalized = tags.map((t) => String(t).trim()).filter(Boolean);
    return normalized.length ? normalized.join(',') : undefined;
  }
  if (typeof tags === 'string' && tags.trim()) {
    return tags.trim();
  }
  return undefined;
}
