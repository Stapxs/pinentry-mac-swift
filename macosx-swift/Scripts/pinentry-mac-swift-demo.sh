#!/bin/sh
set -eu

PINENTRY=${PINENTRY:-${1:-./pinentry-mac-swift.app/Contents/MacOS/pinentry-mac-swift}}
SCENARIO=${2:-getpin}

run_pinentry() {
  "$PINENTRY"
}

case "$SCENARIO" in
  getpin)
    {
      printf 'SETTITLE Unlock Secret Key\n'
      printf 'SETDESC Enter the passphrase for your signing key.\n'
      printf 'SETPROMPT Passphrase\n'
      printf 'SETOK Unlock\n'
      printf 'GETPIN\n'
      printf 'BYE\n'
    } | run_pinentry
    ;;
  confirm)
    {
      printf 'SETTITLE Allow Key Operation\n'
      printf 'SETDESC Another app is requesting permission to use your private key.\n'
      printf 'SETOK Allow\n'
      printf 'SETNOTOK Deny\n'
      printf 'CONFIRM\n'
      printf 'BYE\n'
    } | run_pinentry
    ;;
  repeat)
    {
      printf 'SETTITLE Set New Passphrase\n'
      printf 'SETDESC Create a new passphrase for the selected key.\n'
      printf 'SETPROMPT New Passphrase\n'
      printf 'SETREPEAT Confirm Passphrase\n'
      printf 'GETPIN\n'
      printf 'BYE\n'
    } | run_pinentry
    ;;
  quality)
    {
      printf 'SETTITLE Protect Secret Key\n'
      printf 'SETDESC Choose a passphrase strong enough to secure your key material.\n'
      printf 'SETPROMPT Passphrase\n'
      printf 'SETQUALITYBAR Passphrase Strength\n'
      printf 'GETPIN\n'
      printf 'BYE\n'
    } | run_pinentry
    ;;
  error)
    {
      printf 'SETTITLE Passphrase Incorrect\n'
      printf 'SETDESC The provided passphrase could not unlock your secret key.\n'
      printf 'SETERROR The passphrase you entered was incorrect.\n'
      printf 'SETPROMPT Passphrase\n'
      printf 'GETPIN\n'
      printf 'BYE\n'
    } | run_pinentry
    ;;
  keyinfo)
    {
      printf 'SETTITLE Unlock Signing Key\n'
      printf 'SETDESC Enter the passphrase for your signing key.\n'
      printf 'SETPROMPT Passphrase\n'
      printf 'SETKEYINFO n/demo-cache-id\n'
      printf 'GETPIN\n'
      printf 'BYE\n'
    } | run_pinentry
    ;;
  *)
    printf 'Usage: %s [pinentry-path] [getpin|confirm|repeat|quality|error|keyinfo]\n' "$0" >&2
    exit 2
    ;;
esac
