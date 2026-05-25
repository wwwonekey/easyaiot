# syntax=docker/dockerfile:1.4
# 构建阶段：pnpm 依赖目录挂载宿主机 .build-cache/pnpm-store（由 install_linux.sh 预创建）
FROM node:22-alpine3.21 AS builder

RUN npm config set registry https://registry.npmmirror.com/

RUN npm install -g pnpm@9.0.4 && \
    pnpm config set registry https://registry.npmmirror.com/ && \
    pnpm config set network-timeout 600000 && \
    pnpm config set fetch-retries 5 && \
    pnpm config set fetch-retry-mintimeout 20000 && \
    pnpm config set fetch-retry-maxtimeout 120000

WORKDIR /app
RUN mkdir -p /tmp/web-build-logs /pnpm

# 先复制依赖清单与 npmrc（利用层缓存）
COPY package.json pnpm-lock.yaml .npmrc ./

# 预拉依赖到 store（pnpm-store 通过 docker build --build-context 传入，见 install_linux.sh）
RUN --mount=type=bind,from=pnpm-store,source=.,target=/pnpm/store,rw \
    --mount=type=cache,target=/root/.local/share/pnpm/cache,id=web-pnpm-cache-v2 \
    pnpm config set store-dir /pnpm/store && \
    pnpm fetch --frozen-lockfile 2>&1 | tee /tmp/web-build-logs/pnpm-fetch.log || true

COPY . .

# 必须在 COPY 源码后 install，否则 node_modules 不完整（cross-env not found）
RUN --mount=type=bind,from=pnpm-store,source=.,target=/pnpm/store,rw \
    --mount=type=cache,target=/root/.local/share/pnpm/cache,id=web-pnpm-cache-v2 \
    pnpm config set store-dir /pnpm/store && \
    pnpm install --frozen-lockfile 2>&1 | tee /tmp/web-build-logs/pnpm-install.log && \
    test -x node_modules/.bin/cross-env || (echo "=== pnpm install 未生成 node_modules/.bin/cross-env ===" && exit 1)

RUN --mount=type=bind,from=pnpm-store,source=.,target=/pnpm/store,rw \
    pnpm config set store-dir /pnpm/store && \
    set -e && \
    pnpm run build > /tmp/web-build-logs/pnpm-build.log 2>&1 || \
    (echo "=== pnpm build failed, log: ===" && cat /tmp/web-build-logs/pnpm-build.log && exit 1)

RUN test -d dist || (echo "=== dist missing after build ===" && cat /tmp/web-build-logs/pnpm-build.log && exit 1)

FROM nginx:1.29.2-alpine

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

LABEL org.opencontainers.image.authors="basiclab"

WORKDIR /usr/share/nginx/html

RUN mkdir -p /usr/share/nginx/html /app/logs /opt/web-build-logs

COPY ./conf/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/dist /usr/share/nginx/html
COPY --from=builder /tmp/web-build-logs /opt/web-build-logs

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

CMD ["sh", "-c", "mkdir -p /app/logs && cp -af /opt/web-build-logs/. /app/logs/ && echo \"[$(date '+%Y-%m-%d %H:%M:%S')] web-service container started\" >> /app/logs/runtime.log && nginx -g 'daemon off;'"]
