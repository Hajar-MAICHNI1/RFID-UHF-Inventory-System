# 🏨 Système de Traçabilité RFID UHF pour Hôtels

Solution automatisée et accessible pour réduire les pertes d'équipements hôteliers.
**Coût 450 USD vs 5,000-15,000 USD** pour solutions commerciales.

---

## ✨ Caractéristiques Principales

- ✅ Détection RFID UHF (98.5% précision, portée 5-8m)
- ✅ 3 modes : SAVE (unique), SAVEALL (batch 4), CHECK (temps réel)
- ✅ App mobile Flutter complète
- ✅ Dashboard web embarqué (192.168.4.1)
- ✅ Sécurité : HTTPS/TLS + authentification
- ✅ Performance : Latence < 100ms, uptime 100%
- ✅ ROI : 13.9× investissement (payback 26 jours)

---

## 📁 Structure du Projet

```
RFID-UHF-Inventory-System/
├── embedded/           # Firmware ESP32 (dual-core, FreeRTOS)
├── mobile_app/         # Application Flutter (9 écrans)
├── backend/            # API PHP + MySQL
├── database/           # Script MySQL (users, types, tags, alerts)
├── hardware/           # Schémas & PCB (EasyEDA)
├── docs/               # Diagrammes & screenshots
└── resources/          # Datasheets & références
```

---

## 🚀 Installation Rapide

### **1. Firmware ESP32**
```bash
git clone https://github.com/hajarmaichni/rfid-hotel-firmware.git
cd embedded/
pio run -t upload
```

### **2. App Flutter**
```bash
git clone https://github.com/hajarmaichni/rfid-hotel-flutter.git
cd mobile_app/
flutter pub get && flutter run
```

### **3. Backend PHP**
```bash
# Lancer XAMPP
# Importer base de données
mysql -u root < database/rfid_inventory.sql
# Copier API
cp -r backend/api/ /path/to/xampp/htdocs/
```

---

## 📊 Spécifications

| Aspect | Valeur |
|--------|--------|
| **Détection RFID** | 98.5% (197/200 tags) |
| **Latence** | 85-150ms |
| **Portée** | 5-8 mètres |
| **Modes** | 3 (SAVE, SAVEALL, CHECK) |
| **Coût Prototype** | 535 USD |
| **Coût Production** | 450 USD (100u) |
| **ROI Année 1** | 13.9× |
| **Payback** | 26 jours |

---

## 🏗️ Architecture

```
Tags RFID → Lecteur UHF → ESP32 (WiFi) → MySQL → Flutter App + Dashboard Web
```

**5 Couches:**
1. Tags RFID passifs (EPC Gen2)
2. Lecteur Prime Reader (860-960 MHz)
3. ESP32 dual-core + WiFi
4. MySQL pour vérification
5. Interfaces utilisateur (Flutter + Web)

---

## 🔧 Modes Opérationnels

### **SAVE** - Enregistrement unique
Place 1 tag → Détecte → Enregistre

### **SAVEALL** - Batch rapide
Place 4 tags (< 3s) → Enregistre tous d'un coup (4× plus rapide)

### **CHECK** - Vérification sécurité
Tag → Query BD → Si VALIDE: LED verte | Si INVALIDE: LED rouge + alerte

---

## 🗄️ Base de Données

4 tables:
- **users** : Authentification (admin/opérateur)
- **types** : Catégories articles
- **tags** : Articles RFID (EPC unique)
- **theft_alerts** : Anomalies détectées

---

## 📱 Interface Utilisateur

**Flutter App (9 écrans):**
- Connexion sécurisée
- Dashboard en temps réel
- Gestion alertes & types
- Visualisation base données
- Export rapports (PDF/Excel)

**Web Dashboard (192.168.4.1):**
- Accès local via hotspot WiFi
- 3 modes visibles
- Supervision simple

---

## 🔐 Sécurité

- ✅ HTTPS/TLS (port 443)
- ✅ Authentification bcrypt
- ✅ Prepared statements (pas injection SQL)
- ✅ Sessions PHP sécurisées

---

## 📈 Résultats Validés

✅ Hotspot WiFi stable (10 clients)
✅ App Flutter fluide (0 lag)
✅ Modes SAVE/SAVEALL/CHECK opérationnels
✅ RFID détection 98.5%
✅ Latence 85-150ms
✅ Uptime 100% (8h testé)
✅ Zéro erreur classification

---

## 🎯 Prochaines Étapes

- Fabriquer le PCB
- Test 24h+ continu
- Déploiement pilote hôtel
- Intégration Firebase/VPS (scalabilité multi-sites)

---

## 📚 Documentation Complète

- Rapport PFE complet : voir `docs/rapport.pdf`
- Présentation soutenance : voir `docs/presentation.pdf`
- Architecture détaillée : voir `docs/architecture/`

---

## 👤 Auteur

**MAICHNI Hajar**  
Master Ingénierie Informatique et Systèmes Embarqués  
FSA Ibn Zohr Agadir | Moussasoft SARL  
Juin 2026

---

## 📞 Contact

- 📧 hajar.maichni@example.com
- 🔗 LinkedIn: linkedin.com/in/hajar-maichni
- 💻 GitHub: github.com/hajarmaichni

---

## 📄 Licence

MIT License - Usage académique et commercial autorisé

---

**Status:** ✅ Prototype validé - Prêt pour production
