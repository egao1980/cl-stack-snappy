#!/usr/bin/env bash
# Clean ubuntu:24.04 linux/amd64 smoke against GHCR cl-stack-snappy.
set -euo pipefail

VERSION="${1:-1.2.2}"
IMAGE="ghcr.io/egao1980/cl-systems/cl-stack-snappy:${VERSION}"
CACHE="${CACHE:-/tmp/cl-stack-snappy-smoke-cache}"
PKG="$CACHE/pkg/cl-stack-snappy-${VERSION}"
QL="$CACHE/quicklisp"

mkdir -p "$CACHE/pull" "$CACHE/pkg"
if [[ ! -f "$PKG/native/libsnappy.so" ]]; then
  command -v oras >/dev/null || { echo "need oras" >&2; exit 1; }
  rm -rf "${CACHE}/pull/"* "${CACHE}/pkg/"*
  oras pull --platform linux/amd64 "$IMAGE" -o "$CACHE/pull/"
  for f in "$CACHE/pull"/*.tar.gz; do tar -xzf "$f" -C "$CACHE/pkg/"; done
fi

SMOKE_LISP="$CACHE/smoke.lisp"
cat >"$SMOKE_LISP" <<'EOF'
(require :asdf) (require :uiop)
(defvar *pkg* (uiop:getenv "CL_STACK_SNAPPY_ROOT"))
(asdf:initialize-source-registry
 `(:source-registry (:directory ,(uiop:ensure-directory-pathname *pkg*))
                    :inherit-configuration))
(ql:quickload '("cffi" "cl-stack-snappy") :silent t)
(format t "~&+snappy-version+ => ~A~%" cl-stack-snappy:+snappy-version+)
(let* ((s "hello snappy overlay")
       (raw (map '(simple-array (unsigned-byte 8) (*)) #'char-code s))
       (enc (cl-stack-snappy:compress raw))
       (dec (cl-stack-snappy:decompress enc)))
  (unless (equalp raw dec)
    (error "round-trip mismatch"))
  (format t "~&round-trip OK (~D -> ~D bytes)~%" (length raw) (length enc)))
(format t "~&SMOKE OK~%")
(uiop:quit 0)
EOF

if [[ ! -f "$QL/setup.lisp" ]]; then
  docker run --rm --platform linux/amd64 \
    -e DEBIAN_FRONTEND=noninteractive \
    -v "$QL:/ql" \
    ubuntu:24.04 \
    bash -c 'apt-get update -qq && apt-get install -y -qq ca-certificates curl sbcl >/dev/null \
      && curl -fsSL -o /tmp/ql.lisp https://beta.quicklisp.org/quicklisp.lisp \
      && sbcl --noinform --non-interactive --load /tmp/ql.lisp \
           --eval "(quicklisp-quickstart:install :path #p\"/ql/\")" >/dev/null'
fi

# Resolve natives via CFFI at ASDF load — never LD_LIBRARY_PATH.
docker run --rm --platform linux/amd64 \
  -e DEBIAN_FRONTEND=noninteractive \
  -e CL_STACK_SNAPPY_ROOT=/opt/cl-stack-snappy \
  -v "$PKG:/opt/cl-stack-snappy:ro" \
  -v "$QL:/ql:ro" \
  -v "$SMOKE_LISP:/opt/smoke.lisp:ro" \
  ubuntu:24.04 \
  bash -c 'apt-get update -qq && apt-get install -y -qq ca-certificates sbcl >/dev/null \
    && sbcl --noinform --non-interactive --load /ql/setup.lisp --load /opt/smoke.lisp'
