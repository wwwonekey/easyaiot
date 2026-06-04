import type { LngLat, PoiSearchResult } from '../types';
import { getTiandituKey } from '../constants';

const SEARCH_BASE = 'https://api.tianditu.gov.cn/v2/search';
const GEOCODER_BASE = 'https://api.tianditu.gov.cn/geocoder';

function parsePoiCoords(item: Record<string, unknown>): { lng: number | null; lat: number | null } {
  let lng: number | null = null;
  let lat: number | null = null;

  if (typeof item.lonlat === 'string') {
    const parts = item.lonlat.split(',');
    if (parts.length >= 2) {
      lng = parseFloat(parts[0].trim());
      lat = parseFloat(parts[1].trim());
    }
  }

  if (lng == null || Number.isNaN(lng)) {
    lng = parseFloat(String(item.lon ?? item.lng ?? item.x ?? item.X ?? '')) || null;
  }
  if (lat == null || Number.isNaN(lat)) {
    lat = parseFloat(String(item.lat ?? item.y ?? item.Y ?? '')) || null;
  }

  if (Array.isArray(item.coords) && item.coords.length >= 2) {
    lng = parseFloat(String(item.coords[0])) || lng;
    lat = parseFloat(String(item.coords[1])) || lat;
  }

  if (Array.isArray(item.bbox) && item.bbox.length >= 4) {
    const [minX, minY, maxX, maxY] = item.bbox.map(Number);
    if (!Number.isNaN(minX) && !Number.isNaN(maxX) && (lng == null || Number.isNaN(lng))) {
      lng = (minX + maxX) / 2;
    }
    if (!Number.isNaN(minY) && !Number.isNaN(maxY) && (lat == null || Number.isNaN(lat))) {
      lat = (minY + maxY) / 2;
    }
  }

  return { lng, lat };
}

export async function searchPoi(params: {
  keyword: string;
  page?: number;
  pageSize?: number;
  key?: string;
}): Promise<{ items: PoiSearchResult[]; total: number }> {
  const { keyword, page = 1, pageSize = 10, key = getTiandituKey() } = params;
  if (!keyword.trim()) return { items: [], total: 0 };

  const postStr = JSON.stringify({
    keyWord: keyword,
    mapBound: '-180,-90,180,90',
    level: '13',
    queryType: '1',
    count: pageSize,
    start: (page - 1) * pageSize,
  });

  const url = `${SEARCH_BASE}?postStr=${encodeURIComponent(postStr)}&type=query&tk=${key}`;
  const response = await fetch(url);
  const data = await response.json();
  const resultList: Record<string, unknown>[] = data.result || data.pois || [];

  const items = resultList
    .map((item) => {
      const { lng, lat } = parsePoiCoords(item);
      const name = String(item.name || item.NAME || item.title || item.TITLE || '未知地点');
      return {
        id: String(item.hotPointID || item.id || item.ID || Math.random().toString(36).slice(2, 11)),
        name,
        address: String(item.address || item.addressName || item.ADDRESS || ''),
        lng: lng != null && !Number.isNaN(lng) ? lng : null,
        lat: lat != null && !Number.isNaN(lat) ? lat : null,
        province: String(item.province || item.prov || ''),
        city: String(item.city || item.cityName || ''),
        phone: String(item.phone || ''),
      } satisfies PoiSearchResult;
    })
    .filter((item) => item.name && item.name !== '未知地点');

  return { items, total: data.count || resultList.length };
}

export async function reverseGeocode(params: LngLat & { key?: string }): Promise<string> {
  const { lng, lat, key = getTiandituKey() } = params;
  if (Number.isNaN(lng) || Number.isNaN(lat)) return '';

  const postStr = JSON.stringify({ lon: lng, lat, ver: 1 });
  const url = `${GEOCODER_BASE}?postStr=${encodeURIComponent(postStr)}&type=geocode&tk=${key}`;
  const response = await fetch(url);
  const data = await response.json();

  if (data?.result?.formatted_address) {
    return data.result.formatted_address;
  }

  const comp = data?.result?.addressComponent || {};
  const parts = [comp.province, comp.city, comp.district, comp.street, comp.streetNumber].filter(Boolean);
  return parts.join('');
}
