FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    xmlstarlet \
    jq \
    bc \
    && rm -rf /var/lib/apt/lists/*

# yq — single binary from GitHub releases
RUN curl -sL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

COPY . /opt/the-ark
WORKDIR /opt/the-ark

ENTRYPOINT ["/opt/the-ark/ark"]
