import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';
import type { TiandituBaseMapType } from '../types';
import { getTiandituKey } from '../constants';

function wmtsUrl(server: string, layer: string, key: string): string {
  return `https://${server}.tianditu.gov.cn/${layer}/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=${layer.split('_')[0]}&STYLE=default&TILEMATRIXSET=w&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&FORMAT=tiles&tk=${key}`;
}

function labelUrl(server: string, layer: string, key: string): string {
  return `https://${server}.tianditu.gov.cn/${layer}/wmts?tk=${key}&layer=${layer.split('_')[0]}&style=default&tilematrixset=w&Service=WMTS&Request=GetTile&Version=1.0.0&Format=tiles&TileMatrix={z}&TileCol={x}&TileRow={y}`;
}

/**
 * 创建天地图底图图层组（矢量/影像 + 注记）
 */
export function createTiandituBaseLayers(
  type: TiandituBaseMapType = 'vec',
  key: string = getTiandituKey(),
): TileLayer<XYZ>[] {
  if (!key) {
    console.warn('[TiandituMap] VITE_TIANDITU_KEY 未配置，瓦片可能无法加载');
  }

  if (type === 'img') {
    return [
      new TileLayer({
        source: new XYZ({
          url: wmtsUrl('t0', 'img_w', key),
          projection: 'EPSG:3857',
        }),
      }),
      new TileLayer({
        source: new XYZ({
          url: labelUrl('t1', 'cia_w', key),
          projection: 'EPSG:3857',
        }),
      }),
    ];
  }

  return [
    new TileLayer({
      source: new XYZ({
        url: wmtsUrl('t0', 'vec_w', key),
        projection: 'EPSG:3857',
      }),
    }),
    new TileLayer({
      source: new XYZ({
        url: labelUrl('t1', 'cva_w', key),
        projection: 'EPSG:3857',
      }),
    }),
  ];
}
