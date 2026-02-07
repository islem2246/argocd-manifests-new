#!/bin/bash
# check-logs-and-connectivity.sh - Vérifier les logs et la connectivité

NAMESPACE="plateforme-electronique"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VÉRIFICATION DES LOGS ET CONNECTIVITÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Vérifier les services
echo -e "\n[1/5] Services disponibles:"
kubectl get svc -n $NAMESPACE

# 2. Logs API Gateway
echo -e "\n[2/5] Logs de l'API Gateway (dernières 30 lignes):"
kubectl logs -n $NAMESPACE api-gateway-8585567547-jr968 --tail=30

# 3. Logs Invoice Service
echo -e "\n[3/5] Logs du Invoice Service (dernières 30 lignes):"
kubectl logs -n $NAMESPACE invoice-service-979654d8f-8slqr --tail=30

# 4. Logs Frontend
echo -e "\n[4/5] Logs du Frontend (dernières 30 lignes):"
kubectl logs -n $NAMESPACE frontend-fdcc44598-sfdpx --tail=30

# 5. Tester la base de données
echo -e "\n[5/5] Vérification des factures dans la base:"
kubectl exec -n $NAMESPACE postgresql-5df848d766-fdbq4 -- psql -U plateforme_user -d invoice_db -c "SELECT invoice_number, client_name, status, total FROM invoices;"

echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Vérification terminée"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
