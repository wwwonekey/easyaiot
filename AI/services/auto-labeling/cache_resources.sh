#!/bin/bash
# 预下载标注平台离线 wheel → .build-cache/auto-labeling/pip-wheels
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EASYAIOT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
exec "${EASYAIOT_ROOT}/.scripts/docker/cache_python_resources.sh" auto-labeling "$@"
