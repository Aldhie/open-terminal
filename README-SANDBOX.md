# Sysbox-Isolated Sandbox Variant

This fork adds a variant of `open-webui/open-terminal` that runs a **private,
fully-isolated Docker daemon** inside the container, instead of mounting the
host's `/var/run/docker.sock`.

## Why

Mounting the host's Docker socket into the container (the approach shown in
the upstream README's "Docker access" section) grants the AI agent an
equivalent of root access to the host machine - any container, network,
volume or image on the host becomes reachable. For an AI agent that runs
arbitrary `docker build` / `docker compose up` / `docker network create`
commands autonomously, that is not an acceptable blast radius.

This variant instead runs the container under the [Sysbox](https://github.com/nestybox/sysbox)
runtime, which gives it its own kernel namespaces (PID, mount, network) and
its own nested `dockerd`. The AI agent gets **full, unrestricted Docker
access** (build, compose, network create, volume create - all of it), but
that access is scoped entirely to containers/networks/volumes created inside
the sandbox. The host's real Docker daemon and its 19+ production containers
are never touched and are not even visible from inside the sandbox.

## Host prerequisites

1. Kernel >= 5.6 for `CONFIG_TIME_NS` (verified working on Ubuntu 20.04 HWE,
   kernel `5.15.0-139-generic`). Older kernels fail with:
   `OCI runtime create failed: time namespaces aren't enabled in the kernel`
2. [Sysbox CE](https://github.com/nestybox/sysbox/releases) installed and
   registered as a Docker runtime (`sysbox-runc`).
3. `sysbox-mgr` and `sysbox-fs` systemd services both `active`. If `sysbox-fs`
   times out on start via systemd (10s timeout) but runs fine manually, check
   `systemctl cat sysbox-fs.service` for a duplicated `Type=` directive - the
   shipped unit file in Sysbox 0.7.1 has `Type=simple` followed by
   `Type=notify`, and the latter wins. Override it with a drop-in:

   ```
   # /etc/systemd/system/sysbox-fs.service.d/override.conf
   [Service]
   Type=simple
   ```

## Build & run

```bash
docker compose -f docker-compose.sandbox.yml up -d --build
```

## Verifying isolation

From inside the sandbox container:

```bash
docker ps -a        # must NOT show any host containers
cat /proc/1/status | grep NSpid   # PID namespace must differ from host
curl -m 3 http://<host-service-ip>:<port>   # must time out
```

See the Brain-Memory `infra` namespace entry "Sysbox Nested Docker Sandbox -
IMPLEMENTATION COMPLETE & VERIFIED" for the full verified procedure,
including GRUB boot-safety-net configuration for the kernel upgrade and a
WireGuard/Docker subnet-conflict pitfall to avoid.
