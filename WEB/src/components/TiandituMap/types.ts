/** 天地图公共组件类型定义 */

export type TiandituBaseMapType = 'vec' | 'img';

/** 通用 GIS 地图控制台模式 */
export type GisMapMode = 'markers' | 'picker' | 'track';

/** 通用 GIS 点位数据 */
export interface GisMarkerRow {
  key: string;
  name: string;
  lng: number;
  lat: number;
  remark?: string;
}

export interface LngLat {
  lng: number;
  lat: number;
}

export interface MapMarkerStyle {
  color?: string;
  radius?: number;
  strokeColor?: string;
  strokeWidth?: number;
  icon?: string;
}

export type MapMarkerKind = 'camera' | 'alert' | 'track' | 'picker' | 'custom';

export interface MapMarkerData {
  id: string;
  lng: number;
  lat: number;
  title?: string;
  subtitle?: string;
  kind?: MapMarkerKind;
  online?: boolean;
  /** 安装朝向(°)：0=正北，顺时针；枪机地图扇形指示 */
  heading?: number | null;
  style?: MapMarkerStyle;
  payload?: Record<string, unknown>;
}

export interface MapTrackPoint extends LngLat {
  recordedAt?: string | number;
  speed?: number;
  direction?: number;
  altitude?: number;
}

export interface MapTrackSession {
  id: string;
  deviceId: string;
  title?: string;
  points: MapTrackPoint[];
  color?: string;
}

export interface PoiSearchResult {
  id: string;
  name: string;
  address: string;
  lng: number | null;
  lat: number | null;
  province?: string;
  city?: string;
  phone?: string;
}

export interface MapPickResult extends LngLat {
  address?: string;
}

export interface AlertMapItem {
  id: string | number;
  device_id?: string;
  device_name?: string;
  event?: string;
  time?: string;
  image_url?: string;
  lng?: number | null;
  lat?: number | null;
}

export interface DeviceMapItem {
  id: string;
  name: string;
  lng: number;
  lat: number;
  online?: boolean;
  address?: string | null;
  altitude?: number | null;
  heading?: number | null;
  location_source?: string | null;
  directory_id?: number | null;
}

export interface BasicTiandituMapProps {
  /** 初始中心 [lng, lat]，默认深圳 */
  center?: [number, number];
  zoom?: number;
  baseMapType?: TiandituBaseMapType;
  showToolbar?: boolean;
  showScaleLine?: boolean;
  /** 是否允许点击地图（选址模式） */
  clickable?: boolean;
}

export interface MapToolbarProps {
  baseMapType: TiandituBaseMapType;
  markerCount?: number;
  trackCount?: number;
}
