import Style from 'ol/style/Style';
import Circle from 'ol/style/Circle';
import Fill from 'ol/style/Fill';
import Stroke from 'ol/style/Stroke';
import Text from 'ol/style/Text';
import RegularShape from 'ol/style/RegularShape';
import type { MapMarkerKind, MapMarkerStyle } from '../types';
import { MARKER_COLORS, MARKER_OFFLINE_COLOR } from '../constants';

export function createCircleMarkerStyle(options: MapMarkerStyle & { label?: string } = {}): Style {
  const {
    color = MARKER_COLORS.custom,
    radius = 8,
    strokeColor = '#ffffff',
    strokeWidth = 2,
    label,
  } = options;

  return new Style({
    image: new Circle({
      radius,
      fill: new Fill({ color }),
      stroke: new Stroke({ color: strokeColor, width: strokeWidth }),
    }),
    text: label
      ? new Text({
          text: label,
          offsetY: -radius - 8,
          font: '12px sans-serif',
          fill: new Fill({ color: '#333' }),
          stroke: new Stroke({ color: '#fff', width: 3 }),
        })
      : undefined,
  });
}

/** OpenLayers 旋转角：从正北顺时针朝向角转换为弧度（图标默认指向东） */
export function headingToRotationRad(heading: number): number {
  return ((90 - heading) * Math.PI) / 180;
}

/** 枪机朝向扇形（叠加在圆点之上） */
export function createHeadingWedgeStyle(color: string, heading: number): Style {
  return new Style({
    image: new RegularShape({
      fill: new Fill({ color: `${color}55` }),
      stroke: new Stroke({ color, width: 1.5 }),
      points: 3,
      radius: 24,
      radius2: 3,
      angle: Math.PI / 2,
      rotation: headingToRotationRad(heading),
    }),
  });
}

export function styleForMarkerKind(
  kind: MapMarkerKind = 'custom',
  online?: boolean,
  label?: string,
  heading?: number | null,
): Style | Style[] {
  const color = kind === 'camera' && online === false
    ? MARKER_OFFLINE_COLOR
    : MARKER_COLORS[kind] || MARKER_COLORS.custom;

  const base = createCircleMarkerStyle({
    color,
    radius: kind === 'alert' ? 10 : 8,
    label,
  });

  if (kind === 'camera' && heading != null && !Number.isNaN(Number(heading))) {
    return [base, createHeadingWedgeStyle(color, Number(heading))];
  }
  return base;
}

/** 聚合簇样式 */
export function styleForCluster(size: number): Style {
  const radius = Math.min(22, 10 + Math.log2(size + 1) * 4);
  return new Style({
    image: new Circle({
      radius,
      fill: new Fill({ color: 'rgba(66, 135, 252, 0.85)' }),
      stroke: new Stroke({ color: '#ffffff', width: 2 }),
    }),
    text: new Text({
      text: String(size),
      font: 'bold 12px sans-serif',
      fill: new Fill({ color: '#fff' }),
    }),
  });
}

export function createTrackLineStyle(color = '#52c41a', width = 3): Style {
  return new Style({
    stroke: new Stroke({ color, width }),
  });
}

export function createTrackPlayedStyle(color = '#1677ff', width = 4): Style {
  return new Style({
    stroke: new Stroke({ color, width }),
  });
}
