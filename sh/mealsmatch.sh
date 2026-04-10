#!/bin/sh

# ─────────────────────────────────────────────────────────────────
#  CSV Field Matcher — compatible with Git Bash, macOS, iSH
#
#  - Skips header row (row 1) in both files
#  - For EVERY source row, searches ALL reference rows for
#    a match on src#4 == ref#1
#  - When a ref row matches, compares the remaining field pairs
#  - Processes every source row (full join scan)
#
#  Field mapping (source → reference):
#       src #4  →  ref #1
#       src #5  →  ref #2
#       src #6  →  ref #4
#       src #7  →  ref #6
#       src #8  →  ref #7
#       src #9  →  ref #10
#
#  Usage: ./match_csv.sh <source.csv> <reference.csv>
# ─────────────────────────────────────────────────────────────────

GREEN='\033[0;32;40m'
RED='\033[0;31;40m'
RESET='\033[0m'
BOLD='\033[1m'

if [ $# -ne 2 ]; then
  printf "Usage: %s <source.csv> <reference.csv>\n" "$0"
  exit 1
fi

SOURCE="$1"
REFERENCE="$2"

if [ ! -f "$SOURCE" ];    then printf "Error: '%s' not found.\n" "$SOURCE";    exit 1; fi
if [ ! -f "$REFERENCE" ]; then printf "Error: '%s' not found.\n" "$REFERENCE"; exit 1; fi

FIELD_MAP="4 1|5 2|6 4|7 6|8 7|9 10"

printf "\n${BOLD}CSV Field Matcher${RESET}\n"
printf "Mode: each source row scanned against all reference rows on src#4 = ref#1\n"
printf "%s\n" "─────────────────────────────────────────────────"
printf "%-2s %-2s %-8s %-10s %-10s %s\n" \
    "Src" "Ref" "Field" "Src Val" "Ref Val" "Result"
printf "%s\n" "─────────────────────────────────────────────────"

# ─────────────────────────────────────────────────────────────────
#  Single awk pass:
#   - First file  (REFERENCE): load all data rows into memory
#   - Second file (SOURCE):    for each row, lookup src#4 in the
#                              ref index, then compare all fields
#
#  No process substitution, no pipes, no /dev/fd risk
# ─────────────────────────────────────────────────────────────────
awk -v field_map="$FIELD_MAP" \
    -v green="$GREEN" \
    -v red="$RED" \
    -v reset="$RESET" \
    -v bold="$BOLD" \
'BEGIN {
    FS = ","
    total = 0; matched = 0; mismatched = 0; unmatched = 0

    # Parse field mapping into arrays
    n = split(field_map, pairs, "|")
    for (i = 1; i <= n; i++) {
        split(pairs[i], p, " ")
        src_fields[i] = p[1]
        ref_fields[i] = p[2]
    }
    pair_count = n
}

# ── Skip headers in both files ────────────────────────────────────
FNR == 1 { next }

# ── Load entire reference into memory (first file arg) ────────────
FNR == NR {
    gsub(/\r/, "")
    row = $0

    # Store the full line keyed by row number
    ref_lines[NR] = row
    ref_max = NR

    # Also index ref col#1 value → ref row number for fast lookup
    key = $1
    gsub(/^ +| +$/, "", key)
    if (key != "") {
        # Store all ref rows that share this key (comma-separated list)
        if (ref_index[key] == "") {
            ref_index[key] = NR
        } else {
            ref_index[key] = ref_index[key] "," NR
        }
    }
    next
}

# ── Process each source row (second file arg) ─────────────────────
{
    gsub(/\r/, "")
    src_row = FNR

    # Get src#4 value (the join key)
    split($0, sf, ",")
    join_key = sf[4]
    gsub(/^ +| +$/, "", join_key)

    # Look up matching ref rows via index
    if (join_key == "" || ref_index[join_key] == "") {
        printf "%-6s %-6s %-16s %-20s %-20s %s\n", \
            src_row, "?", "src#4 -> ref#1", join_key, "(no match)", \
            red "NO REF MATCH" reset
        unmatched++
        next
    }

    # There may be multiple ref rows with the same key — check all
    num_ref_matches = split(ref_index[join_key], matched_refs, ",")

    for (m = 1; m <= num_ref_matches; m++) {
        ref_row = matched_refs[m]
        split(ref_lines[ref_row], rf, ",")

        # Compare all mapped field pairs
        for (i = 1; i <= pair_count; i++) {
            s = sf[src_fields[i]]
            r = rf[ref_fields[i]]
            gsub(/\r/, "", s); gsub(/^ +| +$/, "", s)
            gsub(/\r/, "", r); gsub(/^ +| +$/, "", r)

            label = "src#" src_fields[i] " -> ref#" ref_fields[i]
            total++

            if (s == r) {
                matched++
                printf "%-6s %-6s %-16s %-20s %-20s %s\n", \
                    src_row, ref_row, label, s, r, green "CORRECT" reset
            } else {
                mismatched++
                printf "%-6s %-6s %-16s %-20s %-20s %s\n", \
                    src_row, ref_row, label, s, r, red "INCORRECT" reset
            }
        }
    }
}

END {
    printf "%s\n", "──────────────────────────────────────────────────────────────────"
    printf "Total field checks : " bold "%s" reset "\n", total
    printf "Matched            : " green bold "%s" reset "\n", matched
    printf "Mismatched         : " red bold "%s" reset "\n", mismatched
    printf "Source rows w/no ref match : " bold "%s" reset "\n", unmatched
    printf "\n"
}
' "$REFERENCE" "$SOURCE"
