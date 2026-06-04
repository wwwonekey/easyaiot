import type { MapMarkerKind } from './types';

/** 默认地图中心：深圳（市民中心附近） */
export const DEFAULT_MAP_CENTER: [number, number] = [114.057868, 22.543099];
export const DEFAULT_MAP_ZOOM = 10;

export const MAP_LAYER_ZINDEX = {
  base: 0,
  track: 10,
  marker: 20,
  picker: 30,
  overlay: 40,
} as const;

export const MARKER_COLORS: Record<MapMarkerKind, string> = {
  camera: '#1677ff',
  alert: '#ff4d4f',
  track: '#52c41a',
  picker: '#e63946',
  custom: '#722ed1',
};

export const MARKER_OFFLINE_COLOR = '#bfbfbf';

export function getTiandituKey(): string {
  return import.meta.env.VITE_TIANDITU_KEY || '';
}
