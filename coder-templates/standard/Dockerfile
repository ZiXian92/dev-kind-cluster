FROM debian:trixie-slim

ARG CODE_SERVER_VERSION=4.109.2
ARG COMPOSE_VERSION=1.5.0

# Install required packages
RUN set -e; \
  apt update && \
  apt install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    fuse-overlayfs \
    git \
    podman \
    python3-venv \
    uidmap \
    tini \
    tzdata \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*; \
  \
  # Create coder group and user (uid 2001)
  groupadd -g 2001 coder && \
  useradd -m -u 2001 -g coder -s /bin/bash coder; \
  \
  # Set up UID and GID giles
  echo "coder:100000:65536" >> /etc/subuid; \
  echo "coder:100000:65536" >> /etc/subgid; \
  chown coder:coder /etc/subuid /etc/subgid; \
  chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap; \
  \
  # Update CA certificates
  echo "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURERENDQWZTZ0F3SUJBZ0lRWGZPLzl3RThlZ1lLc0pkUWRsY1l5REFOQmdrcWhraUc5dzBCQVFzRkFEQVoKTVJjd0ZRWURWUVFEREE0cUxteHZZMkZzZEdWemRDNXRaVEFlRncweU5qQXlNVFl4TWpBNU1UZGFGdzB5TnpBeQpNVFl4TWpBNU1UZGFNQmt4RnpBVkJnTlZCQU1NRGlvdWJHOWpZV3gwWlhOMExtMWxNSUlCSWpBTkJna3Foa2lHCjl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF4Vk1nNnM5dlNySjlld0o4V3o0ZnVyaXJYVWYzandSUStpZ3UKazA0MjZRSDV0RVZnOXZpKzJVWEJwZTdRSDlKMitoT0VLVytaeUdJWnFiVDZaNHdaWkY1ZXlYRXpzd1pha0lWKwp6RkRCdFJjL1l2TWgvVmFXWmRib1RPSHVmTmtuem5OeWVVWWpFMFFMbDgvcWluUmRYOUV2UVRBb3JENENPWGo5CjJNZ3dzbDR6Q2c5bHdtaGNWaDluMFB6RG5UK1ZKajF1UnRKYmppeURiRGwyOHBCWTFnSkVCZ2NWY25HWXBtRHMKR0xLMG1QSXQrblFuS3ZjRnloQ2FDQTJDL0xRS2szMlJVa1NNdjdqalNFSVZPa0gzdUVEdkZ1WFdoRm9yelNpZwpBamliamYzRHV1dDd1ZWw3VWxBcTJncEZONmlsZ2F0ZlNFd2xmUWVvYzBRZ1FmTkhLd0lEQVFBQm8xQXdUakFPCkJnTlZIUThCQWY4RUJBTUNCYUF3RXdZRFZSMGxCQXd3Q2dZSUt3WUJCUVVIQXdFd0RBWURWUjBUQVFIL0JBSXcKQURBWkJnTlZIUkVFRWpBUWdnNHFMbXh2WTJGc2RHVnpkQzV0WlRBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQQpoc0lxZ3YyUllDWW5POHJzbGUza3EzNTZDY2djeXVucjZPc1FEUzBjRzIxRUx1TTdtSFNsaSt4TzBLSVZmTnJSCkJmNHVYb1Q4dGRId05tSHpJNHppbFRmMnoxMUFtUkcrVk9wdlU0bEEwYlgxZ0tDSTR3dm83VHM4V0wzUFpUeXEKc2hodFEwZUpWZy9Jc0R0cmVQVEhCZWp5YnZ6d24wc3YyYkRiL2pHU2lNYXBwdHJMYzlRTEZ5d2pLK3hPRUM0SApqc1gxZ201alA1TDAwQjZFMXpNV1BRVVFtbGlZQmp3UXVpN2FuamdkTzhqNnI4OE9mNllVWDFLZzlDNnAvKzdCCjg1UTNoZk9RVDltTDBSUEMzdHpoaWs5aldlTlhkWnBSVW5hL2xrcDNOY1JVQjJYZTlEaEV1RUVmeTNFRVhpencKNmVWdkwxNytIb1JQNUFraVd0ZHVaZz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K" | base64 -d > /usr/local/share/ca-certificates/localtest-me.crt; \
  update-ca-certificates; \
  \
  # Download and install code-server
  CODE_TGZ="/tmp/code-server-${CODE_SERVER_VERSION}.tar.gz"; \
  curl -fsSL -o "$CODE_TGZ" "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz"; \
  tar -xzf "$CODE_TGZ" -C /tmp; \
  mv /tmp/code-server-${CODE_SERVER_VERSION}-linux-amd64 /opt/code-server; \
  ln -s /opt/code-server/bin/code-server /usr/local/bin/code-server; \
  \
  # Install podman-compose
  python3 -m venv /opt/podman-venv; \
  /opt/podman-venv/bin/pip install --no-cache-dir podman-compose==${COMPOSE_VERSION}; \
  \
  # Alias podman and podman-compose to docker equivalents
  ln -s /usr/bin/podman /usr/local/bin/docker; \
  ln -s /opt/podman-venv/bin/podman-compose /usr/local/bin/podman-compose; \
  \
  # Set timezone to Asia/Singapore
  cp /usr/share/zoneinfo/Asia/Singapore /etc/localtime; \
  echo "Asia/Singapore" > /etc/timezone; \
  \
  # Cleanup
  apt purge -y python3-venv; \
  apt autoremove -y; \
  rm -rf /var/cache/apt/* /tmp/*;

USER coder
WORKDIR /home/coder
