import { onBeforeUnmount, ref, shallowRef, watch, type Ref } from 'vue';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import Cluster from 'ol/source/Cluster';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import Overlay from 'ol/Overlay';
import type Map from 'ol/Map';
import type { EventsKey } from 'ol/events';
import { unByKey } from 'ol/Observable';
import { boundingExtent } from 'ol/extent';
import { fromLonLat } from 'ol/proj';
import { toMercator } from '../core/coordUtils';
import { styleForCluster, styleForMarkerKind } from '../core/markerStyles';
import { DEFAULT_MAP_CENTER, DEFAULT_MAP_ZOOM, MAP_LAYER_ZINDEX } from '../constants';
import type { MapMarkerData } from '../types';

export interface UseMapMarkersOptions {
  map: Ref<Map | null>;
  onMarkerClick?: (marker: MapMarkerData) => void;
  /** 启用点聚合（默认 true） */
  enableCluster?: boolean | Ref<boolean>;
  /** 聚合像素距离 */
  clusterDistance?: number;
}

function resolveClusterEnabled(option?: boolean | Ref<boolean>): boolean {
  if (option == null) return true;
  if (typeof option === 'boolean') return option;
  return option.value;
}

function layerOnMap(olMap: Map, targetLayer: VectorLayer<VectorSource>) {
  return olMap.getLayers().getArray().includes(targetLayer);
}

export function useMapMarkers(options: UseMapMarkersOptions) {
  const markers = ref<MapMarkerData[]>([]);
  const selectedId = ref<string | null>(null);
  const vectorSource = new VectorSource();
  const clusterSource = new Cluster({
    distance: options.clusterDistance ?? 40,
    source: vectorSource,
  });

  function activeSource(): VectorSource | Cluster {
    return resolveClusterEnabled(options.enableCluster) ? clusterSource : vectorSource;
  }

  const layer = new VectorLayer({
    source: activeSource(),
    zIndex: MAP_LAYER_ZINDEX.marker,
    style: (feature) => {
      const innerFeatures = feature.get('features') as Feature[] | undefined;
      if (innerFeatures && innerFeatures.length > 1) {
        return styleForCluster(innerFeatures.length);
      }
      const target = innerFeatures?.[0] ?? feature;
      const kind = target.get('kind') as MapMarkerData['kind'];
      const online = target.get('online') as boolean | undefined;
      const title = target.get('title') as string | undefined;
      const heading = target.get('heading') as number | null | undefined;
      return styleForMarkerKind(kind, online, title, heading);
    },
  });

  let attachedMap: Map | null = null;
  let popupOverlay: Overlay | null = null;
  let popupEl: HTMLDivElement | null = null;
  let clickListenerKey: EventsKey | null = null;

  function syncClusterSource() {
    const useCluster = resolveClusterEnabled(options.enableCluster);
    layer.setSource(useCluster ? clusterSource : vectorSource);
  }

  function featureToMarker(feature: Feature): MapMarkerData | undefined {
    const id = feature.get('id') as string;
    return markers.value.find((m) => m.id === id);
  }

  function teardownOnMap(olMap: Map) {
    hidePopup();
    if (layerOnMap(olMap, layer)) {
      olMap.removeLayer(layer);
    }
    if (popupOverlay) {
      olMap.removeOverlay(popupOverlay);
      popupOverlay = null;
      popupEl = null;
    }
    if (clickListenerKey) {
      unByKey(clickListenerKey);
      clickListenerKey = null;
    }
  }

  function ensurePopup(olMap: Map) {
    if (popupOverlay) return;
    popupEl = document.createElement('div');
    popupEl.className = 'tianditu-map-popup';
    popupOverlay = new Overlay({
      element: popupEl,
      positioning: 'bottom-center',
      offset: [0, -12],
      stopEvent: false,
    });
    olMap.addOverlay(popupOverlay);
    clickListenerKey = olMap.on('singleclick', handleMapClick);
  }

  function handleMapClick(evt: { pixel: number[] }) {
    if (!options.map.value) return;
    const feature = options.map.value.forEachFeatureAtPixel(evt.pixel, (f) => f);
    if (!feature) {
      hidePopup();
      return;
    }

    const innerFeatures = feature.get('features') as Feature[] | undefined;
    if (innerFeatures && innerFeatures.length > 1) {
      const coords = innerFeatures
        .map((f) => (f.getGeometry() as Point | undefined)?.getCoordinates())
        .filter(Boolean) as number[][];
      if (coords.length) {
        const extent = boundingExtent(coords);
        options.map.value.getView().fit(extent, {
          padding: [80, 80, 80, 80],
          duration: 350,
          maxZoom: (options.map.value.getView().getZoom() ?? 10) + 2,
        });
      }
      return;
    }

    const target = innerFeatures?.[0] ?? feature;
    const marker = featureToMarker(target);
    if (marker) {
      selectedId.value = marker.id;
      showPopup(marker);
      options.onMarkerClick?.(marker);
    }
  }

  function showPopup(marker: MapMarkerData) {
    const olMap = options.map.value;
    if (!olMap) return;
    ensurePopup(olMap);
    if (!popupEl || !popupOverlay) return;
    popupEl.innerHTML = `
      <div class="tianditu-map-popup__title">${marker.title || marker.id}</div>
      ${marker.subtitle ? `<div class="tianditu-map-popup__sub">${marker.subtitle}</div>` : ''}
    `;
    popupOverlay.setPosition(toMercator(marker.lng, marker.lat));
  }

  function hidePopup() {
    popupOverlay?.setPosition(undefined);
    selectedId.value = null;
  }

  function setMarkers(list: MapMarkerData[]) {
    markers.value = list;
    vectorSource.clear();
    const features = list.map((item) => {
      const feature = new Feature({
        geometry: new Point(toMercator(item.lng, item.lat)),
      });
      feature.set('id', item.id);
      feature.set('kind', item.kind ?? 'custom');
      feature.set('online', item.online);
      feature.set('title', item.title);
      feature.set('heading', item.heading ?? null);
      return feature;
    });
    vectorSource.addFeatures(features);
    syncClusterSource();
  }

  function fitToMarkers(padding = 60) {
    const olMap = options.map.value;
    if (!olMap) return;
    const view = olMap.getView();

    if (markers.value.length === 0) {
      view.animate({
        center: fromLonLat(DEFAULT_MAP_CENTER),
        zoom: DEFAULT_MAP_ZOOM,
        duration: 400,
      });
      return;
    }

    if (markers.value.length === 1) {
      const m = markers.value[0];
      view.animate({
        center: fromLonLat([m.lng, m.lat]),
        zoom: 15,
        duration: 400,
      });
      return;
    }

    const coords = markers.value.map((m) => toMercator(m.lng, m.lat));
    const extent = boundingExtent(coords);
    const w = extent[2] - extent[0];
    const h = extent[3] - extent[1];
    if (w < 10 || h < 10) {
      view.animate({
        center: [(extent[0] + extent[2]) / 2, (extent[1] + extent[3]) / 2],
        zoom: 15,
        duration: 400,
      });
      return;
    }
    view.fit(extent, { padding: [padding, padding, padding, padding], duration: 400, maxZoom: 16 });
  }

  function attach() {
    const olMap = options.map.value;
    if (!olMap) return;

    if (attachedMap === olMap && layerOnMap(olMap, layer)) {
      syncClusterSource();
      return;
    }

    if (attachedMap && attachedMap !== olMap) {
      teardownOnMap(attachedMap);
    }

    syncClusterSource();
    if (!layerOnMap(olMap, layer)) {
      olMap.addLayer(layer);
    }
    attachedMap = olMap;
    ensurePopup(olMap);
  }

  function detach() {
    if (attachedMap) {
      teardownOnMap(attachedMap);
      attachedMap = null;
    }
  }

  watch(
    () => options.map.value,
    (olMap, prevMap) => {
      if (olMap) {
        attach();
      } else if (prevMap) {
        teardownOnMap(prevMap);
        attachedMap = null;
      }
    },
    { immediate: true },
  );

  if (options.enableCluster && typeof options.enableCluster !== 'boolean') {
    watch(options.enableCluster, syncClusterSource);
  }

  onBeforeUnmount(detach);

  return {
    layer: shallowRef(layer),
    markers,
    selectedId,
    setMarkers,
    fitToMarkers,
    showPopup,
    hidePopup,
    attach,
    detach,
  };
}
