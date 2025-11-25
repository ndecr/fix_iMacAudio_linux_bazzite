# 🏗️ Architecture Bazzite/rpm-ostree et Driver CS8409

## 📋 Comprendre rpm-ostree et Bazzite

### Qu'est-ce que rpm-ostree ?

**rpm-ostree** est un système hybride de gestion de paquets qui combine :
- Les images immuables (comme les conteneurs)
- Les mises à jour atomiques
- Les fichiers système en lecture seule

### Conséquences pour notre driver audio

Sur Bazzite avec rpm-ostree :
- ❌ `/lib/modules/` est en **lecture seule**
- ❌ On ne peut pas installer directement dans `/lib/modules/`
- ❌ `make install` échoue car il essaie d'écrire dans `/lib/modules/`

---

## 🎯 Notre solution pour contourner le système readonly

### Répertoires persistants sur Bazzite

Ces répertoires **persistent** entre les mises à jour et sont **en lecture-écriture** :

```
✅ /etc/          - Configuration système (persiste)
✅ /var/          - Données variables (persiste)
✅ /usr/local/    - Logiciels locaux (persiste)
✅ /home/         - Données utilisateur (persiste)

❌ /lib/          - Bibliothèques système (readonly)
❌ /usr/lib/      - Bibliothèques (readonly)
❌ /lib/modules/  - Modules kernel (readonly)
```

### Notre architecture

Nous utilisons **exclusivement** les répertoires persistants :

```
/etc/kernel/drivers/
└── snd-hda-codec-cs8409.ko    <-- Driver personnalisé (✅ persistant)

/etc/modprobe.d/
└── cs8409-custom-driver.conf  <-- Config de chargement (✅ persistant)

/var/lib/cs8409-state/
├── working-state-*.json        <-- États sauvegardés (✅ persistant)
└── driver-*.ko                 <-- Sauvegardes drivers (✅ persistant)

/var/log/
├── cs8409-auto-rebuild.log     <-- Logs (✅ persistant)
├── cs8409-rollback.log
└── cs8409-post-boot-check.log

/usr/local/bin/
├── auto-rebuild-cs8409-driver.sh  <-- Scripts (✅ persistant)
├── cs8409-rollback.sh
└── cs8409-post-boot-check.sh

/etc/systemd/system/
├── cs8409-auto-rebuild.service     <-- Services (✅ persistant)
├── cs8409-post-update.service
└── cs8409-post-boot-check.service
```

---

## 🔧 Comment notre driver personnalisé est chargé

### Problème

```
Kernel veut charger: snd_hda_codec_cs8409
     ↓
Par défaut, il charge: /lib/modules/.../snd-hda-codec-cs8409.ko.xz
     ↓
MAIS ce driver natif ne supporte pas les GPIO ! ❌
```

### Solution : Directive "install" dans modprobe.d

**Fichier** : `/etc/modprobe.d/cs8409-custom-driver.conf`

```bash
install snd_hda_codec_cs8409 /usr/sbin/modprobe --ignore-install snd_hda_core; \
/usr/sbin/modprobe --ignore-install snd_hda_codec; \
/usr/sbin/modprobe --ignore-install snd_hda_codec_generic; \
/usr/sbin/insmod /etc/kernel/drivers/snd-hda-codec-cs8409.ko
```

**Explication ligne par ligne** :

1. `install snd_hda_codec_cs8409`
   → Intercepte la demande de chargement du module

2. `/usr/sbin/modprobe --ignore-install snd_hda_core`
   → Charge la dépendance 1 (en ignorant les directives install)

3. `/usr/sbin/modprobe --ignore-install snd_hda_codec`
   → Charge la dépendance 2

4. `/usr/sbin/modprobe --ignore-install snd_hda_codec_generic`
   → Charge la dépendance 3

5. `/usr/sbin/insmod /etc/kernel/drivers/snd-hda-codec-cs8409.ko`
   → Charge NOTRE driver personnalisé depuis /etc/kernel/drivers/

### Flux de chargement

```
1. Système démarre
   ↓
2. Kernel détecte le codec CS8409
   ↓
3. udev/systemd veut charger "snd_hda_codec_cs8409"
   ↓
4. modprobe cherche dans /etc/modprobe.d/
   ↓
5. Trouve notre directive "install"
   ↓
6. Exécute notre script au lieu du chargement normal
   ↓
7. Charge les dépendances (snd_hda_core, etc.)
   ↓
8. Utilise insmod pour charger depuis /etc/kernel/drivers/
   ↓
9. ✅ Notre driver personnalisé est chargé !
```

---

## 🔍 Comment vérifier quel driver est chargé

### ❌ MAUVAISE méthode

```bash
$ modinfo snd_hda_codec_cs8409
filename:       /lib/modules/.../snd-hda-codec-cs8409.ko.xz
```

Cette commande montre le fichier **disponible**, pas celui **chargé** !

### ✅ BONNE méthode 1 : Taille en mémoire

```bash
$ lsmod | grep snd_hda_codec_cs8409
snd_hda_codec_cs8409   196608  1
                       ^^^^^^
                       Cette taille indique quel driver est chargé
```

**Interprétation** :
- `196608 bytes` (~192 KB) = Driver personnalisé (davidjo) ✅
- `40960 bytes` (~40 KB) = Driver natif (sans GPIO) ❌

### ✅ BONNE méthode 2 : Codec détecté

```bash
$ cat /proc/asound/card0/codec#0 | head -3
Codec: Cirrus Logic CS8409/CS42L83
```

**Interprétation** :
- `CS8409/CS42L83` = Driver personnalisé qui reconnaît le DAC ✅
- `Generic` ou `CS8409` seul = Driver natif ❌

### ✅ BONNE méthode 3 : modinfo avec chemin complet

```bash
$ sudo modinfo /etc/kernel/drivers/snd-hda-codec-cs8409.ko
filename:       /etc/kernel/drivers/snd-hda-codec-cs8409.ko
description:    Cirrus Logic HDA bridge
vermagic:       6.16.4-116.bazzite.fc42.x86_64
```

Ceci montre les infos de NOTRE driver.

### ✅ BONNE méthode 4 : Notre script de vérification

```bash
$ ~/check-cs8409-status.sh
```

Affiche toutes les informations pertinentes !

---

## 🛠️ Processus de compilation adapté à Bazzite

### ❌ Méthode standard (ne fonctionne PAS sur Bazzite)

```bash
cd ~/snd_hda_macbookpro/
make
sudo make install    # ❌ ÉCHOUE : /lib/modules/ est readonly
```

### ✅ Notre méthode adaptée

```bash
cd ~/snd_hda_macbookpro/
make                 # ✅ Compile uniquement

# Copier manuellement vers un emplacement persistant
sudo cp build/hda/snd-hda-codec-cs8409.ko /etc/kernel/drivers/

# Configurer SELinux
sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko
```

**Pourquoi ça fonctionne** :
- `/etc/kernel/drivers/` est persistant et writable
- SELinux permet le chargement depuis ce répertoire (avec le bon contexte)
- Notre directive modprobe.d pointe vers ce répertoire

---

## 🔄 Impact sur les mises à jour

### Mise à jour standard sur distribution classique

```
Mise à jour kernel
   ↓
Nouveau kernel installé dans /boot
   ↓
Modules dans /lib/modules/NEW-KERNEL/
   ↓
Driver personnalisé écrasé ou perdu ❌
```

### Mise à jour sur Bazzite avec notre système

```
Mise à jour kernel (rpm-ostree upgrade)
   ↓
Nouveau deployment avec nouveau kernel
   ↓
Premier reboot
   ↓
/etc/kernel/drivers/ toujours présent ✅
MAIS driver incompatible avec nouveau kernel ⚠️
   ↓
Service cs8409-auto-rebuild détecte le changement
   ↓
Recompile automatiquement le driver
   ↓
Copie dans /etc/kernel/drivers/
   ↓
Notification : "Recompilation réussie"
   ↓
Second reboot
   ↓
Driver chargé et fonctionnel ✅
```

### Pourquoi /etc/ persiste entre les mises à jour

Sur rpm-ostree :
- Le système de base est une **image readonly**
- `/etc/` est un **overlay en lecture-écriture**
- Lors d'une mise à jour :
  - Nouvelle image système ✅
  - `/etc/` est **préservé** ✅
  - `/var/` est **préservé** ✅

C'est pourquoi notre driver dans `/etc/kernel/drivers/` survit aux mises à jour !

---

## 📊 Comparaison : Distribution classique vs Bazzite

| Aspect | Distribution classique | Bazzite (rpm-ostree) |
|--------|----------------------|---------------------|
| `/lib/modules/` | ✅ Read-write | ❌ Readonly |
| `make install` | ✅ Fonctionne | ❌ Échoue |
| Persistance `/etc/` | ✅ Oui | ✅ Oui |
| Mise à jour | Incrémentale | Atomique (image complète) |
| Rollback système | ⚠️ Difficile | ✅ Facile (rpm-ostree rollback) |
| Module personnalisé | Dans `/lib/modules/` | Dans `/etc/kernel/drivers/` |
| Configuration modprobe | `/etc/modprobe.d/` | `/etc/modprobe.d/` (identique) |

---

## 🎯 Pourquoi /etc/kernel/drivers/ ?

### Choix de l'emplacement

Plusieurs options étaient possibles :

| Emplacement | Persistant ? | Disponible au boot ? | Conclusion |
|-------------|-------------|---------------------|-----------|
| `/usr/local/lib/modules/` | ✅ Oui | ❌ Monté tard | ❌ Non |
| `/var/lib/modules/` | ✅ Oui | ⚠️ Peut-être | ⚠️ Risqué |
| `/etc/kernel/drivers/` | ✅ Oui | ✅ Disponible tôt | ✅ **PARFAIT** |
| `/home/user/.../` | ✅ Oui | ❌ Monté tard | ❌ Non |

**Notre choix** : `/etc/kernel/drivers/`

**Avantages** :
- ✅ Persistant entre les mises à jour
- ✅ Disponible très tôt au boot
- ✅ Chemin logique et standard
- ✅ SELinux configuré pour accepter modules_object_t
- ✅ Accessible par modprobe.d au démarrage

---

## 🔐 Importance du contexte SELinux

### Qu'est-ce que SELinux ?

**Security-Enhanced Linux** ajoute une couche de sécurité qui contrôle :
- Qui peut accéder à quoi
- Quels processus peuvent charger des modules kernel

### Notre configuration SELinux

```bash
$ ls -Z /etc/kernel/drivers/snd-hda-codec-cs8409.ko
unconfined_u:object_r:modules_object_t:s0 /etc/kernel/drivers/snd-hda-codec-cs8409.ko
                      ^^^^^^^^^^^^^^^^
                      Ce contexte est CRUCIAL
```

**Explication** :
- `modules_object_t` = Type SELinux pour les modules kernel
- Sans ce contexte, `insmod` serait **bloqué** par SELinux
- Même avec `sudo`, ça échouerait !

### Comment définir le contexte

```bash
# Après avoir copié le driver
sudo chcon -t modules_object_t /etc/kernel/drivers/snd-hda-codec-cs8409.ko

# Vérifier
ls -Z /etc/kernel/drivers/snd-hda-codec-cs8409.ko
```

**C'est automatique dans nos scripts** ! ✅

---

## 🧪 Tests de validation

### Test 1 : Vérifier que /lib/modules/ est readonly

```bash
$ sudo touch /lib/modules/$(uname -r)/test.ko
touch: impossible de faire un 'touch' sur '/lib/modules/.../test.ko': Système de fichiers accessible en lecture seulement
```
✅ Confirmé : readonly

### Test 2 : Vérifier que /etc/kernel/drivers/ est writable

```bash
$ sudo touch /etc/kernel/drivers/test.ko
$ ls /etc/kernel/drivers/test.ko
/etc/kernel/drivers/test.ko
$ sudo rm /etc/kernel/drivers/test.ko
```
✅ Confirmé : writable

### Test 3 : Vérifier la persistance après reboot

```bash
# Avant reboot
$ echo "test" | sudo tee /etc/kernel/drivers/test.txt

# Redémarrer
$ sudo systemctl reboot

# Après reboot
$ cat /etc/kernel/drivers/test.txt
test
```
✅ Confirmé : persiste

### Test 4 : Vérifier que notre driver est chargé

```bash
$ lsmod | grep snd_hda_codec_cs8409 | awk '{print $2}'
196608
```
✅ Confirmé : driver personnalisé (taille > 100000)

---

## 📚 Ressources sur rpm-ostree

### Documentation officielle

- [rpm-ostree docs](https://coreos.github.io/rpm-ostree/)
- [Fedora Silverblue](https://docs.fedoraproject.org/en-US/fedora-silverblue/) (même technologie)
- [Universal Blue](https://universal-blue.org/) (base de Bazzite)

### Commandes rpm-ostree utiles

```bash
# Voir les deployments
rpm-ostree status

# Mettre à jour
rpm-ostree upgrade

# Revenir en arrière
rpm-ostree rollback

# Voir les différences
rpm-ostree db diff

# Installer un paquet (layering)
rpm-ostree install package-name

# Changer de version
rpm-ostree rebase ostree-unverified-registry:...
```

---

## 🎓 Conclusion

Notre solution pour le driver CS8409 sur Bazzite :

1. **Respecte l'architecture rpm-ostree**
   - N'essaie pas d'écrire dans `/lib/modules/`
   - Utilise uniquement des emplacements persistants

2. **Survit aux mises à jour**
   - `/etc/kernel/drivers/` persiste
   - `/etc/modprobe.d/` persiste
   - Configuration SELinux persiste

3. **Se recompile automatiquement**
   - Détection des changements de kernel
   - Recompilation automatique
   - Notification utilisateur

4. **Permet le rollback**
   - Sauvegarde des états fonctionnels
   - Rollback du deployment ET du driver
   - Un seul redémarrage

**C'est une solution native et élégante pour Bazzite !** ✅

---

**Dernière mise à jour** : 25 novembre 2025
