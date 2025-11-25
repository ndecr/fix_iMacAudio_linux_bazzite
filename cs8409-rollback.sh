#!/bin/bash
# Script de rollback pour revenir au kernel précédent en cas d'échec du driver audio
# Ce script permet de revenir à un état fonctionnel connu

set -e

STATE_DIR="/var/lib/cs8409-state"
DRIVER_DIR="/etc/kernel/drivers"
DRIVER_FILE="$DRIVER_DIR/snd-hda-codec-cs8409.ko"
LOG_FILE="/var/log/cs8409-rollback.log"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction d'affichage coloré
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Fonction de notification utilisateur
notify_user() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    sudo -u ndecr_ DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u ndecr_)/bus \
        notify-send -u "$urgency" "$title" "$message" 2>/dev/null || true

    log "$title: $message"
}

# Créer le répertoire d'état s'il n'existe pas
mkdir -p "$STATE_DIR"

# Sauvegarder l'état actuel comme "bon état"
save_working_state() {
    log "========================================="
    log "Saving current working state"

    local current_kernel=$(uname -r)
    local state_file="$STATE_DIR/working-state-$(date +%Y%m%d-%H%M%S).json"

    # Vérifier que le driver est chargé
    if ! lsmod | grep -q snd_hda_codec_cs8409; then
        print_color "$RED" "❌ ERROR: Driver CS8409 not loaded. Cannot save non-working state."
        log "ERROR: Driver not loaded, refusing to save state"
        return 1
    fi

    # Vérifier que le driver est le bon (personnalisé, pas natif)
    local driver_size=$(lsmod | grep "^snd_hda_codec_cs8409" | awk '{print $2}')
    if [ "$driver_size" -lt 100000 ]; then
        print_color "$RED" "❌ ERROR: Native driver loaded (size: $driver_size). This is not a working state."
        log "ERROR: Native driver detected, refusing to save state"
        return 1
    fi

    # Vérifier que le fichier driver existe
    if [ ! -f "$DRIVER_FILE" ]; then
        print_color "$RED" "❌ ERROR: Driver file not found at $DRIVER_FILE"
        log "ERROR: Driver file not found"
        return 1
    fi

    # Obtenir l'index du deployment actuel
    local current_deployment_index=$(rpm-ostree status --json | jq '.deployments | map(.booted) | index(true)')
    local current_deployment_checksum=$(rpm-ostree status --json | jq -r ".deployments[$current_deployment_index].checksum")
    local current_deployment_version=$(rpm-ostree status --json | jq -r ".deployments[$current_deployment_index].version")

    # Créer la sauvegarde du driver
    local driver_backup="$STATE_DIR/driver-$current_kernel.ko"
    cp "$DRIVER_FILE" "$driver_backup"
    chcon -t modules_object_t "$driver_backup"

    # Créer le fichier JSON d'état
    cat > "$state_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "kernel_version": "$current_kernel",
  "deployment_index": $current_deployment_index,
  "deployment_checksum": "$current_deployment_checksum",
  "deployment_version": "$current_deployment_version",
  "driver_file": "$driver_backup",
  "driver_size": $(stat -c%s "$DRIVER_FILE"),
  "verified_working": true
}
EOF

    # Créer un lien symbolique vers le dernier état fonctionnel
    ln -sf "$state_file" "$STATE_DIR/last-working-state.json"

    log "Working state saved successfully"
    log "Kernel: $current_kernel"
    log "Deployment: $current_deployment_version (index $current_deployment_index)"
    log "Driver backup: $driver_backup"

    print_color "$GREEN" "✅ Working state saved successfully!"
    print_color "$BLUE" "   Kernel: $current_kernel"
    print_color "$BLUE" "   Deployment: $current_deployment_version"

    notify_user "CS8409 Audio" "État fonctionnel sauvegardé pour kernel $current_kernel" "normal"

    return 0
}

# Lister les états sauvegardés
list_saved_states() {
    print_color "$BLUE" "========================================="
    print_color "$BLUE" "           SAVED WORKING STATES"
    print_color "$BLUE" "========================================="
    echo ""

    if [ ! -d "$STATE_DIR" ] || [ -z "$(ls -A $STATE_DIR/*.json 2>/dev/null)" ]; then
        print_color "$YELLOW" "⚠️  No saved states found"
        return 0
    fi

    local current_kernel=$(uname -r)
    local index=1

    for state_file in "$STATE_DIR"/working-state-*.json; do
        if [ -f "$state_file" ]; then
            local kernel=$(jq -r '.kernel_version' "$state_file")
            local timestamp=$(jq -r '.timestamp' "$state_file")
            local deployment_version=$(jq -r '.deployment_version' "$state_file")

            if [ "$kernel" = "$current_kernel" ]; then
                print_color "$GREEN" "[$index] ✅ $kernel (CURRENT)"
            else
                echo "[$index] $kernel"
            fi
            echo "    Date: $timestamp"
            echo "    Deployment: $deployment_version"
            echo ""

            ((index++))
        fi
    done

    # Montrer l'état actuel
    print_color "$YELLOW" "Current system:"
    echo "  Kernel: $current_kernel"
    rpm-ostree status | head -8
}

# Effectuer le rollback
perform_rollback() {
    log "========================================="
    log "Starting rollback process"

    # Vérifier qu'un état fonctionnel existe
    if [ ! -f "$STATE_DIR/last-working-state.json" ]; then
        print_color "$RED" "❌ ERROR: No working state found to rollback to"
        print_color "$YELLOW" "   You need to save a working state first:"
        print_color "$YELLOW" "   $ sudo $0 save"
        log "ERROR: No working state found"
        return 1
    fi

    # Charger l'état fonctionnel
    local last_state="$STATE_DIR/last-working-state.json"
    local last_kernel=$(jq -r '.kernel_version' "$last_state")
    local last_deployment_index=$(jq -r '.deployment_index' "$last_state")
    local last_driver_file=$(jq -r '.driver_file' "$last_state")
    local last_deployment_version=$(jq -r '.deployment_version' "$last_state")

    local current_kernel=$(uname -r)

    print_color "$BLUE" "========================================="
    print_color "$BLUE" "         ROLLBACK INFORMATION"
    print_color "$BLUE" "========================================="
    echo ""
    print_color "$YELLOW" "Current state:"
    echo "  Kernel: $current_kernel"
    echo ""
    print_color "$GREEN" "Rolling back to:"
    echo "  Kernel: $last_kernel"
    echo "  Deployment: $last_deployment_version"
    echo ""

    # Vérifier si nous sommes déjà sur le bon kernel
    if [ "$current_kernel" = "$last_kernel" ]; then
        print_color "$YELLOW" "⚠️  Already on the target kernel: $last_kernel"
        print_color "$BLUE" "   Only restoring the driver..."

        # Restaurer uniquement le driver
        if [ -f "$last_driver_file" ]; then
            cp "$last_driver_file" "$DRIVER_FILE"
            chcon -t modules_object_t "$DRIVER_FILE"
            log "Driver restored from $last_driver_file"
            print_color "$GREEN" "✅ Driver restored successfully"
            print_color "$YELLOW" "   Please reboot to load the restored driver:"
            print_color "$YELLOW" "   $ sudo systemctl reboot"
            notify_user "CS8409 Rollback" "Driver restauré. Redémarrage nécessaire." "normal"
        else
            print_color "$RED" "❌ ERROR: Driver backup file not found: $last_driver_file"
            log "ERROR: Driver backup not found"
            return 1
        fi

        return 0
    fi

    # Demander confirmation
    print_color "$RED" "⚠️  This will:"
    echo "  1. Rollback rpm-ostree to the previous deployment"
    echo "  2. Restore the working driver for kernel $last_kernel"
    echo "  3. Reboot the system"
    echo ""
    read -p "Do you want to continue? (yes/no): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_color "$YELLOW" "Rollback cancelled by user"
        log "Rollback cancelled by user"
        return 0
    fi

    # Restaurer le driver
    if [ -f "$last_driver_file" ]; then
        log "Restoring driver from $last_driver_file"
        cp "$last_driver_file" "$DRIVER_FILE"
        chcon -t modules_object_t "$DRIVER_FILE"
        print_color "$GREEN" "✅ Driver restored"
    else
        print_color "$RED" "❌ ERROR: Driver backup file not found: $last_driver_file"
        log "ERROR: Driver backup not found"
        return 1
    fi

    # Effectuer le rollback rpm-ostree
    log "Performing rpm-ostree rollback"
    print_color "$BLUE" "Performing rpm-ostree rollback..."

    if rpm-ostree rollback; then
        log "rpm-ostree rollback successful"
        print_color "$GREEN" "✅ Rollback successful!"
        print_color "$YELLOW" ""
        print_color "$YELLOW" "System will reboot in 10 seconds..."
        print_color "$YELLOW" "Press Ctrl+C to cancel"

        notify_user "CS8409 Rollback" "Rollback effectué. Redémarrage dans 10 secondes..." "critical"

        sleep 10

        log "Rebooting system"
        systemctl reboot
    else
        print_color "$RED" "❌ ERROR: rpm-ostree rollback failed"
        log "ERROR: rpm-ostree rollback failed"
        return 1
    fi
}

# Vérifier l'audio après le boot
verify_audio() {
    log "========================================="
    log "Verifying audio functionality"

    print_color "$BLUE" "========================================="
    print_color "$BLUE" "      AUDIO VERIFICATION"
    print_color "$BLUE" "========================================="
    echo ""

    local current_kernel=$(uname -r)
    print_color "$BLUE" "Current kernel: $current_kernel"
    echo ""

    # Vérifier que le driver est chargé
    if ! lsmod | grep -q snd_hda_codec_cs8409; then
        print_color "$RED" "❌ FAIL: Driver CS8409 not loaded"
        log "FAIL: Driver not loaded"
        return 1
    fi
    print_color "$GREEN" "✅ PASS: Driver CS8409 loaded"

    # Vérifier que c'est le driver personnalisé
    local driver_size=$(lsmod | grep "^snd_hda_codec_cs8409" | awk '{print $2}')
    if [ "$driver_size" -lt 100000 ]; then
        print_color "$RED" "❌ FAIL: Native driver loaded (size: $driver_size bytes)"
        print_color "$RED" "   Expected: >100000 bytes (custom driver)"
        log "FAIL: Native driver detected (size: $driver_size)"
        return 1
    fi
    print_color "$GREEN" "✅ PASS: Custom driver loaded (size: $driver_size bytes)"

    # Vérifier que le codec est détecté
    if [ ! -f /proc/asound/card0/codec#0 ]; then
        print_color "$RED" "❌ FAIL: Codec not detected"
        log "FAIL: Codec not detected"
        return 1
    fi

    local codec_name=$(cat /proc/asound/card0/codec#0 | grep "^Codec:" | head -1)
    if echo "$codec_name" | grep -q "CS8409"; then
        print_color "$GREEN" "✅ PASS: Codec detected: $codec_name"
    else
        print_color "$RED" "❌ FAIL: Wrong codec: $codec_name"
        log "FAIL: Wrong codec detected"
        return 1
    fi

    # Test audio optionnel
    echo ""
    print_color "$YELLOW" "All automatic checks passed!"
    echo ""
    read -p "Do you want to test audio playback? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_color "$BLUE" "Testing audio playback..."
        if speaker-test -c 2 -t wav -D hw:0,0 -l 1; then
            print_color "$GREEN" "✅ Audio test completed"
            log "Audio test successful"
            return 0
        else
            print_color "$RED" "❌ Audio test failed"
            log "Audio test failed"
            return 1
        fi
    fi

    log "Audio verification completed successfully"
    return 0
}

# Afficher l'aide
show_help() {
    cat << EOF
CS8409 Driver Rollback System

Usage: $0 [COMMAND]

Commands:
  save          Save current working state (kernel + driver)
  list          List all saved working states
  rollback      Rollback to last working state
  verify        Verify audio functionality
  help          Show this help message

Examples:
  # Save current working state
  sudo $0 save

  # List all saved states
  $0 list

  # Rollback to last working state
  sudo $0 rollback

  # Verify audio after boot
  $0 verify

Note: This script should be run with sudo for save and rollback commands.

EOF
}

# Fonction principale
main() {
    local command="${1:-help}"

    case "$command" in
        save)
            if [ "$EUID" -ne 0 ]; then
                print_color "$RED" "❌ ERROR: 'save' command must be run as root"
                exit 1
            fi
            save_working_state
            ;;
        list)
            list_saved_states
            ;;
        rollback)
            if [ "$EUID" -ne 0 ]; then
                print_color "$RED" "❌ ERROR: 'rollback' command must be run as root"
                exit 1
            fi
            perform_rollback
            ;;
        verify)
            verify_audio
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_color "$RED" "❌ ERROR: Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Exécuter la fonction principale
main "$@"
