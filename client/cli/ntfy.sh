#!/usr/bin/env bash
# ----------------------------------------------------------------------
# ntfy.sh  –  Tiny helper to publish messages to an external “ntfy”
#             (or any HTTP‑push) endpoint.
#
#   Version 1.0
#
#   It is deliberately *generic*: the target URL, authentication,
#   and optional topic are all supplied via environment variables or CLI flags,
#   so downstream projects can invoke it without pulling in any extra
#   dependencies.
#
#   Usage:
#       echo "Hello world" | ./ntfy.sh                     # use defaults
#       echo "$MSG" | ./ntfy.sh --topic myTopic              # custom topic
#       echo "$DATA" | ./ntfy.sh -u https://my.server/api/1  # custom URL
#
#   The script tries to be POSIX‑compliant and works on any system that
#   ships Bash (or Dash) plus curl. No external libraries are required.
#
#   Exit codes:
#       0 – successful POST
#       1 – missing input / malformed arguments
# ----------------------------------------------------------------------

set -euo pipefail

# ---------- Default configuration ----------
# These can be overridden from the command line or environment.
DEFAULT_URL="https://ntfy.sh/${NTFY_TOPIC:-general}"
DEFAULT_METHOD="POST"
CURL_OPTS=("-sS" "-w" "\n%{http_code}")

# ---------- Helper functions ----------
usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [options] < /dev/stdin

Options:
  -u, --url   HTTP(S) endpoint to POST data (default: $DEFAULT_URL)
  -m, --method   curl method (default: \"${DEFAULT_METHOD}\")
      The script accepts only GET or POST; any other value falls back to POST.
  -t, --topic   overrides the environment variable NTFY_TOPIC
                (used if no explicit URL is provided)
  -h, --help    Show this help and exit

Examples:
  # Send from a pipe
  echo "All clear" | ./ntfy.sh                              

  # Use a custom topic name only
  export NTFY_TOPIC=myTeamAlert
  echo "Watch out!" | ./ntfy.sh -u \"https://ntfy.sh/\${NTFY_TOPIC}\"

  # Post JSON with a different method (rare but allowed)
  printf '{\"text\":\"boom\"}' | ./ntfy.sh --method POST -u https://example.com/api

Exit status:
  0   Success
  1   Invalid usage
  >1  Curl error (curl returns non‑zero exit code)

EOF
}

error_exit() {
    printf 'ntfy: %s\n' "$*" >&2
    exit "${2:-1}"
}
# -------------------------------------------

# ---------- Argument parsing ----------
topic_arg=false
method_opt="${DEFAULT_METHOD}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)   URL_ARG="$2"; shift 2 ;;
        -m|--method) method_opt="$2"; shift 2 ;;
        -t|--topic) topic_arg=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) error_exit "Unknown option: $1" ;;
    esac
done

# If a custom URL is supplied, use it verbatim.
if [[ "${URL_ARG:-}" ]]; then
    TARGET_URL="${URL_ARG}"
else
    # Otherwise build the default ntfy.sh address from the optional topic flag
    if $topic_arg; then
        export NTFY_TOPIC="$2"; shift 2   # --topic takes a value
    fi
    TARGET_URL="${DEFAULT_URL}"
fi

# Validate method – only GET and POST are accepted.
if [[ "$method_opt" != "GET" && "$method_opt" != "POST" ]]; then
    error_exit "Method must be GET or POST (got \"${method_opt}\")"
fi

# ---------- Read from stdin ----------
# Guard against an empty stream; curl can handle binary data, but we want a sane exit.
if [ -t 0 ]; then
    # No pipeline – require explicit non‑empty argument?
    error_exit "No data on stdin. Pipe some text into this script."
fi

# Capture the full payload (preserving newlines) in a temporary file.
TMP_PAYLOAD=$(mktemp)
cat > "$TMP_PAYLOAD"

# ---------- Invoke curl ----------
case "$method_opt" in
    POST)
        RESPONSE_CODE=$(curl "${CURL_OPTS[@]}" -X POST \
                         --data-binary @"$TMP_PAYLOAD" \
                         -o /dev/null \
                         -w "%{http_code}" "${TARGET_URL}")
        ;;
    GET)
        # For a GET we do *not* send a body; just request the URL with a query string
        # that can be used to embed data (e.g. ?msg=...). The script assumes no
        # parameters are added by the caller.
        RESPONSE_CODE=$(curl "${CURL_OPTS[@]}" -X GET \
                         -o /dev/null \
                         -w "%{http_code}" "${TARGET_URL}")
esac

# Clean up
rm -f "$TMP_PAYLOAD"

if [[ "$RESPONSE_CODE" -ge 200 && "$RESPONSE_CODE" -lt 400 ]]; then
    echo "ntfy: message sent successfully (HTTP $RESPONSE_CODE)" >&2
    exit 0
else
    error_exit "curl returned unexpected HTTP status ${RESPONSE_CODE}" 2
fi
