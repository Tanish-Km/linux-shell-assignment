#!/usr/bin/env bash
# monitor_cpu_mem.sh
# Purpose : Simple portable CPU + memory monitor that avoids `top`
# Author  : TanZ (example)
# Date    : 2025-11-18
#
# Usage : ./monitor_cpu_mem.sh INTERVAL_SECONDS logfile.csv
# Example: ./monitor_cpu_mem.sh 5 cpu_mem.csv
#
# Output CSV header:
# Timestamp,LoadAvg_1m,LoadAvg_5m,LoadAvg_15m,CPU_User_pct,CPU_System_pct,CPU_Idle_pct,Mem_Total_MB,Mem_Used_MB,Mem_Free_MB

INTERVAL="${1:-5}"
OUTFILE="${2:-./cpu_mem.csv}"

if ! [[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 INTERVAL_SECONDS logfile.csv"
  exit 1
fi

# Write header if file does not exist
if [ ! -f "$OUTFILE" ]; then
  echo "Timestamp,LoadAvg_1m,LoadAvg_5m,LoadAvg_15m,CPU_User_pct,CPU_System_pct,CPU_Idle_pct,Mem_Total_MB,Mem_Used_MB,Mem_Free_MB" > "$OUTFILE"
fi

# Function: read CPU fields from /proc/stat (first line "cpu ...")
# returns: values in order user nice system idle iowait irq softirq steal guest guest_nice
read_proc_stat() {
  if [ -r /proc/stat ]; then
    awk '/^cpu / {for(i=2;i<=NF;i++) printf $i " "; print ""}' /proc/stat
  else
    echo ""
  fi
}

# Function: compute mem info from /proc/meminfo (returns total used free in MB)
read_meminfo_mb() {
  if [ -r /proc/meminfo ]; then
    # read needed fields
    mem_total_k=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    mem_free_k=$(awk '/^MemFree:/ {print $2}' /proc/meminfo)
    mem_buff_cache_k=$(awk '/^Buffers:/ {b=$2} /^Cached:/ {c=$2} END {print (b+c)}' /proc/meminfo)
    # Some systems use "MemAvailable" which is better; try that
    mem_avail_k=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo || true)

    if [ -n "$mem_avail_k" ]; then
      # used = total - available
      mem_used_k=$(( mem_total_k - mem_avail_k ))
      mem_free_use_k=$mem_avail_k
    else
      # fallback used = total - (free + buffers + cache)
      mem_used_k=$(( mem_total_k - (mem_free_k + mem_buff_cache_k) ))
      mem_free_use_k=$(( mem_total_k - mem_used_k ))
    fi

    # convert to MB (integer)
    mem_total_mb=$(( mem_total_k / 1024 ))
    mem_used_mb=$(( mem_used_k / 1024 ))
    mem_free_mb=$(( mem_free_use_k / 1024 ))
    echo "$mem_total_mb $mem_used_mb $mem_free_mb"
  else
    echo ""
  fi
}

# Main loop: sample pair for CPU to compute percent
while true; do
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

  # load averages (try /proc/loadavg)
  if [ -r /proc/loadavg ]; then
    read load1 load5 load15 _ < /proc/loadavg
  else
    load1="NA"; load5="NA"; load15="NA"
  fi

  # Read first CPU sample
  stat1=$(read_proc_stat)
  if [ -z "$stat1" ]; then
    cpu_user="NA"; cpu_sys="NA"; cpu_idle="NA"
  else
    # wait a short time (use half the interval), but ensure nonzero
    sleep 0.5
    stat2=$(read_proc_stat)
    if [ -z "$stat2" ]; then
      cpu_user="NA"; cpu_sys="NA"; cpu_idle="NA"
    else
      # Convert both to arrays
      read -r u1 n1 s1 i1 w1 irq1 sirq1 st1 g1 gn1 <<< "$stat1"
      read -r u2 n2 s2 i2 w2 irq2 sirq2 st2 g2 gn2 <<< "$stat2"

      # compute totals
      tot1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1 + st1 + g1 + gn1))
      tot2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2 + st2 + g2 + gn2))
      # deltas
      tot_delta=$(( tot2 - tot1 ))
      user_delta=$(( (u2 + n2) - (u1 + n1) ))   # treat nice as user time
      sys_delta=$(( s2 - s1 ))
      idle_delta=$(( i2 - i1 ))

      if [ "$tot_delta" -le 0 ]; then
        cpu_user="NA"; cpu_sys="NA"; cpu_idle="NA"
      else
        # Compute percentages using awk for floating math
        cpu_user=$(awk -v ud="$user_delta" -v td="$tot_delta" 'BEGIN {printf "%.2f", (ud/td)*100}')
        cpu_sys=$(awk -v sd="$sys_delta" -v td="$tot_delta" 'BEGIN {printf "%.2f", (sd/td)*100}')
        cpu_idle=$(awk -v id="$idle_delta" -v td="$tot_delta" 'BEGIN {printf "%.2f", (id/td)*100}')
      fi
    fi
  fi

  # Memory
  memvals=$(read_meminfo_mb)
  if [ -z "$memvals" ]; then
    mem_total="NA"; mem_used="NA"; mem_free="NA"
  else
    read -r mem_total mem_used mem_free <<< "$memvals"
  fi

  # Write CSV line
  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$ts" "$load1" "$load5" "$load15" "$cpu_user" "$cpu_sys" "$cpu_idle" \
    "$mem_total" "$mem_used" "$mem_free" >> "$OUTFILE"

  # Sleep full interval before next iteration
  sleep "$INTERVAL"
done