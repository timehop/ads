#!/usr/bin/env bash
# Sanity-checks app-ads.txt before it is published.
#
# Catches the mistakes that would silently cost ad revenue: an empty or
# truncated file, a stray paste, or a line a crawler would skip. It is not a
# full IAB validator.
#
# Usage: check-app-ads.sh [path]   (default: app-ads.txt)
set -euo pipefail

file="${1:-app-ads.txt}"

if [ ! -s "$file" ]; then
  echo "::error file=$file::$file is missing or empty"
  exit 1
fi

awk -v file="$file" '
  function fail(msg) {
    printf "::error file=%s,line=%d::%s: %s\n", file, NR, msg, raw
    errors++
  }
  {
    raw = $0
    line = $0
    sub(/\r$/, "", line)          # tolerate Windows line endings
    sub(/#.*/, "", line)          # drop comments
    gsub(/^[ \t]+|[ \t]+$/, "", line)
    if (line == "") next

    # Variable line, e.g. OWNERDOMAIN=timehop.com. The value may contain commas.
    if (line ~ /^[A-Za-z]+[ \t]*=/) {
      if (line ~ /=$/) fail("variable has no value")
      next
    }

    # Record: domain, account id, DIRECT|RESELLER[, certification authority id]
    # optionally followed by "; extension data", which is ignored here.
    sub(/;.*/, "", line)
    n = split(line, f, ",")
    for (i = 1; i <= n; i++) gsub(/^[ \t]+|[ \t]+$/, "", f[i])
    if (n < 3 || n > 4)                    { fail("expected 3 or 4 comma-separated fields"); next }
    if (f[1] !~ /^[A-Za-z0-9.-]+\.[A-Za-z]+$/) { fail("first field is not a domain"); next }
    if (f[2] == "")                        { fail("account id is empty"); next }
    if (toupper(f[3]) != "DIRECT" && toupper(f[3]) != "RESELLER") {
      fail("third field must be DIRECT or RESELLER"); next
    }
    records++
  }
  END {
    if (records == 0) {
      printf "::error file=%s::no seller records found\n", file
      errors++
    }
    if (errors > 0) {
      printf "%d problem(s) found in %s\n", errors, file
      exit 1
    }
    printf "%s looks OK: %d seller records\n", file, records
  }
' "$file"
