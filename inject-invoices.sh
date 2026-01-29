#!/bin/bash
# inject-invoices.sh

NAMESPACE="plateforme-electronique"
POD=$(kubectl get pods -n $NAMESPACE | grep postgresql | awk '{print $1}')
DB="invoice_db"
USER="plateforme_user"

echo "=== Injection des données dans $DB ==="

kubectl exec -it $POD -n $NAMESPACE -- psql -U $USER -d $DB -c "
INSERT INTO invoices (invoice_number, user_id, subtotal, total, client_name, client_email, billing_address, status, issue_date, due_date) VALUES
('INV-2026-0006', 1, 1200.000, 1428.000, 'New Client', 'new@client.tn', 'Gabes, TN', 'DRAFT', '2026-01-25', '2026-02-25')
ON CONFLICT (invoice_number) DO NOTHING;
"

echo "=== Vérification ==="
kubectl exec -it $POD -n $NAMESPACE -- psql -U $USER -d $DB -c "SELECT invoice_number, client_name, total, status FROM invoices;"
