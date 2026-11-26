#!/bin/sh
# textfile-gen: reads a few host files that node_exporter does not export and
# writes them as Prometheus text metrics for node_exporter's textfile collector.
#
# Runs as an unprivileged user (65534) in a read-only container. Everything it
# reads is world-readable on the host and mounted read-only:
#   $SYS  = host /sys            (GPU power state, msi-ec, battery, throttling)
#   $RUN  = host /run            (only /run/reboot-required is read)
#   $UPD  = host /var/lib/update-notifier
#   /proc/modules, /proc/net/route  (host network namespace: network_mode host)
#
# IMPORTANT: never read current_link_speed / current_link_width or the PCI
# "config" file of the NVIDIA GPU: each read wakes the GPU for ~7 s
# (measured 2026-11-05). Only the power/ files and power_state are safe.
#
# Usage: collect.sh [--once]   (default: loop every $INTERVAL seconds)

set -u

SYS="${SYS:-/host/sys}"
RUN="${RUN:-/host/run}"
UPD="${UPD:-/host/update-notifier}"
PROC="${PROC:-/proc}"
OUT="${OUT:-/out/msi.prom}"
INTERVAL="${INTERVAL:-15}"

# Print a file's first line, or nothing if it cannot be read.
rd() { [ -r "$1" ] && head -n 1 "$1" 2>/dev/null; }

# Print "name{labels} value" only when value is a number.
num() {
    case "$2" in
        '' | *[!0-9.-]*) ;;
        *) printf '%s %s\n' "$1" "$2" ;;
    esac
}

help_type() { printf '# HELP %s %s\n# TYPE %s %s\n' "$1" "$3" "$1" "$2"; }

pci_metrics() {
    help_type msi_pci_runtime_status gauge "Runtime PM status of a PCI function (1 for the current status)."
    help_type msi_pci_power_state gauge "PCI power state (1 for the current state). D3cold = power removed."
    help_type msi_pci_runtime_active_seconds_total counter "Time the function was awake (runtime PM), from power/runtime_active_time."
    help_type msi_pci_runtime_suspended_seconds_total counter "Time the function was suspended (runtime PM), from power/runtime_suspended_time."
    help_type msi_pci_power_control_auto gauge "1 if power/control is auto (runtime PM allowed), 0 if on."
    help_type msi_pci_driver_info gauge "Kernel driver bound to the PCI function."
    for spec in 0000:01:00.0=gpu 0000:01:00.1=gpu_audio 0000:00:01.0=gpu_bridge; do
        dev="${spec%%=*}"
        role="${spec#*=}"
        p="$SYS/bus/pci/devices/$dev"
        [ -d "$p" ] || continue
        l="device=\"$dev\",role=\"$role\""
        st="$(rd "$p/power/runtime_status")"
        for s in active suspended suspending resuming unsupported error; do
            v=0
            [ "$st" = "$s" ] && v=1
            printf 'msi_pci_runtime_status{%s,status="%s"} %s\n' "$l" "$s" "$v"
        done
        ps="$(rd "$p/power_state")"
        for s in D0 D1 D2 D3hot D3cold unknown; do
            v=0
            [ "$ps" = "$s" ] && v=1
            printf 'msi_pci_power_state{%s,state="%s"} %s\n' "$l" "$s" "$v"
        done
        a="$(rd "$p/power/runtime_active_time")"
        s="$(rd "$p/power/runtime_suspended_time")"
        [ -n "$a" ] && num "msi_pci_runtime_active_seconds_total{$l}" "$(awk -v x="$a" 'BEGIN{printf "%.3f", x/1000}')"
        [ -n "$s" ] && num "msi_pci_runtime_suspended_seconds_total{$l}" "$(awk -v x="$s" 'BEGIN{printf "%.3f", x/1000}')"
        c="$(rd "$p/power/control")"
        if [ "$c" = auto ]; then c=1; elif [ "$c" = on ]; then c=0; else c=""; fi
        num "msi_pci_power_control_auto{$l}" "$c"
        drv=none
        [ -e "$p/driver" ] && drv="$(basename "$(readlink "$p/driver")")"
        printf 'msi_pci_driver_info{%s,driver="%s"} 1\n' "$l" "$drv"
    done
}

throttle_metrics() {
    # package_* counters are per physical package: identical on every CPU, so cpu0.
    t="$SYS/devices/system/cpu/cpu0/thermal_throttle"
    [ -d "$t" ] || return 0
    help_type msi_cpu_package_throttle_events_total counter "Times the whole CPU package was slowed down for heat (kernel thermal_throttle)."
    num msi_cpu_package_throttle_events_total "$(rd "$t/package_throttle_count")"
    help_type msi_cpu_package_throttle_seconds_total counter "Total time the CPU package spent throttled for heat."
    v="$(rd "$t/package_throttle_total_time_ms")"
    [ -n "$v" ] && num msi_cpu_package_throttle_seconds_total "$(awk -v x="$v" 'BEGIN{printf "%.3f", x/1000}')"
    # core_* counters are per physical core; two hyper-threads share one. Sum once per core_id.
    help_type msi_cpu_core_throttle_events_total counter "Thermal throttling events summed over physical cores."
    for c in "$SYS"/devices/system/cpu/cpu[0-9]*; do
        [ -r "$c/thermal_throttle/core_throttle_count" ] || continue
        printf '%s %s\n' "$(rd "$c/topology/core_id")" "$(rd "$c/thermal_throttle/core_throttle_count")"
    done | awk '!seen[$1]++ {s += $2} END {if (NR) print "msi_cpu_core_throttle_events_total", s+0}'
}

ec_metrics() {
    e="$SYS/devices/platform/msi-ec"
    [ -d "$e" ] || return 0
    help_type msi_ec_fan_speed_percent gauge "Fan speed reported by the embedded controller (msi-ec), percent."
    num 'msi_ec_fan_speed_percent{fan="cpu"}' "$(rd "$e/cpu/realtime_fan_speed")"
    num 'msi_ec_fan_speed_percent{fan="gpu"}' "$(rd "$e/gpu/realtime_fan_speed")"
    help_type msi_ec_temp_celsius gauge "Temperature reported by the embedded controller (msi-ec). GPU 0 = GPU powered off."
    num 'msi_ec_temp_celsius{sensor="cpu"}' "$(rd "$e/cpu/realtime_temperature")"
    num 'msi_ec_temp_celsius{sensor="gpu"}' "$(rd "$e/gpu/realtime_temperature")"
    help_type msi_ec_shift_mode_info gauge "EC performance mode (msi-ec shift_mode)."
    m="$(rd "$e/shift_mode")"
    [ -n "$m" ] && printf 'msi_ec_shift_mode_info{mode="%s"} 1\n' "$m"
    help_type msi_ec_cooler_boost gauge "1 if the EC cooler boost (fans at full speed) is on."
    cb="$(rd "$e/cooler_boost")"
    if [ "$cb" = on ]; then echo "msi_ec_cooler_boost 1"; elif [ "$cb" = off ]; then echo "msi_ec_cooler_boost 0"; fi
}

hygiene_metrics() {
    b="$SYS/class/power_supply/BAT1"
    help_type msi_battery_charge_threshold_percent gauge "Battery charge thresholds set in firmware (charge_control_*_threshold)."
    num 'msi_battery_charge_threshold_percent{edge="start"}' "$(rd "$b/charge_control_start_threshold")"
    num 'msi_battery_charge_threshold_percent{edge="end"}' "$(rd "$b/charge_control_end_threshold")"

    help_type msi_module_loaded gauge "1 if the kernel module is loaded (from /proc/modules)."
    for m in msi_ec nouveau nvidia snd_hda_intel; do
        v=0
        grep -q "^$m " "$PROC/modules" 2>/dev/null && v=1
        printf 'msi_module_loaded{module="%s"} %s\n' "$m" "$v"
    done

    help_type msi_reboot_required gauge "1 if /run/reboot-required exists (a package update needs a reboot)."
    if [ -e "$RUN/reboot-required" ]; then echo "msi_reboot_required 1"; else echo "msi_reboot_required 0"; fi

    # update-notifier writes this file daily: "5 updates can be applied immediately."
    f="$UPD/updates-available"
    if [ -r "$f" ]; then
        help_type msi_apt_updates_pending gauge "Package updates pending, from update-notifier (refreshed by the system about daily)."
        u="$(awk '/can be applied immediately/ {print $1; exit}' "$f")"
        num msi_apt_updates_pending "${u:-0}"
        help_type msi_apt_security_updates_pending gauge "Security updates pending, from update-notifier."
        s="$(awk '/standard security update/ {print $1; exit}' "$f")"
        num msi_apt_security_updates_pending "${s:-0}"
    fi
}

network_metrics() {
    # Default route with the lowest metric = the interface the MSI uses to go out.
    help_type msi_default_route_interface gauge "1 for the interface that carries the default route (lowest metric)."
    awk 'NR > 1 && $2 == "00000000" && $8 == "00000000" {print $7, $1}' "$PROC/net/route" 2>/dev/null |
        sort -n | head -n 1 | awk '{printf "msi_default_route_interface{device=\"%s\"} 1\n", $2}'
}

collect() {
    {
        pci_metrics
        throttle_metrics
        ec_metrics
        hygiene_metrics
        network_metrics
        help_type msi_textfile_gen_last_run_timestamp_seconds gauge "When textfile-gen last wrote this file (Unix time)."
        echo "msi_textfile_gen_last_run_timestamp_seconds $(date +%s)"
    } > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
    # Rename = atomic: node_exporter never reads a half-written file.
}

if [ "${1:-}" = "--once" ]; then
    collect
    exit 0
fi
while :; do
    collect
    sleep "$INTERVAL"
done
