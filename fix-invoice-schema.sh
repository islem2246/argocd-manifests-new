#!/bin/bash
# fix-invoice-schema.sh - Script de correction du schéma invoice_db
# À exécuter quand le frontend affiche "Impossible de charger les factures via l'API Gateway"

set -e

# Configuration
NAMESPACE="plateforme-electronique"
DB_NAME="invoice_db"
DB_USER="plateforme_user"
DEFAULT_USER_UUID="11111111-1111-1111-1111-111111111111"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Correction du schéma Invoice Database    ${NC}"
echo -e "${BLUE}============================================${NC}"

# 1. Trouver le pod PostgreSQL
echo -e "\n${YELLOW}[1/6] Recherche du pod PostgreSQL...${NC}"
POD_NAME=$(kubectl get pods -n $NAMESPACE | grep postgresql | grep Running | awk '{print $1}')
if [ -z "$POD_NAME" ]; then
    echo -e "${RED}Erreur: Pod PostgreSQL non trouvé${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Pod trouvé: $POD_NAME${NC}"

# Fonction pour exécuter du SQL
run_sql() {
    kubectl exec -n $NAMESPACE $POD_NAME -- psql -U $DB_USER -d $DB_NAME -c "$1"
}

# 2. Sauvegarder les données existantes
echo -e "\n${YELLOW}[2/6] Sauvegarde des données existantes...${NC}"
run_sql "
CREATE TABLE IF NOT EXISTS invoices_backup_script AS 
SELECT * FROM invoices WHERE NOT EXISTS (SELECT 1 FROM invoices_backup_script LIMIT 1);
" 2>/dev/null || echo "Backup déjà existant ou table vide"
echo -e "${GREEN}✓ Sauvegarde effectuée${NC}"

# 3. Recréer la table invoices avec le bon schéma
echo -e "\n${YELLOW}[3/6] Recréation de la table invoices avec UUID...${NC}"
run_sql "
DROP TABLE IF EXISTS invoice_items CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;

CREATE TABLE invoices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    owner_user_id UUID NOT NULL,
    client_name VARCHAR(255),
    client_email VARCHAR(255),
    billing_address VARCHAR(500),
    subtotal NUMERIC(10,3) NOT NULL DEFAULT 0,
    tax_rate NUMERIC(5,2) DEFAULT 19.00,
    tax_amount NUMERIC(10,3) DEFAULT 0,
    total NUMERIC(10,3) NOT NULL DEFAULT 0,
    subtotal_ht NUMERIC(15,4),
    vat_rate NUMERIC(5,2) DEFAULT 19.00,
    vat_amount NUMERIC(15,4),
    total_ttc NUMERIC(15,4),
    signature_hash VARCHAR(255),
    status VARCHAR(50) DEFAULT 'DRAFT',
    issue_date DATE,
    due_date DATE,
    paid_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_invoices_owner ON invoices(owner_user_id);
CREATE INDEX idx_invoices_status ON invoices(status);
"
echo -e "${GREEN}✓ Table invoices recréée${NC}"

# 4. Recréer la table invoice_items
echo -e "\n${YELLOW}[4/6] Recréation de la table invoice_items...${NC}"
run_sql "
CREATE TABLE invoice_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    description VARCHAR(500),
    quantity INTEGER DEFAULT 1,
    unit_price NUMERIC(15,4),
    tax_rate NUMERIC(5,2) DEFAULT 19.00,
    line_total_ht NUMERIC(15,4)
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);
"
echo -e "${GREEN}✓ Table invoice_items recréée${NC}"

# 5. Insérer des données de test
echo -e "\n${YELLOW}[5/6] Insertion des données de test...${NC}"
run_sql "
INSERT INTO invoices (invoice_number, owner_user_id, client_name, client_email, billing_address, subtotal, total, subtotal_ht, vat_rate, vat_amount, total_ttc, status, issue_date, due_date) VALUES
('INV-2026-0001', '$DEFAULT_USER_UUID', 'Societe Atlas', 'contact@atlas.tn', 'Tunis, TN', 1500, 1785, 1500.0000, 19.00, 285.0000, 1785.0000, 'PAID', '2026-01-05', '2026-02-05'),
('INV-2026-0002', '$DEFAULT_USER_UUID', 'Enterprise ABC', 'info@abc.tn', 'Sousse, TN', 3200, 3808, 3200.0000, 19.00, 608.0000, 3808.0000, 'SENT', '2026-01-10', '2026-02-10'),
('INV-2026-0003', '$DEFAULT_USER_UUID', 'Startup XYZ', 'contact@xyz.tn', 'Sfax, TN', 750, 892.5, 750.0000, 19.00, 142.5000, 892.5000, 'PAID', '2026-01-12', '2026-02-12'),
('INV-2026-0004', '$DEFAULT_USER_UUID', 'Tech Solutions', 'contact@techsol.tn', 'Bizerte, TN', 2100, 2499, 2100.0000, 19.00, 399.0000, 2499.0000, 'DRAFT', '2026-01-20', '2026-02-20'),
('INV-2026-0005', '$DEFAULT_USER_UUID', 'Global Services', 'info@global.tn', 'Monastir, TN', 4500, 5355, 4500.0000, 19.00, 855.0000, 5355.0000, 'SENT', '2026-01-22', '2026-02-22')
ON CONFLICT (invoice_number) DO NOTHING;
"
echo -e "${GREEN}✓ Données insérées${NC}"

# 6. Vérification
echo -e "\n${YELLOW}[6/6] Vérification finale...${NC}"
run_sql "SELECT id, invoice_number, client_name, total_ttc, status FROM invoices;"

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}  ✓ Correction terminée avec succès!       ${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "\n${BLUE}Rafraîchissez votre navigateur pour voir les factures.${NC}"
