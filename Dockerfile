FROM ubuntu:24.04

# ── Build arguments ────────────────────────────────────────────────────────────
ARG BORE_VERSION=0.6.0
ARG TZ=Asia/Jakarta

# ── Labels ─────────────────────────────────────────────────────────────────────
LABEL maintainer="Ghost Tunnel" \
      version="3.0.0" \
      description="Ghost Tunnel — Production-ready bore.pub TCP Tunnel on Ubuntu 24.04 with Supervisor"

# ── Environment ────────────────────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ} \
    ROOT_PASS=ChangeMe123! \
    NTFY_TOPIC=ghost-mail \
    BORE_SERVER=bore.pub \
    PORTS=22 \
    PORT=8080 \
    LOG_LEVEL=INFO \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# ── Layer 1: System packages ────────────────────────────────────────────────────
# All packages in a single RUN to minimise layers; cache cleaned in the same layer.
RUN apt-get update && apt-get install -y --no-install-recommends \
        # Process manager
        supervisor \
        # Core system tools
        ca-certificates \
        tzdata \
        locales \
        procps \
        # SSH
        openssh-server \
        openssh-client \
        # Cron
        cron \
        # Networking
        curl \
        wget \
        socat \
        net-tools \
        iproute2 \
        iputils-ping \
        dnsutils \
        netcat-openbsd \
        # Utilities
        git \
        unzip \
        zip \
        tar \
        jq \
        nano \
        vim \
        htop \
        screen \
        tmux \
        # Languages & runtimes
        python3 \
        python3-pip \
        nodejs \
        npm \
        golang-go \
        # Build toolchain
        build-essential \
        gcc \
        g++ \
        make \
        bash \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    # Clean up to keep image lean
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ── Layer 2: bore binary ────────────────────────────────────────────────────────
RUN wget -q "https://github.com/ekzhang/bore/releases/download/v${BORE_VERSION}/bore-v${BORE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
        -O /tmp/bore.tar.gz \
    && tar -xzf /tmp/bore.tar.gz -C /usr/local/bin bore \
    && chmod +x /usr/local/bin/bore \
    && rm /tmp/bore.tar.gz \
    && bore --version

# ── Layer 3: Directory structure ────────────────────────────────────────────────
RUN mkdir -p \
        /run/sshd \
        /var/log/supervisor \
        /var/log/ghost-tunnel \
        /etc/supervisor/conf.d \
        /etc/logrotate.d \
        /app

# ── Layer 4: SSH hardening ──────────────────────────────────────────────────────
RUN ssh-keygen -A \
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
        /etc/ssh/sshd_config \
    && printf '\nBanner /etc/ssh/ghost_banner\nPrintMotd yes\n' >> /etc/ssh/sshd_config

# ── Layer 5: MOTD ───────────────────────────────────────────────────────────────
RUN printf '\n  ╔══════════════════════════════════════════════╗\n  ║           G H O S T   T U N N E L           ║\n  ║     Production · Supervisor · Ubuntu 24.04   ║\n  ║          Ubuntu 24.04  ·  bore.pub           ║\n  ╚══════════════════════════════════════════════╝\n\n' > /etc/motd

# ── Layer 6: Copy project files ─────────────────────────────────────────────────
WORKDIR /app

COPY config/sshd_banner.txt     /etc/ssh/ghost_banner
COPY config/supervisord.conf    /etc/supervisor/supervisord.conf
COPY config/conf.d/             /etc/supervisor/conf.d/
COPY config/logrotate/ghost-tunnel /etc/logrotate.d/ghost-tunnel
COPY scripts/startup.sh         /usr/local/bin/startup.sh
COPY scripts/tunnel.sh          /usr/local/bin/tunnel.sh
COPY scripts/watchdog.sh        /usr/local/bin/watchdog.sh
COPY scripts/health.py          /usr/local/bin/health.py
COPY scripts/notify.sh          /usr/local/bin/notify.sh

RUN chmod +x \
        /usr/local/bin/startup.sh \
        /usr/local/bin/tunnel.sh \
        /usr/local/bin/watchdog.sh \
        /usr/local/bin/notify.sh

# ── Expose health-check port ────────────────────────────────────────────────────
EXPOSE 8080

# ── Health check ────────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD supervisorctl -c /etc/supervisor/supervisord.conf status | grep -qv FATAL \
        && curl -sf "http://localhost:${PORT}/health" || exit 1

# ── Supervisor as PID 1 ─────────────────────────────────────────────────────────
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
