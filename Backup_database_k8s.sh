#!/bin/bash

# Script de sauvegarde de la base de données PostgreSQL pour Kubernetes
# Auteur: yassmineg (adapté pour K8s par Nordine)
# Date: 7 février 2026

echo "💾 Sauvegarde de la Base de Données PostgreSQL (Kubernetes)"
echo "==========================================================="
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

# Créer le répertoire de backup s'il n'existe pas
mkdir -p "$BACKUP_DIR"

# Nom du fichier de backup avec timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup-$DB_NAME-$TIMESTAMP.sql.gz"

echo "📋 Informations de sauvegarde:"
echo "   Pod:        $POD_NAME"
echo "   Namespace:  $NAMESPACE"
echo "   Base:       $DB_NAME"
echo "   Fichier:    $BACKUP_FILE"
echo ""

# Vérifier les statistiques de la base avant le backup
echo "📊 Statistiques de la base:"
echo ""

# Compter les factures
FACTURES_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM factures;" 2>/dev/null | tr -d ' \n\r')

if [ ! -z "$FACTURES_COUNT" ]; then
    echo "   📄 Factures: $FACTURES_COUNT"
fi

# Compter les clients
CLIENTS_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM clients;" 2>/dev/null | tr -d ' \n\r')

if [ ! -z "$CLIENTS_COUNT" ]; then
    echo "   👥 Clients: $CLIENTS_COUNT"
fi

# Taille de la base
DB_SIZE=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null | tr -d ' \n\r')

if [ ! -z "$DB_SIZE" ]; then
    echo "   💽 Taille: $DB_SIZE"
fi

echo ""

# Effectuer le backup
echo "⏳ Sauvegarde en cours..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================="
    echo "✅ Sauvegarde réussie !"
    echo "================================================="
    echo ""
    echo "📦 Fichier de backup:"
    echo "   $BACKUP_FILE"
    echo "   Taille: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo ""
    
    # Lister les backups existants
    echo "📂 Backups disponibles:"
    echo ""
    ls -lh "$BACKUP_DIR" | tail -n +2 | awk '{printf "   %s %s %s\n", $9, $5, $6" "$7" "$8}'
    echo ""
    
    # Nettoyage automatique (garder les 10 derniers backups)
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/backup-*.sql.gz 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 10 ]; then
        echo "🧹 Nettoyage des anciens backups (conservation des 10 derniers)..."
        ls -t "$BACKUP_DIR"/backup-*.sql.gz | tail -n +11 | xargs rm -f
        echo "✅ Nettoyage effectué"
        echo ""
    fi
    
    echo "================================================="
    echo "✨ Sauvegarde terminée avec succès !"
    echo "================================================="
else
    echo ""
    echo "❌ Erreur lors de la sauvegarde"
    rm -f "$BACKUP_FILE"
    exit 1
fi
