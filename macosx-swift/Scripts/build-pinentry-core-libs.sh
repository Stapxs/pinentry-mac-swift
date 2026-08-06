#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
frontend_dir="$(cd "$script_dir/.." && pwd)"
top_srcdir="$(cd "$frontend_dir/.." && pwd)"
build_dir="$frontend_dir/build/core-libs"
config_dir="$build_dir/config"
objects_dir="$build_dir/objects"

mkdir -p "$config_dir" "$objects_dir/secmem" "$objects_dir/pinentry"

cat > "$config_dir/config.h" <<'CONFIG_H'
#ifndef PINENTRY_MAC_SWIFT_GENERATED_CONFIG_H
#define PINENTRY_MAC_SWIFT_GENERATED_CONFIG_H

#define PACKAGE_VERSION "1.3.1"
#define PACKAGE_BUGREPORT "https://bugs.gnupg.org"
#define VERSION "1.3.1"

#define HAVE_MLOCK 1
#define HAVE_MMAP 1
#define HAVE_GETPAGESIZE 1
#define HAVE_STAT 1

#define GPG_ERR_SOURCE_DEFAULT GPG_ERR_SOURCE_PINENTRY

#endif
CONFIG_H

cc="${CC:-$(xcrun -find clang)}"
ar="${AR:-$(xcrun -find ar)}"
ranlib="${RANLIB:-$(xcrun -find ranlib)}"
sdkroot="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
arch="${ARCHS:-$(uname -m)}"

if [[ "$arch" == *" "* ]]; then
  arch="${NATIVE_ARCH_ACTUAL:-$(uname -m)}"
fi

assuan_prefix="${PINENTRY_MAC_SWIFT_ASSUAN_PREFIX:-}"
if [[ -z "$assuan_prefix" ]]; then
  if [[ -f /usr/local/MacGPG2/include/assuan.h ]]; then
    assuan_prefix="/usr/local/MacGPG2"
  elif [[ -f /opt/homebrew/include/assuan.h ]]; then
    assuan_prefix="/opt/homebrew"
  else
    printf 'error: assuan.h not found. Install libassuan or set PINENTRY_MAC_SWIFT_ASSUAN_PREFIX.\n' >&2
    exit 1
  fi
fi

gpg_error_prefix="${PINENTRY_MAC_SWIFT_GPG_ERROR_PREFIX:-}"
if [[ -z "$gpg_error_prefix" ]]; then
  if [[ -f "$assuan_prefix/include/gpg-error.h" ]]; then
    gpg_error_prefix="$assuan_prefix"
  elif [[ -f /usr/local/MacGPG2/include/gpg-error.h ]]; then
    gpg_error_prefix="/usr/local/MacGPG2"
  elif [[ -f /opt/homebrew/include/gpg-error.h ]]; then
    gpg_error_prefix="/opt/homebrew"
  else
    printf 'error: gpg-error.h not found. Install libgpg-error or set PINENTRY_MAC_SWIFT_GPG_ERROR_PREFIX.\n' >&2
    exit 1
  fi
fi

common_flags=(
  -arch "$arch"
  -isysroot "$sdkroot"
  -mmacosx-version-min=13.0
  -DHAVE_CONFIG_H=1
  -I"$config_dir"
  -I"$top_srcdir"
  -I"$top_srcdir/pinentry"
  -I"$top_srcdir/secmem"
  -I"$assuan_prefix/include"
  -I"$gpg_error_prefix/include"
  -Wall
  -Wno-pointer-sign
  -Wno-deprecated-declarations
)

compile() {
  local source="$1"
  local object="$2"
  "$cc" "${common_flags[@]}" -c "$source" -o "$object"
}

compile "$top_srcdir/secmem/secmem.c" "$objects_dir/secmem/secmem.o"
compile "$top_srcdir/secmem/util.c" "$objects_dir/secmem/util.o"
"$ar" cr "$top_srcdir/secmem/libsecmem.a" \
  "$objects_dir/secmem/secmem.o" \
  "$objects_dir/secmem/util.o"
"$ranlib" "$top_srcdir/secmem/libsecmem.a"

compile "$top_srcdir/pinentry/pinentry.c" "$objects_dir/pinentry/pinentry.o"
compile "$top_srcdir/pinentry/argparse.c" "$objects_dir/pinentry/argparse.o"
compile "$top_srcdir/pinentry/password-cache.c" "$objects_dir/pinentry/password-cache.o"
"$ar" cr "$top_srcdir/pinentry/libpinentry.a" \
  "$objects_dir/pinentry/pinentry.o" \
  "$objects_dir/pinentry/argparse.o" \
  "$objects_dir/pinentry/password-cache.o"
"$ranlib" "$top_srcdir/pinentry/libpinentry.a"

printf 'Built %s and %s for %s.\n' \
  "$top_srcdir/secmem/libsecmem.a" \
  "$top_srcdir/pinentry/libpinentry.a" \
  "$arch"
