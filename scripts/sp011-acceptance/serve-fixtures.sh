#!/bin/zsh
# Serve the SP-011 page fixtures over HTTPS on localhost for the browser legs.
#
# HTTPS, not HTTP, because `ProductivityNetworkPolicy` requires it — a plain
# `http://` observation is refused with "provider URL must use HTTPS" before
# any page text is read. That refusal is correct product behaviour; the first
# version of this script simply served the wrong scheme.
#
# The certificate is self-signed and regenerated on demand, so Safari shows an
# interstitial the first time. Accepting it is a per-session browser decision
# and changes nothing in the system trust store.
#
# Usage: ./scripts/sp011-acceptance/serve-fixtures.sh [port]

set -uo pipefail
PORT="${1:-8443}"
cd "$(dirname "$0")/fixtures" || exit 2

if [[ ! -f cert.pem || ! -f key.pem ]]; then
    echo "==> Generating a short-lived self-signed certificate for localhost"
    openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 1 -nodes \
        -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null \
        || { echo "FAILED: could not generate a certificate" >&2; exit 1 }
fi

echo "==> Serving SP-011 fixtures on https://localhost:$PORT/ (Ctrl-C to stop)"
echo "    clean:     https://localhost:$PORT/clean.html"
echo "    injection: https://localhost:$PORT/injection.html"
echo "    Safari will warn about the self-signed certificate the first time."

exec python3 - "$PORT" <<'PY'
import http.server, ssl, sys, functools
port = int(sys.argv[1])
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain("cert.pem", "key.pem")
handler = functools.partial(http.server.SimpleHTTPRequestHandler)
server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
PY
