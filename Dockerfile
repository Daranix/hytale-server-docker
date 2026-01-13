FROM eclipse-temurin:25-jdk

ENV LANG=C.UTF-8 \
    HYTALE_DOWNLOADER_URL=https://downloader.hytale.com/hytale-downloader.zip \
    HYTALE_HOME=/opt/hytale \
    HYTALE_UID=10000 \
    HYTALE_GID=10000

# Install required tools and create non-root user
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip bash jq ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd -g ${HYTALE_GID} hytale \
 && useradd -u ${HYTALE_UID} -g hytale -d ${HYTALE_HOME} -m -s /bin/bash hytale \
 && mkdir -p ${HYTALE_HOME}/downloader ${HYTALE_HOME}/server ${HYTALE_HOME}/tokens \
 && chown -R hytale:hytale ${HYTALE_HOME}

WORKDIR ${HYTALE_HOME}

# Download and unzip the Hytale downloader
RUN curl -fsSL "$HYTALE_DOWNLOADER_URL" -o /tmp/hytale-downloader.zip \
 && unzip /tmp/hytale-downloader.zip -d ${HYTALE_HOME}/downloader \
 && chmod -R +x ${HYTALE_HOME}/downloader 2>/dev/null || true \
 && rm -f /tmp/hytale-downloader.zip \
 && chown -R hytale:hytale ${HYTALE_HOME}

# Copy entrypoint and set permissions
COPY --chown=hytale:hytale entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER hytale

VOLUME ["${HYTALE_HOME}/server", "${HYTALE_HOME}/tokens"]

EXPOSE 5520

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]