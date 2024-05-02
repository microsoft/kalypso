set -eo pipefail
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

while getopts cdl:o:p:t: flag
do
    case "${flag}" in   
        c) ACTION="CREATE";;
        d) ACTION="DELETE";;
        p) PREFIX=${OPTARG};;
        o) ORG=${OPTARG};;
        t) export TOKEN=${OPTARG};;
        l) LOCATION=${OPTARG};;
    esac
done


gh_prefix="https://github.com"
appsrc_repo_name=$ORG/$PREFIX
appgitops_repo_name=$appsrc_repo_name-gitops
appconfigs_repo_name=$appsrc_repo_name-configs
rg_name=$PREFIX-rg
cluster_name=$PREFIX-cluster

check_src_repo() {
    gh repo view $appsrc_repo_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Repository $appsrc_repo_name already exists"        
        exit 1
    else
        echo "Creating repository $appsrc_repo_name"    
        return 1
    fi
}

create_src_repository() {
    gh repo create $appsrc_repo_name --public
    rm -rf src
    git clone https://github.com/microsoft/kalypso-app-src src
    pushd src
    git remote add mine $gh_prefix/$appsrc_repo_name 
    rm .github/workflows/cicd.yaml
    git add .
    git commit -m "Initial commit"
    git push mine main
    popd
    rm -rf src
}

ensure_src_repository() {
    check_src_repo || create_src_repository

}

update_configs_repo() {
    rm -rf configs
    git clone $gh_prefix/$appconfigs_repo_name configs    
    pushd configs
    mv rename_me functional-test

cat <<EOF > functional-test/values.yaml
app:
  name: hello-world-functional
replicas: 3
namespace: \$ENVIRONMENT
EOF
    git add .
    git commit -m "Update functional-test"
    git config pull.rebase false
    git pull --no-edit
    git push
    popd
    rm -rf configs
}

create_gh_repositories() {
    ensure_src_repository
    $parent_path/../setup.sh -o $1 -r $2 -e dev
    update_configs_repo
    $parent_path/../setup.sh -o $1 -r $2 -e stage
    gh api --method PUT -H "Accept: application/vnd.github+json" repos/$appsrc_repo_name/environments/dev
    gh variable set NEXT_ENVIRONMENT -e dev -b stage -R $appsrc_repo_name

    gh pr merge 1 -s -R $gh_prefix/$appsrc_repo_name 

}

delete_gh_repositories() {
    echo "Deleting GitHub repositories..."

    gh repo delete $gh_prefix/$appsrc_repo_name --yes 2> /dev/null
    gh repo delete $gh_prefix/$appgitops_repo_name --yes 2> /dev/null
    gh repo delete $gh_prefix/$appconfigs_repo_name --yes 2> /dev/null
    
    gh api -H "Accept: application/vnd.github+json" -X DELETE "/user/packages/container/$PREFIX%2Fhello-world" > /dev/null 2>&1

}

createAzureResources() {
    echo "Creating Azure resources..."    
    az group create -n $rg_name -l $LOCATION
    create_flux_cluster_type
}

create_flux_cluster_type() {
  echo "Creating "$cluster_name" AKS cluster..." 
  create_AKS_cluster $cluster_name

  az extension add -n k8s-configuration
  az extension add -n k8s-extension

  az k8s-configuration flux create \
    --name cluster-config-dev \
    --cluster-name $cluster_name \
    --namespace flux-system \
    --https-user flux \
    --https-key $TOKEN \
    --resource-group $rg_name \
    -u $gh_prefix/$appgitops_repo_name \
    --scope cluster \
    --interval 10s \
    --cluster-type managedClusters \
    --branch dev \
    --kustomization name=cluster-config-dev prune=true sync_interval=10s path=functional-test

  az k8s-configuration flux create \
    --name cluster-config-stage \
    --cluster-name $cluster_name \
    --namespace flux-system \
    --https-user flux \
    --https-key $TOKEN \
    --resource-group $rg_name \
    -u $gh_prefix/$appgitops_repo_name \
    --scope cluster \
    --interval 10s \
    --cluster-type managedClusters \
    --branch stage \
    --kustomization name=cluster-config-stage prune=true sync_interval=10s path=functional-test

  kubectl create ns dev        
  kubectl create ns stage

  create_platform_config_map dev
  create_platform_config_map stage
  
}

create_platform_config_map() {
    kubectl create configmap platform-config --from-literal=CLUSTER_NAME=$cluster_name \
        --from-literal=REGION=westus2 \
        --from-literal=ENVIRONMENT=$1 \
        --from-literal=DATABASE_URL=https://database.mysql.com \
        -n $1    
}

create_AKS_cluster() {
    az aks create -g $rg_name -n $1 -l $LOCATION --node-count 1 --generate-ssh-keys
    az aks get-credentials -g $rg_name -n $1
    az aks show -g $rg_name -n $1 -o table
}


deleteAzureResources() {
    echo "Deleting Azure resources..."    
    az group delete -n $rg_name -y 2> /dev/null
}


create() {
    echo "---------------------------------"
    echo "Starting deployment. Time for a coffee break. It will take a few minutes..."

    create_gh_repositories $ORG $PREFIX
    createAzureResources
    echo "Deployment is complete!"
    echo "---------------------------------"
    echo "Created repositories:"
    echo "  - "$gh_prefix/$appsrc_repo_name
    echo "  - "$gh_prefix/$appgitops_repo_name
    echo "  - "$gh_prefix/$appconfigs_repo_name
    echo "---------------------------------"
    echo "Created AKS clusters in "$rg_name" resource group:"
    echo "  - $cluster_name"
    echo "---------------------------------"
}

delete() {
    set +e
    echo "---------------------------------"
    echo "Starting deletion. It will take a few minutes..."
    deleteAzureResources
    delete_gh_repositories
    echo "Deletion is complete!"
    echo "---------------------------------"
    echo "Deleted repositories:"
    echo "  - "$gh_prefix/$appsrc_repo_name
    echo "  - "$gh_prefix/$appgitops_repo_name
    echo "  - "$gh_prefix/$appconfigs_repo_name
    echo "---------------------------------"
    echo "Deleted AKS clusters in "$rg_name" resource group:"
    echo "  - $cluster_name"
    echo "---------------------------------"
}

print_usage() {
    printf "Usage: ./deploy.sh -<ACTION> -p <preix> -o <github org> -t <github token> -l <azure-location> \n"
    printf "ACTION: -c for create, -d for delete  \n"
    printf "\nExamples: ./deploy.sh -c -p hello-world -o eedorenko -t ghp_19LPYNhx4Whcn6l3jzfyBIbE2Es0Kn -l westus2 \n"                                                              
    exit 1
}

check_prerequisites() {  
  type -p gh >/dev/null
  type -p git >/dev/null
}

authenticate_gh() {
  echo "$TOKEN" > .githubtoken
  gh auth login --with-token < .githubtoken  
  rm .githubtoken
  gh auth setup-git
}


print_prerequisites() {
  echo "The following tools are required to run this script:"
  echo " - gh"
  echo " - git"
  exit 1
}

 
if [ -z $LOCATION ] || [ -z $PREFIX ] || [ -z $ORG ] || [ -z $TOKEN ];
then
 print_usage
fi

check_prerequisites || print_prerequisites

authenticate_gh


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
