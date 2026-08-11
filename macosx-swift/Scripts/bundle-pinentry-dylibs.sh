#!/bin/bash
set -euo pipefail

app_bundle="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
executable="${app_bundle}/Contents/MacOS/${EXECUTABLE_NAME}"
frameworks_dir="${app_bundle}/Contents/Frameworks"

if [[ ! -x "$executable" ]]; then
  printf 'error: executable not found at %s\n' "$executable" >&2
  exit 1
fi

mkdir -p "$frameworks_dir"

candidate_dirs=(
  "${PINENTRY_MAC_SWIFT_ASSUAN_PREFIX:-}/lib"
  "${PINENTRY_MAC_SWIFT_GPG_ERROR_PREFIX:-}/lib"
  "${PINENTRY_MAC_SWIFT_GETTEXT_PREFIX:-}/lib"
  /usr/local/MacGPG2/lib
  /usr/local/lib
  /opt/homebrew/lib
  /usr/local/opt/libassuan/lib
  /usr/local/opt/libgpg-error/lib
  /usr/local/opt/gettext/lib
  /opt/homebrew/opt/libassuan/lib
  /opt/homebrew/opt/libgpg-error/lib
  /opt/homebrew/opt/gettext/lib
)

read -r -a requested_archs <<< "${ARCHS:-}"

linked_dependency_for_basename() {
  local binary="$1"
  local basename="$2"

  otool -L "$binary" | awk '/^[[:space:]]/ { print $1 }' | while read -r dependency; do
    if [[ "$(basename "$dependency")" == "$basename" ]]; then
      printf '%s\n' "$dependency"
      return 0
    fi
  done
}

find_library() {
  local basename="$1"
  local linked_dependency="${2:-}"

  if [[ -n "$linked_dependency" && -r "$linked_dependency" ]]; then
    printf '%s\n' "$linked_dependency"
    return 0
  fi

  local candidate_dir
  for candidate_dir in "${candidate_dirs[@]}"; do
    if [[ -n "$candidate_dir" && -r "$candidate_dir/$basename" ]]; then
      printf '%s\n' "$candidate_dir/$basename"
      return 0
    fi
  done

  printf 'error: %s not found. Install GPGTools or Homebrew GnuPG libs, or set PINENTRY_MAC_SWIFT_ASSUAN_PREFIX/PINENTRY_MAC_SWIFT_GPG_ERROR_PREFIX.\n' "$basename" >&2
  exit 1
}

thin_to_requested_archs() {
  local binary="$1"

  if [[ "${#requested_archs[@]}" -ne 1 ]]; then
    return 0
  fi

  local requested_arch="${requested_archs[0]}"
  local archs
  if ! archs="$(lipo -archs "$binary" 2>/dev/null)"; then
    return 0
  fi

  if [[ "$archs" == "$requested_arch" ]]; then
    return 0
  fi

  if [[ " $archs " != *" $requested_arch "* ]]; then
    printf 'error: %s does not contain requested architecture %s. Found: %s\n' "$binary" "$requested_arch" "$archs" >&2
    exit 1
  fi

  local thinned_binary="${binary}.thin"
  lipo "$binary" -thin "$requested_arch" -output "$thinned_binary"
  mv "$thinned_binary" "$binary"
}

copy_library() {
  local source="$1"
  local basename="$2"
  local destination="$frameworks_dir/$basename"

  cp -f "$source" "$destination"
  chmod u+w "$destination"
  thin_to_requested_archs "$destination"
  install_name_tool -id "@rpath/$basename" "$destination"
  printf '%s\n' "$destination"
}

rewrite_dependency() {
  local binary="$1"
  local basename="$2"
  local replacement="@rpath/$basename"

  otool -L "$binary" | awk '/^[[:space:]]/ { print $1 }' | while read -r dependency; do
    if [[ "$(basename "$dependency")" == "$basename" && "$dependency" != "$replacement" ]]; then
      install_name_tool -change "$dependency" "$replacement" "$binary"
    fi
  done
}

sign_binary() {
  local binary="$1"
  local signing_identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"

  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign "$signing_identity" --timestamp=none "$binary"
  fi
}

assuan_linked="$(linked_dependency_for_basename "$executable" libassuan.0.dylib || true)"
gpg_error_linked="$(linked_dependency_for_basename "$executable" libgpg-error.0.dylib || true)"

assuan_source="$(find_library libassuan.0.dylib "$assuan_linked")"
gpg_error_source="$(find_library libgpg-error.0.dylib "$gpg_error_linked")"

assuan_destination="$(copy_library "$assuan_source" libassuan.0.dylib)"
gpg_error_destination="$(copy_library "$gpg_error_source" libgpg-error.0.dylib)"

intl_linked="$(linked_dependency_for_basename "$gpg_error_destination" libintl.8.dylib || true)"
if [[ -n "$intl_linked" ]]; then
  intl_source="$(find_library libintl.8.dylib "$intl_linked")"
  intl_destination="$(copy_library "$intl_source" libintl.8.dylib)"
  rewrite_dependency "$executable" libintl.8.dylib
  rewrite_dependency "$assuan_destination" libintl.8.dylib
  rewrite_dependency "$gpg_error_destination" libintl.8.dylib
  rewrite_dependency "$intl_destination" libintl.8.dylib
fi

rewrite_dependency "$executable" libassuan.0.dylib
rewrite_dependency "$executable" libgpg-error.0.dylib
rewrite_dependency "$assuan_destination" libgpg-error.0.dylib
rewrite_dependency "$gpg_error_destination" libgpg-error.0.dylib

sign_binary "$assuan_destination"
sign_binary "$gpg_error_destination"
if [[ -n "${intl_destination:-}" ]]; then
  sign_binary "$intl_destination"
fi

printf 'Bundled pinentry dylibs in %s.\n' "$frameworks_dir"
