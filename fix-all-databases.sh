#!/bin/bash
# fix-all-databases.sh - Script de correction complète de toutes les bases de données
# Plateforme Électronique de Paiement
# À exécuter en cas d'erreurs de schéma (type mismatch integer/UUID, colonnes manquantes)

set -e

# Configuration
NAMESPACE="plateforme-electronique"
DB_USER="plateforme_user"
DEFAULT_USER_UUID="11111111-1111-1111-1111-111111111111"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() { echo -e "\n${YELLOW}[$1] $2${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Trouver le pod PostgreSQL
find_pod() {
    POD_NAME=$(kubectl get pods -n $NAMESPACE 2>/dev/null | grep postgresql | grep Running | awk '{print $1}')
    if [ -z "$POD_NAME" ]; then print_error "Pod PostgreSQL non trouvé"; exit 1; fi
    print_success "Pod trouvé: $POD_NAME"
}

# Fonction pour exécuter du SQL
run_sql() {
    local db=$1; local sql=$2
    kubectl exec -n $NAMESPACE $POD_NAME -- psql -U $DB_USER -d $db -c "$sql" 2>/dev/null
}

run_sql_quiet() {
    local db=$1; local sql=$2
    kubectl exec -n $NAMESPACE $POD_NAME -- psql -U $DB_USER -d $db -c "$sql" 2>/dev/null >/dev/null
}

print_header "CORRECTION COMPLÈTE DES BASES DE DONNÉES"
echo -e "${CYAN}Plateforme Électronique de Paiement${NC}"
echo -e "Date: $(date)"

# ÉTAPE 1: Trouver le pod PostgreSQL
print_step "1/7" "Recherche du pod PostgreSQL..."
find_pod

# ÉTAPE 2: Correction de INVOICE_DB
print_step "2/7" "Correction de invoice_db..."
run_sql "invoice_db" "
DROP TABLE IF EXISTS invoice_items CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS products CASCADE;

CREATE TABLE invoices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    owner_user_id UUID NOT NULL,
    client_name VARCHAR(255), client_email VARCHAR(255), billing_address VARCHAR(500),
    subtotal NUMERIC(10,3) NOT NULL DEFAULT 0, tax_rate NUMERIC(5,2) DEFAULT 19.00,
    tax_amount NUMERIC(10,3) DEFAULT 0, total NUMERIC(10,3) NOT NULL DEFAULT 0,
    subtotal_ht NUMERIC(15,4), vat_rate NUMERIC(5,2) DEFAULT 19.00,
    vat_amount NUMERIC(15,4), total_ttc NUMERIC(15,4), signature_hash VARCHAR(255),
    status VARCHAR(50) DEFAULT 'DRAFT', issue_date DATE, due_date DATE, paid_date DATE,
    notes TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE invoice_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    description VARCHAR(500), quantity INTEGER DEFAULT 1,
    unit_price NUMERIC(15,4), tax_rate NUMERIC(5,2) DEFAULT 19.00, line_total_ht NUMERIC(15,4)
);

CREATE TABLE products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_user_id UUID NOT NULL, name VARCHAR(255) NOT NULL, description TEXT,
    unit_price NUMERIC(15,4) NOT NULL, tax_rate NUMERIC(5,2) DEFAULT 19.00,
    category VARCHAR(100), active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_invoices_owner ON invoices(owner_user_id);
CREATE INDEX idx_invoices_status ON invoices(status);

INSERT INTO invoices (invoice_number, owner_user_id, client_name, client_email, billing_address, subtotal, total, subtotal_ht, vat_rate, vat_amount, total_ttc, status, issue_date, due_date) VALUES
('INV-2026-0001', '$DEFAULT_USER_UUID', 'Societe Atlas', 'contact@atlas.tn', 'Tunis, TN', 1500, 1785, 1500.0000, 19.00, 285.0000, 1785.0000, 'PAID', '2026-01-05', '2026-02-05'),
('INV-2026-0002', '$DEFAULT_USER_UUID', 'Enterprise ABC', 'info@abc.tn', 'Sousse, TN', 3200, 3808, 3200.0000, 19.00, 608.0000, 3808.0000, 'SENT', '2026-01-10', '2026-02-10'),
('INV-2026-0003', '$DEFAULT_USER_UUID', 'Startup XYZ', 'contact@xyz.tn', 'Sfax, TN', 750, 892.5, 750.0000, 19.00, 142.5000, 892.5000, 'PAID', '2026-01-12', '2026-02-12'),
('INV-2026-0004', '$DEFAULT_USER_UUID', 'Tech Solutions', 'contact@techsol.tn', 'Bizerte, TN', 2100, 2499, 2100.0000, 19.00, 399.0000, 2499.0000, 'DRAFT', '2026-01-20', '2026-02-20'),
('INV-2026-0005', '$DEFAULT_USER_UUID', 'Global Services', 'info@global.tn', 'Monastir, TN', 4500, 5355, 4500.0000, 19.00, 855.0000, 5355.0000, 'SENT', '2026-01-22', '2026-02-22');
"
print_success "invoice_db corrigée"

# ÉTAPE 3: Correction de PAYMENT_DB
print_step "3/7" "Correction de payment_db..."
run_sql "payment_db" "
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;

-- IMPORTANT: 'method' et 'reference' (pas 'payment_method' et 'payment_reference')
CREATE TABLE payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reference VARCHAR(100) UNIQUE NOT NULL,
    user_id UUID NOT NULL, invoice_id UUID,
    amount NUMERIC(15,4) NOT NULL, currency VARCHAR(3) DEFAULT 'TND',
    method VARCHAR(50) NOT NULL, status VARCHAR(50) DEFAULT 'PENDING',
    external_transaction_id VARCHAR(255), payment_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payment_methods (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL, type VARCHAR(50) NOT NULL, provider VARCHAR(100),
    last_four VARCHAR(4), expiry_date VARCHAR(7), is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_payments_status ON payments(status);

INSERT INTO payments (reference, user_id, amount, currency, method, status, payment_date) VALUES
('PAY-2026-0001', '$DEFAULT_USER_UUID', 1785.0000, 'TND', 'CARD', 'COMPLETED', '2026-01-06'),
('PAY-2026-0002', '$DEFAULT_USER_UUID', 892.5000, 'TND', 'CARD', 'COMPLETED', '2026-01-13'),
('PAY-2026-0003', '$DEFAULT_USER_UUID', 3808.0000, 'TND', 'BANK_TRANSFER', 'PENDING', NULL);
"
print_success "payment_db corrigée"

# ÉTAPE 4: Correction de SUBSCRIPTION_DB
print_step "4/7" "Correction de subscription_db..."
run_sql "subscription_db" "
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS plans CASCADE;

CREATE TABLE plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL, description TEXT, price NUMERIC(10,2) NOT NULL,
    price_monthly NUMERIC(10,2), price_annual NUMERIC(10,2), currency VARCHAR(3) DEFAULT 'TND',
    duration_months INTEGER NOT NULL DEFAULT 1, max_invoices_per_month INTEGER,
    max_transactions INTEGER, max_users INTEGER DEFAULT 1, api_access BOOLEAN DEFAULT false,
    signature_included BOOLEAN DEFAULT false, features JSONB, active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL, plan_id UUID REFERENCES plans(id),
    status VARCHAR(50) DEFAULT 'ACTIVE', start_date DATE NOT NULL, end_date DATE NOT NULL,
    auto_renew BOOLEAN DEFAULT true, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO plans (name, description, price, price_monthly, price_annual, duration_months, max_invoices_per_month, max_users, api_access, signature_included) VALUES
('Starter', 'Plan de démarrage', 29.00, 29.00, 290.00, 1, 50, 1, false, false),
('Professional', 'Plan professionnel', 79.00, 79.00, 790.00, 1, 200, 5, true, true),
('Enterprise', 'Plan entreprise', 199.00, 199.00, 1990.00, 1, NULL, NULL, true, true);

INSERT INTO subscriptions (user_id, plan_id, status, start_date, end_date, auto_renew)
SELECT '$DEFAULT_USER_UUID', id, 'ACTIVE', '2026-01-01', '2026-12-31', true FROM plans WHERE name = 'Professional';
"
print_success "subscription_db corrigée"

# ÉTAPE 5: Correction de NOTIFICATION_DB
print_step "5/7" "Correction de notification_db..."
run_sql "notification_db" "
DROP TABLE IF EXISTS notifications CASCADE;

CREATE TABLE notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL, type VARCHAR(50) NOT NULL, title VARCHAR(255) NOT NULL,
    message TEXT, status VARCHAR(50) DEFAULT 'UNREAD', sent_at TIMESTAMP,
    read_at TIMESTAMP, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO notifications (user_id, type, title, message, status, sent_at) VALUES
('$DEFAULT_USER_UUID', 'PAYMENT', 'Paiement reçu', 'Votre paiement de 1785 TND a été confirmé', 'READ', '2026-01-06 10:30:00'),
('$DEFAULT_USER_UUID', 'INVOICE', 'Nouvelle facture', 'La facture INV-2026-0005 a été créée', 'UNREAD', '2026-01-22 14:00:00'),
('$DEFAULT_USER_UUID', 'SYSTEM', 'Bienvenue', 'Bienvenue sur la plateforme!', 'READ', '2026-01-01 00:00:00');
"
print_success "notification_db corrigée"

# ÉTAPE 6: Correction de USER_AUTH_DB
print_step "6/7" "Correction de user_auth_db..."
run_sql "user_auth_db" "
DROP TABLE IF EXISTS refresh_tokens CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    keycloak_id VARCHAR(255) UNIQUE, email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100), first_name VARCHAR(100), last_name VARCHAR(100),
    phone VARCHAR(20), company_name VARCHAR(255), company_address TEXT, tax_id VARCHAR(50),
    role VARCHAR(50) DEFAULT 'USER', active BOOLEAN DEFAULT true, email_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

CREATE TABLE refresh_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL, expires_at TIMESTAMP NOT NULL, revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (id, email, username, first_name, last_name, phone, company_name, role, active, email_verified) VALUES
('$DEFAULT_USER_UUID', 'admin@plateforme.tn', 'admin', 'Amel', 'Dabbabi', '+216 71 000 000', 'Ocean Softwares & Technologies', 'ADMIN', true, true);
"
print_success "user_auth_db corrigée"

# ÉTAPE 7: Vérification finale
print_step "7/7" "Vérification finale..."
run_sql "invoice_db" "SELECT COUNT(*) as invoices FROM invoices;"
run_sql "payment_db" "SELECT COUNT(*) as payments FROM payments;"
run_sql "subscription_db" "SELECT COUNT(*) as plans FROM plans;"
run_sql "notification_db" "SELECT COUNT(*) as notifications FROM notifications;"
run_sql "user_auth_db" "SELECT COUNT(*) as users FROM users;"

print_header "CORRECTION TERMINÉE AVEC SUCCÈS"
echo -e "${GREEN}Toutes les bases de données ont été corrigées.${NC}"
echo -e "${YELLOW}UUID utilisateur: $DEFAULT_USER_UUID${NC}"
echo -e "\n${BLUE}Rafraîchir le navigateur pour voir les données.${NC}"
