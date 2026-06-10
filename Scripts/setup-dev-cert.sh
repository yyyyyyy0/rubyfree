#!/usr/bin/env bash
set -euo pipefail

# Create a stable self-signed code-signing certificate "rubyfree-dev" in the login
# keychain. S0-1 confirmed that signing with this FIXED identity keeps the macOS TCC
# grant (Accessibility / Screen Recording) across rebuilds — ad-hoc signing does NOT,
# because its Designated Requirement is cdhash-based and changes on every build.
#
# Run once per dev machine. Idempotent: skips if the cert already exists.

CERT_CN="rubyfree-dev"

if security find-certificate -c "$CERT_CN" >/dev/null 2>&1; then
    echo "==> '$CERT_CN' already present in keychain; nothing to do"
    exit 0
fi

WORK="$(mktemp -d)"
PW="rubyfreedev"   # non-empty: macOS `security` rejects empty-password PKCS12

cat > "$WORK/cert.conf" <<'EOF'
[req]
distinguished_name=dn
prompt=no
x509_extensions=v3
[dn]
CN=rubyfree-dev
[v3]
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
basicConstraints=critical,CA:false
EOF

# Use macOS LibreSSL (/usr/bin/openssl): its PKCS12 is importable by `security`.
# Homebrew OpenSSL 3.x emits a MAC that `security` cannot verify.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORK/cert.key" -out "$WORK/cert.crt" -config "$WORK/cert.conf"
/usr/bin/openssl pkcs12 -export -inkey "$WORK/cert.key" -in "$WORK/cert.crt" \
    -out "$WORK/cert.p12" -passout "pass:$PW"

# -T /usr/bin/codesign lets codesign use the key without a per-build keychain prompt.
security import "$WORK/cert.p12" \
    -k "$HOME/Library/Keychains/login.keychain-db" -P "$PW" -T /usr/bin/codesign

trash "$WORK" 2>/dev/null || rm -rf "$WORK"

echo "==> created self-signed code-signing identity '$CERT_CN'"
echo "    build-app.sh / run-dev.sh will now sign with it automatically."
