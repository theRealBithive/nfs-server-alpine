# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Docker image that runs an NFS v4 server on Alpine Linux. It exposes NFS over TCP on port 2049. The image is configured entirely via environment variables at container runtime.

## Build & Run

```bash
# Build the image
docker build -t nfs-server-alpine .

# Run (minimum required: SHARED_DIRECTORY)
docker run -d --name nfs --privileged \
  -v /some/where/fileshare:/nfsshare \
  -e SHARED_DIRECTORY=/nfsshare \
  -p 2049:2049 \
  nfs-server-alpine
```

## Architecture

The repo has three meaningful files:

- **`nfsd.sh`** — the container entrypoint. On startup it: (1) builds `/etc/exports` by substituting `{{PLACEHOLDER}}` tokens with environment variable values, then (2) starts `rpcbind`, `rpc.nfsd`, and `rpc.mountd` in a retry loop. A monitor loop then watches `rpc.mountd` and exits (causing Docker to restart) if it dies. Handles `SIGTERM`/`SIGINT` for clean shutdown.
- **`exports`** — a template file with `{{PLACEHOLDER}}` tokens. Copied to `/etc/exports` in the image; overwritten at runtime by `nfsd.sh`.
- **`Dockerfile`** — installs `nfs-utils`, `bash`, `iproute2` on Alpine; copies the three config files; sets `nfsd.sh` as the entrypoint.

## Environment Variables

| Variable | Default | Effect |
|---|---|---|
| `SHARED_DIRECTORY` | (required) | Root NFS export path; must be set or container exits |
| `SHARED_DIRECTORY_2` | unset | Optional second export (must be a subdirectory of `SHARED_DIRECTORY`) |
| `PERMITTED` | `*` | IP/subnet allowed to mount (e.g. `10.11.99.*`) |
| `READ_ONLY` | unset → `rw` | Set to any value to make exports read-only |
| `SYNC` | unset → `async` | Set to any value to enable synchronous writes |

## Key Constraints

- NFS v4 only (v2 and v3 explicitly disabled). `fsid=0` on the root export means clients mount as `host:/` not `host:/path`.
- Requires `--privileged` (or at minimum `SYS_ADMIN` + `SETPCAP` capabilities).
- OverlayFS filesystems cannot be NFS-exported — volume-mount from ext4 or similar.
- Additional shares via `SHARED_DIRECTORY_N` must be subdirectories of `SHARED_DIRECTORY` (NFSv4 requirement).
- `showmount` does not work against this server (rpcbind is only started to work around an IPv6 socket bug).
