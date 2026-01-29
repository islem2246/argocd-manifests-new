# Plateforme Électronique - Manifests Kubernetes Corrigés

## 📋 Corrections apportées

| Fichier | Correction |
|---------|------------|
| `postgres-init-configmap.yaml` | Ajout de `notification_db` |
| `postgres-pvc.yaml` | storageClassName: standard (compatible provisioner dynamique) |
| `redis-pvc.yaml` | storageClassName: standard (compatible provisioner dynamique) |
| `api-gateway-deployment.yaml` | Ajout des routes pour tous les services |
| `*-service.yaml` | Changement LoadBalancer → ClusterIP |
| `ingress.yaml` | **NOUVEAU** - Ingress pour accès externe |
| `namespace.yaml` | **NOUVEAU** - Namespace dédié |
| `kustomization.yaml` | Ajout namespace + suppression PV |
| `argocd-application.yaml` | **NOUVEAU** - Configuration ArgoCD |
| `postgres-seed-configmap.yaml` | Ajout données pour notification_db |
| Plusieurs deployments | Ajout de readinessProbe et livenessProbe |

## 🚀 Déploiement avec ArgoCD

### Prérequis

```bash
# 1. Installer Nginx Ingress Controller (si pas déjà fait)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# 2. Vérifier que ArgoCD est installé
kubectl get pods -n argocd
```

### Option 1: Déploiement via ArgoCD UI

1. Pousser ces fichiers dans ton dépôt Git
2. Dans ArgoCD UI → New App
3. Configurer:
   - Application Name: `plateforme-electronique`
   - Project: `default`
   - Sync Policy: `Automatic`
   - Repository URL: `https://github.com/YOUR_USERNAME/argocd-manifests.git`
   - Path: `.`
   - Cluster: `https://kubernetes.default.svc`
   - Namespace: `plateforme-electronique`

### Option 2: Déploiement via CLI

```bash
# 1. Créer le namespace
kubectl create namespace plateforme-electronique

# 2. Modifier l'URL du repo dans argocd-application.yaml
sed -i 's|YOUR_USERNAME|ton-username-github|g' argocd-application.yaml

# 3. Appliquer l'application ArgoCD
kubectl apply -f argocd-application.yaml
```

### Option 3: Déploiement direct (sans ArgoCD)

```bash
# Créer le namespace
kubectl create namespace plateforme-electronique

# Appliquer avec Kustomize
kubectl apply -k . -n plateforme-electronique
```

## 🌐 Configuration des accès locaux

Ajouter dans `/etc/hosts`:

```
# Plateforme Électronique
<INGRESS_IP>  plateforme.local
<INGRESS_IP>  auth.plateforme.local
<INGRESS_IP>  eureka.plateforme.local
```

Pour obtenir l'IP de l'Ingress:
```bash
kubectl get ingress -n plateforme-electronique
```

## 📊 URLs d'accès

| Service | URL |
|---------|-----|
| Frontend | http://plateforme.local |
| API Gateway | http://plateforme.local/api |
| Keycloak | http://auth.plateforme.local |
| Eureka | http://eureka.plateforme.local |

## 🔍 Vérification du déploiement

```bash
# Vérifier les pods
kubectl get pods -n plateforme-electronique -w

# Vérifier les services
kubectl get svc -n plateforme-electronique

# Vérifier l'ingress
kubectl get ingress -n plateforme-electronique

# Logs d'un service
kubectl logs -f deployment/api-gateway -n plateforme-electronique
```

## 🐛 Dépannage

### PostgreSQL ne démarre pas
```bash
# Vérifier les PVC
kubectl get pvc -n plateforme-electronique

# Vérifier les logs
kubectl logs deployment/postgresql -n plateforme-electronique
```

### Services ne s'enregistrent pas dans Eureka
```bash
# Vérifier que Eureka est accessible
kubectl port-forward svc/eureka-server 8761:8761 -n plateforme-electronique
# Ouvrir http://localhost:8761
```

### Keycloak ne démarre pas
```bash
# Vérifier que la DB keycloak existe
kubectl exec -it deployment/postgresql -n plateforme-electronique -- psql -U plateforme_user -c "\l"
```

## 📁 Structure des fichiers

```
argocd-manifests-corrected/
├── Infrastructure
│   ├── postgres-*.yaml          # PostgreSQL
│   ├── redis-*.yaml             # Redis
│   └── plateforme-secrets.yaml  # Secrets
├── Security
│   └── keycloak-*.yaml          # Keycloak
├── Discovery
│   └── eureka-*.yaml            # Eureka Server
├── Gateway
│   └── api-gateway-*.yaml       # Spring Cloud Gateway
├── Frontend
│   └── frontend-*.yaml          # React + Nginx
├── Services
│   ├── user-auth-service-*.yaml
│   ├── invoice-service-*.yaml
│   ├── payment-service-*.yaml
│   ├── subscription-service-*.yaml
│   ├── notification-service-*.yaml
│   └── signature-service-*.yaml
├── Networking
│   └── ingress.yaml             # Nginx Ingress
├── ArgoCD
│   └── argocd-application.yaml  # Application ArgoCD
├── kustomization.yaml           # Kustomize config
└── README.md                    # Ce fichier
```

## ⚠️ Notes importantes

1. **Secrets**: Les credentials dans `plateforme-secrets.yaml` sont des valeurs par défaut. En production, utiliser des outils comme Sealed Secrets ou External Secrets.

2. **Storage**: Les PVC utilisent `storageClassName: standard`. Vérifier que ce provisioner existe dans ton cluster:
   ```bash
   kubectl get storageclass
   ```

3. **Ingress**: Nécessite un Ingress Controller (nginx recommandé).

4. **Keycloak Realm**: Tu devras configurer le realm `plateforme-electronique` manuellement ou importer un fichier realm.json.
