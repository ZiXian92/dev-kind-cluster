FROM alpine:3.23

ARG CODE_SERVER_VERSION=4.109.2
ARG COMPOSE_VERSION=v5.0.2

RUN set -e; \
  apk update; \
  apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    docker \
    git \
    nodejs \
    tar \
    tini \
    tzdata \
    xz \
  ; \
  # Create coder group and user (uid 2001)
  addgroup -g 2001 coder; \
  adduser -D -u 2001 -G coder -s /bin/bash coder; \
  # Allow coder user to run docker commands
  addgroup coder docker; \
  # Make sure coder user can access Docker socket (mounted from daemon container)
  echo "export DOCKER_HOST=${DOCKER_HOST}" >> /home/coder/.bashrc; \
  # Update CA certificates
  echo "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURERENDQWZTZ0F3SUJBZ0lRWGZPLzl3RThlZ1lLc0pkUWRsY1l5REFOQmdrcWhraUc5dzBCQVFzRkFEQVoKTVJjd0ZRWURWUVFEREE0cUxteHZZMkZzZEdWemRDNXRaVEFlRncweU5qQXlNVFl4TWpBNU1UZGFGdzB5TnpBeQpNVFl4TWpBNU1UZGFNQmt4RnpBVkJnTlZCQU1NRGlvdWJHOWpZV3gwWlhOMExtMWxNSUlCSWpBTkJna3Foa2lHCjl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF4Vk1nNnM5dlNySjlld0o4V3o0ZnVyaXJYVWYzandSUStpZ3UKazA0MjZRSDV0RVZnOXZpKzJVWEJwZTdRSDlKMitoT0VLVytaeUdJWnFiVDZaNHdaWkY1ZXlYRXpzd1pha0lWKwp6RkRCdFJjL1l2TWgvVmFXWmRib1RPSHVmTmtuem5OeWVVWWpFMFFMbDgvcWluUmRYOUV2UVRBb3JENENPWGo5CjJNZ3dzbDR6Q2c5bHdtaGNWaDluMFB6RG5UK1ZKajF1UnRKYmppeURiRGwyOHBCWTFnSkVCZ2NWY25HWXBtRHMKR0xLMG1QSXQrblFuS3ZjRnloQ2FDQTJDL0xRS2szMlJVa1NNdjdqalNFSVZPa0gzdUVEdkZ1WFdoRm9yelNpZwpBamliamYzRHV1dDd1ZWw3VWxBcTJncEZONmlsZ2F0ZlNFd2xmUWVvYzBRZ1FmTkhLd0lEQVFBQm8xQXdUakFPCkJnTlZIUThCQWY4RUJBTUNCYUF3RXdZRFZSMGxCQXd3Q2dZSUt3WUJCUVVIQXdFd0RBWURWUjBUQVFIL0JBSXcKQURBWkJnTlZIUkVFRWpBUWdnNHFMbXh2WTJGc2RHVnpkQzV0WlRBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQQpoc0lxZ3YyUllDWW5POHJzbGUza3EzNTZDY2djeXVucjZPc1FEUzBjRzIxRUx1TTdtSFNsaSt4TzBLSVZmTnJSCkJmNHVYb1Q4dGRId05tSHpJNHppbFRmMnoxMUFtUkcrVk9wdlU0bEEwYlgxZ0tDSTR3dm83VHM4V0wzUFpUeXEKc2hodFEwZUpWZy9Jc0R0cmVQVEhCZWp5YnZ6d24wc3YyYkRiL2pHU2lNYXBwdHJMYzlRTEZ5d2pLK3hPRUM0SApqc1gxZ201alA1TDAwQjZFMXpNV1BRVVFtbGlZQmp3UXVpN2FuamdkTzhqNnI4OE9mNllVWDFLZzlDNnAvKzdCCjg1UTNoZk9RVDltTDBSUEMzdHpoaWs5aldlTlhkWnBSVW5hL2xrcDNOY1JVQjJYZTlEaEV1RUVmeTNFRVhpencKNmVWdkwxNytIb1JQNUFraVd0ZHVaZz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K" | base64 -d > /usr/local/share/ca-certificates/localtest-me.crt; \
  update-ca-certificates; \
  # Download and install code-server (manual, no install script)
  CODE_TGZ="/tmp/code-server-${CODE_SERVER_VERSION}.tar.gz"; \
  curl -fsSL -o "$CODE_TGZ" "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz"; \
  tar -xzf "$CODE_TGZ" -C /tmp; \
  mv /tmp/code-server-${CODE_SERVER_VERSION}-linux-amd64 /opt/code-server; \
  ln -s /opt/code-server/bin/code-server /usr/local/bin/code-server; \
  # Replace code server's node with Alpine's node
  ln -sf /usr/bin/node /opt/code-server/lib/node; \
  # Download docker-compose standalone binary
  curl -fsSL -o /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64"; \
  chmod +x /usr/local/bin/docker-compose; \
  # Set timezone to Asia/Singapore
  cp /usr/share/zoneinfo/Asia/Singapore /etc/localtime; \
  echo "Asia/Singapore" > /etc/timezone; \
  # Cleanup
  apk del tzdata; \
  rm -rf /var/cache/apk/* /tmp/*;

USER coder
WORKDIR /home/coder
