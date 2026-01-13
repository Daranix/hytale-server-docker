FROM eclipse-temurin:25-jdk

ENV LANG=C.UTF-8 \
    HYTALE_DOWNLOADER_URL=https://downloader.hytale.com/hytale-downloader.zip

# Install required tools on Debian-based image so native glibc loader is available
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip bash jq ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/hytale /usr/local/bin

WORKDIR /opt/hytale

# Download and unzip the Hytale downloader into the image
RUN curl -fsSL "$HYTALE_DOWNLOADER_URL" -o /tmp/hytale-downloader.zip \
 && unzip /tmp/hytale-downloader.zip -d /opt/hytale/downloader \
 && chmod -R +x /opt/hytale/downloader || true \
 && rm -f /tmp/hytale-downloader.zip

# copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/opt/hytale/server"]

EXPOSE 5520

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
