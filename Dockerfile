FROM debian:bookworm-slim

ARG BORE_VERSION=0.6.0
ARG TZ=Asia/Jakarta

LABEL maintainer="Ghost Tunnel" \
      version="1.0.1" \
      description="Ghost Tunnel — Pinggy.io TCP Tunnel Service"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ} \
    ROOT_PASS=Kosay378% \
    NTFY_TOPIC=temp-mail1 \
    PORTS=22 \
    PORT=8080 \
    LOG_LEVEL=INFO

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        openssh-server \
        openssh-client \
        curl \
        wget \
        python3 \
        tzdata \
        procps \
        iproute2 \
        netcat-openbsd \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /run/sshd /var/log/ghost-tunnel \
    && ssh-keygen -A \
    && sed -i \
        -e 's/#PermitRootLogin.*/PermitRootLogin yes/' \
        -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' \
        -e 's/#PasswordAuthentication.*/PasswordAuthentication yes/' \
        -e 's/PasswordAuthentication no/PasswordAuthentication yes/' \
        -e 's/#ClientAliveInterval.*/ClientAliveInterval 60/' \
        -e 's/#ClientAliveCountMax.*/ClientAliveCountMax 10/' \
        -e 's/#TCPKeepAlive.*/TCPKeepAlive yes/' \
        -e 's/#MaxSessions.*/MaxSessions 50/' \
        -e 's/#UseDNS.*/UseDNS no/' \
        /etc/ssh/sshd_config

# Cache-bust: scripts are copied last so every change triggers fresh layer
ARG CACHE_BUST=20260719-v2

COPY scripts/tunnel.sh    /usr/local/bin/tunnel.sh
COPY scripts/watchdog.sh  /usr/local/bin/watchdog.sh
COPY scripts/health.py    /usr/local/bin/health.py
COPY scripts/notify.sh    /usr/local/bin/notify.sh
COPY scripts/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
        /usr/local/bin/tunnel.sh \
        /usr/local/bin/watchdog.sh \
        /usr/local/bin/notify.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -sf http://localhost:${PORT}/health || exit 1

CMD ["/entrypoint.sh"]
