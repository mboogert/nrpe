#!/bin/sh

CURL=$(which curl)

CODE=$($CURL -ks "http://knmi.nl/waarschuwingen" | grep "\<h1 class=\"alert__heading\">Code " | sed 's/:.*$//' | sed 's/^.*Code //')

ok() {
    printf 'OK: %s\n' "KNMI zegt code groen :-)"
    exit 0
}

critical() {
    printf 'CRITICAL: %s\n' "KNMI zegt code $CODE !!"
    exit 2
}

warning() {
    printf 'WARNING: %s\n' "KNMI zegt code $CODE !!"
    exit 1
}

unknown() {
    printf 'UNKNOWN: %s\n' "KNMI zegt code...ahum...paars?"
    exit 3
}

case "$CODE" in
  groen)
    ok
    ;;
  geel|oranje)
    warning
    ;;
  rood)
    critical
    ;;
  *)
    unknown
    ;;
esac
