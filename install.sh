#!/bin/bash



gcloud container clusters get-credentials argo-prd-0 \
    --region=us-east1 --project=argo-prd

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)

gcloud container clusters get-credentials argo-dev-0 \
    --region=us-central1 --project=argo-dev-455710

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)

# gcloud container clusters get-credentials argo-mgmt-0 \
#     --region=us-west1 --project=argo-mgmt

# kubectl create clusterrolebinding cluster-admin-binding \
#   --clusterrole cluster-admin \
#   --user $(gcloud config get-value account)

#Setar o cluster de gerenciamento como o cluster padrão
kubectl config use-context gke_argo-prd_us-east1_argo-prd-0

# Install ArgoCD

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --version 7.8.7 -n argocd --create-namespace --values ./argocd-mgmt/argocd-values/argocd-without-ha.yaml --wait

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > argo-pass.pass.argo

#Bootstrap
argocd login localhost:32501 --username admin --password $(cat argo-pass.pass.argo) --insecure --grpc-web
# argocd login argo.konzelmann.com.br --username admin --password $(cat argo-pass.pass.argo) --insecure --grpc-web

argocd cluster add gke_argo-dev-455710_us-central1_argo-dev-0 -y
# argocd cluster add gke_argo-prd_us-east1_argo-prd-0 -y


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