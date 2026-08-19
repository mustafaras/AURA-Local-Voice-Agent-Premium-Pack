#!/bin/zsh
# Serve the SP-011 page fixtures on localhost for the browser legs.
#
# The approved-page and injection-ignore legs both need a page on an allowed
# host whose content is known exactly. `example.com` is fixed and carries no
# injection payload, so the injection leg needs a page this repository owns.
# Binding to 127.0.0.1 keeps the fixtures off every other interface.
#
# Usage: ./scripts/sp011-acceptance/serve-fixtures.sh [port]

set -uo pipefail
PORT="${1:-8011}"
cd "$(dirname "$0")/fixtures" || exit 2

echo "==> Serving SP-011 fixtures on http://localhost:$PORT/ (Ctrl-C to stop)"
echo "    clean:     http://localhost:$PORT/clean.html"
echo "    injection: http://localhost:$PORT/injection.html"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
