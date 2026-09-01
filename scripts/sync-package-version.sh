#!/usr/bin/env bash
# Rewrite ASDF :version and +snappy-version+ to match the published Snappy release.
# Usage: ./scripts/sync-package-version.sh <version>
set -euo pipefail

VERSION="${1:?version required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

sed -i.bak 's/:version "[^"]*"/:version "'"${VERSION}"'"/' "$ROOT/cl-stack-snappy.asd"
sed -i.bak 's/(defparameter +snappy-version+ "[^"]*"/(defparameter +snappy-version+ "'"${VERSION}"'"/' "$ROOT/src/api.lisp"
rm -f "$ROOT/cl-stack-snappy.asd.bak" "$ROOT/src/api.lisp.bak"
