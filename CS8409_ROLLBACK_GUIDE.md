# 🔄 Guide de Rollback du Driver CS8409

## 📋 Vue d'ensemble

Ce système de rollback permet de revenir à un état fonctionnel connu en cas de problème après une mise à jour du kernel. Il sauvegarde à la fois le driver compilé ET la version du deployment rpm-ostree.

---

## 🎯 Quand utiliser le rollback ?

### Scénarios d'utilisation

1. **Après une mise à jour de kernel, l'audio ne fonctionne pas**
   - Le driver a été recompilé mais ne fonctionne pas correctement
   - Le codec n'est pas détecté
   - Les haut-parleurs restent muets

2. **Le driver natif se charge au lieu du driver personnalisé**
   - Vérifiable avec : `lsmod | grep snd_hda_codec_cs8409` (taille < 100000)

3. **Erreurs de compilation du driver**
   - Le système ne peut pas recompiler le driver pour le nouveau kernel

4. **Instabilité audio après mise à jour**
   - Crackling, coupures, ou comportement anormal

---

## 📦 Installation

Le système de rollback est déjà installé avec les fichiers suivants :

```
/usr/local/bin/cs8409-rollback.sh              # Script principal
/usr/local/bin/cs8409-post-boot-check.sh       # Vérification post-boot
/etc/systemd/system/cs8409-post-boot-check.service  # Service de vérification
/var/lib/cs8409-state/                         # États sauvegardés
/var/log/cs8409-rollback.log                   # Logs
```

---

## 🚀 Utilisation

### 1. Sauvegarder l'état actuel fonctionnel

**Quand ?** Après avoir vérifié que l'audio fonctionne parfaitement.

```bash
# Sauvegarder l'état actuel
sudo cs8409-rollback.sh save
```

**Ce qui est sauvegardé** :
- ✅ Version du kernel actuel
- ✅ Copie du driver CS8409 fonctionnel
- ✅ Index et checksum du deployment rpm-ostree
- ✅ Version du deployment
- ✅ Timestamp de la sauvegarde

**Sortie exemple** :
```
✅ Working state saved successfully!
   Kernel: 6.16.4-116.bazzite.fc42.x86_64
   Deployment: 42.20251019
```

### 2. Lister les états sauvegardés

```bash
cs8409-rollback.sh list
```

**Sortie exemple** :
```
=========================================
           SAVED WORKING STATES
=========================================

[1] ✅ 6.16.4-116.bazzite.fc42.x86_64 (CURRENT)
    Date: 2025-11-25T10:53:19+01:00
    Deployment: 42.20251019

[2] 6.16.3-115.bazzite.fc42.x86_64
    Date: 2025-11-20T14:23:45+01:00
    Deployment: 42.20251015

Current system:
  Kernel: 6.16.4-116.bazzite.fc42.x86_64
  ...
```

### 3. Vérifier que l'audio fonctionne

```bash
cs8409-rollback.sh verify
```

**Tests effectués** :
1. ✅ Driver CS8409 chargé
2. ✅ Driver personnalisé (pas natif)
3. ✅ Codec CS8409/CS42L83 détecté
4. 🔊 Test audio optionnel

**Sortie exemple** :
```
=========================================
      AUDIO VERIFICATION
=========================================

Current kernel: 6.16.4-116.bazzite.fc42.x86_64

✅ PASS: Driver CS8409 loaded
✅ PASS: Custom driver loaded (size: 196608 bytes)
✅ PASS: Codec detected: Codec: Cirrus Logic CS8409/CS42L83

All automatic checks passed!

Do you want to test audio playback? (y/n):
```

### 4. Effectuer un rollback

**⚠️ ATTENTION** : Cette commande va redémarrer votre système !

```bash
sudo cs8409-rollback.sh rollback
```

**Ce qui se passe** :

1. **Affichage des informations** :
   ```
   =========================================
            ROLLBACK INFORMATION
   =========================================

   Current state:
     Kernel: 6.16.5-117.bazzite.fc42.x86_64

   Rolling back to:
     Kernel: 6.16.4-116.bazzite.fc42.x86_64
     Deployment: 42.20251019
   ```

2. **Confirmation demandée** :
   ```
   ⚠️  This will:
     1. Rollback rpm-ostree to the previous deployment
     2. Restore the working driver for kernel 6.16.4-116
     3. Reboot the system

   Do you want to continue? (yes/no):
   ```

3. **Si vous confirmez (tapez `yes`)** :
   - ✅ Restauration du driver sauvegardé
   - ✅ Rollback rpm-ostree vers le deployment précédent
   - 🔄 Redémarrage automatique après 10 secondes

4. **Après le reboot** :
   - Le système démarre sur l'ancien kernel
   - Le driver fonctionnel est chargé
   - L'audio devrait fonctionner ✅

---

## 🔄 Workflow de mise à jour sécurisé

### Procédure recommandée

```bash
# 0. AVANT la mise à jour : Sauvegarder l'état actuel si tout fonctionne
sudo cs8409-rollback.sh save

# 1. Faire la mise à jour
rpm-ostree upgrade

# 2. Premier redémarrage
sudo systemctl reboot

# 3. Le système recompile automatiquement le driver
#    🔔 Vous recevez une notification

# 4. Second redémarrage
sudo systemctl reboot

# 5. Vérifier que l'audio fonctionne
cs8409-rollback.sh verify

# 6a. SI L'AUDIO FONCTIONNE : Sauvegarder le nouvel état
sudo cs8409-rollback.sh save

# 6b. SI L'AUDIO NE FONCTIONNE PAS : Rollback
sudo cs8409-rollback.sh rollback
```

---

## 🔍 Détection automatique des problèmes

### Service post-boot

Un service systemd vérifie automatiquement l'audio après chaque démarrage :

**Service** : `cs8409-post-boot-check.service`

**Vérifications effectuées** :
1. Driver CS8409 chargé
2. Driver personnalisé (pas natif)
3. Codec correctement détecté

**Notifications automatiques** :

| Statut | Notification |
|--------|-------------|
| ✅ Tout OK | "Driver audio chargé correctement. Système prêt!" |
| ⚠️ Driver natif | "Driver natif chargé. Audio des haut-parleurs ne fonctionnera pas." |
| ❌ Driver absent | "Driver audio non chargé! Utilisez cs8409-rollback.sh rollback" |
| 💾 Nouveau kernel | "Nouveau kernel détecté! Sauvegardez l'état après test." |

**Consulter les logs** :
```bash
# Logs du service de vérification
sudo journalctl -u cs8409-post-boot-check.service

# Fichier log
cat /var/log/cs8409-post-boot-check.log
```

---

## 📊 Structure des états sauvegardés

### Emplacement

```
/var/lib/cs8409-state/
├── working-state-20251125-105319.json    # État sauvegardé
├── working-state-20251120-142345.json    # Ancien état
├── last-working-state.json               # Lien vers le dernier état
├── driver-6.16.4-116.bazzite.fc42.x86_64.ko   # Driver sauvegardé
└── driver-6.16.3-115.bazzite.fc42.x86_64.ko   # Ancien driver
```

### Format JSON

```json
{
  "timestamp": "2025-11-25T10:53:19+01:00",
  "kernel_version": "6.16.4-116.bazzite.fc42.x86_64",
  "deployment_index": 0,
  "deployment_checksum": "ca0d9ff74c55fa3c...",
  "deployment_version": "42.20251019",
  "driver_file": "/var/lib/cs8409-state/driver-6.16.4-116.bazzite.fc42.x86_64.ko",
  "driver_size": 1911744,
  "verified_working": true
}
```

---

## 🐛 Dépannage

### Problème 1 : "No working state found to rollback to"

**Cause** : Aucun état fonctionnel n'a été sauvegardé.

**Solution** :
```bash
# Si votre système actuel fonctionne, sauvegardez-le d'abord
sudo cs8409-rollback.sh save

# Sinon, vous devrez recompiler manuellement ou réinstaller
```

### Problème 2 : Le rollback ne restaure pas l'audio

**Vérifications** :

1. **Vérifier quel driver est chargé** :
   ```bash
   lsmod | grep snd_hda_codec_cs8409
   modinfo snd_hda_codec_cs8409 | grep filename
   ```

2. **Vérifier le contexte SELinux du driver** :
   ```bash
   ls -lZ /etc/kernel/drivers/snd-hda-codec-cs8409.ko
   # Doit montrer: modules_object_t
   ```

3. **Si le contexte est incorrect** :
   ```bash
   sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko
   sudo systemctl reboot
   ```

### Problème 3 : "Driver backup file not found"

**Cause** : Le fichier de sauvegarde du driver a été supprimé ou n'existe pas.

**Solution** :
```bash
# Recompiler le driver pour le kernel actuel
sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh

# Redémarrer
sudo systemctl reboot

# Si ça fonctionne, sauvegarder l'état
sudo cs8409-rollback.sh save
```

### Problème 4 : Impossible de sauvegarder l'état

**Erreur** : "ERROR: Driver CS8409 not loaded"

**Cause** : Le driver n'est pas chargé actuellement.

**Solution** :
```bash
# Vérifier pourquoi le driver n'est pas chargé
sudo dmesg | grep -i cs8409

# Recharger le driver
sudo modprobe -r snd_hda_codec_cs8409
sudo modprobe snd_hda_codec_cs8409

# Ou redémarrer
sudo systemctl reboot
```

---

## ⚙️ Configuration avancée

### Modifier le délai avant redémarrage automatique

Par défaut, le rollback redémarre après 10 secondes.

Éditez `/usr/local/bin/cs8409-rollback.sh` :

```bash
# Trouver cette ligne :
sleep 10

# Changer à 30 secondes par exemple :
sleep 30
```

### Désactiver la vérification post-boot

```bash
# Désactiver le service
sudo systemctl disable cs8409-post-boot-check.service

# Réactiver
sudo systemctl enable cs8409-post-boot-check.service
```

### Nettoyer les anciens états

```bash
# Lister les états
ls -lt /var/lib/cs8409-state/working-state-*.json

# Supprimer les états de plus de 60 jours
sudo find /var/lib/cs8409-state/ -name "working-state-*.json" -mtime +60 -delete

# Supprimer les drivers orphelins (sans état JSON correspondant)
cd /var/lib/cs8409-state/
for driver in driver-*.ko; do
    kernel_version=${driver#driver-}
    kernel_version=${kernel_version%.ko}
    if ! grep -q "$kernel_version" working-state-*.json 2>/dev/null; then
        echo "Orphaned driver: $driver"
        # sudo rm "$driver"
    fi
done
```

---

## 🔐 Sécurité et permissions

### Fichiers et permissions

```bash
# Scripts (exécutables par tous, modifiables par root uniquement)
-rwxr-xr-x root root /usr/local/bin/cs8409-rollback.sh
-rwxr-xr-x root root /usr/local/bin/cs8409-post-boot-check.sh

# États sauvegardés (lecture/écriture root uniquement)
drwxr-xr-x root root /var/lib/cs8409-state/
-rw-r--r-- root root /var/lib/cs8409-state/*.json
-rw-r--r-- root root /var/lib/cs8409-state/*.ko

# Logs (lecture tous, écriture root)
-rw-rw-rw- root root /var/log/cs8409-rollback.log
```

### Contexte SELinux

Les drivers sauvegardés doivent avoir le contexte `modules_object_t` :

```bash
# Vérifier
ls -lZ /var/lib/cs8409-state/*.ko

# Corriger si nécessaire
sudo chcon -t modules_object_t /var/lib/cs8409-state/*.ko
```

---

## 📈 Bonnes pratiques

### 1. Sauvegarder régulièrement

```bash
# Après chaque mise à jour réussie
sudo cs8409-rollback.sh save
```

### 2. Tester l'audio avant de sauvegarder

```bash
# Vérifier automatiquement
cs8409-rollback.sh verify

# Ou tester manuellement
speaker-test -c 2 -t wav -D hw:0,0 -l 1
```

### 3. Conserver au moins 2-3 états fonctionnels

Ne supprimez pas tous les anciens états. Gardez au moins 2-3 sauvegardes au cas où.

### 4. Noter les versions qui fonctionnent

Créez un fichier de suivi :

```bash
cat >> ~/kernel-audio-history.txt << EOF
$(date) - Kernel $(uname -r) - Audio OK ✅
EOF
```

### 5. Avant une mise à jour majeure

```bash
# 1. Vérifier l'état actuel
cs8409-rollback.sh list

# 2. Sauvegarder si ce n'est pas fait
sudo cs8409-rollback.sh save

# 3. Noter le deployment actuel
rpm-ostree status

# 4. Faire la mise à jour
rpm-ostree upgrade
```

---

## 📚 Commandes de référence

### Diagnostic rapide

```bash
# État global du système
~/check-cs8409-status.sh

# Vérifier l'audio
cs8409-rollback.sh verify

# Lister les états sauvegardés
cs8409-rollback.sh list

# Kernel actuel
uname -r

# Deployments disponibles
rpm-ostree status
```

### Gestion des états

```bash
# Sauvegarder l'état actuel
sudo cs8409-rollback.sh save

# Rollback complet (kernel + driver)
sudo cs8409-rollback.sh rollback

# Voir les logs
sudo tail -50 /var/log/cs8409-rollback.log
```

### Rollback manuel (sans le script)

Si le script ne fonctionne pas :

```bash
# 1. Rollback rpm-ostree uniquement
sudo rpm-ostree rollback

# 2. Redémarrer
sudo systemctl reboot

# 3. Après le boot, restaurer le driver manuellement si nécessaire
sudo cp /var/lib/cs8409-state/driver-KERNEL-VERSION.ko \
       /etc/kernel/drivers/snd-hda-codec-cs8409.ko
sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko
sudo systemctl reboot
```

---

## 🆘 En cas d'urgence

### Scénario : Système ne démarre plus après rollback

1. **Au boot, sélectionner l'ancien deployment dans le menu GRUB**
   - Appuyez sur une touche pendant le démarrage
   - Sélectionnez un deployment antérieur

2. **Une fois démarré** :
   ```bash
   # Vérifier les deployments
   rpm-ostree status

   # Supprimer le deployment problématique
   sudo rpm-ostree cleanup -p
   ```

### Scénario : Aucun état sauvegardé et audio ne fonctionne pas

1. **Essayer de recompiler** :
   ```bash
   sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh
   sudo systemctl reboot
   ```

2. **Si la compilation échoue** :
   - Consulter la documentation originale : `~/CS8409_AUTO_UPDATE.md`
   - Vérifier le dépôt GitHub : https://github.com/ndecr/fix_iMacAudio_linux_bazzite

3. **En dernier recours** :
   ```bash
   # Revenir à une version stable de Bazzite
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/ublue-os/bazzite:stable
   sudo systemctl reboot
   ```

---

## 📝 Notes importantes

1. **Double redémarrage** : Après un rollback, comme après une mise à jour, il faut parfois redémarrer deux fois.

2. **Persistance des données** : Les états sauvegardés dans `/var/lib/` persistent entre les mises à jour Bazzite.

3. **Espace disque** : Chaque état sauvegardé prend environ 2 MB. Surveillez l'espace disque si vous accumulez beaucoup d'états.

4. **Compatibilité** : Ce système est spécifique à Bazzite/rpm-ostree. Il ne fonctionnera pas sur des distributions traditionnelles.

5. **Automation** : Le système de vérification post-boot est automatique. Vous n'avez rien à faire manuellement.

---

## ✅ Checklist de vérification

Après chaque mise à jour :

- [ ] Le système a redémarré sur le nouveau kernel
- [ ] Le driver CS8409 est chargé (`lsmod | grep cs8409`)
- [ ] Le driver est personnalisé (taille > 100000 bytes)
- [ ] Le codec est détecté (`cat /proc/asound/card0/codec#0`)
- [ ] L'audio fonctionne (`speaker-test`)
- [ ] L'état a été sauvegardé (`sudo cs8409-rollback.sh save`)

---

## 🎓 Pour aller plus loin

- **Documentation complète** : `~/CS8409_AUTO_UPDATE.md`
- **Référence rapide** : `~/QUICK_REFERENCE.md`
- **Dépôt GitHub** : https://github.com/ndecr/fix_iMacAudio_linux_bazzite
- **Driver source** : https://github.com/davidjo/snd_hda_macbookpro

---

**Dernière mise à jour** : 25 novembre 2025
**Version** : 1.0
