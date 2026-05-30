# Pinned CI/runtime image for the koncept CLI.
#
# Multi-stage build:
#   1. build the static-ish Go binary
#   2. ship it on a slim Debian base together with the pinned kcl toolchain
#
# Build from the repository root:
#   docker build -f cmd/koncept/Dockerfile -t koncept:dev .
#
# The kcl-go SDK resolves its runtime from ~/.kcl; bundling the kcl CLI keeps
# `koncept render` and `kcl run` behaviour aligned inside CI.

FROM golang:1.25-bookworm AS build
WORKDIR /src
COPY cmd/koncept/go.mod cmd/koncept/go.sum ./
RUN go mod download
COPY cmd/koncept/ ./
ARG VERSION=dev
ARG BUILD_TIME=unknown
RUN CGO_ENABLED=0 go build \
    -ldflags "-X github.com/idp-concept/koncept/cmd.version=${VERSION} -X github.com/idp-concept/koncept/cmd.buildTime=${BUILD_TIME}" \
    -o /out/koncept .

FROM debian:bookworm-slim AS runtime
ARG KCL_VERSION=0.11.3
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://github.com/kcl-lang/cli/releases/download/v${KCL_VERSION}/kcl-v${KCL_VERSION}-linux-amd64.tar.gz" \
       | tar -xz -C /usr/local/bin kcl \
    && chmod +x /usr/local/bin/kcl

COPY --from=build /out/koncept /usr/local/bin/koncept

ENV KCL_FAST_EVAL=1
WORKDIR /workspace
ENTRYPOINT ["koncept"]
CMD ["--help"]
