FROM alpine:3.23.3
LABEL maintainer="Steven Iveson <steve@iveson.eu>"
LABEL org.opencontainers.image.source="https://github.com/sjiveson/nfs-server-alpine"
LABEL org.opencontainers.image.description="NFS v4 server based on Alpine Linux"
LABEL org.opencontainers.image.licenses="MIT"
COPY Dockerfile README.md /

RUN apk add --no-cache --update --verbose nfs-utils bash iproute2 && \
    rm -rf /var/cache/apk /tmp /sbin/halt /sbin/poweroff /sbin/reboot && \
    mkdir -p /var/lib/nfs/rpc_pipefs /var/lib/nfs/v4recovery && \
    echo "rpc_pipefs    /var/lib/nfs/rpc_pipefs rpc_pipefs      defaults        0       0" >> /etc/fstab && \
    echo "nfsd  /proc/fs/nfsd   nfsd    defaults        0       0" >> /etc/fstab

COPY exports /etc/
COPY nfsd.sh /usr/bin/nfsd.sh
COPY .bashrc /root/.bashrc

RUN chmod +x /usr/bin/nfsd.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD pidof rpc.mountd > /dev/null || exit 1

ENTRYPOINT ["/usr/bin/nfsd.sh"]
