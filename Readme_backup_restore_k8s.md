# Scripts de Backup/Restore PostgreSQL pour Kubernetes

## 📋 Description

Ces scripts permettent de sauvegarder et restaurer la base de données PostgreSQL déployée dans Kubernetes/Minikube.

## 🔧 Prérequis

- `kubectl` installé et configuré
- Accès au namespace `plateforme-electronique`
- Pod PostgreSQL avec le label `app=postgresql`

## 📁 Fichiers

- `BACKUP-DATABASE-K8S.sh` : Script de sauvegarde
- `RESTORE-DATABASE-K8S.sh` : Script de restauration

## 🚀 Installation

1. Rendre les scripts exécutables :
```bash
chmod +x BACKUP-DATABASE-K8S.sh
chmod +x RESTORE-DATABASE-K8S.sh
```

## 💾 Sauvegarde de la base de données

### Utilisation simple :
```bash
./BACKUP-DATABASE-K8S.sh
```

### Ce que fait le script :
1. ✅ Vérifie que le pod PostgreSQL est actif
2. 📊 Affiche les statistiques de la base (nombre de factures, clients, taille)
3. 💾 Effectue un dump PostgreSQL compressé (.sql.gz)
4. 📂 Sauvegarde dans `~/backups/plateforme-db/`
5. 🧹 Nettoie automatiquement (garde les 10 derniers backups)

### Exemple de sortie :
```
💾 Sauvegarde de la Base de Données PostgreSQL (Kubernetes)
===========================================================

🔍 Vérification du namespace...
✅ Namespace trouvé

🔍 Recherche du pod PostgreSQL...
✅ Pod PostgreSQL actif: postgresql-5df848d766-fdbq4

📋 Informations de sauvegarde:
   Pod:        postgresql-5df848d766-fdbq4
   Namespace:  plateforme-electronique
   Base:       invoice_db
   Fichier:    /home/user/backups/plateforme-db/backup-invoice_db-20260207-143052.sql.gz

📊 Statistiques de la base:
   📄 Factures: 1523
   👥 Clients: 342
   💽 Taille: 12 MB

⏳ Sauvegarde en cours...

=================================================
✅ Sauvegarde réussie !
=================================================

📦 Fichier de backup:
   /home/user/backups/plateforme-db/backup-invoice_db-20260207-143052.sql.gz
   Taille: 2.3M
```

## 🔄 Restauration de la base de données

### Utilisation interactive (recommandée) :
```bash
./RESTORE-DATABASE-K8S.sh
```
Le script affichera la liste des backups disponibles et vous demandera de choisir.

### Utilisation avec un fichier spécifique :
```bash
./RESTORE-DATABASE-K8S.sh ~/backups/plateforme-db/backup-invoice_db-20260207-143052.sql.gz
```

### Ce que fait le script :
1. ✅ Vérifie que le pod PostgreSQL est actif
2. 📂 Liste les backups disponibles (si aucun fichier spécifié)
3. 💾 Crée un backup de sécurité automatique avant restauration
4. ⚠️  Demande confirmation (tape 'OUI')
5. 🗑️  Supprime la base existante
6. 📦 Crée une nouvelle base vide
7. 📥 Restaure les données
8. ✅ Vérifie les données restaurées

### Exemple de sortie :
```
🔄 Restauration de la Base de Données PostgreSQL (Kubernetes)
==============================================================

🔍 Vérification du namespace...
✅ Namespace trouvé

🔍 Recherche du pod PostgreSQL...
✅ Pod PostgreSQL actif: postgresql-5df848d766-fdbq4

📂 Backups disponibles:

   [1] backup-invoice_db-20260207-143052.sql.gz - 2.3M - 2026-02-07 14:30:52
   [2] backup-invoice_db-20260206-092315.sql.gz - 2.1M - 2026-02-06 09:23:15

Entrez le numéro du backup à restaurer (ou 'q' pour quitter):
1

📋 Informations de restauration:
   Pod:     postgresql-5df848d766-fdbq4
   Fichier: /home/user/backups/plateforme-db/backup-invoice_db-20260207-143052.sql.gz
   Taille:  2.3M
   Base:    invoice_db

⚠️  ATTENTION !
   Cette opération va ÉCRASER toutes les données actuelles
   de la base de données 'invoice_db'

Voulez-vous continuer? (tapez 'OUI' en majuscules pour confirmer)
OUI

💾 Création d'un backup de sécurité avant restauration...
✅ Backup de sécurité créé: /home/user/backups/plateforme-db/safety-backup-before-restore-20260207-144223.sql.gz

🗜️  Décompression du backup...
⏳ Restauration en cours...

🗑️  Suppression de la base existante...
📦 Création d'une nouvelle base...
📥 Restauration des données...

=================================================
✅ Restauration réussie !
=================================================

📊 Vérification des données restaurées:

   ✅ Factures restaurées: 1523
   ✅ Clients restaurés: 342

💾 Backup de sécurité conservé: /home/user/backups/plateforme-db/safety-backup-before-restore-20260207-144223.sql.gz

=================================================
✨ Restauration terminée avec succès !
=================================================
```

## ⚙️ Configuration

### Paramètres modifiables dans les scripts :

```bash
# Namespace Kubernetes
NAMESPACE="plateforme-electronique"

# Label pour trouver le pod PostgreSQL
POD_LABEL="app=postgresql"

# Utilisateur PostgreSQL
DB_USER="plateforme_user"

# Nom de la base de données
DB_NAME="invoice_db"

# Répertoire des backups
BACKUP_DIR="$HOME/backups/plateforme-db"
```

## 🔍 Vérification du pod PostgreSQL

Pour vérifier manuellement le pod PostgreSQL :

```bash
# Lister les pods du namespace
kubectl get pods -n plateforme-electronique

# Voir les détails du pod PostgreSQL
kubectl describe pod postgresql-5df848d766-fdbq4 -n plateforme-electronique

# Se connecter au pod
kubectl exec -it postgresql-5df848d766-fdbq4 -n plateforme-electronique -- bash

# Se connecter à PostgreSQL
kubectl exec -it postgresql-5df848d766-fdbq4 -n plateforme-electronique -- psql -U plateforme_user -d invoice_db
```

## 🛠️ Différences avec la version Docker

| Aspect | Version Docker | Version Kubernetes |
|--------|---------------|-------------------|
| **Commande de base** | `docker exec` | `kubectl exec -n namespace` |
| **Identification** | Nom de conteneur fixe | Label + récupération dynamique du pod |
| **Namespace** | N/A | Requis (plateforme-electronique) |
| **Redémarrage pod** | Impact immédiat | Géré par Deployment |

## 📝 Principales modifications

1. **Découverte dynamique du pod** : 
   - Utilise `kubectl get pods -l app=postgresql` pour trouver le pod
   - Le nom du pod change à chaque redémarrage

2. **Namespace** :
   - Toutes les commandes incluent `-n plateforme-electronique`

3. **Vérification du statut** :
   - Vérifie que le pod est en état "Running"

4. **Compatibilité** :
   - Fonctionne avec Minikube, K3s, et autres distributions K8s

## ⚠️ Notes importantes

1. **Backup de sécurité** : Un backup automatique est créé avant chaque restauration
2. **Confirmation requise** : Vous devez taper 'OUI' pour confirmer la restauration
3. **Compression** : Les backups sont automatiquement compressés (.sql.gz)
4. **Rétention** : Les 10 derniers backups sont conservés automatiquement
5. **Permissions** : Vous devez avoir les permissions kubectl pour le namespace

## 🐛 Dépannage

### Erreur : "Aucun pod PostgreSQL trouvé"
```bash
# Vérifier les pods
kubectl get pods -n plateforme-electronique

# Vérifier les labels
kubectl get pods -n plateforme-electronique --show-labels
```

### Erreur : "Permission denied"
```bash
# Vérifier les permissions kubectl
kubectl auth can-i get pods -n plateforme-electronique
```

### Le pod PostgreSQL redémarre souvent
```bash
# Vérifier les logs
kubectl logs postgresql-5df848d766-fdbq4 -n plateforme-electronique

# Vérifier les événements
kubectl get events -n plateforme-electronique --sort-by='.lastTimestamp'
```

## 📚 Ressources

- Documentation PostgreSQL : https://www.postgresql.org/docs/
- Documentation Kubernetes : https://kubernetes.io/docs/
- Documentation kubectl : https://kubernetes.io/docs/reference/kubectl/

## 👤 Auteur

- Script original : yassmineg
- Adaptation Kubernetes : Nordine
- Date : 7 février 2026
