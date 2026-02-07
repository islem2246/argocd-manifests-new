#!/bin/bash
# inject-all-data.sh - Injection automatique de toutes les données dans la base
# Détection automatique des noms de pods

set -e

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

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  INJECTION COMPLÈTE DES DONNÉES${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Trouver automatiquement le pod PostgreSQL
echo -e "\n${YELLOW}[1/8] Recherche du pod PostgreSQL...${NC}"
POSTGRES_POD=$(kubectl get pods -n $NAMESPACE | grep postgresql | grep Running | awk '{print $1}')

if [ -z "$POSTGRES_POD" ]; then
    echo -e "${RED}✗ Pod PostgreSQL non trouvé ou non running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Pod PostgreSQL trouvé: $POSTGRES_POD${NC}"

# Fonction pour exécuter du SQL
run_sql() {
    local db=$1
    local sql=$2
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U $DB_USER -d $db -c "$sql" 2>/dev/null
}

# ÉTAPE 2: USER_AUTH_DB
echo -e "\n${YELLOW}[2/8] Injection des données dans user_auth_db...${NC}"
run_sql "user_auth_db" "
DROP TABLE IF EXISTS refresh_tokens CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    keycloak_id VARCHAR(255) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    company_name VARCHAR(255),
    company_address TEXT,
    tax_id VARCHAR(50),
    role VARCHAR(50) DEFAULT 'USER',
    active BOOLEAN DEFAULT true,
    email_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

CREATE TABLE refresh_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (id, email, username, first_name, last_name, phone, company_name, role, active, email_verified) VALUES
('$DEFAULT_USER_UUID', 'admin@plateforme.tn', 'admin', 'Amel', 'Dabbabi', '+216 71 000 000', 'Ocean Softwares & Technologies', 'ADMIN', true, true);
"
echo -e "${GREEN}✓ user_auth_db - OK (1 utilisateur créé)${NC}"

# ÉTAPE 3: INVOICE_DB
echo -e "\n${YELLOW}[3/8] Injection des données dans invoice_db...${NC}"
run_sql "invoice_db" "
DROP TABLE IF EXISTS invoice_items CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS products CASCADE;

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

CREATE TABLE invoice_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    description VARCHAR(500),
    quantity INTEGER DEFAULT 1,
    unit_price NUMERIC(15,4),
    tax_rate NUMERIC(5,2) DEFAULT 19.00,
    line_total_ht NUMERIC(15,4)
);

CREATE TABLE products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_user_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    unit_price NUMERIC(15,4) NOT NULL,
    tax_rate NUMERIC(5,2) DEFAULT 19.00,
    category VARCHAR(100),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
echo -e "${GREEN}✓ invoice_db - OK (5 factures créées)${NC}"

# ÉTAPE 4: PAYMENT_DB
echo -e "\n${YELLOW}[4/8] Injection des données dans payment_db...${NC}"
run_sql "payment_db" "
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;

CREATE TABLE payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reference VARCHAR(100) UNIQUE NOT NULL,
    user_id UUID NOT NULL,
    invoice_id UUID,
    amount NUMERIC(15,4) NOT NULL,
    currency VARCHAR(3) DEFAULT 'TND',
    method VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING',
    external_transaction_id VARCHAR(255),
    payment_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payment_methods (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    provider VARCHAR(100),
    last_four VARCHAR(4),
    expiry_date VARCHAR(7),
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_payments_status ON payments(status);

INSERT INTO payments (reference, user_id, amount, currency, method, status, payment_date) VALUES
('PAY-2026-0001', '$DEFAULT_USER_UUID', 1785.0000, 'TND', 'CARD', 'COMPLETED', '2026-01-06'),
('PAY-2026-0002', '$DEFAULT_USER_UUID', 892.5000, 'TND', 'CARD', 'COMPLETED', '2026-01-13'),
('PAY-2026-0003', '$DEFAULT_USER_UUID', 3808.0000, 'TND', 'BANK_TRANSFER', 'PENDING', NULL);
"
echo -e "${GREEN}✓ payment_db - OK (3 paiements créés)${NC}"

# ÉTAPE 5: SUBSCRIPTION_DB
echo -e "\n${YELLOW}[5/8] Injection des données dans subscription_db...${NC}"
run_sql "subscription_db" "
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS plans CASCADE;

CREATE TABLE plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL,
    price_monthly NUMERIC(10,2),
    price_annual NUMERIC(10,2),
    currency VARCHAR(3) DEFAULT 'TND',
    duration_months INTEGER NOT NULL DEFAULT 1,
    max_invoices_per_month INTEGER,
    max_transactions INTEGER,
    max_users INTEGER DEFAULT 1,
    api_access BOOLEAN DEFAULT false,
    signature_included BOOLEAN DEFAULT false,
    features JSONB,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    plan_id UUID REFERENCES plans(id),
    status VARCHAR(50) DEFAULT 'ACTIVE',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    auto_renew BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO plans (name, description, price, price_monthly, price_annual, duration_months, max_invoices_per_month, max_users, api_access, signature_included) VALUES
('Starter', 'Plan de démarrage', 29.00, 29.00, 290.00, 1, 50, 1, false, false),
('Professional', 'Plan professionnel', 79.00, 79.00, 790.00, 1, 200, 5, true, true),
('Enterprise', 'Plan entreprise', 199.00, 199.00, 1990.00, 1, NULL, NULL, true, true);

INSERT INTO subscriptions (user_id, plan_id, status, start_date, end_date, auto_renew)
SELECT '$DEFAULT_USER_UUID', id, 'ACTIVE', '2026-01-01', '2026-12-31', true FROM plans WHERE name = 'Professional';
"
echo -e "${GREEN}✓ subscription_db - OK (3 plans + 1 souscription créés)${NC}"

# ÉTAPE 6: NOTIFICATION_DB
echo -e "\n${YELLOW}[6/8] Injection des données dans notification_db...${NC}"
run_sql "notification_db" "
DROP TABLE IF EXISTS notifications CASCADE;

CREATE TABLE notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    status VARCHAR(50) DEFAULT 'UNREAD',
    sent_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO notifications (user_id, type, title, message, status, sent_at) VALUES
('$DEFAULT_USER_UUID', 'PAYMENT', 'Paiement reçu', 'Votre paiement de 1785 TND a été confirmé', 'READ', '2026-01-06 10:30:00'),
('$DEFAULT_USER_UUID', 'INVOICE', 'Nouvelle facture', 'La facture INV-2026-0005 a été créée', 'UNREAD', '2026-01-22 14:00:00'),
('$DEFAULT_USER_UUID', 'SYSTEM', 'Bienvenue', 'Bienvenue sur la plateforme!', 'READ', '2026-01-01 00:00:00');
"
echo -e "${GREEN}✓ notification_db - OK (3 notifications créées)${NC}"

# ÉTAPE 7: Vérification des données
echo -e "\n${YELLOW}[7/8] Vérification des données injectées...${NC}"

echo -e "\n${CYAN}📊 Résumé des données:${NC}"
run_sql "user_auth_db" "SELECT COUNT(*) as users FROM users;" | tail -3
run_sql "invoice_db" "SELECT COUNT(*) as invoices FROM invoices;" | tail -3
run_sql "payment_db" "SELECT COUNT(*) as payments FROM payments;" | tail -3
run_sql "subscription_db" "SELECT COUNT(*) as plans FROM plans;" | tail -3
run_sql "notification_db" "SELECT COUNT(*) as notifications FROM notifications;" | tail -3

echo -e "\n${CYAN}📄 Aperçu des factures:${NC}"
run_sql "invoice_db" "SELECT invoice_number, client_name, status, total_ttc FROM invoices ORDER BY created_at;"

# ÉTAPE 8: Redémarrage des services
echo -e "\n${YELLOW}[8/8] Redémarrage des services backend...${NC}"

kubectl rollout restart deployment api-gateway -n $NAMESPACE 2>/dev/null && echo -e "${GREEN}✓ API Gateway redémarré${NC}" || echo -e "${YELLOW}⚠ API Gateway non trouvé${NC}"
kubectl rollout restart deployment invoice-service -n $NAMESPACE 2>/dev/null && echo -e "${GREEN}✓ Invoice Service redémarré${NC}" || echo -e "${YELLOW}⚠ Invoice Service non trouvé${NC}"
kubectl rollout restart deployment payment-service -n $NAMESPACE 2>/dev/null && echo -e "${GREEN}✓ Payment Service redémarré${NC}" || echo -e "${YELLOW}⚠ Payment Service non trouvé${NC}"
kubectl rollout restart deployment frontend -n $NAMESPACE 2>/dev/null && echo -e "${GREEN}✓ Frontend redémarré${NC}" || echo -e "${YELLOW}⚠ Frontend non trouvé${NC}"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ INJECTION TERMINÉE AVEC SUCCÈS!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}UUID utilisateur par défaut: $DEFAULT_USER_UUID${NC}"
echo -e "${CYAN}Email: admin@plateforme.tn${NC}"
echo -e "\n${YELLOW}⏱️  Attendez 30-60 secondes que les pods redémarrent...${NC}"
echo -e "${CYAN}Puis rafraîchissez votre navigateur (F5)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
