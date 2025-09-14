#!/bin/bash



gcloud container clusters get-credentials argo-prd-0 \
    --region=us-east1 --project=argo-prod-471308

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account) \
  --user serviceAccount:argo-prd@argo-prod-471308.iam.gserviceaccount.com

gcloud container clusters get-credentials argo-dev-0 \
    --region=us-central1 --project=develop-464014

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)

gcloud container clusters get-credentials argo-mgmt-0 \
    --region=us-west1 --project=homol-argo

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)

#Setar o cluster de gerenciamento como o cluster padrão
#kubectl config use-context gke_argo-mgmt_us-west1_argo-mgmt-0
#kubectl config use-context gke_argo-dev-455710_us-central1_argo-dev-0

# Install ArgoCD

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --version 7.8.7 -n argocd --create-namespace --values ./argocd-mgmt/argocd-values/argocd-without-ha.yaml --wait

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > argo-pass.pass.argo

#Bootstrap
argocd login localhost:32501 --username admin --password $(cat argo-pass.pass.argo) --insecure --grpc-web
# argocd login argo.konzelmann.com.br --username admin --password $(cat argo-pass.pass.argo) --insecure --grpc-web

argocd cluster add gke_develop-464014_us-central1_argo-dev-0 -y
argocd cluster add gke_argo-prod-471308_us-east1_argo-prd-0 -y
# argocd cluster add gke_argo-prd_us-east1_argo-prd-0 -y




# Apply manifests argocd-mgmt
kubectl apply -f argocd-mgmt/app-project/mgmt-project.yaml
kubectl apply -f argocd-mgmt/k8s-mgmt/app-of-apps/infra.yaml 
kubectl apply -f argocd-mgmt/k8s-mgmt/app-of-apps/application.yaml
kubectl apply -f config/mgmt/

# apply manifests k8s application
#### Alterar o server para o IP do cluster para os ambientes dev e prod
#### Realizar o commit das alterações
./commit.sh

# Aplicando dev
kubectl apply -f argocd-mgmt/app-project/dev-project.yaml 
kubectl apply -f argocd-mgmt/app-of-apps/dev/infra.yaml
kubectl apply -f argocd-mgmt/app-of-apps/dev/shared.yaml 
kubectl apply -f argocd-mgmt/app-of-apps/dev/application.yaml

#Altere o contexto para aplicar os arquivos de config
kubectl config use-context gke_develop-464014_us-central1_argo-dev-0
kubectl config use-context gke_argo-prod-471308_us-east1_argo-prd-0
kubectl apply -f config/dev/

# .
# ├── argocd-mgmt
# │   ├── argocd-values
# │   │   ├── argocd-values-ha.yaml
# │   │   └── argocd-without-ha.yaml
# │   ├── argocd-install.sh
# │   ├── app-of-apps
# │   │   ├── k8s-shared-manifests.yaml
# │   │   ├── k8s-application.yaml
# │   │   └── k8s-infra.yaml
# |    
# ├── k8s-application
# │   ├── dev
# │   └── prod
# ├── k8s-infra
# │   ├── dev
# │   └── prod
# ├── k8s-shared-manifests
# │   ├── dev
# │   └── prod
# └── README.md