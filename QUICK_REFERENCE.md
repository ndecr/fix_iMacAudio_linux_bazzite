# 🚀 Référence Rapide - Système Auto-Update CS8409

## 📋 Commandes essentielles

### Vérifier le statut du driver
```bash
~/check-cs8409-status.sh
```

### Forcer une recompilation manuelle
```bash
sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh
```

### Consulter les logs
```bash
# Logs de compilation
sudo tail -50 /var/log/cs8409-auto-rebuild.log

# Logs du service
sudo journalctl -u cs8409-auto-rebuild.service -n 50
```

### Tester l'audio
```bash
speaker-test -c 2 -t wav -D hw:0,0 -l 1
```

---

## 🔄 Workflow de mise à jour du kernel

### Méthode automatique (recommandée)

1. **Faire la mise à jour système**
   ```bash
   rpm-ostree upgrade
   ```

2. **Premier redémarrage**
   ```bash
   sudo systemctl reboot
   ```
   - Le système détecte automatiquement le nouveau kernel
   - Recompile le driver automatiquement
   - Vous recevez une notification 🔔

3. **Second redémarrage** (pour charger le nouveau driver)
   ```bash
   sudo systemctl reboot
   ```

4. **Vérifier que tout fonctionne**
   ```bash
   ~/check-cs8409-status.sh
   speaker-test -c 2 -t wav -D hw:0,0 -l 1
   ```

✅ **C'est tout !** Le système s'occupe de la recompilation automatiquement.

---

## ⚠️ Si l'audio ne fonctionne pas après une mise à jour

### Diagnostic rapide

```bash
# 1. Vérifier le statut
~/check-cs8409-status.sh

# 2. Vérifier quel driver est chargé
lsmod | grep snd_hda_codec_cs8409
# La taille doit être ~196608 bytes (driver personnalisé)
# Si plus petit (~40000), c'est le driver natif ❌

# 3. Vérifier si le driver est compatible
modinfo /etc/kernel/drivers/snd-hda-codec-cs8409.ko | grep vermagic

# 4. Comparer avec le kernel actuel
uname -r
```

### Solution 1 : Recompilation manuelle

```bash
# Forcer la recompilation
sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh

# Redémarrer
sudo systemctl reboot
```

### Solution 2 : Vérifier le service

```bash
# Vérifier que le service est activé
systemctl status cs8409-auto-rebuild.service

# Si désactivé, l'activer
sudo systemctl enable cs8409-auto-rebuild.service

# Redémarrer
sudo systemctl reboot
```

---

## 📁 Fichiers importants

| Fichier | Emplacement | Description |
|---------|-------------|-------------|
| **Driver actif** | `/etc/kernel/drivers/snd-hda-codec-cs8409.ko` | Driver personnalisé chargé au boot |
| **Config modprobe** | `/etc/modprobe.d/cs8409-custom-driver.conf` | Force le chargement du driver personnalisé |
| **Script auto** | `/usr/local/bin/auto-rebuild-cs8409-driver.sh` | Script de recompilation automatique |
| **Service systemd** | `/etc/systemd/system/cs8409-auto-rebuild.service` | Service qui s'exécute au boot |
| **Logs** | `/var/log/cs8409-auto-rebuild.log` | Logs de compilation |
| **Version kernel** | `/var/lib/cs8409-kernel-version` | Kernel pour lequel le driver est compilé |
| **Sources** | `/var/home/ndecr_/snd_hda_macbookpro/` | Code source du driver |
| **Documentation** | `/var/home/ndecr_/CS8409_AUTO_UPDATE.md` | Documentation complète |

---

## 🎯 Indicateurs de bon fonctionnement

### ✅ Tout est OK si :

```bash
# Driver personnalisé chargé (taille > 100000)
$ lsmod | grep snd_hda_codec_cs8409
snd_hda_codec_cs8409   196608  1

# Codec correctement détecté
$ cat /proc/asound/card0/codec#0 | head -3
Codec: Cirrus Logic CS8409/CS42L83
Address: 0
AFG Function Id: 0x1 (unsol 1)

# Driver compatible avec le kernel actuel
$ ~/check-cs8409-status.sh
...
   ✅ Compatible avec le kernel actuel
...
🔊 Driver chargé: ✅ Oui
   ✅ Driver personnalisé (davidjo)
```

### ❌ Problème si :

```bash
# Driver natif chargé (petite taille)
$ lsmod | grep snd_hda_codec_cs8409
snd_hda_codec_cs8409   40960  1

# Codec détecté comme "Generic"
$ cat /proc/asound/card0/codec#0 | head -3
Codec: Generic
...

# Driver incompatible
$ ~/check-cs8409-status.sh
...
   ❌ INCOMPATIBLE avec le kernel actuel
   ⚠️  RECOMPILATION NÉCESSAIRE
```

**Solution** : Lancer `sudo /usr/local/bin/auto-rebuild-cs8409-driver.sh` puis redémarrer.

---

## 🔧 Maintenance

### Nettoyer les anciennes sauvegardes

```bash
# Lister les sauvegardes
ls -lh /etc/kernel/drivers/*.backup*

# Supprimer les sauvegardes de plus de 30 jours
sudo find /etc/kernel/drivers/ -name "*.backup-*" -mtime +30 -delete
```

### Nettoyer les logs anciens

```bash
# Tronquer le fichier log s'il devient trop gros
sudo truncate -s 0 /var/log/cs8409-auto-rebuild.log
```

---

## 🆘 Urgence : Restaurer un ancien driver

Si la nouvelle compilation ne fonctionne pas :

```bash
# 1. Lister les sauvegardes
ls -lt /etc/kernel/drivers/*.backup* | head -5

# 2. Restaurer la dernière sauvegarde qui fonctionnait
sudo cp /etc/kernel/drivers/snd-hda-codec-cs8409.ko.backup-YYYYMMDD-HHMMSS \
       /etc/kernel/drivers/snd-hda-codec-cs8409.ko

# 3. Corriger le contexte SELinux
sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko

# 4. Redémarrer
sudo systemctl reboot
```

---

## 📚 Documentation complète

Pour plus de détails, consultez : `/var/home/ndecr_/CS8409_AUTO_UPDATE.md`

---

**Dernière mise à jour** : 25 novembre 2025
