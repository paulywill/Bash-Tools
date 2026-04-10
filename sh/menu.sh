#!/usr/bin/env bash
# Usage: ./menu.sh <csvfile>

FILE="$HOME/Desktop/Notes/code/data/nutrition.csv"

if [[ ! -f "$FILE" ]]; then
	echo "Error: File '$FILE' not found."
	exit 1
fi

# 📅 Log file setup
YEAR=$(date +%Y)
LOG_FILE="$HOME/Notes/log/$YEAR/health/meals.csv"

# 🍽 Meal entries array
declare -a MEAL_ENTRIES

# 🔍 Parse sections with awk — much faster than while read loop
# Outputs lines like: TITLE<TAB>body line 1|body line 2|...
declare -a TITLES
declare -a BODIES

# awk reads the whole file in one pass, splitting on '#' headers
# Body lines within a section are joined with a pipe '|' delimiter
while IFS=$'\t' read -r title body; do
	TITLES+=("$title")
	BODIES+=("$body")
done < <(awk '
	/^#/ {
		if (idx >= 0) {
			print title "\t" body
		}
		title = $0
		body = ""
		idx++
		next
	}
	idx >= 0 {
		body = (body == "") ? $0 : body "|" $0
	}
	END {
		if (idx >= 0) print title "\t" body
	}
' "$FILE")

total="${#TITLES[@]}"

if [[ $total -eq 0 ]]; then
	echo "No sections starting with '#' found in '$FILE'."
	exit 1
fi

# ❓ Helper: ask meal type
ask_meal_type() {
	while true; do
		echo ""
		echo "╔══════════════════════════════════════╗"
		echo " What type of meal is this?"
		echo "╚══════════════════════════════════════╝"
		echo " 1) Breakfast"
		echo " 2) Lunch"
		echo " 3) Dinner"
		echo " 4) Snack"
		echo " q) Quit"
		echo "════════════════════════════════════════"
		printf "Choose [1-4 or q]: "
		read -r mchoice
		case "$mchoice" in
			1) MEAL_TYPE="breakfast"; return 0 ;;
			2) MEAL_TYPE="lunch";     return 0 ;;
			3) MEAL_TYPE="dinner";    return 0 ;;
			4) MEAL_TYPE="snack";     return 0 ;;
			q|Q) echo "Goodbye."; exit 0 ;;
			*) echo " ⚠ Invalid choice. Please enter 1, 2, 3, or 4." ;;
		esac
	done
}

# 💾 Helper: save entries to log
save_entries() {
	local entry_count="${#MEAL_ENTRIES[@]}"
	if [[ $entry_count -eq 0 ]]; then
		echo ""
		echo " ℹ No entries to save."
		return
	fi
	echo ""
	echo "════════════════════════════════════════"
	echo " Entries to be saved:"
	echo "════════════════════════════════════════"
	for entry in "${MEAL_ENTRIES[@]}"; do
		printf '%s\n' "$entry" >> "$LOG_FILE"
	done
	echo "════════════════════════════════════════"
	echo " ✅ $entry_count entry/entries appended to: $LOG_FILE"
	MEAL_ENTRIES=()
}

# 📋 Helper: show body lines as numbered choices
# Body lines are stored pipe-delimited; awk splits and extracts fields
show_body_menu() {
	local title="$1"
	local body="$2"

	# Split pipe-delimited body into array (no subshell, no read loop)
	IFS='|' read -r -a LINES <<< "$body"

	local line_count="${#LINES[@]}"
	if [[ $line_count -eq 0 ]]; then
		echo " (no lines in this section)"
		return
	fi

	while true; do
		echo ""
		echo "════════════════════════════════════════"
		echo " $title"
		echo "════════════════════════════════════════"

		# Use awk to format all display lines in one pass — no per-line cut forks
		printf '%s\n' "${LINES[@]}" | awk -F',' '{
			printf " %d) %s, %s\n", NR, $1, $2
		}'

		echo " b) Back to search"
		echo " q) Quit"
		echo "════════════════════════════════════════"
		printf "Choose a line [1-%d, b, or q]: " "$line_count"
		read -r lchoice

		if [[ "$lchoice" == "q" || "$lchoice" == "Q" ]]; then
			echo "Goodbye."
			exit 0
		fi
		if [[ "$lchoice" == "b" || "$lchoice" == "B" ]]; then
			return
		fi
		if ! [[ "$lchoice" =~ ^[0-9]+$ ]] || (( lchoice < 1 || lchoice > line_count )); then
			echo " ⚠ Invalid choice. Please enter a number between 1 and $line_count."
			continue
		fi

		lidx=$(( lchoice - 1 ))

		# Extract all 6 needed fields in one awk call — replaces 6x cut forks
		read -r f1 f2 f4 f6 f7 f10 < <(
			echo "${LINES[$lidx]}" | awk -F',' '{print $1, $2, $4, $6, $7, $10}'
		)

		datestamp=$(date '+%Y-%m-%d')
		timestamp=$(date '+%H:%M')
		entry="$datestamp,$timestamp,$MEAL_TYPE,$f1,$f2,$f4,$f6,$f7,$f10"
		MEAL_ENTRIES+=("$entry")
		echo ""
		echo " ✅ Added: $entry"
		echo " (${#MEAL_ENTRIES[@]} item(s) in session — enter 's' at the main menu to save)"
		return
	done
}

# 🎬 Ask meal type once at the start
ask_meal_type

# 🔄 Interactive menu
while true; do
	echo ""
	printf "════════════════════════════════════════\n"
	printf " Search sections in: %s\n" "$FILE"
	printf " Meal type : %s | Items queued: %d\n" "$MEAL_TYPE" "${#MEAL_ENTRIES[@]}"
	printf " s=save  m=change meal type  q=quit\n"
	printf "════════════════════════════════════════\n"
	printf "Enter keyword: "
	read -r keyword

	case "$keyword" in
		q|Q) echo "Goodbye."; exit 0 ;;
		s|S) save_entries; continue ;;
		m|M) ask_meal_type; continue ;;
		"") echo " ⚠ Please enter a keyword."; continue ;;
	esac

	# Search titles with awk — one pass, no per-title grep forks
	declare -a MATCH_IDX
	while IFS= read -r i; do
		MATCH_IDX+=("$i")
	done < <(
		printf '%s\n' "${TITLES[@]}" | awk -v kw="$keyword" '
			BEGIN { IGNORECASE=1 }
			tolower($0) ~ tolower(kw) { print NR-1 }
		'
	)

	match_count="${#MATCH_IDX[@]}"
	if [[ $match_count -eq 0 ]]; then
		echo " ℹ No sections found matching '$keyword'."
		unset MATCH_IDX
		continue
	fi
	if [[ $match_count -eq 1 ]]; then
		idx="${MATCH_IDX[0]}"
		show_body_menu "${TITLES[$idx]}" "${BODIES[$idx]}"
		unset MATCH_IDX
		continue
	fi

	while true; do
		echo ""
		echo "════════════════════════════════════════"
		printf " %d section(s) matching '%s':\n" "$match_count" "$keyword"
		echo "════════════════════════════════════════"
		for i in "${!MATCH_IDX[@]}"; do
			printf " %d) %s\n" $(( i + 1 )) "${TITLES[${MATCH_IDX[$i]}]}"
		done
		echo " b) New search"
		echo " q) Quit"
		echo "════════════════════════════════════════"
		printf "Choose a section [1-%d, b, or q]: " "$match_count"
		read -r schoice

		case "$schoice" in
			q|Q) echo "Goodbye."; exit 0 ;;
			b|B) break ;;
		esac

		if ! [[ "$schoice" =~ ^[0-9]+$ ]] || (( schoice < 1 || schoice > match_count )); then
			echo " ⚠ Invalid choice. Please enter a number between 1 and $match_count."
			continue
		fi
		sidx="${MATCH_IDX[$(( schoice - 1 ))]}"
		show_body_menu "${TITLES[$sidx]}" "${BODIES[$sidx]}"
	done
	unset MATCH_IDX
done
