#!/bin/sh
set -e
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

while getopts l:o:p:t: flag
do
    case "${flag}" in        
        p) PREFIX=${OPTARG};;
        o) ORG=${OPTARG};;
        t) TOKEN=${OPTARG};;
        l) LOCATION=${OPTARG};;
    esac
done

print_usage() {
    echo "\nUsage: ./deploy.sh -l <azure-location>  -t <local-cluster-type> \n"
    echo "Available local cluster types: kind, k3d \n"
    echo "Example: ./deploy.sh -l westus2 -t k3d \n"
    exit 1
}


gh_prefix="https://github.com"
controlplane_repo_name=$ORG/$PREFIX-control-plane
gitops_repo_name=$ORG/$PREFIX-gitops
appsrc_repo_name=$ORG/$PREFIX-app-src
appgitops_repo_name=$ORG/$PREFIX-app-gitops
rg_name=$PREFIX-rg

export GH_TOKEN=$TOKEN


update_files_in_branch() {
 git checkout $1
 for file in `find . -type f \( -name "*.yaml" \)`; do cat "$file" | sed "s/microsoft/$ORG/g" | sed "s/kalypso-/$PREFIX-/g" > "$file"1 && mv "$file"1 "$file"; done
 git add .
 git commit -m "Update "$1" with new org and prefix"
 git push origin $1
}

create_control_plane_repo() {
  controlplane_repo_template=microsoft/kalypso-control-plane
  echo "Creating Controll Plane Repository "$controlplane_repo_name
  gh repo create $controlplane_repo_name --public --include-all-branches  -p $controlplane_repo_template
  sleep 3
  jq -n '{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}'|gh api -H "Accept: application/vnd.github+json" -X PUT /repos/$controlplane_repo_name/environments/dev --input -
  gh secret set GITOPS_REPO -b $gitops_repo_name -R $controlplane_repo_name
  gh secret set GITOPS_REPO_TOKEN -b $TOKEN -R $controlplane_repo_name
  echo "stage" | gh secret set NEXT_ENVIRONMENT -e dev -R $controlplane_repo_name

  subid=$(az account list --query "[?isDefault].id" -o tsv)
  az ad sp create-for-rbac --name kalypso-$PREFIX --role contributor --scopes /subscriptions/$subid --sdk-auth | gh secret set AZURE_CREDENTIALS -R $controlplane_repo_name
  
  git clone $gh_prefix/$controlplane_repo_name control-plane
  
  pushd control-plane
  update_files_in_branch dev
  update_files_in_branch stage  
  update_files_in_branch main
  popd
  rm -rf control-plane
}

init_gitops_branch() {
  git checkout -b $1
  echo $1 > Readme.md  
  git add .
  git commit -m "Initial commit"
  git push origin $1
}

create_gitops_repo() {
  echo "Creating GitOps Repository "$1
  gh repo create $1 --public
  sleep 3
  git clone $gh_prefix/$1 gitops
  
  pushd gitops
  init_gitops_branch dev
  init_gitops_branch stage
  popd
  rm -rf gitops
}

create_appsrc_repo() {
  appsrc_repo_template=microsoft/kalypso-app-src
  echo "Creating Application Source Repository "$appsrc_repo_name
  gh repo create $appsrc_repo_name --public --include-all-branches  -p $appsrc_repo_template
  sleep 3
  gh secret set MANIFESTS_TOKEN -b $TOKEN -R $appsrc_repo_name
  gh secret set MANIFESTS_REPO -b $gh_prefix/$appgitops_repo_name -R $appsrc_repo_name
  
  git clone $gh_prefix/$appsrc_repo_name app-src
  
  pushd app-src
  update_files_in_branch main
  popd
  rm -rf app-src
}


create_AKS_cluster() {
    az aks create -g $rg_name -n $1 -l $LOCATION --node-count 1
    az aks get-credentials -g $rg_name -n $1
    az aks show -g $rg_name -n $1 -o table
}

create_control_plane() {
  echo "Creating control-plane AKS cluster..." 
  create_AKS_cluster "control-plane"
  kubectl create ns kalypso 
  helm repo add kalypso-scheduler https://raw.githubusercontent.com/microsoft/kalypso-scheduler/gh-pages/ --force-update 
  kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
  helm upgrade --devel -i kalypso kalypso-scheduler/kalypso-scheduler -n kalypso --set controlPlaneURL=$gh_prefix/$controlplane_repo_name \
    --set controlPlaneBranch=main 
    #  --set ghRepoToken=$TOKEN
}

create_flux_cluster_type() {
    # --https-user kalypso \
    # --https-key $TOKEN \

  echo "Creating "$1" AKS cluster..." 
  create_AKS_cluster $1
  az k8s-configuration flux create \
    --name cluster-config-dev \
    --cluster-name $1 \
    --namespace flux-system \
    --resource-group $rg_name \
    -u $gh_prefix/$gitops_repo_name \
    --scope cluster \
    --interval 10s \
    --cluster-type managedClusters \
    --branch dev \
    --kustomization name=cluster-config-dev prune=true path=$1

  az k8s-configuration flux create \
    --name cluster-config-stage \
    --cluster-name $1 \
    --namespace flux-system \
    --resource-group $rg_name \
    -u $gh_prefix/$gitops_repo_name \
    --scope cluster \
    --interval 10s \
    --cluster-type managedClusters \
    --branch stage \
    --kustomization name=cluster-config-stage prune=true path=$1

#   kubectl create secret generic repo-secret -n flux-system \
#         --from-literal=username=kalypso \
#         --from-literal=password=$TOKEN
  
}

create_argo_cluster_type() {
  echo "Creating "$1" AKS cluster..." 
  create_AKS_cluster $1
  kubectl create ns argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  echo "ArgoCD username: admin, password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"

#   kubectl create secret generic gitops -n argocd \
#         --from-literal=username=kalypso \
#         --from-literal=password=$TOKEN \
#         --from-literal=url=$gh_prefix/$gitops_repo_name
#   kubectl label secret gitops -n argocd argocd.argoproj.io/secret-type=repository
    
#   kubectl create secret generic app-gitops -n argocd \
#         --from-literal=username=kalypso \
#         --from-literal=password=$TOKEN \
#         --from-literal=url=$gh_prefix/$appgitops_repo_name
#   kubectl label secret app-gitops -n argocd argocd.argoproj.io/secret-type=repository      

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev
  namespace: argocd
spec:
    destination:
        server: https://kubernetes.default.svc
        namespace: argocd
    project: default
    source:
        path: large
        repoURL: $gh_prefix/$gitops_repo_name
        targetRevision: dev
        directory:
            recurse: true
            include: '*.yaml'        
    syncPolicy:
        automated:
            prune: true
            selfHeal: true
            allowEmpty: false
        syncOptions:
        - CreateNamespace=true
EOF
}

createAzureResources() {
    echo "Creating Azure resources..."    
    az group create -n $rg_name -l $LOCATION
    create_control_plane    
    create_flux_cluster_type drone
    create_argo_cluster_type large
}


create_gh_repositories() {
    echo "Creating GitHub repositories..."

    create_control_plane_repo
    create_gitops_repo $gitops_repo_name
    create_gitops_repo $appgitops_repo_name
    create_appsrc_repo
}

echo "Starting depoyment..."
create_gh_repositories
createAzureResources
echo "Depoyment is complete!"

# TODO:
#   - update argocd template in the control plane
#   - usage
#   - performance test 
#   - promotion flows in control Plane
#   - promotion flows in app
#   - templates repos
#   - prometheus repo
#   - get rid of token  