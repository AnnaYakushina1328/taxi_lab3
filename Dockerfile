FROM ghcr.io/userver-framework/ubuntu-22.04-userver:latest AS builder

WORKDIR /app

COPY . .

ENV HOME=/tmp
ENV CCACHE_DIR=/tmp/.ccache

RUN rm -rf build-debug \
    && mkdir -p "$CCACHE_DIR" \
    && make build-debug

FROM ghcr.io/userver-framework/ubuntu-22.04-userver:latest

WORKDIR /app

COPY --from=builder /app/build-debug/taxi_service /app/taxi_service
COPY --from=builder /app/configs /app/configs
COPY --from=builder /app/openapi.yaml /app/openapi.yaml
COPY --from=builder /app/README.md /app/README.md

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --retries=5 CMD curl -fsS http://127.0.0.1:8080/ping || exit 1

CMD ["./taxi_service", "-c", "configs/static_config.yaml"]
