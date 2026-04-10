#!/usr/bin/env bash
# Simple ASCII nutrition summary for CSV logs
# Compatible with Git Bash, iSH, and minimal BusyBox environments
# Usage:
#   cat nutrition.csv | ./graph.sh
# or paste your CSV directly after `cat <<EOF | ./graph.sh` ... EOF
awk -F',' '
BEGIN {
  GREEN  = "\033[32m"
  RED    = "\033[31m"
  YELLOW = "\033[33m"
  RESET  = "\033[0m"
}
NR > 1 {
  date = $1
  gsub(/^[ \t]+|[ \t]+$/, "", date)
  if (!(date in kcal)) {
    dates[++n] = date
  }
  kcal[date]    += $6
  protein[date] += $7
  carb[date]    += $8
  fat[date]     += $9
}
END {
  # Insertion sort on the dates array (POSIX-safe, no asorti)
  for (i = 2; i <= n; i++) {
    key = dates[i]
    j = i - 1
    while (j >= 1 && dates[j] > key) {
      dates[j + 1] = dates[j]
      j--
    }
    dates[j + 1] = key
  }

  # Color picker function inline via ternary-style logic
  # Returns GREEN/RED/YELLOW/RESET based on value and range

  # Print the summary table header
  printf "\n%-10s | %-6s %-8s %-7s %-8s\n", "Date", "kcal", "Protein", "Carb", "Fat"
  print "--------------------------------------------"
  for (i = 1; i <= n; i++) {
    d = dates[i]
    k = kcal[d]
    pr = protein[d]
    cr = carb[d]
    fa = fat[d]

    # kcal: green 1800-2150, red >2150, yellow <1800
    if      (k  >= 1800 && k  <= 2200) kc = GREEN
    else if (k  >  2201)               kc = RED
    else if (k  >= 1700 && k  <= 1799) kc = YELLOW
    else                               kc = RESET

    # protein: green 180-195, red >195, yellow <180
    if      (pr >= 175 && pr <= 195)  pc = GREEN
    else if (pr >  196)               pc = RED
    else if (pr >= 170 && pr <= 179)  pc = YELLOW
    else                              pc = RESET

    # carbs: green 185-215, red >215, yellow <185
    if      (cr >= 185 && cr <= 215)  cc = GREEN
    else if (cr >  216)               cc = RED
    else if (cr >= 175 && cr <= 184)  cc = YELLOW
    else                              cc = RESET

    # fat: green 47-81, red >81, yellow <47
    if      (fa >= 47  && fa <= 81)   fc = GREEN
    else if (fa >  81)                fc = RED
    else if (fa >= 46)                fc = YELLOW
    else                              fc = RESET

    printf "%-6s | %s%-4.0f%s   %s%-6.1f%s   %s%-5.1f%s   %s%-4.1f%s\n", \
      d, \
      kc, k,  RESET, \
      pc, pr, RESET, \
      cc, cr, RESET, \
      fc, fa, RESET
  }

  # Print the ASCII bar chart
  print "\nASCII BAR CHART (1 # = 100 kcal):"
  print "---------------------------------"
  for (i = 1; i <= n; i++) {
    d = dates[i]
    k = kcal[d]
    bars = int(k / 100)
    bar = ""
    for (j = 0; j < bars; j++) bar = bar "#"

    # kcal: green 1800-2150, red >2150, yellow <1800
    if      (k  >= 1800 && k <= 2200) kc = GREEN
    else if (k  >  2201)              kc = RED
    else if (k  >= 1700 && k <= 1799) kc = YELLOW
    else                              kc = RESET

    printf "%-9s | %s%s %d %s\n", d, kc, bar, k, RESET
  }
}
'
