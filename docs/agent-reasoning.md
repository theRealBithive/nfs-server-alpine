# Agent Reasoning Log

This file documents the reasoning behind non-obvious changes made to this repository by Claude Code.

---

## 2026-03-27 — Mount `/proc/fs/nfsd` explicitly before starting `rpc.nfsd`

**Change:** Added `mount -t nfsd nfsd /proc/fs/nfsd` to `nfsd.sh` before the `rpc.nfsd` invocation.

**Problem:** After upgrading `nfs-utils` from `2.3.2-r1` (used by the upstream `sjiveson/nfs-server-alpine` image, Alpine ~3.12) to `2.6.4-r6` (Alpine 3.23 with `apk upgrade`), NFS mounts from Kubernetes pods began timing out after 110s. The liveness probe (TCP socket on port 2049) also failed, causing repeated pod restarts — though that was a separate issue fixed by switching to a `pidof rpc.mountd` exec probe.

**Root cause:** `nfs-utils` 2.5+ requires the `nfsd` pseudo-filesystem to be mounted at `/proc/fs/nfsd` before `rpc.nfsd` starts. Without this mount, the kernel NFS server cannot properly bind its sockets in the container's network namespace, making port 2049 unreachable from within the cluster. The `Dockerfile` already adds an `/etc/fstab` entry for this mount, but containers do not process `fstab` at startup — it must be mounted explicitly in the entrypoint script. The old `2.3.x` release worked without this step due to a different internal socket setup path.

**Why not just downgrade nfs-utils?** `nfs-utils 2.3.2` is only available in Alpine 3.12, which is EOL. Alpine 3.23 only ships `2.6.4`. Pinning to an older Alpine base would reintroduce other CVEs. The `apk upgrade` in the Dockerfile was added specifically to patch `zlib` CVEs (`CVE-2026-22184`, `CVE-2026-27171`), so removing it would re-expose the image to those vulnerabilities.

**Liveness probe fix (same session):** Changed the Kubernetes liveness/readiness probe from `tcpSocket` on port 2049 to an `exec` probe using `pidof rpc.mountd`. The `tcpSocket` probe was failing because `rpc.nfsd` runs as a kernel thread and binds port 2049 in the host network namespace, not the pod's — so Kubernetes probing the pod IP:2049 found nothing. The `pidof` check mirrors the health logic already used inside `nfsd.sh`'s own monitor loop.
