FROM debian:trixie-slim

ARG CODER_USER_ID=2001
ARG CODE_SERVER_VERSION=4.109.2
ARG COMPOSE_VERSION=1.5.0

# Install required packages
RUN <<EOF
  set -e; \
  apt update
  apt install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    fuse-overlayfs \
    git \
    gosu \
    python3-venv \
    tini \
    tzdata \
    unzip \
    vim \
    xz-utils
  
  # Create coder group and user
  groupadd -g ${CODER_USER_ID} coder
  useradd -m -u ${CODER_USER_ID} -g coder -s /bin/bash coder
  
  # Download and install code-server
  CODE_TGZ="/tmp/code-server-${CODE_SERVER_VERSION}.tar.gz"
  curl -fsSL -o "$CODE_TGZ" "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz"
  tar -xzf "$CODE_TGZ" -C /tmp
  mv /tmp/code-server-${CODE_SERVER_VERSION}-linux-amd64 /opt/code-server
  ln -s /opt/code-server/bin/code-server /usr/local/bin/code-server

  # Install Docker
  apt remove -y $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc 2>/dev/null | cut -f1) || true
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOT
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOT
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  usermod -aG docker coder
  
  # Set timezone to Asia/Singapore
  cp /usr/share/zoneinfo/Asia/Singapore /etc/localtime
  echo "Asia/Singapore" > /etc/timezone
  \
  # Cleanup
  apt purge -y python3-venv
  apt autoremove -y
  rm -rf /var/cache/apt/* /tmp/* /var/lib/apt/lists/*
EOF

WORKDIR /home/coder

# ENTRYPOINT ["tini", "--", "/bin/bash"]
