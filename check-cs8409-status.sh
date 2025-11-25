#!/bin/bash
# Script de vérification du statut du driver CS8409

DRIVER_FILE="/etc/kernel/drivers/snd-hda-codec-cs8409.ko"
KERNEL_VERSION_FILE="/var/lib/cs8409-kernel-version"
LOG_FILE="/var/log/cs8409-auto-rebuild.log"
CURRENT_KERNEL=$(uname -r)

echo "======================================"
echo "CS8409 Driver Status Check"
echo "======================================"
echo ""

# Kernel actuel
echo "🖥️  Kernel actuel: $CURRENT_KERNEL"

# Kernel sauvegardé
if [ -f "$KERNEL_VERSION_FILE" ]; then
    SAVED_KERNEL=$(cat "$KERNEL_VERSION_FILE")
    echo "💾 Kernel sauvegardé: $SAVED_KERNEL"
    if [ "$SAVED_KERNEL" = "$CURRENT_KERNEL" ]; then
        echo "   ✅ Kernel inchangé"
    else
        echo "   ⚠️  Kernel a changé!"
    fi
else
    echo "💾 Kernel sauvegardé: Aucun (première installation)"
fi

echo ""

# Vérifier le driver
if [ -f "$DRIVER_FILE" ]; then
    DRIVER_SIZE=$(stat -c%s "$DRIVER_FILE")
    DRIVER_SIZE_MB=$(echo "scale=2; $DRIVER_SIZE / 1024 / 1024" | bc)
    DRIVER_KERNEL=$(modinfo "$DRIVER_FILE" 2>/dev/null | grep "^vermagic:" | awk '{print $2}')

    echo "📦 Driver installé: Oui"
    echo "   📏 Taille: $DRIVER_SIZE_MB MB"
    echo "   🔧 Compilé pour: $DRIVER_KERNEL"

    if [ "$DRIVER_KERNEL" = "$CURRENT_KERNEL" ]; then
        echo "   ✅ Compatible avec le kernel actuel"
    else
        echo "   ❌ INCOMPATIBLE avec le kernel actuel"
        echo "   ⚠️  RECOMPILATION NÉCESSAIRE"
    fi
else
    echo "📦 Driver installé: ❌ NON"
fi

echo ""

# Vérifier si le driver est chargé
if lsmod | grep -q snd_hda_codec_cs8409; then
    LOADED_SIZE=$(lsmod | grep "^snd_hda_codec_cs8409" | awk '{print $2}')
    echo "🔊 Driver chargé: ✅ Oui"
    echo "   📏 Taille en mémoire: $LOADED_SIZE bytes"

    if [ "$LOADED_SIZE" -gt 100000 ]; then
        echo "   ✅ Driver personnalisé (davidjo)"
    else
        echo "   ⚠️  Driver natif (pas de support GPIO)"
    fi
else
    echo "🔊 Driver chargé: ❌ Non"
fi

echo ""

# Vérifier l'audio
if [ -f /proc/asound/card0/codec#0 ]; then
    echo "🎵 Codec détecté: ✅ Oui"
    CODEC_NAME=$(cat /proc/asound/card0/codec#0 | grep "Codec:" | head -1)
    echo "   $CODEC_NAME"
else
    echo "🎵 Codec détecté: ❌ Non"
fi

echo ""

# Vérifier le service
SERVICE_STATUS=$(systemctl is-enabled cs8409-auto-rebuild.service 2>/dev/null || echo "not-found")
echo "⚙️  Service auto-rebuild: $SERVICE_STATUS"

if [ "$SERVICE_STATUS" = "enabled" ]; then
    SERVICE_ACTIVE=$(systemctl is-active cs8409-auto-rebuild.service 2>/dev/null || echo "unknown")
    echo "   État: $SERVICE_ACTIVE"
fi

echo ""

# Dernières lignes du log
if [ -f "$LOG_FILE" ]; then
    echo "📋 Dernières entrées du log:"
    tail -5 "$LOG_FILE" | sed 's/^/   /'
else
    echo "📋 Fichier log: Aucun"
fi

echo ""
echo "======================================"

# Test audio rapide (optionnel)
echo ""
read -p "Voulez-vous tester l'audio maintenant? (o/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Oo]$ ]]; then
    echo "🔊 Test audio en cours..."
    speaker-test -c 2 -t wav -D hw:0,0 -l 1 2>&1
fi
