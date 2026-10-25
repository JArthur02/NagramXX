#!/usr/bin/env bash
# Writes TMessagesProj/release.keystore from the Base64 RELEASE_KEYSTORE secret.
# Pass --required to fail when the secret is missing (release builds).
set -euo pipefail
OUT=TMessagesProj/release.keystore

if [ -z "${RELEASE_KEYSTORE:-}" ]; then
  if [ "${1:-}" = "--required" ]; then
    echo "::error::RELEASE_KEYSTORE secret is not set; release builds must be signed."
    exit 1
  fi
  echo "RELEASE_KEYSTORE is not set; building without the release key."
  exit 0
fi

# Tolerate spaces and line breaks picked up when pasting the secret.
if ! printf '%s' "$RELEASE_KEYSTORE" | tr -d ' \t\r\n' | base64 --decode > "$OUT" 2>/dev/null; then
  rm -f "$OUT"
  echo "::error::RELEASE_KEYSTORE is not valid Base64. Re-create it with: base64 -w0 release.keystore"
  exit 1
fi

# PKCS12 keystores start with an ASN.1 SEQUENCE (0x30), JKS ones with 0xFEEDFEED.
magic=$(head -c 4 "$OUT" | od -An -tx1 | tr -d ' \n')
case "$magic" in
  30*|feedfeed) ;;
  *)
    rm -f "$OUT"
    echo "::error::RELEASE_KEYSTORE does not decode to a keystore (starts with 0x$magic). Re-create it with: base64 -w0 release.keystore"
    exit 1
    ;;
esac
echo "Restored release keystore ($(wc -c < "$OUT") bytes)."
