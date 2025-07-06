#!/bin/bash

S="************************************"
D="-------------------------------------"
COLOR="y"

# Setup colors
if [ "$COLOR" == "y" ]; then
  GCOLOR="\e[32mOK/HEALTHY\e[0m"
  WCOLOR="\e[33mWARNING\e[0m"
  CCOLOR="\e[31mCRITICAL\e[0m"
else
  GCOLOR="OK/HEALTHY"
  WCOLOR="WARNING"
  CCOLOR="CRITICAL"
fi


echo -e "$S"
echo -e "        System Health Status"
echo -e "$S"
echo -e "Hostname : $(hostname -f 2>/dev/null || hostname -s)"
echo -e "Operating System : $(. /etc/os-release && echo \"$NAME $VERSION\")"
echo -e "Kernel Version : $(uname -r)"
echo -en "OS Architecture : " && (arch | grep -q x86_64 && echo "64 Bit OS" || echo "32 Bit OS")
echo -e "System Uptime : $(uptime -p)"
echo -e "Current System Date & Time : $(date '+%a %d %b %Y %T')"

# Fastfetch (optional)
fastfetch
# Read-only filesystems
echo -e "\nRead-only File Systems:"
mount | grep -E 'ext[234]|xfs|btrfs' | grep -w ro && echo "  Found read-only file systems" || echo "  All file systems are writable"

# Mounted file systems
echo -e "\nMounted File Systems:"
mount | column -t

# Disk Usage
echo -e "\nDisk Usage (0-85%=$GCOLOR, 85-95%=$WCOLOR, 95-100%=$CCOLOR):"
df -Ph | grep -vE 'tmpfs|cdrom|udev|loop' | awk 'NR>1 {print $1, $6, $5}' | while read fs mount pct; do
  val=$(echo "$pct" | tr -d '%')
  if [[ "$val" =~ ^[0-9]+$ ]]; then
    if [ "$val" -ge 95 ]; then
      echo -e "$fs $mount  $pct  $CCOLOR"
    elif [ "$val" -ge 85 ]; then
      echo -e "$fs $mount  $pct  $WCOLOR"
    else
      echo -e "$fs $mount  $pct  $GCOLOR"
    fi
  else
    echo -e "$fs $mount  -% (Unavailable)"
  fi
done

# Zombie Processes
echo -e "\nZombie Processes:"
ZCNT=$(ps aux | awk '{ if ($8 ~ /Z/) print }' | wc -l)
if [ "$ZCNT" -gt 0 ]; then
  echo "  Found $ZCNT zombie process(es):"
  ps aux | awk '{ if ($8 ~ /Z/) print }'
else
  echo "  No zombie processes found."
fi

# INode Usage
# INode Usage
echo -e "\nINode Usage (0-85%=$GCOLOR, 85-95%=$WCOLOR, 95-100%=$CCOLOR):"
df -iP | grep -v "/dev/loop" | awk 'NR>1 {print $1, $6, $5}' | while read fs mount pct; do
  # Skip inode check for vfat (e.g., /boot/efi)
  fstype=$(findmnt -n -o FSTYPE "$mount")
  if [ "$fstype" = "vfat" ]; then
    echo -e "$fs $mount  -% (Skipped: vfat has no valid inode info)"
    continue
  fi

  val=$(echo "$pct" | tr -d '%')
  if [[ "$val" =~ ^[0-9]+$ ]]; then
    if [ "$val" -ge 95 ]; then
      echo -e "$fs $mount  $pct  $CCOLOR"
    elif [ "$val" -ge 85 ]; then
      echo -e "$fs $mount  $pct  $WCOLOR"
    else
      echo -e "$fs $mount  $pct  $GCOLOR"
    fi
  else
    actual=$(stat -f -c %f "$mount" 2>/dev/null)
    total=$(stat -f -c %i "$mount" 2>/dev/null)
    if [[ "$actual" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ && "$total" -gt 0 ]]; then
      used=$((total - actual))
      used_pct=$((used * 100 / total))
      if [ "$used_pct" -ge 95 ]; then
        echo -e "$fs $mount  ${used_pct}%  $CCOLOR"
      elif [ "$used_pct" -ge 85 ]; then
        echo -e "$fs $mount  ${used_pct}%  $WCOLOR"
      else
        echo -e "$fs $mount  ${used_pct}%  $GCOLOR"
      fi
    else
      echo -e "$fs $mount  -% (Unavailable or Btrfs subvolume)"
    fi
  fi
done


# SWAP
echo -e "\nSWAP Usage:"
SWAP_TOTAL=$(awk '/SwapTotal/ {printf "%.2f", $2/1024/1024}' /proc/meminfo)
SWAP_FREE=$(awk '/SwapFree/ {printf "%.2f", $2/1024/1024}' /proc/meminfo)
echo -e "  Total Swap: $SWAP_TOTAL GiB"
echo -e "  Swap Free : $SWAP_FREE GiB"

# CPU Usage
echo -e "\nCPU Utilization:"
if command -v mpstat >/dev/null 2>&1; then
  mpstat 1 1 | tail -n 2
else
  echo "  mpstat not found. Install sysstat package."
fi

# Load Average
echo -e "\nLoad Average:"
echo -e "  $(uptime | awk -F'load average: ' '{ print $2 }')"

# Reboot & Shutdown Logs
echo -e "\nRecent Reboot Events:"
last -x | grep reboot | head -3 || echo "  No reboot history available"
echo -e "\nRecent Shutdown Events:"
last -x | grep shutdown | head -3 || echo "  No shutdown history available"

# Top Memory Hogs
echo -e "\nTop 5 Memory-Consuming Processes:"
ps -eo pmem,pid,ppid,user,stat,args --sort=-pmem | head -n 6

# Top CPU Hogs
echo -e "\nTop 5 CPU-Consuming Processes:"
ps -eo pcpu,pid,ppid,user,stat,args --sort=-pcpu | head -n 6

# Broken Packages
if command -v dnf &>/dev/null; then
  echo -e "\nBroken Packages (DNF):"
  dnf check 2>&1 | grep -iE 'broken|error|fail|dependency|incomplete' || echo "  No broken packages detected."
elif command -v apt &>/dev/null; then
  echo -e "\nBroken Packages (APT):"
  apt -f check 2>&1 | grep -iE 'broken|error|fail|dependency|incomplete' || echo "  No broken packages detected."
else
  echo -e "\nBroken Packages: Package manager not supported."
fi

# Broken Permissions
echo -e "\nBroken Permissions (Expected: root owned, 755/700):"
declare -A expected_modes
expected_modes[/etc]=755
expected_modes[/var/log]=755
expected_modes[/var/spool]=755
for path in "${!expected_modes[@]}"; do
  if [ -d "$path" ]; then
    stat_out=$(stat -c "%U %a" "$path")
    owner=$(echo "$stat_out" | awk '{print $1}')
    perms=$(echo "$stat_out" | awk '{print $2}')
    expected=${expected_modes[$path]}
    if [ "$owner" != "root" ] || [ "$perms" != "$expected" ]; then
      echo "  Warning: $path is $owner:$perms (expected: root:$expected)"
    fi
  fi
done

# Footer
echo -e "\nNOTE: Some fields may be blank or NA if unsupported by the system."

echo -e "\nHardware Information:"

# CPU Info
echo -e "\nCPU Info:"
if command -v lscpu >/dev/null 2>&1; then
  lscpu | grep -E 'Model name|Socket|Thread|Core|CPU MHz|Architecture'
else
  echo "  lscpu command not found."
fi

# Memory Info
echo -e "\nMemory Info:"
if command -v free >/dev/null 2>&1; then
  free -h | head -2
else
  echo "  free command not found."
fi

# Total RAM and Swap (from /proc/meminfo)
RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
RAM_TOTAL_MB=$((RAM_TOTAL/1024))
SWAP_TOTAL=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
SWAP_TOTAL_MB=$((SWAP_TOTAL/1024))
echo "  RAM Total : ${RAM_TOTAL_MB} MB"
echo "  SWAP Total: ${SWAP_TOTAL_MB} MB"

# Disk Info
echo -e "\nDisk Info:"
if command -v lsblk >/dev/null 2>&1; then
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v loop
else
  echo "  lsblk command not found."
fi

# GPU Info
echo -e "\nGPU Info:"
if command -v lspci >/dev/null 2>&1; then
  lspci | grep -i 'vga\|3d\|2d' || echo "  No GPU detected."
else
  echo "  lspci command not found."
fi

# Network Interface Info
echo -e "\nNetwork Interfaces:"
if command -v ip >/dev/null 2>&1; then
  ip -brief link show | awk '{print $1, $2, $3}'
else
  echo "  ip command not found."
fi

echo -e "\nBattery Health Check:"
#!/bin/bash

# Warna terminal
GCOLOR="\e[32m"  # Hijau
WCOLOR="\e[33m"  # Kuning
CCOLOR="\e[31m"  # Merah
NCOLOR="\e[0m"   # Reset

echo "Checking Battery Info..."

# Coba cari path UPower
UPOWER_PATH=$(upower -e 2>/dev/null | grep battery | head -n 1)
if [ -n "$UPOWER_PATH" ]; then
  echo "  Using UPower at: $UPOWER_PATH"
  UINFO=$(upower -i "$UPOWER_PATH")

  STATUS=$(echo "$UINFO" | awk -F: '/state/ {gsub(/^[ \t]+/, "", $2); print $2}')
  CAPACITY=$(echo "$UINFO" | awk -F: '/capacity/ {gsub(/^[ \t]+/, "", $2); print int($2)}')

  # Paksa cari informasi kapasitas penuh dari /sys
  BAT_PATH="/sys/class/power_supply/BAT0"
  if [ -d "$BAT_PATH" ]; then
    if [ -f "$BAT_PATH/charge_full" ] && [ -f "$BAT_PATH/charge_full_design" ]; then
      FULL=$(cat "$BAT_PATH/charge_full")
      DESIGN=$(cat "$BAT_PATH/charge_full_design")
    elif [ -f "$BAT_PATH/energy_full" ] && [ -f "$BAT_PATH/energy_full_design" ]; then
      FULL=$(cat "$BAT_PATH/energy_full")
      DESIGN=$(cat "$BAT_PATH/energy_full_design")
    fi

    if [[ "$FULL" =~ ^[0-9]+$ ]] && [[ "$DESIGN" =~ ^[0-9]+$ ]] && [ "$DESIGN" -gt 0 ]; then
      HEALTH=$(( 100 * FULL / DESIGN ))
    else
      HEALTH="Unknown"
    fi
  else
    HEALTH="Unknown"
  fi

  echo "  Status   : $STATUS"
  echo "  Capacity : $CAPACITY%"
  echo "  Health   : $HEALTH%"


  # Tentukan status kesehatan
  health_msg="OK"
  health_color="$GCOLOR"

  if [[ "$HEALTH" == "Unknown" ]]; then
    if [ -n "$CAPACITY" ] && [ "$CAPACITY" -lt 30 ]; then
      health_color="$CCOLOR"
      health_msg="Low Capacity - Battery Degraded"
    else
      health_color="$WCOLOR"
      health_msg="Health Unknown"
    fi
  else
    if [ "$HEALTH" -ge 90 ]; then
      health_color="$GCOLOR"
      health_msg="Excellent"
    elif [ "$HEALTH" -ge 70 ]; then
      health_color="$WCOLOR"
      health_msg="Good - Some Wear"
    elif [ "$HEALTH" -ge 50 ]; then
      health_color="$WCOLOR"
      health_msg="Fair - Consider Replacing"
    else
      health_color="$CCOLOR"
      health_msg="Poor - Replace Soon"
    fi
  fi
fi
echo -e "  Battery Health Status: ${health_color}${health_msg}${NCOLOR}"

echo -e "\nDisk SMART Health Check:"
if command -v smartctl >/dev/null 2>&1; then
  for dev in /dev/sd?; do
    if [ -b "$dev" ]; then
      echo "  Checking $dev..."
      sudo smartctl -H "$dev" | grep -iE 'SMART overall-health|SMART Health Status|PASSED|FAILED|OK'
    fi
  done
else
  echo "  smartctl not found. Please install smartmontools."
fi

echo -e "\nFan Health Check:"
if [ -f /proc/acpi/ibm/fan ]; then
  cat /proc/acpi/ibm/fan
elif [ -d /sys/class/hwmon ]; then
  for hw in /sys/class/hwmon/hwmon*; do
    label=$(cat "$hw/name" 2>/dev/null)
    fan_speed=$(cat "$hw"/fan*_input 2>/dev/null)
    if [[ -n "$fan_speed" ]]; then
      echo "  Fan ($label): ${fan_speed} RPM"
    fi
  done
else
  echo "  Fan information not available on this system."
fi

echo "=== Zero Error System Check ==="
echo ""

# 1. Boot log errors
echo "[1] Log error boot saat ini:"
sudo journalctl -p err..alert -b | grep -v bpf-restrict-fs | grep -v FileManager1 | grep -v osnoise
echo ""

# 2. Systemd failed service
echo "[2] Service systemd yang gagal:"
sudo systemctl --failed
echo ""

# 3. Kernel dmesg error
echo "[3] Error kernel (dmesg):"
sudo dmesg --level=err,crit,emerg
echo ""

# 4. Log audit/SELinux (jika aktif)
echo "[4] Log audit/SELinux (opsional):"
sudo journalctl -t audit | grep -i denied
echo ""

# 5. Cek log umum: error, fail, denied
echo "[5] Grep error umum:"
echo -e "\\n${YELLOW}[5] Grep error umum:${NC}"
journalctl -b --no-pager | grep -iE "error|fail|invalid|denied" | grep -vE "kioworker|wpad-detector|oom-notifier|plasma-session-shortcuts|snap-device-helper|Bluetooth|Couldnt parse dbx"


# Ring Summary with Clean Visual and Bigger Center Font

echo -e "\n\e[1mSystem Health Summary (Visual Ring)\e[0m"

# Warna untuk output
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
BLUE='\e[1;34m'
NC='\e[0m' # No Color
COLOR=$GREEN

# Skor awal
SCORE=100

# Ring ASCII
RING=("○" "○" "○" "○" "○" "○" "○")
GCOLOR=$GREEN
WCOLOR=$YELLOW
CCOLOR=$RED

# Fungsi untuk visualisasi ring
draw_ring() {
  local percent=$1
  local -n ref=$2

  local filled=$(( percent / 14 ))

  for ((i=0;i<7;i++)); do
    if (( i < filled )); then
      if (( percent >= 80 )); then
        ref[$i]="${GCOLOR}●${NC}"
      elif (( percent >= 60 )); then
        ref[$i]="${WCOLOR}●${NC}"
      else
        ref[$i]="${CCOLOR}●${NC}"
      fi
    else
      ref[$i]="${NC}○${NC}"
    fi
  done
}


# Header
echo -e "$BLUE************************************$NC"
echo -e "        ${BLUE}System Health Status${NC}"
echo -e "$BLUE************************************$NC"
echo -e "Hostname : $(hostname -f 2>/dev/null || hostname -s)"
echo -e "Operating System : $(. /etc/os-release && echo \"$NAME $VERSION\")"
echo -e "Kernel Version : $(uname -r)"
echo -en "OS Architecture : " && (arch | grep -q x86_64 && echo "64 Bit OS" || echo "32 Bit OS")
echo -e "System Uptime : $(uptime -p)"
echo -e "Current System Date & Time : $(date '+%a %d %b %Y %T')"

# Fastfetch (optional)
command -v fastfetch >/dev/null && fastfetch

# Tambahan Hardware Summary dari fastfetch jika tersedia
command -v fastfetch >/dev/null || {
  echo -e "\n${BLUE}Hardware Summary:${NC}"
  echo -e "CPU: $(lscpu | grep 'Model name' | sed 's/Model name:\s*//')"
  echo -e "Memory: $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
  echo -e "Swap: $(free -h | awk '/Swap:/ {print $3 "/" $2}')"
  echo -e "Disk (/): $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
  echo -e "Battery: $(upower -d 2>/dev/null | grep -E 'percentage|state' | xargs)"
}

# Penyesuaian skor berdasarkan keseluruhan sistem (tidak hanya log)

# Error count dari log (log dianggap aman jika < 200)
ERR_COUNT=$(journalctl -b -p err..alert | wc -l)
(( ERR_COUNT >= 200 )) && SCORE=$(( SCORE - 20 ))

# Disk usage
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
(( DISK_USAGE > 95 )) && SCORE=$(( SCORE - 15 ))
(( DISK_USAGE > 90 && DISK_USAGE <= 95 )) && SCORE=$(( SCORE - 10 ))
(( DISK_USAGE > 85 && DISK_USAGE <= 90 )) && SCORE=$(( SCORE - 5 ))

# Zombie process
ZOMBIE=$(ps -eo stat | grep -c '^Z')
(( ZOMBIE > 0 )) && SCORE=$(( SCORE - 5 ))

# Swap terlalu kecil
SWAP_FREE=$(awk '/SwapFree/ { print int($2) }' /proc/meminfo)
(( SWAP_FREE < 102400 )) && SCORE=$(( SCORE - 5 ))  # <100MB swap

# Load average
CPU_LOAD=$(uptime | awk -F 'load average:' '{ print $2 }' | cut -d',' -f1 | sed 's/ //g')
CPU_INT=${CPU_LOAD%.*}
(( CPU_INT > 3 )) && SCORE=$(( SCORE - 5 ))

# Clamp
(( SCORE < 0 )) && SCORE=0
(( SCORE > 100 )) && SCORE=100

# Visual Ring
draw_ring $SCORE RING

# Ring Output
echo -e "\nSystem Health Summary (Visual Ring)"
echo -e "   ${RING[0]}   ${RING[1]}   ${RING[2]}"
echo -e "  ${RING[3]}   $SCORE% ${RING[4]}"
echo -e "   ${RING[5]}   ${RING[6]}"

# Kesimpulan
echo -e "\n     ${COLOR}System Health Score: ${SCORE}%${NC}\n"
echo "=== Selesai ==="
mail -H 2>/dev/null && echo "Anda memiliki surat baru dalam /var/spool/mail/\$USER"

exit 0
