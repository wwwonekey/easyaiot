import logging
import os
from typing import Iterable, Optional, Tuple
from urllib.parse import urlparse

import requests

_logger = logging.getLogger(__name__)


GB28181_SOURCE_PREFIX = 'gb28181://'


def is_gb28181_source(source: Optional[str]) -> bool:
    return bool(source and source.strip().lower().startswith(GB28181_SOURCE_PREFIX))


def parse_gb28181_source(source: Optional[str]) -> Optional[Tuple[str, str]]:
    if not is_gb28181_source(source):
        return None

    parsed = urlparse(source.strip())
    device_id = (parsed.netloc or '').strip()
    channel_id = (parsed.path or '').strip('/ ')
    if not device_id or not channel_id:
        return None
    return device_id, channel_id


def _candidate_bases() -> Iterable[str]:
    configured_base = (os.getenv('GB28181_SERVICE_URL') or '').strip().rstrip('/')
    if configured_base:
        yield configured_base

    gateway_url = (os.getenv('GATEWAY_URL') or '').strip().rstrip('/')
    if gateway_url:
        if gateway_url.endswith('/admin-api'):
            yield f'{gateway_url}/gb28181'
        else:
            yield f'{gateway_url}/admin-api/gb28181'

    yield 'http://localhost:48088/api'


def _build_play_url(base_url: str, device_id: str, channel_id: str) -> str:
    base = base_url.rstrip('/')
    if base.endswith('/api'):
        return f'{base}/play/start/{device_id}/{channel_id}'
    return f'{base}/play/start/{device_id}/{channel_id}'


def _body_suggests_hevc_rtmp(body: dict) -> bool:
    """播放接口返回的 RTMP 地址若标明 HEVC/H.265，OpenCV 内置 FFmpeg 拉 RTMP(FLV) 常失败 (codec_id=0)。"""
    if not isinstance(body, dict):
        return False
    for key in ('rtmp', 'rtmps'):
        u = body.get(key)
        if not isinstance(u, str) or not u.strip():
            continue
        lu = u.lower()
        if 'h265' in lu or 'hevc' in lu:
            return True
    return False


def _stream_url_candidates(body: dict) -> list:
    """
    按协议顺序返回候选播放地址。

    默认 (GB28181_PLAY_PROTOCOL=rtmp_first) 将 RTMP 置于 RTSP 之前：
    ZLMediaKit 在「RTMP 协议无读者」时会触发 on_stream_none_reader；WVP/iot-gb28181
    在 streamOnDemand=true 时会对国标 rtp 流返回 close。若仅使用 RTSP 拉流，则
    RTMP 侧始终无读者，约 streamNoneReaderDelayMS（常配 20s）后整路流被释放，
    实时算法仍用 OpenCV/FFmpeg 拉流会表现为灰屏/断流。以 RTMP 作为输入时，拉流端
    会占用 RTMP 读者，可保持流存活。

    若环境仅通 RTSP 或拉 RTMP 失败，可设 GB28181_PLAY_PROTOCOL=rtsp_first 恢复旧顺序。

    GB28181_HEVC_RTSP_FIRST（默认 1）：当播放接口返回的 RTMP 地址含 HEVC/H.265 线索时，
    在仍为 rtmp_first 策略的前提下自动改为「先 RTSP」——用于规避 OpenCV VideoCapture 对
    RTMP+HEVC 无法建解码器的问题。若因此出现 ZLM「无 RTMP 读者断流」，可调大
    streamNoneReaderDelayMS，或设 GB28181_HEVC_RTSP_FIRST=0 并改用带 libx265 的 FFmpeg 构建 OpenCV。
    """
    flv_block = [
        body.get('flv'),
        body.get('https_flv'),
        body.get('ws_flv'),
    ]
    other = [
        body.get('fmp4'),
        body.get('hls'),
        body.get('rtc'),
        body.get('rtcs'),
    ]
    mode = (os.getenv('GB28181_PLAY_PROTOCOL') or 'rtmp_first').strip().lower()
    if mode in ('rtsp_first', 'rtsp', 'legacy'):
        return [
            body.get('rtsp'),
            body.get('rtsps'),
            body.get('rtmp'),
            body.get('rtmps'),
            *flv_block,
            *other,
        ]
    # 默认：rtmp_first；若接口标明 HEVC 的 RTMP，则对 OpenCV 侧优先 RTSP
    hevc_rtsp_first = (os.getenv('GB28181_HEVC_RTSP_FIRST', '1').strip().lower() not in (
        '0', 'false', 'no', 'off',
    ))
    if hevc_rtsp_first and _body_suggests_hevc_rtmp(body if isinstance(body, dict) else {}):
        _logger.info(
            'GB28181: 检测到 HEVC/H.265 的 RTMP 播放地址，已优先选用 RTSP（缓解 OpenCV RTMP codec_id=0）；'
            '若需强制 RTMP 优先请设 GB28181_HEVC_RTSP_FIRST=0'
        )
        return [
            body.get('rtsp'),
            body.get('rtsps'),
            body.get('rtmp'),
            body.get('rtmps'),
            *flv_block,
            *other,
        ]
    return [
        body.get('rtmp'),
        body.get('rtmps'),
        body.get('rtsp'),
        body.get('rtsps'),
        *flv_block,
        *other,
    ]


def _extract_stream_url(payload: dict) -> Optional[str]:
    body = payload.get('data') if isinstance(payload.get('data'), dict) else payload
    candidates = _stream_url_candidates(body if isinstance(body, dict) else {})
    return next((url for url in candidates if isinstance(url, str) and url.strip()), None)


def resolve_gb28181_source(
    source: Optional[str],
    *,
    timeout: int = 15,
    logger=None,
) -> Optional[str]:
    parsed = parse_gb28181_source(source)
    if not parsed:
        return source

    device_id, channel_id = parsed
    headers = {}
    jwt_token = (os.getenv('JWT_TOKEN') or '').strip()
    if jwt_token:
        headers['X-Authorization'] = f'Bearer {jwt_token}'

    errors = []
    for base_url in _candidate_bases():
        play_url = _build_play_url(base_url, device_id, channel_id)
        try:
            response = requests.get(play_url, headers=headers, timeout=timeout)
            response.raise_for_status()
            payload = response.json()
            stream_url = _extract_stream_url(payload if isinstance(payload, dict) else {})
            if stream_url:
                if logger:
                    logger.info(
                        f'GB28181源解析成功: {device_id}/{channel_id} -> {stream_url} (via {base_url})'
                    )
                return stream_url
            errors.append(f'{base_url}: 未返回可播放流地址')
        except Exception as exc:
            errors.append(f'{base_url}: {exc}')

    if logger:
        logger.error(
            f'GB28181源解析失败: {device_id}/{channel_id}, errors={"; ".join(errors)}'
        )
    return None
