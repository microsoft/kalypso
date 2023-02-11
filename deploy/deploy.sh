#!/bin/sh
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

while getopts cdl:o:p:t: flag
do
    case "${flag}" in   
        c) ACTION="CREATE";;
        d) ACTION="DELETE";;
        p) PREFIX=${OPTARG};;
        o) ORG=${OPTARG};;
        t) TOKEN=${OPTARG};;
        l) LOCATION=${OPTARG};;
    esac
done

print_usage() {
    echo "\nUsage: ./deploy.sh -<ACTION> -p <preix> -o <github org> -t <github token> -l <azure-location>"
    echo "ACTION: -c for create, -d for delete  \n"
    echo "Examples: ./deploy.sh -c -p kalypso -o eedorenko -t ghp_19LPYNhx4Whcn6l3jzfyBIbE2Es0Kn -l westus2 \n"                                                              
    exit 1
}

check_prerequisites() {  
  gh
  helm
  kubectl
  az
}

print_prerequisites() {
  echo "The following tools are required to run this script:"
  echo " - gh"
  echo " - helm"
  echo " - kubectl"
  echo " - az"
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

create_gitops_repo() {
  gitops_repo_template=microsoft/kalypso-gitops
  echo "Creating GitOps Repository "$gitops_repo_name
  gh repo create $gitops_repo_name --public --include-all-branches  -p $gitops_repo_template
  sleep 3
  git clone $gh_prefix/$gitops_repo_name gitops
  
  pushd gitops
  update_files_in_branch dev
  update_files_in_branch stage  
  popd
  rm -rf gitops

  gh secret set CONTROL_PLANE_TOKEN -b $TOKEN -R $gitops_repo_name
}

init_gitops_branch() {
  git checkout -b $1
  echo $1 > Readme.md  
  git add .
  git commit -m "Initial commit"
  git push origin $1
}

create_app_gitops_repo() {
  echo "Creating GitOps Repository "$appgitops_repo_name
  gh repo create $appgitops_repo_name --public
  sleep 3
  git clone $gh_prefix/$appgitops_repo_name gitops
  
  pushd gitops
  git checkout -b dev
  echo "dev" > Readme.md  
  mkdir functional-test
  echo "Manifests" > functional-test/Readme.md
  mkdir performance-test
  echo "Manifests" > performance-test/Readme.md
  git add .
  git commit -m "dev"
  git push origin dev

  git checkout -b stage
  echo "stage" > Readme.md  
  rm -rf functional-test
  rm -rf performance-test
  mkdir uat-test
  echo "Manifests" > uat-test/Readme.md
  git add .
  git commit -m "stage"
  git push origin stage
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
  jq -n '{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}'|gh api -H "Accept: application/vnd.github+json" -X PUT /repos/$appsrc_repo_name/environments/dev --input -
  jq -n '{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}'|gh api -H "Accept: application/vnd.github+json" -X PUT /repos/$appsrc_repo_name/environments/stage --input -
  
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
  # helm repo add kalypso-scheduler https://raw.githubusercontent.com/microsoft/kalypso-scheduler/gh-pages/ --force-update 
  kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
  helm upgrade --devel -i kalypso kalypso-scheduler/kalypso-scheduler -n kalypso --set controlPlaneURL=$gh_prefix/$controlplane_repo_name \
    --set controlPlaneBranch=main --set ghRepoToken=$TOKEN
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
    --kustomization name=cluster-config-dev prune=true sync_interval=10s path=$1

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
    --kustomization name=cluster-config-stage prune=true sync_interval=10s path=$1  

  kubectl create secret generic repo-secret -n flux-system \
        --from-literal=username=kalypso \
        --from-literal=password=$TOKEN
  
}

create_argo_cluster_type() {
  echo "Creating "$1" AKS cluster..." 
  create_AKS_cluster $1
  kubectl create ns argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  # echo "ArgoCD username: admin, password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"

  kubectl create secret generic gitops -n argocd \
        --from-literal=username=kalypso \
        --from-literal=password=$TOKEN \
        --from-literal=url=$gh_prefix/$gitops_repo_name
  kubectl label secret gitops -n argocd argocd.argoproj.io/secret-type=repository
    
  kubectl create secret generic app-gitops -n argocd \
        --from-literal=username=kalypso \
        --from-literal=password=$TOKEN \
        --from-literal=url=$gh_prefix/$appgitops_repo_name
  kubectl label secret app-gitops -n argocd argocd.argoproj.io/secret-type=repository      

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

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: stage
  namespace: argocd
spec:
    destination:
        server: https://kubernetes.default.svc
        namespace: argocd
    project: default
    source:
        path: large
        repoURL: $gh_prefix/$gitops_repo_name
        targetRevision: stage
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

deleteAzureResources() {
    echo "Deleting Azure resources..."    
    az group delete -n $rg_name -y
}


create_gh_repositories() {
    echo "Creating GitHub repositories..."

    create_gitops_repo
    create_control_plane_repo
    create_app_gitops_repo
    create_appsrc_repo
}

delete_gh_repositories() {
    echo "Deleting GitHub repositories..."

    gh repo delete $gh_prefix/$controlplane_repo_name --yes
    gh repo delete $gh_prefix/$gitops_repo_name --yes
    gh repo delete $gh_prefix/$appgitops_repo_name --yes
    gh repo delete $gh_prefix/$appsrc_repo_name --yes
}

create() {
  set -e
    echo "---------------------------------"
    echo "Starting depoyment. Time for a coffee break. It will take a few minutes..."
    create_gh_repositories
    createAzureResources
    echo "Depoyment is complete!"
    echo "---------------------------------"
    echo "Created repositories:"
    echo "  - "$gh_prefix/$controlplane_repo_name
    echo "  - "$gh_prefix/$gitops_repo_name
    echo "  - "$gh_prefix/$appsrc_repo_name
    echo "  - "$gh_prefix/$appgitops_repo_name
    echo "---------------------------------"
    echo "Created AKS clusters in "$rg_name" resource group:"
    echo "  - control-plane"
    echo "  - drone (Azure Arc Flux based workload cluster)"
    echo "  - large (ArgoCD based workload cluster)"     
    echo "---------------------------------"
}

delete() {
    echo "---------------------------------"
    echo "Starting deletion. It will take a few minutes..."
    deleteAzureResources
    delete_gh_repositories
    echo "Deletion is complete!"
    echo "---------------------------------"
    echo "Deleted repositories:"
    echo "  - "$gh_prefix/$controlplane_repo_name
    echo "  - "$gh_prefix/$gitops_repo_name
    echo "  - "$gh_prefix/$appsrc_repo_name
    echo "  - "$gh_prefix/$appgitops_repo_name
    echo "---------------------------------"
    echo "Deleted AKS clusters in "$rg_name" resource group:"
    echo "  - control-plane"
    echo "  - drone (Azure Arc Flux based workload cluster)"
    echo "  - large (ArgoCD based workload cluster)" 
    echo "---------------------------------"
}

if [ -z $LOCATION ] || [ -z $PREFIX ] || [ -z $ORG ] || [ -z $TOKEN ];
then
 print_usage
fi


check_prerequisites > /dev/null
[ $? -eq 0 ]  || print_prerequisites


if [ $ACTION == "CREATE" ];
then
 create
elif [ $ACTION == "DELETE" ];
then
 delete
else
  echo "Invalid action: "$ACTION
  print_usage
fi


# TODO:
#   - delete package with the source repo
#   - prometheus repo
#   - templates repos
   
