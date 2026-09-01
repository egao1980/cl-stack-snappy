# cl-stack-snappy

MIT. Ships **Snappy** (`libsnappy`) as
[cl-repository](https://github.com/egao1980/cl-repository) platform overlays,
plus a thin CFFI `compress` / `decompress` API (raw Snappy, same shape as
`cl-stack-zstd`). HTTP `Content-Encoding: snappy` is
[`http-encoding-snappy`](https://github.com/egao1980/http-encoding-snappy).

| | |
|--|--|
| ASDF | `cl-stack-snappy` |
| GHCR | `ghcr.io/egao1980/cl-systems/cl-stack-snappy:<snappy-ver>` |
| Upstream | [google/snappy](https://github.com/google/snappy) **1.2.2** |
| Wire | raw Snappy (`snappy-c.h`) — not the framed/streaming format |

## Platforms

| OS | Arch | Runner |
|----|------|--------|
| linux | amd64 | `ubuntu-latest` |
| linux | arm64 | `ubuntu-24.04-arm` |
| darwin | arm64 | `macos-latest` |
| windows | amd64 | `windows-latest` |

## Consumer

```lisp
;; cl-repository: cl-repo-init.lisp preloads native/. No ensure-*, no LD_LIBRARY_PATH.
(asdf:load-system "cl-stack-snappy")
(cl-stack-snappy:decompress (cl-stack-snappy:compress octets))
```

`:level` on `compress` is accepted and ignored (C API has no level). Gray
streams slurp then wrap the one-shot C API.

Smoke (linux/amd64): `scripts/smoke-clean-container.sh` (no `LD_LIBRARY_PATH`).

## Build natives locally

```bash
./scripts/build-snappy.sh          # SNAPPY_VERSION=1.2.2 by default
# → lib/<os>-<arch>/libsnappy*
```
