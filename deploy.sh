#!/bin/bash

export myName="jhub-firedrake"
export azureRegion="westeurope"

az ad sp create-for-rbac --skip-assignment >> sp.out

cat sp.out

export servicePrincipal=`grep appId sp.out | awk -F\" '{print $4}'`
export clientSecret=`grep password sp.out | awk -F\" '{print $4}'`

export resourceGroup=${myName}

az group create --name=${myName} --location=${azureRegion} --output table >> resgroup.out
cat resgroup.out

export aksNodeCount=3
export kubernetesVersion=1.11.5

az aks create --resource-group ${myName} --name ${myName} --node-count ${aksNodeCount} --kubernetes-version ${kubernetesVersion} --service-principal ${servicePrincipal} --client-secret ${clientSecret} --generate-ssh-keys >> aksCreate.out
cat aksCreate.out

rm -rf ~/.kube/ 

az aks get-credentials --resource-group ${myName} --name ${myName}

echo "
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system" > helm-rbac.yaml

kubectl create -f helm-rbac.yaml 

helm init --service-account tiller 
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/ 
helm repo update 

export proxySecretToken=`openssl rand -hex 32`

echo "proxy:
  secretToken: '${proxySecretToken}'
  https:
    hosts:
      - '${myName}.${azureRegion}.cloudapp.azure.com'
    letsencrypt:
      contactEmail: tim.greaves@imperial.ac.uk

hub:
  image:
    name: jupyterhub/k8s-hub
    tag: '0.7.0'

auth:
  type: custom
  custom:
    className: 'tmpauthenticator.TmpAuthenticator'

singleuser:
  image:
    name: tmbgreaves/jupyterhub-k8s
    tag: 'firedrakeSingleUser20190207-000'
  storage:
    type: none" > jhub-config.yaml


helm upgrade --install jupyterhub jupyterhub/jupyterhub --namespace jupyterhub --version 0.7.0   --values jhub-config.yaml

export ipAddress=$(az network public-ip list --resource-group MC_${myName}_${myName}_${azureRegion} | grep ipAddress | awk -F\" '{print $4}')
export ipName=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '${ipAddress}')].[name]" --output tsv | uniq)

az network public-ip update --resource-group MC_${myName}_${myName}_${azureRegion} --name  ${ipName} --dns-name ${myName}
