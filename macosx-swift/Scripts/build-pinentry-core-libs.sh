#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
frontend_dir="$(cd "$script_dir/.." && pwd)"
top_srcdir="$(cd "$frontend_dir/.." && pwd)"
build_dir="$frontend_dir/build/core-libs"
config_dir="$build_dir/config"
objects_dir="$build_dir/objects"
libraries_dir="$build_dir/libraries"

mkdir -p "$config_dir" "$objects_dir" "$libraries_dir"

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
read -r -a archs <<< "${ARCHS:-$(uname -m)}"

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
  local arch="$1"
  local source="$2"
  local object="$3"
  "$cc" -arch "$arch" "${common_flags[@]}" -c "$source" -o "$object"
}

build_for_arch() {
  local arch="$1"
  local arch_objects_dir="$objects_dir/$arch"

  mkdir -p "$arch_objects_dir/secmem" "$arch_objects_dir/pinentry"

  compile "$arch" "$top_srcdir/secmem/secmem.c" "$arch_objects_dir/secmem/secmem.o"
  compile "$arch" "$top_srcdir/secmem/util.c" "$arch_objects_dir/secmem/util.o"
  "$ar" cr "$libraries_dir/libsecmem-$arch.a" \
    "$arch_objects_dir/secmem/secmem.o" \
    "$arch_objects_dir/secmem/util.o"
  "$ranlib" "$libraries_dir/libsecmem-$arch.a"

  compile "$arch" "$top_srcdir/pinentry/pinentry.c" "$arch_objects_dir/pinentry/pinentry.o"
  compile "$arch" "$top_srcdir/pinentry/argparse.c" "$arch_objects_dir/pinentry/argparse.o"
  compile "$arch" "$top_srcdir/pinentry/password-cache.c" "$arch_objects_dir/pinentry/password-cache.o"
  "$ar" cr "$libraries_dir/libpinentry-$arch.a" \
    "$arch_objects_dir/pinentry/pinentry.o" \
    "$arch_objects_dir/pinentry/argparse.o" \
    "$arch_objects_dir/pinentry/password-cache.o"
  "$ranlib" "$libraries_dir/libpinentry-$arch.a"
}

for arch in "${archs[@]}"; do
  build_for_arch "$arch"
done

if [[ "${#archs[@]}" -gt 1 ]]; then
  secmem_libraries=()
  pinentry_libraries=()
  for arch in "${archs[@]}"; do
    secmem_libraries+=("$libraries_dir/libsecmem-$arch.a")
    pinentry_libraries+=("$libraries_dir/libpinentry-$arch.a")
  done

  lipo -create "${secmem_libraries[@]}" -output "$top_srcdir/secmem/libsecmem.a"
  lipo -create "${pinentry_libraries[@]}" -output "$top_srcdir/pinentry/libpinentry.a"
else
  cp "$libraries_dir/libsecmem-${archs[0]}.a" "$top_srcdir/secmem/libsecmem.a"
  cp "$libraries_dir/libpinentry-${archs[0]}.a" "$top_srcdir/pinentry/libpinentry.a"
fi

"$ranlib" "$top_srcdir/secmem/libsecmem.a"
"$ranlib" "$top_srcdir/pinentry/libpinentry.a"

printf 'Built %s and %s for %s.\n' \
  "$top_srcdir/secmem/libsecmem.a" \
  "$top_srcdir/pinentry/libpinentry.a" \
  "${archs[*]}"
