#!/bin/bash

set -eu

CSV_FILE="$HOME/Notes/code/data/nutrition.csv"

fields=(
    "Food Name"
    "Measure"
    "Weight (g)"
    "Energy (kcal)"
    "Energy (kJ)"
    "Protein (g)"
    "Carbohydrate (g)"
    "Total Sugar (g)"
    "Total Dietary Fibre (g)"
    "Total Fat (g)"
    "Saturated Fat (g)"
    "Cholesterol (mg)"
    "Calcium (mg)"
    "Iron (mg)"
    "Sodium (mg)"
    "Potassium (mg)"
    "Magnesium (mg)"
    "Phosphorus (mg)"
    "Vitamin A (RAE)"
    "Folate (DFE)"
    "Vitamin C (mg)"
    "Vitamin B12 (mcg)"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

die() { echo "Error: $*" >&2; exit 1; }

csv_quote() {
    echo "$1"
}

ensure_trailing_newline() {
    local file="$1"
    if [ -s "$file" ] && [ "$(tail -c1 "$file" | wc -l)" -eq 0 ]; then
        echo "" >> "$file"
    fi
}

# Parse a single CSV row into one field per line.
# Handles quoted fields (including commas and escaped quotes inside them).
# Uses awk — no Python required.
parse_csv_row() {
    local row="$1"
    local outfile="$2"
    echo "$row" | awk '
    {
        line = $0
        while (length(line) > 0) {
            if (substr(line, 1, 1) == "\"") {
                field = ""
                line = substr(line, 2)
                while (length(line) > 0) {
                    pos = index(line, "\"")
                    if (pos == 0) {
                        field = field line
                        line = ""
                        break
                    }
                    field = field substr(line, 1, pos - 1)
                    line  = substr(line, pos + 1)
                    if (substr(line, 1, 1) == "\"") {
                        field = field "\""
                        line  = substr(line, 2)
                    } else {
                        break
                    }
                }
                if (substr(line, 1, 1) == ",") line = substr(line, 2)
            } else {
                pos = index(line, ",")
                if (pos == 0) {
                    field = line
                    line  = ""
                } else {
                    field = substr(line, 1, pos - 1)
                    line  = substr(line, pos + 1)
                }
            }
            print field
        }
    }
    ' > "$outfile"
}

# Extract just the first CSV field from a row (for display purposes).
csv_first_field() {
    local row="$1"
    echo "$row" | awk '
    {
        line = $0
        if (substr(line, 1, 1) == "\"") {
            field = ""
            line = substr(line, 2)
            while (length(line) > 0) {
                pos = index(line, "\"")
                if (pos == 0) { field = field line; break }
                field = field substr(line, 1, pos - 1)
                line  = substr(line, pos + 1)
                if (substr(line, 1, 1) == "\"") {
                    field = field "\""
                    line  = substr(line, 2)
                } else { break }
            }
        } else {
            pos = index(line, ",")
            field = (pos == 0) ? line : substr(line, 1, pos - 1)
        }
        print field
    }
    '
}

# Shared search: prompts for a query, populates global matches array,
# prints the numbered list. Exits cleanly if no matches found.
# Sets globals: matches, query (for display).
run_search() {
    echo ""
    read -rp "Search for food name (partial match, case-insensitive): " query

   matches=()
   while IFS= read -r line; do
       matches+=("$line")
   done < <(
       grep -in "$query" "$CSV_FILE" \
           | grep -v '^[0-9]*:#' \
           | grep -v '^[0-9]*:[[:space:]]*$' \
           || true
    )

    if [ "${#matches[@]}" -eq 0 ]; then
        echo "No rows matching '$query' found."
        exit 0
    fi

    echo ""
    echo "Matching rows:"
    echo "--------------"
    for i in "${!matches[@]}"; do
        local line_num="${matches[$i]%%:*}"
        local row_content="${matches[$i]#*:}"
        local food_display
        food_display=$(csv_first_field "$row_content")
        echo "$((i+1)). [line $line_num] $food_display"
    done
    echo ""
}

# ── Validate file ─────────────────────────────────────────────────────────────

[ -f "$CSV_FILE" ] || die "$CSV_FILE not found."
ensure_trailing_newline "$CSV_FILE"

# ── Temp files (cleaned up on exit) ──────────────────────────────────────────

tmp_sections=$(mktemp)
tmp_file=$(mktemp)
tmp_fields=$(mktemp)
trap 'rm -f "$tmp_sections" "$tmp_file" "$tmp_fields"' EXIT

# ── Mode selection ────────────────────────────────────────────────────────────

echo "What would you like to do?"
echo "  a) Append a new row"
echo "  e) Edit an existing row"
echo "  d) Delete a row"
echo "  q) Quit"
echo ""
read -rp "Choice (a/e/d/q): " mode_choice

case "$mode_choice" in
    a|A) MODE="append" ;;
    e|E) MODE="edit" ;;
    d|D) MODE="delete" ;;
    q|Q) echo "Goodbye."; exit 0 ;;
    *) die "Invalid choice. Enter a, e, d, or q." ;;
esac

# ── Extract sections (used by append mode) ────────────────────────────────────

grep -n "^#" "$CSV_FILE" | sed 's/,.*$//' | sed 's/"//g' > "$tmp_sections"

sections=()
while IFS= read -r line; do
    sections+=("$line")
done < "$tmp_sections"

[ "${#sections[@]}" -gt 0 ] || die "No sections (lines starting with #) found in $CSV_FILE."

# ══════════════════════════════════════════════════════════════════════════════
# DELETE MODE
# ══════════════════════════════════════════════════════════════════════════════

if [ "$MODE" = "delete" ]; then

    matches=()
    run_search

    read -rp "Select row to delete (number): " row_choice

    [[ "$row_choice" =~ ^[0-9]+$ ]] \
        && [ "$row_choice" -ge 1 ] \
        && [ "$row_choice" -le "${#matches[@]}" ] \
        || die "Invalid choice."

    selected_match="${matches[$((row_choice-1))]}"
    target_line="${selected_match%%:*}"
    current_row="${selected_match#*:}"
    food_display=$(csv_first_field "$current_row")

    echo ""
    echo "About to delete: $food_display"
    echo "  $current_row"
    echo ""
    read -rp "Confirm delete? (y/n): " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted."; exit 0; }

    # Delete the target line by printing all lines except it
    awk -v linenum="$target_line" '
        NR != linenum { print }
    ' "$CSV_FILE" > "$tmp_file" || die "awk failed — original file untouched."

    mv "$tmp_file" "$CSV_FILE"
    echo "Row '$food_display' deleted."
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# EDIT MODE
# ══════════════════════════════════════════════════════════════════════════════

if [ "$MODE" = "edit" ]; then

    matches=()
    run_search

    read -rp "Select row to edit (number): " row_choice

    [[ "$row_choice" =~ ^[0-9]+$ ]] \
        && [ "$row_choice" -ge 1 ] \
        && [ "$row_choice" -le "${#matches[@]}" ] \
        || die "Invalid choice."

    selected_match="${matches[$((row_choice-1))]}"
    target_line="${selected_match%%:*}"
    current_row="${selected_match#*:}"

    # ── Parse existing field values ───────────────────────────────────────────

    parse_csv_row "$current_row" "$tmp_fields"

    current_values=()
    while IFS= read -r f; do
        current_values+=("$f")
    done < "$tmp_fields"

    # Pad to full field count if the row is short
    while [ "${#current_values[@]}" -lt "${#fields[@]}" ]; do
        current_values+=("")
    done

    # ── Interactive field editing ─────────────────────────────────────────────

    echo ""
    echo "Edit fields (press Enter to keep the value shown in brackets):"
    echo "---------------------------------------------------------------"

    quoted_values=()
    for i in "${!fields[@]}"; do
        current="${current_values[$i]:-}"
        read -rp "${fields[$i]} [${current}]: " val
        if [ -z "$val" ]; then
            val="$current"
        fi
        quoted_values+=("$(csv_quote "$val")")
    done

    # ── Preview & confirm ─────────────────────────────────────────────────────

    new_row=$(IFS=,; echo "${quoted_values[*]}")

    echo ""
    echo "Updated row:"
    echo "  $new_row"
    echo ""
    read -rp "Confirm edit? (y/n): " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted."; exit 0; }

    # ── Replace the target line ───────────────────────────────────────────────

    awk -v linenum="$target_line" -v newrow="$new_row" '
        NR == linenum { print newrow; next }
        { print }
    ' "$CSV_FILE" > "$tmp_file" || die "awk failed — original file untouched."

    mv "$tmp_file" "$CSV_FILE"
    echo "Row on line $target_line updated."
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# APPEND MODE
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "Available sections:"
echo "------------------"
for i in "${!sections[@]}"; do
    echo "$((i+1)). ${sections[$i]#*:}"
done
echo ""

read -rp "Select section number to append to: " section_choice

[[ "$section_choice" =~ ^[0-9]+$ ]] \
    && [ "$section_choice" -ge 1 ] \
    && [ "$section_choice" -le "${#sections[@]}" ] \
    || die "Invalid section choice."

selected_line=$(echo "${sections[$((section_choice-1))]}" | cut -d: -f1)
next_section_line=$(grep -n "^#" "$CSV_FILE" \
    | awk -F: -v curr="$selected_line" '$1 > curr {print $1; exit}')

if [ -z "$next_section_line" ]; then
    insert_after=$(wc -l < "$CSV_FILE" | tr -d ' ')
else
    insert_after=$((next_section_line - 1))
fi

echo ""
echo "Enter nutrition data (press Enter to leave blank):"
echo "--------------------------------------------------"

quoted_values=()
for field in "${fields[@]}"; do
    read -rp "$field: " val
    quoted_values+=("$(csv_quote "$val")")
done

new_row=$(IFS=,; echo "${quoted_values[*]}")

echo ""
echo "Preview:"
echo "  $new_row"
echo ""

food_name="${quoted_values[0]//\"/}"
if grep -qiF "${food_name}," "$CSV_FILE" 2>/dev/null; then
    echo "Warning: '${food_name}' may already exist in this file."
fi

read -rp "Confirm append? (y/n): " confirm
[[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted."; exit 0; }

awk -v line="$insert_after" -v row="$new_row" '
    NR == line { print; print row; next }
    { print }
' "$CSV_FILE" > "$tmp_file" || die "awk failed — original file untouched."

mv "$tmp_file" "$CSV_FILE"
echo "Row successfully added under section: ${sections[$((section_choice-1))]#*:}"
