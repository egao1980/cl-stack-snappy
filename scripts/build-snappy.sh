#!/usr/bin/env bash
# Build shared libsnappy into lib/<os>-<arch>/.
# Usage: ./scripts/build-snappy.sh
# Env: SNAPPY_VERSION (default 1.2.2), DEST_DIR (optional override)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SNAPPY_VERSION="${SNAPPY_VERSION:-1.2.2}"
JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

uname_s="$(uname -s)"
uname_m="$(uname -m)"
case "$uname_s" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) echo "unsupported OS: $uname_s (Windows: use build-snappy.ps1)" >&2; exit 1 ;;
esac
case "$uname_m" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "unsupported arch: $uname_m" >&2; exit 1 ;;
esac

OUT="${DEST_DIR:-$ROOT/lib/${os}-${arch}}"
BUILD="$ROOT/build/snappy-${SNAPPY_VERSION}-${os}-${arch}"
SRC_TGZ="$ROOT/build/snappy-${SNAPPY_VERSION}.tar.gz"
SRC_URL="https://github.com/google/snappy/archive/refs/tags/${SNAPPY_VERSION}.tar.gz"

mkdir -p "$ROOT/build" "$OUT"
if [[ ! -f "$SRC_TGZ" ]]; then
  echo "==> download $SRC_URL"
  curl -fsSL "$SRC_URL" -o "$SRC_TGZ"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"
tar -xzf "$SRC_TGZ" -C "$BUILD" --strip-components=1

echo "==> cmake/build snappy ${SNAPPY_VERSION} -> $OUT"
cmake -S "$BUILD" -B "$BUILD/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$BUILD/prefix" \
  -DBUILD_SHARED_LIBS=ON \
  -DSNAPPY_BUILD_TESTS=OFF \
  -DSNAPPY_BUILD_BENCHMARKS=OFF \
  -DSNAPPY_INSTALL=ON
cmake --build "$BUILD/build" -j"$JOBS"
cmake --install "$BUILD/build"

rm -rf "$OUT"
mkdir -p "$OUT"
shopt -s nullglob
libs=(
  "$BUILD/prefix/lib"/libsnappy.so*
  "$BUILD/prefix/lib"/libsnappy*.dylib
  "$BUILD/prefix/lib64"/libsnappy.so*
)
if ((${#libs[@]} == 0)); then
  echo "libsnappy shared library not found under $BUILD/prefix" >&2
  ls -la "$BUILD/prefix/lib" "$BUILD/prefix/lib64" 2>/dev/null || true
  exit 1
fi
cp -a "${libs[@]}" "$OUT/"

if [[ "$os" == "linux" ]]; then
  if [[ ! -e "$OUT/libsnappy.so" ]]; then
    cand="$(ls -1 "$OUT"/libsnappy.so.* 2>/dev/null | head -1 || true)"
    [[ -n "$cand" ]] && ln -sfn "$(basename "$cand")" "$OUT/libsnappy.so"
  fi
  if command -v patchelf >/dev/null; then
    for f in "$OUT"/libsnappy.so*; do
      [[ -f "$f" && ! -L "$f" ]] || continue
      patchelf --set-rpath '$ORIGIN' "$f"
    done
  fi
elif [[ "$os" == "darwin" ]]; then
  if [[ ! -e "$OUT/libsnappy.dylib" ]]; then
    cand="$(ls -1 "$OUT"/libsnappy.*.dylib 2>/dev/null | head -1 || true)"
    [[ -n "$cand" ]] && ln -sfn "$(basename "$cand")" "$OUT/libsnappy.dylib"
  fi
  if command -v install_name_tool >/dev/null; then
    for f in "$OUT"/libsnappy*.dylib; do
      [[ -f "$f" && ! -L "$f" ]] || continue
      install_name_tool -id "@loader_path/$(basename "$f")" "$f" 2>/dev/null || true
    done
  fi
fi

echo "==> staged:"
ls -la "$OUT"
echo "OK: snappy ${SNAPPY_VERSION} -> ${os}/${arch}"
