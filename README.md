# Nebula lighthouse OCI image

Nix-built x86_64 Linux image using the pinned Nixpkgs Nebula 1.11.2 package.

## Build

```sh
nix flake check
nix build .#image
```

## Upstream Dockerfile baseline

The version-matched [Dockerfile](https://raw.githubusercontent.com/slackhq/nebula/v1.11.2/docker/Dockerfile) uses `gcr.io/distroless/static:latest`, copies both `nebula` and `nebula-cert`, declares `/config` as a volume, and sets `ENTRYPOINT ["/nebula"]` with `CMD ["-config", "/config/config.yml"]`. The tagged [Docker README](https://raw.githubusercontent.com/slackhq/nebula/v1.11.2/docker/README.md) documents host networking and `NET_ADMIN` for TUN. The Makefile builds static binaries with `CGO_ENABLED=0` and `-trimpath`.

This image keeps the upstream binary paths, both executables, config volume, entrypoint, and command. It adds UDP 4242 port metadata and runs as fixed UID/GID `10001:10001` rather than the upstream default root. The Nixpkgs package is dynamically linked, so the image includes its glibc runtime closure rather than using a static distroless base. The Docker Hub page has inconsistent config-mount examples; this image follows the tag-matched Dockerfile's `/config` path.

## Runtime contract

- Entrypoint: `/nebula`; default command: `-config /config/config.yml`.
- Mount the config and runtime certificate/key files at `/config`; ensure they are readable by UID/GID `10001:10001`. The external config must enable lighthouse mode with `lighthouse.am_lighthouse: true`; the image embeds no role-specific configuration.
- UDP port metadata: 4242. The upstream-recommended mode is host networking.
- With TUN enabled, pass `/dev/net/tun` and `NET_ADMIN` as required by the host runtime. The upstream Docker README says TUN-disabled operation needs no `NET_ADMIN`; a discovery-only lighthouse can set `tun.disabled: true`, but then does not carry overlay peer traffic. This runtime path was not smoke-tested here.
- The image contains no configuration, certificates, keys, or CA private key. Generate and distribute host certificates through a separate trusted workflow.
