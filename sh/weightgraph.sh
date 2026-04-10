#!/bin/sh
# Portable ASCII graph from CSV
# Usage:
#   ./weight_graph.sh file.csv
#   cat file.csv | ./weight_graph.sh

WIDTH=50
HEIGHT=10

INPUT="$1"

awk -F',' -v W="$WIDTH" -v H="$HEIGHT" '

function date_to_days(d,   a,y,m,dy,days,dm) {
    split(d,a,"-")
    y=a[1]+0; m=a[2]+0; dy=a[3]+0

    days=(y-1970)*365+int((y-1969)/4)

    dm[1]=0;dm[2]=31;dm[3]=59;dm[4]=90;dm[5]=120;dm[6]=151
    dm[7]=181;dm[8]=212;dm[9]=243;dm[10]=273;dm[11]=304;dm[12]=334

    days+=dm[m]+dy-1
    if (m>2 && ((y%4==0 && y%100!=0) || y%400==0)) days++

    return days
}

function to_col(t) {
    return int((t - T_MIN) / (T_MAX - T_MIN) * (W-1) + 0.5)
}

function to_row(v) {
    return int((1 - (v - Y_MIN) / (Y_MAX - Y_MIN)) * (H-1) + 0.5)
}

BEGIN {
    count=0
}

$1 !~ /^#/ && NF>=3 {
    dates[count]=$1
    weights[count]=$3+0
    times[count]=date_to_days($1)

    if (count==0 || times[count]<T_MIN) T_MIN=times[count]
    if (count==0 || times[count]>T_MAX) T_MAX=times[count]

    if (count==0 || weights[count]<W_MIN) W_MIN=weights[count]
    if (count==0 || weights[count]>W_MAX) W_MAX=weights[count]

    sum+=weights[count]
    count++
}

END {
    if (count < 2) {
        print "Error: need at least 2 data points" > "/dev/stderr"
        exit 1
    }

    if (T_MAX == T_MIN) T_MAX = T_MIN + 1

    pad=(W_MAX-W_MIN)*0.2
    if (pad==0) pad=1
    Y_MIN=W_MIN-pad
    Y_MAX=W_MAX+pad

    for (r=0; r<H; r++) {
        for (c=0; c<W; c++) {
            grid[r "," c]=" "
        }
    }

    for (i=0; i<count; i++) {
        col=to_col(times[i])
        row=to_row(weights[i])

        cols[i]=col
        rows[i]=row

        if (i>0) {
            dc=col-prev_col
            dr=row-prev_row
            abs_dc = (dc<0?-dc:dc)
            abs_dr = (dr<0?-dr:dr)
            steps = (abs_dc>abs_dr?abs_dc:abs_dr)

            for (s=1; s<steps; s++) {
                ic = prev_col + int(s*dc/steps)
                ir = prev_row + int(s*dr/steps)
                if (grid[ir "," ic] == " ")
                    grid[ir "," ic] = "-"
            }
        }

        grid[row "," col]="*"
        prev_col=col
        prev_row=row
    }

    print ""
    print "  Weight (lbs)"

    for (r=0; r<H; r++) {
        if (r%3==0)
            printf "%6.1f |", Y_MAX - r*(Y_MAX-Y_MIN)/(H-1)
        else
            printf "%6s |", ""

        for (c=0; c<W; c++) {
            printf "%s", grid[r "," c]
        }
        print ""
    }

    printf "%6s +", ""
    for (i=0;i<W;i++) printf "-"
    print ""

    printf "%8s", ""
    printed=0
    for (i=0; i<count; i++) {
        col = cols[i]
        label = substr(dates[i],6,5)
        pos = col - 2
        if (pos < 0) pos = 0

        while (printed < pos) {
            printf " "
            printed++
        }

       # printf "%s", label
       # printed += length(label)
    }
    print ""

    avg = sum / count
    change = weights[count-1] - weights[0]

    printf "  entries: %d \n",
        count

    printf "  min: %.1f\n",
        W_MIN

    printf "  max: %.1f\n",
        W_MAX


    printf "  avg: %.1f \n",
        avg

    printf "  chg: %+0.1f lbs\n",
        change

}
' "$INPUT"
