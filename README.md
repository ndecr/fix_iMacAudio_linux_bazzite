# Guide Post-Reboot - Fix Audio iMac 18,2 sur Bazzite 42

**Date:** 2025-11-19
**Contexte:** Après rebase de Bazzite 43 (kernel 6.17.7) vers Bazzite 42 (kernel 6.16.x)

**DERNIÈRE MISE À JOUR:** 2025-11-20 20:30 - Session 19 🎉 SUCCÈS TOTAL! LE SON FONCTIONNE! 🎉 Après reboot 19, le driver davidjo/snd_hda_macbookpro (1.9M) a parfaitement initialisé les amplificateurs TDM. Les haut-parleurs internes de l'iMac 18,2 produisent enfin du son! La solution finale était d'utiliser un driver qui supporte les amplificateurs TDM externes (MAX98706/SSM3515/TAS5764L) en plus du codec CS8409/CS42L83.

---

## 🎉 SUCCÈS! LE SON FONCTIONNE!

**CONFIGURATION FINALE FONCTIONNELLE:**
- ✅ **Driver:** davidjo/snd_hda_macbookpro (1.9M) dans `/etc/kernel/drivers/`
- ✅ **Kernel:** Bazzite 6.16.4-116.bazzite.fc42.x86_64
- ✅ **Hardware:** iMac 18,2 avec codec CS8409/CS42L83 + amplificateurs TDM
- ✅ **Contexte SELinux:** `modules_object_t:s0` (critique pour insmod)
- ✅ **Directive modprobe:** `/etc/modprobe.d/cs8409-custom-driver.conf` avec `install` pour intercepter le chargement

**COMMANDES DE VÉRIFICATION SI LE SON ARRÊTE DE FONCTIONNER:**

```bash
# 1. Vérifier que le bon driver est chargé (doit être ~1.9M)
lsmod | grep snd_hda_codec_cs8409

# 2. Vérifier les logs d'initialisation
sudo dmesg | grep -iE "cs8409|cs42l83|tdm|amp" | head -50

# 3. Vérifier le codec
cat /proc/asound/card0/codec#0 | head -30

# 4. Vérifier que la carte audio est détectée
aplay -l

# 5. Tester le son
speaker-test -c 2 -t wav -l 1
```

**SI LE DRIVER NE CHARGE PLUS (après mise à jour kernel):**

```bash
# 1. Vérifier que le driver existe toujours
ls -lhZ /etc/kernel/drivers/snd-hda-codec-cs8409.ko

# 2. Vérifier le contexte SELinux (doit être modules_object_t)
# Si incorrect, corriger avec:
sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko

# 3. Vérifier la config modprobe
cat /etc/modprobe.d/cs8409-custom-driver.conf
# Doit contenir la directive "install snd_hda_codec_cs8409 ..."

# 4. Recharger le driver manuellement
sudo modprobe -r snd_hda_codec_cs8409
sudo modprobe snd_hda_codec_cs8409

# 5. Si ça ne fonctionne pas, reboot
sudo systemctl reboot
```

---

## Résumé de la situation

### Problème
- **iMac 18,2 (2019)** avec codec **Cirrus Logic CS8409** (Subsystem ID: 0x106b0f00)
- **Les haut-parleurs internes ne fonctionnent pas**
- Le casque fonctionne correctement
- Le driver natif du kernel ne supporte pas les GPIOs nécessaires pour activer l'amplificateur

### Solution appliquée - Session 2 (2025-11-19 18:00-18:30)
1. ✅ Rebase vers **Bazzite 42** (kernel 6.16.4-116.bazzite.fc42.x86_64) - VÉRIFIÉ
2. ✅ Driver **egorenar/snd-hda-codec-cs8409** compilé avec succès (1.9M)
3. ✅ Driver installé dans `/usr/local/lib/modules/6.16.4-116.bazzite.fc42.x86_64/extra/`
4. ✅ Configuration modprobe créée `/etc/modprobe.d/imac-cs8409.conf`
5. ✅ Service systemd créé et activé `load-cs8409-driver.service`
6. ✅ Reboot effectué

### Solution appliquée - Session 3 (2025-11-19 19:30-19:45) - DIAGNOSTIC CRUCIAL

**Problème découvert après reboot 3:**
- ✅ Le driver externe (192KB) a été chargé avec succès
- ❌ **Les GPIOs étaient désactivés** (GPIO1 et GPIO2 enable=0)
- ❌ Pas de son des haut-parleurs internes

**Cause racine identifiée:**
Le driver **natif** du kernel se chargeait EN PREMIER au boot et initialisait le codec avec les GPIOs désactivés. Notre driver externe se chargeait ensuite mais ne prenait pas le contrôle des GPIOs.

**Solution appliquée:**
1. ✅ **Blacklisté le driver natif** : `/etc/modprobe.d/blacklist-cs8409-native.conf`
   ```
   blacklist snd-hda-codec-cs8409
   ```
2. ✅ Le service systemd reste en place et chargera uniquement notre driver externe

**Résultat attendu au prochain reboot (Reboot 4):**
- Le driver natif ne se chargera plus (blacklisté)
- Notre driver externe se chargera EN PREMIER
- Les GPIOs seront activés (GPIO1 et GPIO2 enable=1)
- Les haut-parleurs devraient fonctionner

**Vérifications à faire après Reboot 4:**
```bash
# 1. Vérifier qu'aucun driver natif n'est chargé
lsmod | grep snd_hda_codec_cs8409
# Doit afficher ~192KB (driver externe), PAS 40K (natif)

# 2. Vérifier les GPIOs (CRITIQUE!)
cat /proc/asound/card0/codec#0 | grep -A 10 "GPIO:"
# GPIO1 et GPIO2 doivent avoir enable=1, dir=1, data=1

# 3. Tester le son
speaker-test -c 2 -t wav -l 1
```

---

## ⚠️ IMPORTANT - Spécificités Bazzite/OSTree

Bazzite utilise **rpm-ostree**, ce qui signifie que `/lib/modules/` est en **lecture seule**.

### Solution mise en place (Session 2)

1. **Installation du driver dans un emplacement modifiable:**
   ```
   /usr/local/lib/modules/6.16.4-116.bazzite.fc42.x86_64/extra/snd-hda-codec-cs8409.ko
   ```

2. **Service systemd pour charger le driver au boot:**
   - Fichier: `/etc/systemd/system/load-cs8409-driver.service`
   - Statut: Activé (`systemctl enable`)
   - Fonction: Décharge le driver natif et charge notre driver externe

3. **Configuration modprobe:**
   - Fichier: `/etc/modprobe.d/imac-cs8409.conf`
   - Options simplifiées pour le driver externe

### Vérifications à faire APRÈS LE PROCHAIN REBOOT

```bash
# 1. Vérifier que le service s'est bien exécuté
sudo systemctl status load-cs8409-driver.service

# 2. Vérifier que le bon driver est chargé (doit être 1.9M, pas 40K)
modinfo snd_hda_codec_cs8409 | grep -E "filename|vermagic"

# 3. Vérifier la taille du module chargé
lsmod | grep snd_hda_codec_cs8409

# 4. Tester immédiatement le son
speaker-test -c 2 -t wav -D hw:0,0 -l 1
```

### Fichiers créés dans Session 2 (pour référence)

1. **Driver compilé:**
   - Source: `~/snd-hda-codec-cs8409/snd-hda-codec-cs8409.ko` (1.9M)
   - Installation: `/usr/local/lib/modules/6.16.4-116.bazzite.fc42.x86_64/extra/snd-hda-codec-cs8409.ko`

2. **Configuration modprobe:**
   - Fichier: `/etc/modprobe.d/imac-cs8409.conf`
   - Contenu:
     ```
     options snd-hda-intel model=auto
     options snd-hda-intel index=0,1
     options snd-hda-intel power_save=0
     ```

3. **Service systemd:**
   - Fichier: `/etc/systemd/system/load-cs8409-driver.service`
   - Statut: Activé (lien créé dans `/etc/systemd/system/sysinit.target.wants/`)
   - Le service décharge le driver natif et charge notre driver externe avec `insmod`

4. **Configuration modules-load (optionnel):**
   - Fichier: `/etc/modules-load.d/cs8409.conf`
   - Contenu: `snd-hda-codec-cs8409`

### Fichiers créés dans Session 3 (pour référence)

1. **Blacklist du driver natif (CRUCIAL):**
   - Fichier: `/etc/modprobe.d/blacklist-cs8409-native.conf`
   - Contenu:
     ```
     # Blacklist native CS8409 driver to use external driver instead
     blacklist snd-hda-codec-cs8409
     ```
   - **Fonction:** Empêche le driver natif du kernel de se charger, permettant à notre driver externe de prendre le contrôle des GPIOs dès le boot

### Modifications effectuées dans Session 5 (pour référence)

1. **Correction du contexte SELinux (CRITIQUE):**
   - Commande: `sudo chcon -t modules_object_t /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko`
   - **Fonction:** Permet au système de charger le module externe (sinon "Permission denied")
   - ⚠️ **IMPORTANT:** À refaire après chaque recompilation du driver !

2. **Mise à jour du service systemd (V1 - obsolète, voir Session 6):**
   - Fichier: `/etc/systemd/system/load-cs8409-driver.service`
   - **Modification:** Ajout de `ExecStartPre=-/usr/sbin/modprobe -r snd_hda_codec_cs8409`
   - **Fonction:** Décharge le driver natif avant de charger notre driver externe
   - ⚠️ **Problème:** Ne chargeait pas les dépendances audio avant insmod

### Modifications effectuées dans Session 6 (pour référence) - VERSION ACTUELLE

1. **Mise à jour du service systemd (V2 - VERSION ACTUELLE):**
   - Fichier: `/etc/systemd/system/load-cs8409-driver.service`
   - **Modification:** Ajout du chargement des dépendances AVANT insmod
   - **Fonction:** Résout les symboles manquants en chargeant les modules audio de base d'abord
   - ⚠️ **CRITIQUE:** Cette version est nécessaire pour que insmod puisse résoudre les symboles
   - Fichier complet:
     ```
     [Unit]
     Description=Load custom CS8409 audio driver
     DefaultDependencies=no
     Before=sound.target
     After=systemd-modules-load.service

     [Service]
     Type=oneshot
     # Load audio dependencies first
     ExecStartPre=-/usr/sbin/modprobe snd_hda_core
     ExecStartPre=-/usr/sbin/modprobe snd_hda_codec
     ExecStartPre=-/usr/sbin/modprobe snd_hda_codec_generic
     # Prevent native driver from loading
     ExecStartPre=-/usr/sbin/modprobe -r snd_hda_codec_cs8409
     # Load our custom driver
     ExecStart=/usr/sbin/insmod /usr/local/lib/modules/6.16.4-116.bazzite.fc42.x86_64/extra/snd-hda-codec-cs8409.ko
     RemainAfterExit=yes

     [Install]
     WantedBy=sysinit.target
     ```

---

## ÉTAPES POST-REBOOT (ANCIENNES - déjà effectuées dans Session 2)

### 1. Vérifier le kernel

```bash
uname -r
```

**Résultat attendu:** 6.16.x (pas 6.17.x)

Si le kernel est toujours 6.17.x:
- Vérifier les déploiements: `rpm-ostree status`
- Le système devrait avoir booté sur l'index 0 (Bazzite 42)
- Si besoin, sélectionner manuellement depuis GRUB au prochain boot

### 2. Vérifier que le répertoire du driver existe

```bash
ls -la ~/snd-hda-codec-cs8409/
```

Le répertoire devrait contenir les fichiers source du driver.

### 3. Compiler le driver CS8409

```bash
cd ~/snd-hda-codec-cs8409
make clean
make
```

**Important:** Avec kernel 6.16.x, la compilation devrait **réussir** sans erreurs.

Si erreurs de compilation:
- Vérifier la version du kernel: `uname -r`
- Vérifier que gcc et kernel-devel sont installés: `rpm -qa | grep -E "gcc|kernel-devel"`

### 4. Installer le driver

```bash
cd ~/snd-hda-codec-cs8409
sudo make install
```

Cela va copier le module compilé dans `/lib/modules/$(uname -r)/extra/`

### 5. Vérifier que le module est installé

```bash
find /lib/modules/$(uname -r) -name "*cs8409*"
```

Devrait afficher le chemin vers `snd-hda-codec-cs8409.ko`

### 6. Nettoyer les anciennes configurations modprobe

Le fichier `/etc/modprobe.d/imac-cs8409.conf` contient des paramètres GPIO qui ne fonctionnent pas avec le driver natif. Avec le driver externe, on peut utiliser une configuration plus simple:

```bash
sudo tee /etc/modprobe.d/imac-cs8409.conf <<'EOF'
# Configuration pour iMac 18,2 avec driver externe CS8409
# Le driver externe gère automatiquement les GPIOs

options snd-hda-intel model=auto
options snd-hda-intel index=0,1
options snd-hda-intel power_save=0
EOF
```

### 7. Recharger les modules audio

```bash
# Décharger les modules actuels
sudo modprobe -r snd_hda_codec_cs8409
sudo modprobe -r snd_hda_intel

# Recharger avec le nouveau driver
sudo modprobe snd_hda_intel
sudo modprobe snd_hda_codec_cs8409
```

OU simplement **reboot** pour appliquer le nouveau driver:

```bash
sudo systemctl reboot
```

### 8. Vérifier que le bon driver est chargé

```bash
modinfo snd_hda_codec_cs8409
```

Vérifier le champ **filename:** - il devrait pointer vers `/lib/modules/.../extra/snd-hda-codec-cs8409.ko` (le driver externe)

### 9. Tester le son

```bash
# Test simple
speaker-test -c 2 -t wav -D hw:0,0 -l 1

# Vérifier les périphériques
aplay -l
pactl list sinks short

# Ajuster le volume si nécessaire
alsamixer
pactl set-sink-volume @DEFAULT_SINK@ 100%
```

### 10. Vérifier les mixers ALSA

```bash
amixer -c 0 contents | grep -A 3 "Speaker"
```

S'assurer que les contrôles Speaker ne sont pas en mute:

```bash
amixer -c 0 set 'Speaker Front' unmute
amixer -c 0 set 'Speaker Surround' unmute
amixer -c 0 set PCM unmute 100%
```

---

## Troubleshooting

### Le service systemd ne charge pas le driver

**Vérifier le statut du service:**
```bash
sudo systemctl status load-cs8409-driver.service
sudo journalctl -u load-cs8409-driver.service
```

**Si le service a échoué:**
```bash
# Charger manuellement le driver
sudo insmod /usr/local/lib/modules/6.16.4-116.bazzite.fc42.x86_64/extra/snd-hda-codec-cs8409.ko

# Vérifier les erreurs
dmesg | grep -i cs8409 | tail -20
```

**Si "module not found":**
```bash
# Vérifier que le fichier existe
ls -lh /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko

# Si manquant, recompiler et réinstaller
cd ~/snd-hda-codec-cs8409
make clean && make
sudo mkdir -p /usr/local/lib/modules/$(uname -r)/extra/
sudo cp snd-hda-codec-cs8409.ko /usr/local/lib/modules/$(uname -r)/extra/
```

### Le service échoue avec "Permission denied" (Session 5)

**Symptôme:** Le service systemd échoue avec:
```
insmod: ERROR: could not insert module ... Permission denied
```

**Cause:** Contexte SELinux incorrect sur le fichier .ko

**Solution:**
```bash
# Vérifier le contexte actuel
ls -lZ /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko

# Si le contexte est "lib_t", le corriger en "modules_object_t"
sudo chcon -t modules_object_t /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko

# Vérifier que le contexte est maintenant correct
ls -lZ /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko
# Doit afficher: ... modules_object_t:s0 ...

# Essayer de charger manuellement
sudo insmod /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko

# Redémarrer le service
sudo systemctl restart load-cs8409-driver.service
```

**Note:** Ce contexte SELinux doit être corrigé après chaque compilation du driver.

### Le codec est "Cirrus Logic Generic" au lieu d'Apple et les GPIOs sont désactivés (Session 6)

**Symptôme:** Après le boot, le codec est détecté comme "Cirrus Logic Generic" et les GPIOs 1 et 2 sont enable=0

**Diagnostic:**
```bash
# Vérifier le nom du codec
cat /proc/asound/card0/codec#0 | head -5

# Vérifier les logs pour erreurs de symboles
sudo dmesg | grep "Unknown symbol" | grep cs8409
```

**Cause:** Erreurs "Unknown symbol" dans les logs - le service systemd charge le driver avec `insmod` avant que les modules de dépendances ne soient disponibles.

**Solution:**
Le service systemd doit charger les modules audio de base AVANT notre driver. Vérifier que `/etc/systemd/system/load-cs8409-driver.service` contient :

```bash
[Service]
Type=oneshot
# Load audio dependencies first (CRITIQUE!)
ExecStartPre=-/usr/sbin/modprobe snd_hda_core
ExecStartPre=-/usr/sbin/modprobe snd_hda_codec
ExecStartPre=-/usr/sbin/modprobe snd_hda_codec_generic
# Prevent native driver from loading
ExecStartPre=-/usr/sbin/modprobe -r snd_hda_codec_cs8409
# Load our custom driver
ExecStart=/usr/sbin/insmod /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko
```

Si le fichier n'est pas correct:
```bash
# Copier le service mis à jour (voir Section "Modifications effectuées dans Session 6")
sudo systemctl daemon-reload
sudo systemctl restart load-cs8409-driver.service
# Reboot nécessaire pour réinitialiser le codec
sudo systemctl reboot
```

### Le driver natif est toujours chargé (40K au lieu de 1.9M)

**Vérifier quel driver est chargé:**
```bash
lsmod | grep snd_hda_codec_cs8409
# Si la taille est ~40K, c'est le driver natif
```

**Forcer le chargement du driver externe:**
```bash
# Décharger tous les modules audio
sudo modprobe -r snd_hda_codec_hdmi
sudo modprobe -r snd_hda_codec_cs8409
sudo modprobe -r snd_hda_intel

# Charger le driver externe
sudo insmod /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko

# Recharger les autres modules
sudo modprobe snd_hda_intel
```

### Le driver ne compile toujours pas

**Vérifier le kernel:**
```bash
uname -r
# Doit être 6.16.x, PAS 6.17.x
```

**Vérifier les outils de compilation:**
```bash
rpm -qa | grep kernel-devel
rpm -qa | grep gcc
```

Si manquants, les installer:
```bash
sudo rpm-ostree install kernel-devel gcc make
sudo systemctl reboot
```

### Le son ne fonctionne toujours pas après installation

1. **Vérifier les logs kernel:**
```bash
sudo journalctl -k | grep -i "cs8409\|hda" | tail -50
```

2. **Vérifier que le driver externe est bien chargé:**
```bash
modinfo snd_hda_codec_cs8409 | grep filename
# Doit pointer vers /lib/modules/.../extra/
```

3. **Vérifier le codec:**
```bash
cat /proc/asound/PCH/codec#0 | head -20
```

4. **Test avec le script GPIO interactif:**
```bash
~/test-gpio-audio.sh
```

### Le système ne boote pas sur Bazzite 42

Au démarrage, dans GRUB:
1. Sélectionner "Fedora Linux 42..."
2. Le système devrait booter sur le kernel 6.16.x

Ou forcer depuis le système actuel:
```bash
rpm-ostree status
# Noter l'index du déploiement Bazzite 42
sudo rpm-ostree deploy <index>
sudo systemctl reboot
```

---

## Informations système de référence

### Modèle
- **iMac 18,2 (2019)**
- **Subsystem ID:** 0x106b0f00

### Codec Audio
- **Cirrus Logic CS8409**
- **Vendor ID:** 0x10138409

### Driver
- **Externe:** https://github.com/egorenar/snd-hda-codec-cs8409
- **Location locale:** `~/snd-hda-codec-cs8409`

### GPIOs identifiés (d'après le code source)
- **GPIO1:** Speaker Power Down (WARLOCK)
- **GPIO2:** Speaker Power Down (CYBORG)
- **GPIO4:** CS42L42 Interrupt
- **GPIO5:** CS42L42 Reset

Le driver externe gère automatiquement ces GPIOs.

---

## Commandes de diagnostic rapide

```bash
# Version kernel
uname -r

# Modules chargés
lsmod | grep snd_hda

# Driver info
modinfo snd_hda_codec_cs8409

# Codec details
cat /proc/asound/PCH/codec#0 | head -30

# Périphériques audio
aplay -l

# Test son
speaker-test -c 2 -t wav -D hw:0,0 -l 1

# Logs
sudo journalctl -k | grep -i cs8409
```

---

## Si tout fonctionne

### Rendre le changement permanent

Le driver est installé dans `/usr/local/lib/modules/`, mais après une mise à jour du kernel, il faudra le recompiler.

**⚠️ IMPORTANT pour Bazzite/OSTree:**

Le service systemd `load-cs8409-driver.service` utilise un chemin codé en dur avec la version du kernel:
```
/usr/local/lib/modules/6.16.4-116.bazzite.fc42.x86_64/extra/snd-hda-codec-cs8409.ko
```

Si vous mettez à jour vers un nouveau kernel, vous devrez:
1. Recompiler le driver
2. Copier le `.ko` dans le nouveau chemin `/usr/local/lib/modules/NOUVEAU_KERNEL/extra/`
3. **CRITIQUE:** Corriger le contexte SELinux: `sudo chcon -t modules_object_t /usr/local/lib/modules/NOUVEAU_KERNEL/extra/snd-hda-codec-cs8409.ko`
4. Mettre à jour le chemin dans `/etc/systemd/system/load-cs8409-driver.service`
5. Recharger systemd: `sudo systemctl daemon-reload`

**Option 1: Pin le déploiement actuel (RECOMMANDÉ)**
```bash
sudo ostree admin pin 0
```

Cela garde Bazzite 42 comme option de boot même après les mises à jour. Vous pourrez toujours tester les nouvelles versions, mais Bazzite 42 restera disponible avec votre driver fonctionnel.

**Option 2: Créer un script de recompilation automatique**

Après chaque mise à jour de kernel, exécuter:
```bash
cd ~/snd-hda-codec-cs8409
make clean && make
sudo mkdir -p /usr/local/lib/modules/$(uname -r)/extra/
sudo cp snd-hda-codec-cs8409.ko /usr/local/lib/modules/$(uname -r)/extra/
# CRITIQUE: Corriger le contexte SELinux (sinon Permission denied!)
sudo chcon -t modules_object_t /usr/local/lib/modules/$(uname -r)/extra/snd-hda-codec-cs8409.ko
# Mettre à jour le service systemd avec le nouveau chemin
sudo sed -i "s|/usr/local/lib/modules/.*/extra/|/usr/local/lib/modules/$(uname -r)/extra/|" /etc/systemd/system/load-cs8409-driver.service
sudo systemctl daemon-reload
sudo systemctl restart load-cs8409-driver.service
```

**Option 3: DKMS (À explorer - plus complexe sur OSTree)**

Pour recompiler automatiquement après chaque mise à jour du kernel, DKMS pourrait être une solution, mais c'est plus complexe sur les systèmes OSTree comme Bazzite.

### Nettoyer les anciens fichiers

Une fois que tout fonctionne, vous pouvez nettoyer:
```bash
# Garder ces fichiers pour référence:
# - ~/snd-hda-codec-cs8409/ (source du driver)
# - ~/AUDIO_DIAGNOSTIC_RAPPORT.md (diagnostic complet)
# - ~/POST_REBOOT_AUDIO_FIX.md (ce fichier)

# Fichiers à supprimer si vous voulez:
# - ~/fix-imac-audio.sh (ancien script non fonctionnel)
# - ~/fix-imac-audio-v2.sh (ancien script non fonctionnel)
# - ~/IMAC_AUDIO_FIX.md (ancienne doc)
# - ~/IMAC_AUDIO_FIX_V2.md (ancienne doc)
```

---

## Commande complète pour post-reboot

Après le reboot, exécuter cette séquence:

```bash
# 1. Vérifier le kernel
echo "Kernel version:"
uname -r

# 2. Compiler et installer le driver
cd ~/snd-hda-codec-cs8409
make clean && make && sudo make install

# 3. Configurer modprobe
sudo tee /etc/modprobe.d/imac-cs8409.conf <<'EOF'
options snd-hda-intel model=auto
options snd-hda-intel index=0,1
options snd-hda-intel power_save=0
EOF

# 4. Reboot
echo "Installation terminée. Reboot maintenant avec: sudo systemctl reboot"
```

Après le 2e reboot:
```bash
# Tester le son
speaker-test -c 2 -t wav -D hw:0,0 -l 1
```

---

## 📋 Récapitulatif des sessions

### Session 1 (avant le premier reboot)
- Diagnostic complet du problème audio
- Identification du codec CS8409 et du besoin d'un driver externe
- Téléchargement du code source depuis GitHub
- Rebase vers Bazzite 42 (kernel 6.16.x compatible)

### Session 2 (2025-11-19 18:00-18:30)
- ✅ Vérification du kernel: 6.16.4-116.bazzite.fc42.x86_64
- ✅ Compilation réussie du driver (1.9M)
- ✅ Installation dans `/usr/local/lib/modules/` (contournement OSTree)
- ✅ Création du service systemd `load-cs8409-driver.service`
- ✅ Configuration de modprobe
- ⏳ Prêt pour le reboot

### Session 3 (2025-11-19 19:30-19:45) - DIAGNOSTIC DES GPIOs
- ✅ Vérification après reboot 3
- ✅ Driver externe chargé (192KB) mais GPIOs désactivés
- ✅ **Diagnostic crucial:** Le driver natif s'initialisait en premier et bloquait les GPIOs
- ✅ **Solution:** Blacklisté le driver natif (`/etc/modprobe.d/blacklist-cs8409-native.conf`)
- ⏳ Prêt pour reboot 4

### Session 4 (2025-11-19 19:00-19:15) - MODIFICATION DU DRIVER POUR ACTIVER LES GPIOs
- ✅ **Problème identifié:** Le driver chargeait le codec générique, pas les fixups Apple
- ✅ **Modifications apportées:**
  1. Activé APPLE_FIXUPS dans le Makefile
  2. Décommenté le support iMac 18,2 (0x106b0f00) dans `patch_cirrus_apple.h`
  3. Modifié `cs_8409_apple_fixup_gpio` pour configurer GPIO1+GPIO2 (mask=0x06, dir=0x06, data=0x06)
  4. Décommenté le code d'application des GPIOs dans `cs_8409_apple_init`
  5. Décommenté l'appel à `snd_hda_pick_fixup` et `snd_hda_apply_fixup` dans `patch_cs8409_apple`
  6. Corrigé les types de structure (hda_quirk au lieu de snd_pci_quirk)
- ✅ Driver recompilé avec succès (192KB)
- ⚠️ **Découverte:** Le système charge le driver NATIF depuis `/lib/modules/.../kernel/` au lieu de notre driver externe
- 🔄 **Solution:** Reboot nécessaire pour que la blacklist prenne effet et force le chargement de notre driver modifié
- ⏳ Prêt pour reboot 5

### Session 5 (2025-11-20 07:30-07:40) - DIAGNOSTIC SELINUX ET PRIORITÉ DES DRIVERS
- ✅ **Vérification après reboot 5**
- ❌ **Problème critique 1:** Le service systemd a échoué avec "Permission denied"
  - **Cause:** Contexte SELinux incorrect (`lib_t` au lieu de `modules_object_t`)
  - **Solution:** `sudo chcon -t modules_object_t /usr/local/lib/modules/.../extra/snd-hda-codec-cs8409.ko`
- ❌ **Problème critique 2:** Le driver NATIF se chargeait toujours au lieu du driver externe
  - **Cause:** Le driver natif dans `/lib/modules/.../kernel/` est prioritaire sur notre driver dans `/usr/local/lib/modules/.../extra/`
  - **Diagnostic:** `modinfo snd_hda_codec_cs8409` montrait `/lib/modules/.../kernel/...` au lieu de notre driver
  - GPIOs toujours désactivés (GPIO1 et GPIO2 enable=0)
- ✅ **Solution 1:** Chargement manuel du driver externe réussi après correction SELinux
  - Module chargé: 192KB (confirme driver externe)
  - Mais `modinfo` montrait toujours le driver natif car il est dans le path prioritaire
- ✅ **Solution 2:** Mise à jour du service systemd pour décharger le driver natif:
  ```
  ExecStartPre=-/usr/sbin/modprobe -r snd_hda_codec_cs8409
  ```
- ⚠️ **Contrainte OSTree:** Impossible de modifier `/lib/modules` (lecture seule)
- 🔄 **Solution finale:** Reboot nécessaire pour que:
  1. Le contexte SELinux soit appliqué dès le boot
  2. La blacklist empêche le chargement du driver natif
  3. Le service systemd mis à jour charge notre driver en premier
- ⏳ Prêt pour reboot 6

### Session 6 (2025-11-20 07:50-08:00) - DIAGNOSTIC SYMBOLES MANQUANTS ET DÉPENDANCES
- ✅ **Vérification après reboot 6**
- ✅ Service systemd a réussi (code 0/SUCCESS)
- ❌ **Problème critique:** Codec toujours détecté comme "Cirrus Logic Generic" au lieu d'Apple
- ❌ **GPIOs toujours désactivés:** GPIO1 et GPIO2 enable=0, dir=0, data=0
- ✅ **Cause identifiée:** Erreurs "Unknown symbol" dans les logs kernel
  - Le service systemd utilisait `insmod` qui ne résout pas les dépendances automatiquement
  - Les modules audio de base (snd_hda_codec, snd_hda_codec_generic) n'étaient pas chargés avant notre driver
  - Le système a utilisé le driver générique au lieu de notre driver CS8409
- ✅ **Diagnostic:**
  - Module chargé : 192KB (confirme driver externe)
  - `modinfo` pointe vers driver natif (path prioritaire)
  - Symboles audio exportés et disponibles dans /proc/kallsyms
  - Mais `insmod` ne peut pas les résoudre sans modules chargés d'abord
- ✅ **Solution appliquée:** Mise à jour du service systemd
  ```
  ExecStartPre=-/usr/sbin/modprobe snd_hda_core
  ExecStartPre=-/usr/sbin/modprobe snd_hda_codec
  ExecStartPre=-/usr/sbin/modprobe snd_hda_codec_generic
  ExecStartPre=-/usr/sbin/modprobe -r snd_hda_codec_cs8409
  ExecStart=/usr/sbin/insmod /usr/local/lib/modules/.../snd-hda-codec-cs8409.ko
  ```
- ⏳ Prêt pour reboot 7

### Session 7 (2025-11-20 08:05-08:45) - CAUSE RACINE IDENTIFIÉE ET CORRIGÉE!
- ✅ **Vérification après reboot 7**
- ✅ Service systemd a réussi avec toutes les dépendances chargées
- ✅ Aucune erreur "Unknown symbol" dans les logs
- ❌ **PROBLÈME CRITIQUE:** Codec toujours "Cirrus Logic Generic" au lieu d'Apple
- ❌ **GPIOs toujours désactivés:** GPIO1 et GPIO2 enable=0
- ✅ **EUREKA - CAUSE RACINE IDENTIFIÉE:**
  - Le driver externe (192KB) était bien chargé en mémoire
  - MAIS la fonction `patch_cs8409_apple` n'était **JAMAIS appelée**!
  - Raison: La table `cs8409_fixup_tbl` ne contenait QUE des machines **DELL** (vendor 0x1028)
  - Notre **iMac** a le vendor **0x106b** (Apple), donc aucun match trouvé
  - Le driver utilisait le codec générique par défaut sans appliquer les fixups Apple
- ✅ **SOLUTION FINALE appliquée:**
  1. Modifié `patch_cs8409.c` pour détecter le vendor Apple (0x106b) AVANT la recherche de fixup
  2. Ajouté un appel direct à `patch_cs8409_apple` pour toutes les machines Apple
  3. Ajouté des messages de debug pour tracer l'initialisation
  4. Driver recompilé (1.9M)
  5. Copié dans `/usr/local/lib/modules/.../extra/`
  6. Contexte SELinux corrigé
- 🔄 **Reboot nécessaire:** Le codec doit être réinitialisé depuis le début avec le bon driver
- ⏳ Prêt pour reboot 8

**Code modifié dans patch_cs8409.c:**
```c
// Check if this is an Apple machine (vendor 0x106b)
// Apple machines use the CS8409 but need different initialization
if (codec->bus->pci->subsystem_vendor == 0x106b) {
    printk("snd_hda_intel: Detected Apple machine, using patch_cs8409_apple\n");
    cs8409_free(codec);
    err = patch_cs8409_apple(codec);
    return err;
}
```

### Session 8 (2025-11-20 08:50-09:00) - DIAGNOSTIC DU CHARGEMENT DU DRIVER
- ✅ **Vérification après reboot 8**
- ✅ Service systemd a réussi (tous les processus status=0/SUCCESS)
- ❌ **PROBLÈME MAJEUR:** Codec toujours "Cirrus Logic Generic", GPIOs 1 et 2 toujours enable=0
- ❌ **Aucun message "Detected Apple machine" dans les logs** - la fonction patch_cs8409 n'a jamais été appelée!
- ✅ **CAUSE IDENTIFIÉE:**
  - Le driver externe (192KB) était chargé en mémoire
  - MAIS le codec était déjà initialisé par `snd_hda_codec_generic` au boot (9.7 secondes)
  - Le service systemd chargeait notre driver trop tard (après l'initialisation du codec)
  - Raison: L'alias `hdaudio:v10138409r*a01* snd_hda_codec_cs8409` charge automatiquement le module
  - La blacklist empêchait le natif, donc le système utilisait le driver générique comme fallback
  - Notre driver se chargeait après mais ne prenait jamais le contrôle du codec
- ✅ **SOLUTION APPLIQUÉE:**
  1. Créé `/etc/modprobe.d/cs8409-custom-driver.conf` avec directive `install`:
     ```
     install snd_hda_codec_cs8409 /usr/sbin/modprobe --ignore-install snd_hda_core; /usr/sbin/modprobe --ignore-install snd_hda_codec; /usr/sbin/modprobe --ignore-install snd_hda_codec_generic; /usr/sbin/insmod /usr/local/lib/modules/6.16.4-116.bazzite.fc42.x86_64/extra/snd-hda-codec-cs8409.ko
     ```
  2. Supprimé `/etc/modprobe.d/blacklist-cs8409-native.conf` (plus nécessaire)
  3. Désactivé `load-cs8409-driver.service` (remplacé par la directive install)
- **Fonctionnement attendu:**
  - Le système détecte le codec au boot
  - L'alias déclenche le chargement de `snd_hda_codec_cs8409`
  - La directive `install` intercepte et charge notre driver custom au lieu du natif
  - Notre driver s'initialise avec le code Apple DÈS la détection du codec
- ⏳ Prêt pour reboot 9

### Session 9 (2025-11-20 08:55-09:00) - DIAGNOSTIC BLACKLIST ET DIRECTIVE INSTALL
- ✅ **Vérification après reboot 9**
- ❌ **PROBLÈME CRITIQUE:** Le driver CS8409 n'était PAS chargé au boot
  - Aucun module `snd_hda_codec_cs8409` dans `lsmod`
  - Le système utilisait `snd_hda_codec_generic` à la place
  - Codec toujours détecté comme "Cirrus Logic Generic"
  - GPIOs 1 et 2 toujours désactivés (enable=0)
- ✅ **CAUSE IDENTIFIÉE:** Conflit entre blacklist et directive `install`
  - La blacklist `/etc/modprobe.d/blacklist-cs8409.conf` empêchait complètement le chargement du module
  - La directive `install` dans `/etc/modprobe.d/cs8409-custom-driver.conf` n'était JAMAIS appelée
  - Raison: La directive `install` ne s'applique QUE si le système essaie de charger le module via modprobe
  - Avec la blacklist, le système n'essayait jamais de charger le module, donc utilisait le fallback générique
- ✅ **SOLUTION APPLIQUÉE:**
  - Supprimé `/etc/modprobe.d/blacklist-cs8409.conf`
  - Gardé la directive `install` qui interceptera maintenant le chargement
  - Configuration active:
    ```
    install snd_hda_codec_cs8409 /usr/sbin/modprobe --ignore-install snd_hda_core; /usr/sbin/modprobe --ignore-install snd_hda_codec; /usr/sbin/modprobe --ignore-install snd_hda_codec_generic; /usr/sbin/insmod /usr/local/lib/modules/6.16.4-116.bazzite.fc42.x86_64/extra/snd-hda-codec-cs8409.ko
    ```
- ✅ **TEST MANUEL RÉUSSI:**
  - Chargement manuel avec `modprobe snd_hda_codec_cs8409` a fonctionné
  - Driver custom chargé: 192KB (confirmé dans lsmod)
  - Mais codec déjà initialisé avec driver générique, reboot nécessaire
- **Fonctionnement attendu au prochain boot:**
  1. Système détecte le codec CS8409
  2. Alias `hdaudio:v10138409r*a01*` déclenche chargement de `snd_hda_codec_cs8409`
  3. Directive `install` intercepte et charge notre driver custom via insmod
  4. Notre driver initialise le codec avec les fixups Apple
  5. GPIOs activés, son fonctionnel
- ⏳ Prêt pour reboot 10

### Session 10 (2025-11-20 10:00-10:45) - DÉCOUVERTE PROBLÈME DEPMOD SUR OSTREE
- ✅ **Vérification après reboot 10**
- ❌ **PROBLÈME CRITIQUE:** Le codec était toujours "Cirrus Logic Generic", GPIOs désactivés
- ✅ **Driver custom chargé en mémoire** (192KB confirmé dans lsmod)
- ❌ **MAIS le driver NATIF était prioritaire** (modinfo montrait toujours /lib/modules/.../kernel/...)
- ✅ **Logs montrent:** Le fichier custom n'était pas trouvé au boot initial, puis module inséré mais version native utilisée
- ✅ **CAUSE RACINE IDENTIFIÉE:** Sur OSTree, `/lib/modules` est en lecture seule
  - Impossible d'exécuter `depmod -a` (erreurs "Read-only file system")
  - Le système utilise toujours les dépendances pré-calculées qui pointent vers le driver natif
  - Notre driver dans `/usr/local/lib/modules/` n'est jamais considéré comme prioritaire
- ✅ **SOLUTION TROUVÉE via recherche web:**
  - Créé `/etc/depmod.d/cs8409-override.conf` avec directive `override`
  - Créé `/etc/depmod.d/cs8409-search-path.conf` avec directive `search` incluant `/usr/local/lib/modules/`
  - Ces fichiers seront lus au boot pour prioriser notre driver
- ✅ **Recherches effectuées:**
  - rpm-ostree et modules custom sur systèmes immutables
  - akmods sur Bazzite/Silverblue
  - depmod override et search directives
- 🔄 **Reboot nécessaire:** Les configs depmod.d doivent être appliquées au boot
- ⏳ Prêt pour reboot 11

### Session 11 (2025-11-20 13:40-13:50) - VRAIE CAUSE RACINE IDENTIFIÉE: /usr/local TIMING!
- ✅ **Vérification après reboot 11**
- ✅ Driver custom chargé en mémoire (192KB)
- ❌ **PROBLÈME:** Codec toujours "Cirrus Logic Generic", GPIOs 1 et 2 désactivés (enable=0)
- ❌ `modinfo` pointait toujours vers le driver natif (depmod.d n'a PAS fonctionné)
- ✅ **DÉCOUVERTE CRITIQUE dans les logs journalctl:**
  - `13:40:10` : `insmod: ERROR: could not load module /usr/local/lib/modules/.../snd-hda-codec-cs8409.ko: No such file or directory`
  - La directive `install` dans modprobe.d a été exécutée mais le fichier n'était PAS TROUVÉ au boot!
  - Le système a ensuite chargé le driver natif comme fallback
- ✅ **VRAIE CAUSE RACINE IDENTIFIÉE:**
  - `/usr/local` est un **symlink** vers `../var/usrlocal` sur OSTree
  - `/var/usrlocal` est créé dynamiquement par `systemd-tmpfiles` APRÈS le boot
  - `systemd-modules-load` s'exécute AVANT que `/var/usrlocal` soit disponible
  - Donc `/usr/local/lib/modules/.../snd-hda-codec-cs8409.ko` n'existe pas quand insmod essaie de le charger!
- ✅ **RECHERCHES WEB CONFIRMANT LE PROBLÈME:**
  - Sur OSTree, `/usr/local` pointe vers `/var/usrlocal` qui est créé par tmpfiles
  - Problème de timing documenté entre systemd-modules-load et /var
  - akmods ne fonctionne pas sur Bazzite (systèmes immutables)
  - depmod.d ne fonctionne pas car /lib/modules est lecture seule et pré-généré
- ✅ **SOLUTION FINALE appliquée:**
  1. Créé `/etc/kernel/drivers/` (disponible dès le début du boot, contrairement à /usr/local)
  2. Copié le driver: `sudo cp /usr/local/.../snd-hda-codec-cs8409.ko /etc/kernel/drivers/`
  3. Corrigé le contexte SELinux: `sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko`
  4. Mis à jour `/etc/modprobe.d/cs8409-custom-driver.conf` pour pointer vers `/etc/kernel/drivers/snd-hda-codec-cs8409.ko`
  5. Supprimé les configs depmod.d inutiles (ne fonctionnent pas sur OSTree)
- 🔄 **Reboot nécessaire:** Le codec doit être initialisé avec le driver custom dès le début
- ⏳ Prêt pour reboot 12

### Session 12 (2025-11-20 13:50-14:17) - BUG CRITIQUE TROUVÉ: GPIOS ÉCRASÉS PAR patch_cs8409_apple()
- ✅ **Vérification après reboot 12**
- ✅ Driver chargé avec succès depuis `/etc/kernel/drivers/` (192KB)
- ✅ Aucune erreur "No such file or directory" dans les logs
- ✅ Messages "Primary patch_cs8409" et "Detected Apple machine" présents
- ✅ Codec reconnu comme "Cirrus Logic CS8409/CS42L83" (pas Generic!)
- ✅ Subsystem ID correct: 0x106b0f00 (iMac 18,2)
- ❌ **PROBLÈME CRITIQUE DÉCOUVERT:** GPIOs avaient **enable=1** et **dir** correct MAIS **data=0** au lieu de **data=1**
- ❌ Pas de son des haut-parleurs (amplificateurs désactivés car data=0)

**ANALYSE DU CODE:**
- ✅ La fonction `cs_8409_apple_fixup_gpio` configurait correctement:
  - `spec->gpio_mask = 0x06` (GPIO1 + GPIO2)
  - `spec->gpio_dir = 0x06` (outputs)
  - `spec->gpio_data = 0x06` (high = amplis ON)
- ✅ La fonction `cs_8409_apple_init` appliquait ces valeurs au hardware
- ❌ **MAIS** la fonction `patch_cs8409_apple` (lignes 2614-2625) **ÉCRASAIT** ces valeurs APRÈS le fixup:
  - `spec->gpio_dir = spec->scodecs[CS8409_CODEC0]->reset_gpio;`
  - `spec->gpio_data = 0;` ← **VOILÀ LE BUG!**
  - `spec->gpio_mask = 0x0f;`
- Cette logique était conçue pour le reset GPIO du CS42L83, mais elle écrasait les GPIOs des amplificateurs speakers!

**CORRECTION APPLIQUÉE:**
1. ✅ Modifié `patch_cirrus_apple.h` ligne 2616 pour tester `if (spec->gpio_mask == 0)` avant d'écraser
2. ✅ Si gpio_mask est déjà configuré par le fixup, les valeurs sont préservées
3. ✅ Ajouté un message de debug pour confirmer: "GPIO already configured by fixup, keeping fixup values"
4. ✅ Driver recompilé avec succès (1.9M)
5. ✅ Copié dans `/etc/kernel/drivers/snd-hda-codec-cs8409.ko`
6. ✅ Contexte SELinux corrigé

**Code modifié dans patch_cirrus_apple.h:**
```c
// NOTE: DO NOT overwrite gpio_dir, gpio_data, gpio_mask if already set by fixup!
// The fixup cs_8409_apple_fixup_gpio sets these for iMac speaker amplifiers
if (spec->gpio_mask == 0) {
    spec->gpio_dir = spec->scodecs[CS8409_CODEC0]->reset_gpio;
    spec->gpio_data = 0;
    // ... (reste du code pour autres machines)
} else {
    myprintk("snd_hda_intel: GPIO already configured by fixup, keeping fixup values (mask=0x%x dir=0x%x data=0x%x)\n",
        spec->gpio_mask, spec->gpio_dir, spec->gpio_data);
}
```

**Résultat attendu au prochain reboot (Reboot 13):**
- Le driver se chargera depuis /etc/kernel/drivers/
- Le fixup configurera GPIO1 et GPIO2 avec data=0x06
- La fonction patch_cs8409_apple NE les écrasera PAS (gpio_mask != 0)
- cs_8409_apple_init appliquera les valeurs au hardware
- Les GPIOs auront enable=1, dir=1, **data=1** ← CRITIQUE!
- Les amplificateurs seront activés
- LE SON DEVRAIT FONCTIONNER!

🔄 **Reboot nécessaire:** Le codec doit être réinitialisé avec les GPIOs corrects
⏳ Prêt pour reboot 13

### Session 13 (2025-11-20 14:20-14:35) - DÉCOUVERTE: GPIOs ACTIVÉS MAIS PAS DE SON!
- ✅ **Vérification après reboot 13**
- ✅ Driver chargé depuis /etc/kernel/drivers/ (192KB)
- ✅ Codec reconnu comme "CS8409/CS42L83" (PAS Generic!)
- ✅ Logs montrent "CS8409: picked fixup for codec SSID 106b:0f00"
- ✅ **DÉCOUVERTE MAJEURE:** Les GPIOs sont maintenant CORRECTEMENT ACTIVÉS!
  - `cat /proc/asound/card*/codec#*` montre:
  - GPIO1: enable=1, dir=1, **data=1** ✅
  - GPIO2: enable=1, dir=1, **data=1** ✅
  - C'est exactement ce que nous voulions depuis le début!
- ❌ **PROBLÈME CRITIQUE:** Pas de son malgré les GPIOs activés
  - Test `speaker-test -c 2 -t wav -l 1` ne produit aucun son
  - L'utilisateur confirme: "j'ai rien entendu"
  - Le périphérique audio est détecté et configuré
  - Les volumes ALSA sont à 100% (PCM = 255/255)
  - PipeWire voit le sink: `alsa_output.pci-0000_00_1f.3.analog-stereo`
- ❌ **Fichier /proc/asound/card0/codec#0 apparaissait VIDE**
  - Mais `cat /proc/asound/card*/codec#*` fonctionne et montre tout le codec
  - Problème de syntaxe de commande, pas un vrai bug
- ❌ **PROBLÈME SECONDAIRE:** Aucun message myprintk() dans les logs
  - MYSOUNDDEBUG n'était pas activé dans le Makefile
  - Impossible de voir le flow d'initialisation du CS42L83
  - Impossible de voir si le fixup est appelé à toutes les phases

**ANALYSE DE LA SITUATION:**
- Les GPIOs contrôlent les amplificateurs speakers (ON maintenant)
- Mais le CS42L83 (le codec/amplificateur lui-même) doit être initialisé via I2C
- Le driver a une séquence `cs42l83_init_reg_seq` mais sans logs, impossible de savoir si elle s'exécute
- Recherches web confirment: le driver egorenar fonctionne pour beaucoup d'utilisateurs sur iMac 18,1 et similaires
- Kernel 6.16 a un support CS8409 amélioré mais nous utilisons le driver externe

- ✅ **SOLUTION APPLIQUÉE:**
  1. Modifié Makefile pour activer MYSOUNDDEBUG
  2. Ajouté -DMYSOUNDDEBUG et -DCONFIG_SND_DEBUG=1 aux CFLAGS
  3. Driver recompilé avec logs de debug (2.0M au lieu de 1.9M)
  4. Copié dans /etc/kernel/drivers/
  5. Contexte SELinux corrigé

- **Résultat attendu au prochain reboot (Reboot 14):**
  - Tous les messages myprintk() apparaîtront dans dmesg
  - Pourra voir l'initialisation complète du CS42L83 via I2C
  - Pourra voir si fixup est appelé à quelle phase (PRE_PROBE, PROBE, INIT, etc.)
  - Pourra diagnostiquer pourquoi le son ne fonctionne pas malgré GPIOs corrects
  - Pourra voir les séquences I2C envoyées au CS42L83

- 🔄 **Reboot nécessaire:** Pour voir les logs complets du chargement
- ⏳ Prêt pour reboot 14

**NOTE IMPORTANTE:** Les GPIOs sont maintenant corrects (data=1), ce qui est un ÉNORME progrès! Le problème est maintenant l'initialisation du CS42L83 lui-même, pas les GPIOs. Les logs de debug nous diront exactement ce qui manque.

### Session 14 (2025-11-20 14:40-15:30) - DÉCOUVERTE: SÉQUENCE I2C VIDE + DRIVER NATIF 6.16
- ✅ **Vérification après reboot 14**
- ✅ GPIOs toujours corrects (GPIO1 et GPIO2 avec enable=1, dir=1, **data=1**)
- ✅ Driver custom chargé depuis /etc/kernel/drivers/ (270KB)
- ✅ Codec reconnu comme "CS8409/CS42L83"
- ✅ Logs montrent initialisation complète: cs42l83_inithw start/end
- ❌ **PAS DE SON malgré tout correctement configuré**
- ✅ **CAUSE RACINE DÉCOUVERTE:**
  - Analyse du code source `patch_cirrus_apple.h` ligne 145-147
  - La séquence d'initialisation I2C est **VIDE**: `cs42l83_init_reg_seq[] = { //{ 0x0000, 0x00 }, };`
  - Le CS42L83 n'est jamais configuré avec les registres I2C pour activer les amplificateurs internes
  - C'est pourquoi GPIOs corrects mais pas de son!
- ✅ **SOLUTION TROUVÉE:**
  - Le kernel 6.16 contient un module natif: `snd-soc-cs42l83-i2c.ko.xz`
  - Ce module fait partie du support complet CS42L83 dans le kernel récent
  - Le driver natif HDA CS8409 du kernel 6.16 devrait avoir les bonnes séquences
- ✅ **ACTIONS APPLIQUÉES:**
  1. Sauvegardé le driver custom: `/etc/kernel/drivers/snd-hda-codec-cs8409.ko.backup`
  2. Sauvegardé la config modprobe: `/etc/modprobe.d/cs8409-custom-driver.conf.backup`
  3. Au prochain boot, le driver NATIF du kernel 6.16 se chargera
  4. Le driver natif devrait avoir les séquences I2C correctes pour le CS42L83
- 🔄 **Reboot nécessaire:** Pour tester le driver natif du kernel 6.16
- ⏳ Prêt pour reboot 15

**Recherches web effectuées:**
- Confirmation que le kernel 6.16 a un support CS42L83 complet (CONFIG_SND_SOC_CS42L83)
- Le CS42L83 est basé sur le CS42L42 mais avec des séquences spécifiques
- Le driver egorenar était conçu pour d'autres modèles d'iMac, pas spécifiquement pour le CS42L83

### Session 15 (2025-11-20 15:35-16:00) - DRIVER NATIF ÉCHOUE, RETOUR AU DRIVER CUSTOM
- ✅ **Vérification après reboot 15**
- ✅ Driver NATIF du kernel 6.16 chargé (40KB au lieu de 192KB custom)
- ❌ **RÉGRESSION MAJEURE:** Le driver natif est PIRE que notre driver custom!
  - **Problème 1:** GPIOs 1 et 2 DÉSACTIVÉS (enable=0, dir=0, data=0) - seul GPIO4 activé
  - **Problème 2:** La carte audio (carte 0) n'apparaît PLUS DU TOUT dans `aplay -l`
  - **Problème 3:** PipeWire ne voit qu'un "auto_null" sink
  - **Problème 4:** Seule la carte HDMI (carte 1) est détectée
- ❌ Pas de son (évidemment, la carte n'existe même plus)
- ✅ **DÉCISION:** Le driver natif du kernel Bazzite 6.16.4 n'a PAS le support complet
  - Recherches web confirment: Linux 6.16-rc6 MAINLINE a le support complet
  - Mais le kernel Bazzite 6.16.4-116 n'inclut pas ces patches récents
- ✅ **ACTIONS EFFECTUÉES:**
  1. Driver custom restauré depuis `/etc/kernel/drivers/snd-hda-codec-cs8409.ko.backup`
  2. Config modprobe restaurée depuis `/etc/modprobe.d/cs8409-custom-driver.conf.backup`
- ✅ **PLAN FINAL:**
  - Notre driver custom a GPIOs corrects (data=1) ✅
  - Il manque SEULEMENT la séquence I2C pour initialiser le CS42L83
  - La ligne 145-147 de patch_cirrus_apple.h a la séquence VIDE: `cs42l83_init_reg_seq[] = {}`
  - Trouver/créer la séquence I2C basée sur CS42L42 ou kernel 6.16-rc6 source
- 🔄 **Reboot nécessaire:** Pour que le driver custom se charge à nouveau
- ⏳ Prêt pour reboot 16

**COMPARAISON DRIVER NATIF vs CUSTOM:**
| Aspect | Driver Natif 6.16.4 | Driver Custom egorenar |
|--------|---------------------|------------------------|
| GPIOs 1 et 2 | enable=0 ❌ | enable=1, data=1 ✅ |
| Carte audio détectée | NON ❌ | OUI ✅ |
| PipeWire/ALSA | auto_null uniquement ❌ | Périphériques visibles ✅ |
| Codec reconnu | "CS8409" générique ❌ | "CS8409/CS42L83" ✅ |
| Initialisation I2C | Inconnue | Séquence vide ❌ |
| **VERDICT** | **PIRE** | **Meilleur mais incomplet** |

**PROCHAINE ÉTAPE:** Compléter la séquence I2C CS42L83 dans notre driver custom

### Session 16 (2025-11-20 16:00-16:10) - AJOUT SÉQUENCE I2C CS42L83
- ✅ **Driver custom restauré** (après échec du driver natif)
- ✅ **SOLUTION TROUVÉE:** Copier la séquence I2C du CS42L42
  - Le CS42L83 est basé sur le CS42L42 (confirmé dans /usr/src/kernels/.../include/sound/cs42l42.h ligne 44)
  - Le driver egorenar contient une séquence complète pour CS42L42 dans patch_cs8409-tables.c ligne 87-147
  - 60 registres I2C à initialiser (timeout, ADC, oscillateur, MCLK, SRC, ASP, power, mixer, etc.)
- ✅ **MODIFICATION APPLIQUÉE:**
  - Fichier: `/var/home/ndecr_/snd-hda-codec-cs8409/patch_cirrus_apple.h` ligne 144-206
  - Remplacé la séquence VIDE `cs42l83_init_reg_seq[] = {}` par la séquence complète du CS42L42
  - Ajouté commentaire: "Based on CS42L42 sequence since CS42L83 is derived from CS42L42"
- ✅ **COMPILATION RÉUSSIE:**
  - Driver recompilé avec succès (2.0M)
  - Quelques warnings (missing prototypes, empty body) mais pas d'erreurs
- ✅ **INSTALLATION:**
  - Driver copié dans `/etc/kernel/drivers/snd-hda-codec-cs8409.ko`
  - Contexte SELinux corrigé: `modules_object_t:s0` ✅
- 🔄 **Reboot nécessaire:** Pour initialiser le CS42L83 avec la nouvelle séquence I2C
- ⏳ Prêt pour reboot 16

**SÉQUENCE I2C AJOUTÉE:**
- 60 commandes I2C pour initialiser le CS42L83
- Configure: timeout I2C, ADC, oscillateur, MCLK, sample rate converter, ASP (audio serial port)
- Configure: power control, mixer volumes, headphone control, microphone detect, tip sense
- Configure: bias control, masques d'interruption pour tous les événements
- Dernier registre avec delay de 10ms pour stabilisation

**SI LE SON FONCTIONNE AU REBOOT 16:**
- ✅ Les GPIOs activent les amplificateurs speakers (GPIO1 et GPIO2 data=1)
- ✅ La séquence I2C initialise correctement le CS42L83
- ✅ Le codec CS8409/CS42L83 est complètement fonctionnel
- 🎉 **SUCCÈS TOTAL!**

**SI LE SON NE FONCTIONNE PAS AU REBOOT 16:**
- Analyser les logs I2C avec `dmesg | grep -i "cs8409\|cs42l83\|i2c"`
- Comparer avec le code du kernel 6.16-rc6 mainline pour CS42L83
- Possibilité que le CS42L83 ait des registres légèrement différents du CS42L42

---

### Session 17 (2025-11-20 18:30-19:00) - DÉCOUVERTE: PROBLÈME D'AMPLIFICATEURS TDM!
- ✅ **Vérification après reboot 16**
- ✅ Driver custom chargé depuis /etc/kernel/drivers/ (274KB)
- ✅ Codec reconnu comme "CS8409/CS42L83" (pas Generic!)
- ✅ **GPIOs CORRECTEMENT ACTIVÉS:** GPIO1 et GPIO2 avec enable=1, dir=1, **data=1** ✅✅✅
- ✅ Séquence I2C complète (60 registres) envoyée au CS42L83
- ✅ Aucune erreur I2C dans les logs
- ✅ Initialisation I2C terminée: `cs42l83_inithw end`
- ✅ Périphériques audio détectés: carte 0 "CS8409/CS42L83 Analog"
- ✅ Tests audio exécutés sans erreur: `speaker-test` et `aplay` fonctionnent
- ❌ **PAS DE SON des haut-parleurs internes** malgré tout semble correct

**DÉCOUVERTE CRITIQUE:**
- Les logs montrent des appels à `cs_8409_setup_TDM_amps34` et `cs_8409_amps_disable_streaming`
- Cela indique que le système utilise des **amplificateurs TDM** (Time Division Multiplexing)
- Les amplificateurs possibles: MAX98706, SSM3515, ou TAS5764L (différents du CS42L83!)
- Le driver egorenar/snd-hda-codec-cs8409 est conçu pour iMac27 5k avec CS42L42/CS42L83 uniquement
- Notre iMac 18,2 pourrait avoir un setup différent avec amplificateurs TDM externes

**RECHERCHE WEB EFFECTUÉE:**
- Utilisateurs d'iMac18,2 ont réussi avec le driver davidjo/snd_hda_macbookpro
- Ce driver supporte explicitement: CS8409 + MAX98706/SSM3515/TAS5764L amplifiers
- Thread Arch Linux [SOLVED] confirme le succès avec davidjo driver sur iMac18,2
- Le driver egorenar a un fork: egorenar/snd_hda_macbookpro qui supporte aussi ces amplificateurs

**ANALYSE:**
- Les GPIOs (GPIO1 et GPIO2 data=1) activent probablement les amplificateurs TDM
- MAIS le CS42L83 seul ne suffit pas - il faut AUSSI initialiser les amplificateurs MAX/SSM/TAS via I2C
- Notre driver actuel envoie la séquence CS42L83 mais ne configure pas les amplificateurs externes
- C'est pourquoi tout semble correct mais aucun son ne sort

**SOLUTION PROPOSÉE:**
1. Essayer le driver davidjo/snd_hda_macbookpro qui supporte les amplificateurs TDM
2. OU essayer le fork egorenar/snd_hda_macbookpro (plus récent)
3. Ces drivers ont la logique complète pour:
   - Initialiser le CS8409 (bridge HDA)
   - Initialiser le CS42L83 (codec)
   - **Initialiser les amplificateurs TDM (MAX98706/SSM3515/TAS5764L)**
   - Configurer le routage TDM entre tous ces composants

**PROCHAINE ÉTAPE:** Télécharger et tester un des drivers qui supporte les amplificateurs TDM
- Option 1: https://github.com/davidjo/snd_hda_macbookpro (original, plus de stars)
- Option 2: https://github.com/egorenar/snd_hda_macbookpro (fork récent)

⏳ Prêt pour Session 18: Installation du driver avec support amplificateurs TDM

---

### Session 18 (2025-11-20 19:56-20:05) - INSTALLATION DRIVER DAVIDJO AVEC SUPPORT TDM!
- ✅ **Actions effectuées:**
  1. Sauvegarde du driver egorenar: `/etc/kernel/drivers/snd-hda-codec-cs8409.ko.egorenar` (2.0M)
  2. Téléchargé le repo davidjo/snd_hda_macbookpro depuis GitHub
  3. Compilé le driver avec le script `install.cirrus.driver.pre617.sh`
     - Le script a téléchargé les sources kernel 6.16.4
     - Appliqué les patches spécifiques davidjo
     - Compilé avec succès: `snd-hda-codec-cs8409.ko` (1.9M)
  4. Installation manuelle dans `/etc/kernel/drivers/` (car /lib/modules en lecture seule sur OSTree)
  5. Correction du contexte SELinux: `modules_object_t:s0` ✅

**DIFFÉRENCES CLÉS DU DRIVER DAVIDJO:**
- Supporte explicitement les amplificateurs TDM: MAX98706, SSM3515, TAS5764L
- Code de routage TDM complet pour 4 speakers (left/right tweeter + left/right woofer)
- Initialisation I2C des amplificateurs externes (pas juste le CS42L83)
- Duplication stéréo automatique vers les 4 canaux speakers
- Basé sur reverse engineering du driver macOS AppleHDA

**FICHIERS EN PLACE:**
- Driver: `/etc/kernel/drivers/snd-hda-codec-cs8409.ko` (1.9M davidjo)
- Backup egorenar: `/etc/kernel/drivers/snd-hda-codec-cs8409.ko.egorenar` (2.0M)
- Ancien backup: `/etc/kernel/drivers/snd-hda-codec-cs8409.ko.backup` (2.0M)
- Config modprobe: `/etc/modprobe.d/cs8409-custom-driver.conf` (directive install)
- Sources: `~/snd_hda_macbookpro/` (peut être supprimé après succès)

**POURQUOI ÇA DEVRAIT FONCTIONNER:**
1. Thread Arch Linux [SOLVED] confirme succès sur iMac18,2 avec ce driver
2. Le README mentionne explicitement le support des amplificateurs TDM
3. Notre diagnostic Session 17 a montré que les amplificateurs TDM sont présents
4. Le driver egorenar initialise le CS42L83 mais ignore les amplificateurs TDM

🔄 **Reboot nécessaire:** Le codec et les amplificateurs doivent être initialisés avec le nouveau driver
⏳ Prêt pour reboot 17

---

### Session 19 (2025-11-20 20:30) - 🎉 SUCCÈS TOTAL! LE SON FONCTIONNE! 🎉

**VÉRIFICATION APRÈS REBOOT 19:**
- ✅ Driver davidjo chargé depuis `/etc/kernel/drivers/` (1.9M confirmé dans lsmod)
- ✅ Codec reconnu comme "CS8409/CS42L83"
- ✅ Amplificateurs TDM initialisés avec succès
- ✅ Carte audio détectée: "CS8409 Analog" (device 0)
- ✅ **LE SON FONCTIONNE!** Les haut-parleurs internes produisent du son! 🎉🎉🎉

**LEÇONS APPRISES - CAUSE RACINE DU PROBLÈME:**
1. **Le driver natif du kernel 6.16.4-116 Bazzite ne supporte PAS les amplificateurs TDM**
   - Il détecte le CS8409 mais n'initialise pas les amplificateurs externes
   - GPIOs restent désactivés (enable=0)

2. **Le driver egorenar/snd-hda-codec-cs8409 supporte le CS42L83 mais PAS les amplificateurs TDM**
   - Il active correctement les GPIOs (enable=1, data=1)
   - Il initialise le codec CS42L83 via I2C
   - MAIS il ne supporte pas les amplificateurs externes MAX98706/SSM3515/TAS5764L
   - Résultat: codec initialisé mais pas de son car amplificateurs non configurés

3. **Le driver davidjo/snd_hda_macbookpro est le SEUL qui supporte TOUT:**
   - Codec CS8409 (bridge HDA)
   - Codec CS42L83 (DAC/amplificateur casque)
   - Amplificateurs TDM externes (MAX98706/SSM3515/TAS5764L)
   - Routage TDM 4 canaux pour les haut-parleurs
   - ✅ **C'EST CELUI QUI FONCTIONNE!**

**ARCHITECTURE MATÉRIELLE DE L'iMac 18,2:**
```
CS8409 (HDA bridge)
    ├── CS42L83 (codec/DAC pour casque via I2C)
    └── Amplificateurs TDM (speakers internes via I2C + TDM bus)
        ├── Left Tweeter (haute fréquence)
        ├── Right Tweeter (haute fréquence)
        ├── Left Woofer (basse fréquence)
        └── Right Woofer (basse fréquence)
```

**SOLUTION FINALE FONCTIONNELLE:**
- Kernel: Bazzite 6.16.4-116.bazzite.fc42.x86_64
- Driver: davidjo/snd_hda_macbookpro compilé pour kernel 6.16.4
- Emplacement: `/etc/kernel/drivers/snd-hda-codec-cs8409.ko` (disponible dès le début du boot)
- Contexte SELinux: `modules_object_t:s0` (critique!)
- Chargement: via directive `install` dans `/etc/modprobe.d/cs8409-custom-driver.conf`

**SI UNE MISE À JOUR KERNEL CASSE LE SON:**
1. Le driver actuel (compilé pour kernel 6.16.4) ne sera plus compatible
2. Solution: recompiler le driver pour le nouveau kernel
   ```bash
   cd ~/snd_hda_macbookpro
   sudo ./install.cirrus.driver.pre617.sh
   # Puis copier le .ko dans /etc/kernel/drivers/
   sudo cp [chemin_vers_.ko] /etc/kernel/drivers/snd-hda-codec-cs8409.ko
   sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko
   sudo systemctl reboot
   ```
3. OU: Pin le déploiement Bazzite 42 actuel avec `sudo ostree admin pin 0`

🎉 **VICTOIRE FINALE!** Après 19 reboots et 18 sessions de diagnostic, le problème est RÉSOLU!

---

**ÉTAT ACTUEL (Post-Session 19):**

✅ **SUCCÈS TOTAL!** Le son fonctionne parfaitement!
✅ **CONFIGURATION STABLE:** Driver davidjo dans /etc/kernel/drivers/ avec contexte SELinux correct
✅ **PROBLÈME RÉSOLU:** Les amplificateurs TDM sont maintenant initialisés correctement
🎉 **MISSION ACCOMPLIE!** Après 19 reboots et 18 sessions de diagnostic, l'audio iMac 18,2 fonctionne!

**Résumé du parcours de débogage (19 sessions):**
1. Sessions 1-6: Compilation et installation du driver externe egorenar
2. Sessions 7-13: Diagnostic et correction des GPIOs (problème data=0 → data=1)
3. Sessions 14-17: Ajout de la séquence I2C CS42L83 (codec casque)
4. Session 18: **DÉCOUVERTE CLÉ** - Les amplificateurs TDM externes étaient manquants!
5. Session 19: **SUCCÈS** - Driver davidjo avec support TDM complet!

**Commandes de vérification si le son arrête de fonctionner:**
```bash
# 1. Vérifier les logs de chargement au boot
sudo journalctl -b | grep -i "cs8409\|insmod" | head -20
# NE DOIT PAS montrer "No such file or directory" !

# 2. Vérifier que le driver est chargé automatiquement
lsmod | grep snd_hda_codec_cs8409
# Doit afficher ~192KB (driver custom, pas 40KB natif)

# 3. Vérifier les logs d'initialisation du driver (CRITIQUE!)
sudo dmesg | grep -i "primary patch_cs8409\|detected apple\|subsystem vendor"
# Doit montrer "Primary patch_cs8409" et "Detected Apple machine"

# 4. Vérifier le nom du codec
cat /proc/asound/card0/codec#0 | head -5
# NE DOIT PAS afficher "Cirrus Logic Generic" !

# 5. Vérifier les GPIOs (CRUCIAL!)
cat /proc/asound/card0/codec#0 | grep -A 10 "GPIO:"
# GPIO1 et GPIO2 doivent être enable=1, dir=1

# 6. Tester le son
speaker-test -c 2 -t wav -l 1
```
