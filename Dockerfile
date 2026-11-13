# GitHub Actions self-hosted runner for Railway: the official runner image, a few build
# tools most workflows expect, and an entrypoint that registers it once and keeps it running.
FROM ghcr.io/actions/actions-runner:2.338.2
USER root
# The official image is minimal. Compilers, Python and zip are what workflows most often
# assume a Linux runner has; anything else can be installed in a job with sudo apt-get.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential python3 python3-venv zip xz-utils \
    && rm -rf /var/lib/apt/lists/*
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod 755 /usr/local/bin/railway-entrypoint.sh
# Starts as root to fix the volume's owner, then runs the runner as the runner user.
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
