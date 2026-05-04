FROM google/cloud-sdk:slim

# Set environment variables
ENV PORT=8080
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    curl git vim wget jq fuse nano \
    bash-completion \
    netstat-nat \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install gcsfuse
RUN curl -fsSL https://github.com/GoogleCloudPlatform/gcsfuse/releases/download/v2.4.0/gcsfuse_2.4.0_amd64.deb \
    -o /tmp/gcsfuse.deb \
    && dpkg -i /tmp/gcsfuse.deb \
    && rm /tmp/gcsfuse.deb

# Install ttyd
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 \
    -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

# Configure shell
RUN cat >> /root/.bashrc << 'EOF'
export TERM=xterm-256color
export CLICOLOR=1
alias ls="ls --color=auto"
alias ll="ls -lah --color=auto"
export PS1="\[\e[01;32m\]\u@gcp-cli\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\]\$ "
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi
if [ -f /usr/lib/google-cloud-sdk/completion.bash.inc ]; then
    . /usr/lib/google-cloud-sdk/completion.bash.inc
fi
EOF

# Create startup script - SIMPLIFIED VERSION
RUN mkdir -p /app && cat > /app/start.sh << 'EOF'
#!/bin/bash
set -e

# Set defaults
SHELL_PASSWORD="${SHELL_PASSWORD:-admin}"
PORT="${PORT:-8080}"

echo "Starting GCP Web CLI on port ${PORT}..."

# Create workspace
mkdir -p /root/workspace

# Set project
gcloud config set project llm-mcp-463803 --quiet 2>/dev/null || true

# Start ttyd - CRITICAL: Must listen on PORT environment variable
exec ttyd --port "${PORT}" --writable bash
EOF

chmod +x /app/start.sh

EXPOSE 8080
WORKDIR /root

# CRITICAL: Must use exec form of CMD to properly handle signals
CMD ["/app/start.sh"]