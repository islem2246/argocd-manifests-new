#!/bin/bash

#===============================================================================
# SCRIPT DE DÉPLOIEMENT - PLATEFORME ÉLECTRONIQUE
# Auteur: Nordine Grassa
# Date: 2026-01-29
# Description: Déploie la plateforme électronique sur Minikube avec ArgoCD
#===============================================================================

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/ngrassa/argocd-manifests.git"
NAMESPACE="plateforme-electronique"
ARGOCD_NAMESPACE="argocd"
APP_NAME="plateforme-electronique"

#===============================================================================
# FONCTIONS UTILITAIRES
#===============================================================================

print_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${BLUE}[ÉTAPE]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}    Attente des pods ($label) dans $namespace...${NC}"
    kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout="${timeout}s" 2>/dev/null || {
        print_warning "Timeout atteint, vérification manuelle requise"
        return 1
    }
    print_success "Pods prêts!"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 n'est pas installé!"
        return 1
    fi
    print_success "$1 est disponible"
}

#===============================================================================
# VÉRIFICATION DES PRÉREQUIS
#===============================================================================

print_header "VÉRIFICATION DES PRÉREQUIS"

print_step "Vérification des outils..."
check_command kubectl
check_command minikube

print_step "Vérification de Minikube..."
if minikube status | grep -q "Running"; then
    print_success "Minikube est en cours d'exécution"
else
    print_error "Minikube n'est pas démarré!"
    echo "Démarrer avec: minikube start --cpus=4 --memory=8192"
    exit 1
fi

# Afficher les infos du cluster
echo -e "\n${CYAN}Informations du cluster:${NC}"
kubectl cluster-info | head -2

#===============================================================================
# ACTIVATION DES ADDONS MINIKUBE
#===============================================================================

print_header "CONFIGURATION DE MINIKUBE"

print_step "Activation des addons nécessaires..."

# Ingress addon pour Minikube (plus simple que nginx-ingress externe)
if minikube addons list | grep -q "ingress.*enabled"; then
    print_success "Addon ingress déjà activé"
else
    print_step "Activation de l'addon ingress..."
    minikube addons enable ingress
    print_success "Addon ingress activé"
fi

# Storage provisioner (pour les PVC)
if minikube addons list | grep -q "storage-provisioner.*enabled"; then
    print_success "Addon storage-provisioner déjà activé"
else
    print_step "Activation de l'addon storage-provisioner..."
    minikube addons enable storage-provisioner
    print_success "Addon storage-provisioner activé"
fi

# Default storageclass
if minikube addons list | grep -q "default-storageclass.*enabled"; then
    print_success "Addon default-storageclass déjà activé"
else
    print_step "Activation de l'addon default-storageclass..."
    minikube addons enable default-storageclass
    print_success "Addon default-storageclass activé"
fi

# Metrics server (optionnel mais utile)
if minikube addons list | grep -q "metrics-server.*enabled"; then
    print_success "Addon metrics-server déjà activé"
else
    print_step "Activation de l'addon metrics-server..."
    minikube addons enable metrics-server
    print_success "Addon metrics-server activé"
fi

#===============================================================================
# INSTALLATION D'ARGOCD
#===============================================================================

print_header "INSTALLATION D'ARGOCD"

# Vérifier si ArgoCD est déjà installé
if kubectl get namespace "$ARGOCD_NAMESPACE" &> /dev/null; then
    print_warning "Le namespace $ARGOCD_NAMESPACE existe déjà"
    
    if kubectl get pods -n "$ARGOCD_NAMESPACE" 2>/dev/null | grep -q "argocd-server"; then
        print_success "ArgoCD semble déjà installé"
    else
        print_step "Installation d'ArgoCD dans le namespace existant..."
        kubectl apply -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    fi
else
    print_step "Création du namespace ArgoCD..."
    kubectl create namespace "$ARGOCD_NAMESPACE"
    
    print_step "Installation d'ArgoCD..."
    kubectl apply -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    print_success "ArgoCD installé"
fi

print_step "Attente du démarrage d'ArgoCD..."
sleep 10
wait_for_pods "$ARGOCD_NAMESPACE" "app.kubernetes.io/name=argocd-server" 180

#===============================================================================
# CONFIGURATION D'ARGOCD
#===============================================================================

print_header "CONFIGURATION D'ARGOCD"

# Récupérer le mot de passe initial
print_step "Récupération du mot de passe admin ArgoCD..."
ARGOCD_PASSWORD=""
for i in {1..30}; do
    ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d) && break
    sleep 2
done

if [ -z "$ARGOCD_PASSWORD" ]; then
    print_warning "Impossible de récupérer le mot de passe automatiquement"
    echo "Récupérez-le manuellement avec:"
    echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
else
    print_success "Mot de passe récupéré"
fi

#===============================================================================
# CRÉATION DU NAMESPACE DE L'APPLICATION
#===============================================================================

print_header "PRÉPARATION DU NAMESPACE"

if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_warning "Le namespace $NAMESPACE existe déjà"
else
    print_step "Création du namespace $NAMESPACE..."
    kubectl create namespace "$NAMESPACE"
    print_success "Namespace créé"
fi

# Labelliser le namespace pour ArgoCD
kubectl label namespace "$NAMESPACE" app.kubernetes.io/managed-by=argocd --overwrite

#===============================================================================
# DÉPLOIEMENT DE L'APPLICATION ARGOCD
#===============================================================================

print_header "DÉPLOIEMENT DE L'APPLICATION"

print_step "Création de l'application ArgoCD..."

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: ${ARGOCD_NAMESPACE}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

print_success "Application ArgoCD créée"

#===============================================================================
# SYNCHRONISATION
#===============================================================================

print_header "SYNCHRONISATION DE L'APPLICATION"

print_step "Déclenchement de la synchronisation..."

# Attendre que l'application soit créée
sleep 5

# Vérifier si argocd CLI est disponible pour sync manuel
if command -v argocd &> /dev/null; then
    print_step "ArgoCD CLI détecté, tentative de sync..."
    # Le sync automatique devrait fonctionner, mais on peut forcer
else
    print_warning "ArgoCD CLI non installé - la synchronisation automatique est activée"
    echo "Pour installer ArgoCD CLI: brew install argocd (Mac) ou voir https://argo-cd.readthedocs.io/en/stable/cli_installation/"
fi

# Attendre la synchronisation
print_step "Attente de la synchronisation (peut prendre quelques minutes)..."
echo ""

# Boucle de vérification du statut
for i in {1..60}; do
    SYNC_STATUS=$(kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    HEALTH_STATUS=$(kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    
    echo -ne "\r    Sync: ${YELLOW}${SYNC_STATUS}${NC} | Health: ${YELLOW}${HEALTH_STATUS}${NC} | Tentative: $i/60    "
    
    if [ "$SYNC_STATUS" == "Synced" ] && [ "$HEALTH_STATUS" == "Healthy" ]; then
        echo ""
        print_success "Application synchronisée et en bonne santé!"
        break
    fi
    
    if [ "$SYNC_STATUS" == "Synced" ]; then
        echo ""
        print_success "Synchronisation terminée"
        print_warning "En attente que tous les pods soient prêts..."
    fi
    
    sleep 10
done

echo ""

#===============================================================================
# VÉRIFICATION DU DÉPLOIEMENT
#===============================================================================

print_header "VÉRIFICATION DU DÉPLOIEMENT"

print_step "État des pods dans $NAMESPACE:"
echo ""
kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || print_warning "Aucun pod trouvé encore"

echo ""
print_step "État des services:"
echo ""
kubectl get svc -n "$NAMESPACE" 2>/dev/null || print_warning "Aucun service trouvé encore"

echo ""
print_step "État des PVC:"
echo ""
kubectl get pvc -n "$NAMESPACE" 2>/dev/null || print_warning "Aucun PVC trouvé encore"

echo ""
print_step "État de l'Ingress:"
echo ""
kubectl get ingress -n "$NAMESPACE" 2>/dev/null || print_warning "Aucun ingress trouvé encore"

#===============================================================================
# CONFIGURATION DES ACCÈS
#===============================================================================

print_header "CONFIGURATION DES ACCÈS"

# Récupérer l'IP de Minikube
MINIKUBE_IP=$(minikube ip)
print_success "IP Minikube: $MINIKUBE_IP"

echo ""
print_step "Ajoutez ces lignes à votre /etc/hosts:"
echo ""
echo -e "${YELLOW}# Plateforme Électronique${NC}"
echo -e "${GREEN}${MINIKUBE_IP}  plateforme.local${NC}"
echo -e "${GREEN}${MINIKUBE_IP}  auth.plateforme.local${NC}"
echo -e "${GREEN}${MINIKUBE_IP}  eureka.plateforme.local${NC}"
echo ""

# Commande pour ajouter automatiquement (optionnel)
echo -e "${CYAN}Ou exécutez cette commande (nécessite sudo):${NC}"
echo ""
echo "sudo bash -c 'echo \"${MINIKUBE_IP}  plateforme.local auth.plateforme.local eureka.plateforme.local\" >> /etc/hosts'"
echo ""

#===============================================================================
# ACCÈS À ARGOCD UI
#===============================================================================

print_header "ACCÈS À ARGOCD UI"

echo -e "${CYAN}Pour accéder à l'interface ArgoCD:${NC}"
echo ""
echo "1. Dans un terminal séparé, lancez:"
echo -e "   ${GREEN}kubectl port-forward svc/argocd-server -n argocd 8443:443${NC}"
echo ""
echo "2. Ouvrez: ${GREEN}https://localhost:8443${NC}"
echo ""
echo "3. Connectez-vous avec:"
echo -e "   Username: ${GREEN}admin${NC}"
if [ -n "$ARGOCD_PASSWORD" ]; then
    echo -e "   Password: ${GREEN}${ARGOCD_PASSWORD}${NC}"
else
    echo -e "   Password: ${YELLOW}(récupérez-le avec la commande ci-dessus)${NC}"
fi
echo ""

#===============================================================================
# ACCÈS À L'APPLICATION
#===============================================================================

print_header "ACCÈS À L'APPLICATION"

echo -e "${CYAN}URLs de l'application (après configuration /etc/hosts):${NC}"
echo ""
echo -e "  Frontend:  ${GREEN}http://plateforme.local${NC}"
echo -e "  API:       ${GREEN}http://plateforme.local/api${NC}"
echo -e "  Keycloak:  ${GREEN}http://auth.plateforme.local${NC}"
echo -e "  Eureka:    ${GREEN}http://eureka.plateforme.local${NC}"
echo ""

echo -e "${CYAN}Alternative avec minikube tunnel (dans un autre terminal):${NC}"
echo ""
echo -e "  ${GREEN}minikube tunnel${NC}"
echo ""

echo -e "${CYAN}Pour tester rapidement sans /etc/hosts:${NC}"
echo ""
echo -e "  ${GREEN}minikube service frontend -n ${NAMESPACE}${NC}"
echo ""

#===============================================================================
# COMMANDES UTILES
#===============================================================================

print_header "COMMANDES UTILES"

echo -e "${CYAN}Surveillance:${NC}"
echo "  kubectl get pods -n $NAMESPACE -w"
echo "  kubectl logs -f deployment/api-gateway -n $NAMESPACE"
echo ""

echo -e "${CYAN}Dépannage:${NC}"
echo "  kubectl describe pod <pod-name> -n $NAMESPACE"
echo "  kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo ""

echo -e "${CYAN}ArgoCD:${NC}"
echo "  kubectl get application $APP_NAME -n argocd -o yaml"
echo "  kubectl patch application $APP_NAME -n argocd --type merge -p '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{}}}'"
echo ""

echo -e "${CYAN}Nettoyage complet:${NC}"
echo "  kubectl delete application $APP_NAME -n argocd"
echo "  kubectl delete namespace $NAMESPACE"
echo ""

#===============================================================================
# FIN
#===============================================================================

print_header "DÉPLOIEMENT TERMINÉ"

echo -e "${GREEN}La plateforme électronique est en cours de déploiement via ArgoCD!${NC}"
echo ""
echo -e "${YELLOW}Note: Les premiers démarrages peuvent prendre 3-5 minutes${NC}"
echo -e "${YELLOW}      le temps que PostgreSQL initialise les bases de données.${NC}"
echo ""
echo -e "Surveillez la progression avec: ${CYAN}kubectl get pods -n $NAMESPACE -w${NC}"
echo ""
