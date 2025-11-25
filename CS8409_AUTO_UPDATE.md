# Système de Mise à Jour Automatique du Driver CS8409

Documentation du système automatique de recompilation du driver audio CS8409 pour iMac 18,2 sous Bazzite Linux.

## 📋 Table des Matières

- [Vue d'ensemble](#vue-densemble)
- [Composants du système](#composants-du-système)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Maintenance](#maintenance)
- [Dépannage](#dépannage)
- [Architecture technique](#architecture-technique)

---

## 🎯 Vue d'ensemble

Ce système automatise la recompilation du driver audio CS8409 personnalisé après chaque mise à jour du kernel Linux. Il garantit que vos haut-parleurs internes continuent de fonctionner même après les mises à jour système.

### Problème résolu

- **Sans ce système** : Après une mise à jour du kernel, le driver compilé pour l'ancien kernel ne fonctionne plus → perte de l'audio des haut-parleurs
- **Avec ce système** : Détection automatique du changement de kernel + recompilation automatique du driver + notification utilisateur

### Fonctionnalités

✅ Détection automatique des changements de kernel
✅ Recompilation automatique du driver
✅ Notifications système en cas de succès ou d'échec
✅ Logs détaillés pour le débogage
✅ Sauvegarde automatique des anciens drivers
✅ Script de vérification du statut

---

## 🔧 Composants du système

### 1. Script principal : `auto-rebuild-cs8409-driver.sh`

**Emplacement** : `/usr/local/bin/auto-rebuild-cs8409-driver.sh`
**Permissions** : 755 (exécutable par root)

**Fonctions** :
- Détecte si le kernel a changé depuis la dernière exécution
- Vérifie la compatibilité du driver actuel avec le kernel
- Compile le driver si nécessaire
- Installe le driver dans `/etc/kernel/drivers/`
- Configure le contexte SELinux
- Envoie des notifications à l'utilisateur
- Génère des logs détaillés

**Variables importantes** :
```bash
DRIVER_DIR="/etc/kernel/drivers"
DRIVER_FILE="$DRIVER_DIR/snd-hda-codec-cs8409.ko"
SOURCE_DIR="/var/home/ndecr_/snd_hda_macbookpro"
KERNEL_VERSION_FILE="/var/lib/cs8409-kernel-version"
LOG_FILE="/var/log/cs8409-auto-rebuild.log"
```

### 2. Service systemd : `cs8409-auto-rebuild.service`

**Emplacement** : `/etc/systemd/system/cs8409-auto-rebuild.service`
**Type** : oneshot
**Activation** : Au démarrage du système (multi-user.target)

**Fonction** : Exécute le script de recompilation automatiquement à chaque démarrage pour détecter les changements de kernel.

### 3. Service post-update : `cs8409-post-update.service`

**Emplacement** : `/etc/systemd/system/cs8409-post-update.service`
**Type** : oneshot
**Activation** : Après les mises à jour rpm-ostree

**Fonction** : Vérifie le driver après les mises à jour système.

### 4. Script de vérification : `check-cs8409-status.sh`

**Emplacement** : `/var/home/ndecr_/check-cs8409-status.sh`
**Permissions** : 755 (exécutable)

**Fonction** : Affiche un rapport détaillé sur l'état du driver et du système audio.

---

## 📦 Installation

### Étape 1 : Vérifier les prérequis

```bash
# Vérifier que le driver source existe
ls -la /var/home/ndecr_/snd_hda_macbookpro/

# Vérifier que le driver actuel fonctionne
lsmod | grep snd_hda_codec_cs8409
cat /proc/asound/card0/codec#0 | head -10
```

### Étape 2 : Installation du système automatique

Les fichiers ont déjà été créés et installés :

```bash
# Scripts
/usr/local/bin/auto-rebuild-cs8409-driver.sh
/var/home/ndecr_/check-cs8409-status.sh

# Services systemd
/etc/systemd/system/cs8409-auto-rebuild.service
/etc/systemd/system/cs8409-post-update.service

# Fichiers de données
/var/lib/cs8409-kernel-version           # Sauvegarde de la version du kernel
/var/log/cs8409-auto-rebuild.log         # Logs de compilation
```

### Étape 3 : Activation des services

```bash
# Activer le service principal
sudo systemctl enable cs8409-auto-rebuild.service

# Vérifier le statut
systemctl status cs8409-auto-rebuild.service
```

### Étape 4 : Test initial

```bash
# Lancer le script manuellement pour tester
sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh

# Vérifier les logs
sudo tail -30 /var/log/cs8409-auto-rebuild.log

# Vérifier le fichier de version
cat /var/lib/cs8409-kernel-version
```

---

## 🚀 Utilisation

### Workflow normal

1. **Mise à jour système**
   ```bash
   rpm-ostree upgrade
   # ou
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/ublue-os/bazzite:stable
   ```

2. **Premier redémarrage** (vers le nouveau kernel)
   - Le système démarre avec le nouveau kernel
   - Le service `cs8409-auto-rebuild.service` s'exécute automatiquement
   - Il détecte que le kernel a changé
   - Il recompile le driver automatiquement
   - 🔔 Vous recevez une notification : **"Nouveau kernel détecté"**
   - 🔔 Notification suivante : **"Recompilation réussie! Redémarrage nécessaire."**

3. **Second redémarrage** (pour charger le nouveau driver)
   ```bash
   sudo systemctl reboot
   ```

4. **Vérification**
   ```bash
   ~/check-cs8409-status.sh
   ```

### Vérification manuelle du statut

```bash
# Exécuter le script de vérification
~/check-cs8409-status.sh
```

**Exemple de sortie** :
```
======================================
CS8409 Driver Status Check
======================================

🖥️  Kernel actuel: 6.16.5-117.bazzite.fc42.x86_64
💾 Kernel sauvegardé: 6.16.5-117.bazzite.fc42.x86_64
   ✅ Kernel inchangé

📦 Driver installé: Oui
   📏 Taille: 1.82 MB
   🔧 Compilé pour: 6.16.5-117.bazzite.fc42.x86_64
   ✅ Compatible avec le kernel actuel

🔊 Driver chargé: ✅ Oui
   📏 Taille en mémoire: 196608 bytes
   ✅ Driver personnalisé (davidjo)

🎵 Codec détecté: ✅ Oui
   Codec: Cirrus Logic CS8409/CS42L83

⚙️  Service auto-rebuild: enabled
   État: inactive

📋 Dernières entrées du log:
   [2025-11-25 10:48:25] Driver installation complete
   [2025-11-25 10:48:25] Driver rebuild completed successfully
```

### Compilation manuelle (si nécessaire)

```bash
# Forcer une recompilation
sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh

# Vérifier les logs en temps réel
sudo tail -f /var/log/cs8409-auto-rebuild.log
```

---

## 🔍 Maintenance

### Consulter les logs

```bash
# Voir tous les logs
sudo cat /var/log/cs8409-auto-rebuild.log

# Voir les 50 dernières lignes
sudo tail -50 /var/log/cs8409-auto-rebuild.log

# Suivre les logs en temps réel
sudo tail -f /var/log/cs8409-auto-rebuild.log

# Logs du service systemd
sudo journalctl -u cs8409-auto-rebuild.service
```

### Sauvegardes automatiques

Le système crée automatiquement des sauvegardes du driver avant chaque recompilation :

```bash
# Lister les sauvegardes
ls -lh /etc/kernel/drivers/*.backup*

# Restaurer une sauvegarde si nécessaire
sudo cp /etc/kernel/drivers/snd-hda-codec-cs8409.ko.backup-YYYYMMDD-HHMMSS \
       /etc/kernel/drivers/snd-hda-codec-cs8409.ko
sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko
sudo systemctl reboot
```

### Nettoyer les anciennes sauvegardes

```bash
# Supprimer les sauvegardes de plus de 30 jours
sudo find /etc/kernel/drivers/ -name "*.backup-*" -mtime +30 -delete
```

### Mettre à jour le script

Si vous modifiez le script :

```bash
# Éditer le script
nano /var/home/ndecr_/auto-rebuild-cs8409-driver.sh

# Copier vers /usr/local/bin
sudo cp /var/home/ndecr_/auto-rebuild-cs8409-driver.sh /usr/local/bin/

# Tester
sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh
```

---

## 🐛 Dépannage

### Problème 1 : Le driver ne se recompile pas après une mise à jour

**Symptômes** :
- Pas d'audio après une mise à jour du kernel
- Pas de notification reçue

**Solutions** :

```bash
# 1. Vérifier que le service est activé
systemctl status cs8409-auto-rebuild.service

# 2. Si désactivé, l'activer
sudo systemctl enable cs8409-auto-rebuild.service

# 3. Lancer manuellement
sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh

# 4. Vérifier les logs
sudo journalctl -u cs8409-auto-rebuild.service -n 50
```

### Problème 2 : La compilation échoue

**Symptômes** :
- Notification "Échec de la compilation"
- Driver non compatible avec le kernel actuel

**Solutions** :

```bash
# 1. Consulter les logs détaillés
sudo tail -100 /var/log/cs8409-auto-rebuild.log

# 2. Vérifier que les sources du kernel sont disponibles
ls -la /usr/src/kernels/$(uname -r)/

# 3. Si les sources manquent, les installer
rpm-ostree install kernel-devel

# 4. Vérifier l'espace disque
df -h

# 5. Nettoyer et recompiler
cd /var/home/ndecr_/snd_hda_macbookpro
make clean
sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh
```

### Problème 3 : Pas de notifications

**Symptômes** :
- Le script s'exécute mais pas de notification visible

**Solutions** :

```bash
# Tester les notifications manuellement
notify-send -u normal "Test" "Ceci est un test"

# Vérifier que les notifications système sont activées
# Paramètres système → Notifications
```

### Problème 4 : Driver chargé mais pas d'audio

**Symptômes** :
- Le driver est chargé (lsmod le montre)
- Mais les haut-parleurs ne fonctionnent pas

**Solutions** :

```bash
# 1. Vérifier quel driver est chargé
modinfo snd_hda_codec_cs8409 | grep filename

# Si ça montre /lib/modules/.../kernel/... (driver natif), alors :

# 2. Vérifier la configuration modprobe
cat /etc/modprobe.d/cs8409-custom-driver.conf

# 3. Recharger le driver manuellement
sudo modprobe -r snd_hda_codec_cs8409
sudo modprobe snd_hda_codec_cs8409

# 4. Vérifier les GPIO (doivent être = 1)
cat /proc/asound/card0/codec#0 | grep -A 5 "GPIO:"

# 5. Si toujours pas de solution, redémarrer
sudo systemctl reboot
```

### Problème 5 : SELinux bloque le chargement du module

**Symptômes** :
- Erreur "Permission denied" lors du insmod
- Driver compilé mais ne se charge pas

**Solutions** :

```bash
# 1. Vérifier le contexte SELinux
ls -lZ /etc/kernel/drivers/snd-hda-codec-cs8409.ko

# Doit montrer : modules_object_t

# 2. Si incorrect, le corriger
sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko

# 3. Vérifier les logs SELinux
sudo ausearch -m avc -ts recent | grep snd_hda

# 4. Si SELinux continue de bloquer, vérifier le mode
getenforce
# Doit retourner: Enforcing

# 5. Redémarrer
sudo systemctl reboot
```

---

## 🏗️ Architecture technique

### Flux de détection et recompilation

```
┌─────────────────────────┐
│  Démarrage du système   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  Service cs8409-auto-rebuild        │
│  s'exécute au boot                  │
└───────────┬─────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│  Script auto-rebuild-cs8409-driver  │
└───────────┬─────────────────────────┘
            │
            ▼
┌──────────────────────────────────────┐
│  Lecture de                          │
│  /var/lib/cs8409-kernel-version      │
└───────────┬──────────────────────────┘
            │
            ▼
       ┌────┴────┐
       │ Kernel  │
       │ changé? │
       └────┬────┘
            │
    ┌───────┴───────┐
    │               │
   NON             OUI
    │               │
    ▼               ▼
┌─────────┐   ┌──────────────────┐
│  Vérifie│   │  Notification:   │
│  compa- │   │  "Nouveau kernel"│
│ tibilité│   └────────┬─────────┘
└────┬────┘            │
     │                 ▼
     │           ┌───────────────────┐
     │           │  make clean       │
     │           └────────┬──────────┘
     │                    │
     │                    ▼
     │           ┌───────────────────┐
     │           │  make (compile)   │
     │           └────────┬──────────┘
     │                    │
     │            ┌───────┴────────┐
     │            │                │
     │         SUCCÈS           ÉCHEC
     │            │                │
     │            ▼                ▼
     │    ┌────────────────┐  ┌──────────────┐
     │    │ Copie vers     │  │ Notification │
     │    │ /etc/kernel/   │  │ "Échec!"     │
     │    │ drivers/       │  └──────────────┘
     │    └────────┬───────┘
     │             │
     │             ▼
     │    ┌────────────────────┐
     │    │ chcon SELinux      │
     │    └────────┬───────────┘
     │             │
     │             ▼
     │    ┌────────────────────┐
     │    │ Sauvegarde version │
     │    │ dans kernel-version│
     │    └────────┬───────────┘
     │             │
     │             ▼
     │    ┌────────────────────┐
     │    │ Notification:      │
     │    │ "Recompilation OK! │
     │    │  Reboot requis"    │
     │    └────────────────────┘
     │
     ▼
┌──────────────┐
│  Pas d'action│
│  nécessaire  │
└──────────────┘
```

### Structure des fichiers

```
/
├── etc/
│   ├── kernel/
│   │   └── drivers/
│   │       └── snd-hda-codec-cs8409.ko          # Driver actif
│   │           └── *.backup-YYYYMMDD-HHMMSS     # Sauvegardes
│   ├── modprobe.d/
│   │   └── cs8409-custom-driver.conf            # Config modprobe
│   └── systemd/
│       └── system/
│           ├── cs8409-auto-rebuild.service      # Service principal
│           └── cs8409-post-update.service       # Service post-update
│
├── usr/
│   └── local/
│       └── bin/
│           └── auto-rebuild-cs8409-driver.sh    # Script principal
│
├── var/
│   ├── home/
│   │   └── ndecr_/
│   │       ├── snd_hda_macbookpro/              # Sources du driver
│   │       │   ├── build/
│   │       │   │   └── hda/
│   │       │   │       └── snd-hda-codec-cs8409.ko  # Driver compilé
│   │       │   └── install.cirrus.driver.pre617.sh
│   │       ├── check-cs8409-status.sh           # Script de vérification
│   │       └── CS8409_AUTO_UPDATE.md            # Cette documentation
│   │
│   ├── lib/
│   │   └── cs8409-kernel-version                # Version du kernel sauvegardée
│   │
│   └── log/
│       └── cs8409-auto-rebuild.log              # Logs de compilation
```

### Fonctionnement de modprobe.d

Le fichier `/etc/modprobe.d/cs8409-custom-driver.conf` intercepte le chargement du module :

```bash
install snd_hda_codec_cs8409 /usr/sbin/modprobe --ignore-install snd_hda_core; \
/usr/sbin/modprobe --ignore-install snd_hda_codec; \
/usr/sbin/modprobe --ignore-install snd_hda_codec_generic; \
/usr/sbin/insmod /etc/kernel/drivers/snd-hda-codec-cs8409.ko
```

**Explication** :
1. Quand le système veut charger `snd_hda_codec_cs8409`
2. Au lieu de charger le driver natif depuis `/lib/modules/`
3. Il charge d'abord les dépendances (snd_hda_core, snd_hda_codec, snd_hda_codec_generic)
4. Puis utilise `insmod` pour charger notre driver personnalisé depuis `/etc/kernel/drivers/`

### Gestion de la persistance sur Bazzite (rpm-ostree)

**Problème** : `/lib/modules/` est en lecture seule sur les systèmes rpm-ostree

**Solution** :
- ✅ `/etc/` est en lecture-écriture et persiste entre les mises à jour
- ✅ `/var/` est en lecture-écriture et persiste entre les mises à jour
- ✅ `/usr/local/` est en lecture-écriture et persiste entre les mises à jour

C'est pourquoi nous utilisons :
- `/etc/kernel/drivers/` pour le driver
- `/var/lib/` pour les données
- `/var/log/` pour les logs
- `/usr/local/bin/` pour les scripts système

---

## 📚 Références

### Documentation originale
- Dépôt GitHub : https://github.com/ndecr/fix_iMacAudio_linux_bazzite
- Driver source : https://github.com/davidjo/snd_hda_macbookpro

### Commandes utiles

#### Vérification du driver
```bash
# Taille du driver chargé en mémoire
lsmod | grep snd_hda_codec_cs8409

# Informations du driver
modinfo snd_hda_codec_cs8409

# Codec détecté
cat /proc/asound/card0/codec#0 | head -20

# GPIO status (doit être 1 pour les speakers)
cat /proc/asound/card0/codec#0 | grep -A 5 "GPIO:"

# Test audio
speaker-test -c 2 -t wav -D hw:0,0 -l 1
```

#### Gestion du système
```bash
# Status des services
systemctl status cs8409-auto-rebuild.service

# Logs systemd
journalctl -u cs8409-auto-rebuild.service

# Version du kernel
uname -r

# Status rpm-ostree
rpm-ostree status

# Liste des kernel installés
rpm-ostree status | grep "Digest"
```

#### Debugging
```bash
# Vérifier si le driver peut se charger
sudo insmod /etc/kernel/drivers/snd-hda-codec-cs8409.ko

# Messages du kernel
sudo dmesg | grep -i cs8409

# SELinux denials
sudo ausearch -m avc -ts recent
```

---

## 🎓 Notes importantes

1. **Double redémarrage requis** : Après une mise à jour du kernel, il faut redémarrer **deux fois** :
   - 1er reboot : Boot sur le nouveau kernel → détection → recompilation
   - 2ème reboot : Chargement du nouveau driver → audio fonctionne

2. **Temps de compilation** : La recompilation prend environ 5 secondes sur votre système

3. **Notifications** : Les notifications apparaissent dans le centre de notifications du système (zone de notification KDE/GNOME)

4. **Logs rotatifs** : Le fichier log peut devenir volumineux. Considérez l'utilisation de logrotate :
   ```bash
   # À implémenter si nécessaire
   sudo nano /etc/logrotate.d/cs8409-auto-rebuild
   ```

5. **Sécurité SELinux** : Le contexte `modules_object_t` est crucial. Sans lui, le module ne peut pas se charger.

---

## ✅ Checklist post-installation

- [ ] Service `cs8409-auto-rebuild.service` activé
- [ ] Script `/usr/local/bin/auto-rebuild-cs8409-driver.sh` exécutable
- [ ] Fichier `/var/lib/cs8409-kernel-version` existe
- [ ] Test du script manuel réussi
- [ ] Notification reçue lors du test
- [ ] Audio fonctionne actuellement
- [ ] Script `check-cs8409-status.sh` fonctionne

---

## 📝 Historique des versions

### Version 1.0 (2025-11-25)
- Création du système automatique
- Support Bazzite 42 avec kernel 6.16.x
- Notifications système
- Scripts de vérification du statut
- Documentation complète

---

## 👤 Auteur

Système créé pour iMac 18,2 sous Bazzite Linux
Utilisateur : ndecr_
Date : 25 novembre 2025

---

## 📞 Support

En cas de problème :

1. Consulter la section [Dépannage](#dépannage)
2. Vérifier les logs : `sudo tail -50 /var/log/cs8409-auto-rebuild.log`
3. Exécuter le script de vérification : `~/check-cs8409-status.sh`
4. Consulter les issues GitHub du projet original

---

**Fin de la documentation**
