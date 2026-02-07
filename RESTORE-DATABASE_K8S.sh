#!/bin/bash

# Script de restauration de la base de données PostgreSQL pour Kubernetes
# Auteur: yassmineg (adapté pour K8s par Nordine)
# Date: 7 février 2026

echo "🔄 Restauration de la Base de Données PostgreSQL (Kubernetes)"
echo "=============================================================="
echo ""

# Configuration
NAMESPACE="plateforme-electronique"
POD_LABEL="app=postgresql"
DB_USER="plateforme_user"
DB_NAME="invoice_db"
BACKUP_DIR="$HOME/backups/plateforme-db"

# Fonction pour obtenir le nom du pod PostgreSQL
get_postgres_pod() {
    kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Vérifier que kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo "❌ Erreur: kubectl n'est pas installé"
    exit 1
fi

# Vérifier que le namespace existe
echo "🔍 Vérification du namespace..."
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "❌ Erreur: Le namespace $NAMESPACE n'existe pas"
    exit 1
fi
echo "✅ Namespace trouvé"
echo ""

# Récupérer le nom du pod PostgreSQL
echo "🔍 Recherche du pod PostgreSQL..."
POD_NAME=$(get_postgres_pod)

if [ -z "$POD_NAME" ]; then
    echo "❌ Erreur: Aucun pod PostgreSQL trouvé avec le label $POD_LABEL"
    echo "   Pods disponibles dans le namespace:"
    kubectl get pods -n "$NAMESPACE"
    exit 1
fi

# Vérifier que le pod est en cours d'exécution
POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Erreur: Le pod $POD_NAME n'est pas en état Running (état: $POD_STATUS)"
    exit 1
fi

echo "✅ Pod PostgreSQL actif: $POD_NAME"
echo ""

# Si un fichier de backup est passé en argument
if [ -n "$1" ]; then
    BACKUP_FILE="$1"
else
    # Lister les backups disponibles
    echo "📂 Backups disponibles:"
    echo ""

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        echo "❌ Aucun backup trouvé dans $BACKUP_DIR"
        echo "   Créez d'abord un backup avec: ./BACKUP-DATABASE-K8S.sh"
        exit 1
    fi

    # Afficher les backups avec numéro
    FILES=()
    i=1
    for file in "$BACKUP_DIR"/*.sql.gz "$BACKUP_DIR"/*.sql; do
        if [ -f "$file" ]; then
            SIZE=$(du -h "$file" | cut -f1)
            DATE=$(stat -c %y "$file" 2>/dev/null || stat -f "%Sm" "$file")
            echo "   [$i] $(basename $file) - $SIZE - $DATE"
            FILES+=("$file")
            ((i++))
        fi
    done

    echo ""
    echo "Entrez le numéro du backup à restaurer (ou 'q' pour quitter):"
    read -r CHOICE

    if [[ "$CHOICE" =~ ^[Qq]$ ]]; then
        echo "Annulé."
        exit 0
    fi

    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#FILES[@]}" ]; then
        echo "❌ Choix invalide"
        exit 1
    fi

    BACKUP_FILE="${FILES[$((CHOICE-1))]}"
fi

# Vérifier que le fichier existe
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Erreur: Fichier introuvable: $BACKUP_FILE"
    exit 1
fi

echo ""
echo "📋 Informations de restauration:"
echo "   Pod:     $POD_NAME"
echo "   Fichier: $BACKUP_FILE"
echo "   Taille:  $(du -h "$BACKUP_FILE" | cut -f1)"
echo "   Base:    $DB_NAME"
echo ""

# Avertissement
echo "⚠️  ATTENTION !"
echo "   Cette opération va ÉCRASER toutes les données actuelles"
echo "   de la base de données '$DB_NAME'"
echo ""
echo "Voulez-vous continuer? (tapez 'OUI' en majuscules pour confirmer)"
read -r CONFIRM

if [ "$CONFIRM" != "OUI" ]; then
    echo "Annulé."
    exit 0
fi

# Créer le répertoire de backup s'il n'existe pas
mkdir -p "$BACKUP_DIR"

# Créer un backup de sécurité avant la restauration
echo ""
echo "💾 Création d'un backup de sécurité avant restauration..."
SAFETY_BACKUP="$BACKUP_DIR/safety-backup-before-restore-$(date +%Y%m%d-%H%M%S).sql.gz"

kubectl exec -n "$NAMESPACE" "$POD_NAME" -- pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip > "$SAFETY_BACKUP"

if [ $? -eq 0 ]; then
    echo "✅ Backup de sécurité créé: $SAFETY_BACKUP"
else
    echo "⚠️  Avertissement: Impossible de créer le backup de sécurité"
    echo "   Voulez-vous continuer quand même? (tapez 'OUI' pour confirmer)"
    read -r CONFIRM2
    if [ "$CONFIRM2" != "OUI" ]; then
        echo "Annulé."
        exit 0
    fi
fi
echo ""

# Décompresser si nécessaire
TEMP_FILE=""
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "🗜️  Décompression du backup..."
    TEMP_FILE="/tmp/restore-$(basename "$BACKUP_FILE" .gz)"
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    RESTORE_FILE="$TEMP_FILE"
else
    RESTORE_FILE="$BACKUP_FILE"
fi

# Restauration
echo "⏳ Restauration en cours..."
echo ""

# Supprimer et recréer la base
echo "🗑️  Suppression de la base existante..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"

if [ $? -ne 0 ]; then
    echo "❌ Erreur lors de la suppression de la base"
    [ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    exit 1
fi

echo "📦 Création d'une nouvelle base..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"

if [ $? -ne 0 ]; then
    echo "❌ Erreur lors de la création de la base"
    [ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    exit 1
fi

echo "📥 Restauration des données..."
kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" -d "$DB_NAME" < "$RESTORE_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================="
    echo "✅ Restauration réussie !"
    echo "================================================="
    echo ""

    # Vérifier les données restaurées
    echo "📊 Vérification des données restaurées:"
    echo ""

    # Compter les factures
    FACTURES_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM factures;" 2>/dev/null | tr -d ' \n\r')

    if [ ! -z "$FACTURES_COUNT" ]; then
        echo "   ✅ Factures restaurées: $FACTURES_COUNT"
    fi

    # Compter les clients
    CLIENTS_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM clients;" 2>/dev/null | tr -d ' \n\r')

    if [ ! -z "$CLIENTS_COUNT" ]; then
        echo "   ✅ Clients restaurés: $CLIENTS_COUNT"
    fi

    echo ""
    if [ -f "$SAFETY_BACKUP" ]; then
        echo "💾 Backup de sécurité conservé: $SAFETY_BACKUP"
    fi
    echo ""

else
    echo "❌ Erreur lors de la restauration"
    echo ""
    if [ -f "$SAFETY_BACKUP" ]; then
        echo "💾 Vos données sont toujours dans le backup de sécurité:"
        echo "   $SAFETY_BACKUP"
    fi

    # Nettoyer
    [ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    exit 1
fi

# Nettoyer le fichier temporaire
[ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"

echo "================================================="
echo "✨ Restauration terminée avec succès !"
echo "================================================="
