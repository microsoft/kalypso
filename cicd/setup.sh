#!/bin/bash

# Usage: setup.sh -o <github org> -r <github service src repo> -e <first environment in chain>
# Example: setup.sh -o liupeirong -r ConfiguratiX -e dev

# The script requires the following environment variables to be set:
#     TOKEN: github personal access token with repo access
# OPTIONAL:
#     AZURE_CREDENTIALS_SP: service principal azure credentials, if not set, the script will create a new service principal with contributor role on the default subscription

set -eo pipefail
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

while getopts o:r:s:e:d: flag
do
    case "${flag}" in   
        o) ORG=${OPTARG};;
        r) REPO=${OPTARG};;
        e) ENV=${OPTARG};; 
    esac
done

print_usage() {
    printf "Usage: setup.sh -o <github org> -r <github service src repo> -e <first environment in chain> \n"
    printf "\nExample: setup.sh -o eedorenko -r hello-world -e dev \n"
    printf "The script requires the following environment variables to be set: \n"
    printf " - TOKEN: github personal access token with repo access \n"
    printf " OPTIONAL: \n"
    printf " - AZURE_CREDENTIALS_SP: service principal azure credentials, if not set, the script will create a new service principal with contributor role on the default subscription."

    exit 1
}

check_gh_username() {
  ghusername=$(git config --get user.name) || true
  ghuseremail=$(git config --get user.email) || true
  
  if [ -z "$ghusername" ] || [ -z "$ghuseremail" ];
  then
    echo "Please configure your git username and email before running this script"
    echo "git config --global user.email \"you@example.com\""
    echo "git config --global user.name \"Your Name\""
    exit 1
  fi
}


check_prerequisites() {  
  type -p gh >/dev/null
  type -p git >/dev/null
}

print_prerequisites() {
  echo "The following tools are required to run this script:"
  echo " - gh"
  echo " - git"
  exit 1
}

authenticate_gh() {
  gh auth setup-git
}

check_az_sub() {
  if [ -z "$AZURE_CREDENTIALS_SP" ]
  then
    subid=$(az account list --query "[?isDefault].id" -o tsv)
    if [ -z "$subid" ]
    then
        echo "Please login to Azure before running this script"
        echo "az login"
        exit 1
    fi
    AZURE_CREDENTIALS_SP=$(az ad sp create-for-rbac --name kalypso-$REPO --role contributor --scopes /subscriptions/$subid --sdk-auth)    
    echo "Created service principal kalypso-$REPO with contributor role on subscription $subid: $AZURE_CREDENTIALS_SP "
  fi    
} 
  
  
  


if [ -z $ORG ] || [ -z $REPO ] || [ -z $ENV ] || [ -z $TOKEN ];
then
 print_usage
fi

gh_prefix="https://github.com"
src_repo_name="$ORG/$REPO"
configs_repo_name="${src_repo_name}-configs"
gitops_repo_name="${src_repo_name}-gitops"

check_repo() {
    repo_name=$1
    gh repo view $repo_name >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Repository $repo_name already exists"        
        return 0
    else
        return 1
    fi
}

create_repo() {  
  repo_name=$1  
  echo "Repository $repo_name does not exist"
  gh repo create $repo_name --private  
  echo "Created Repository $repo_name"
  sleep 3
}

ensure_gitops_repo() {
    rm -rf gitops
    check_repo $gitops_repo_name || create_repo $gitops_repo_name    
    git clone $gh_prefix/$gitops_repo_name gitops
}

ensure_branch() {
    branch_name=$1
    if  (( $(git branch -a | grep "remotes/origin/$branch_name" | wc -l) == 0)) ; then
        echo "Branch $branch_name does not exist"
        git checkout -b $branch_name
    else
        echo "Branch $branch_name already exists"
        git checkout $branch_name
    fi
} 

configure_gitops_repo() {
    echo "Configuring Repository "$gitops_repo_name

    gh variable set SRC_REPO -b $src_repo_name -R $gitops_repo_name
    gh secret set CD_BOOTSTRAP_TOKEN -b $TOKEN -R $gitops_repo_name
    gh label create promoted --color 0e8a16 --force -R $gitops_repo_name
    gh repo edit $gitops_repo_name --delete-branch-on-merge

    pushd gitops

    ensure_branch $ENV

    mkdir -p .github/workflows
    cp $parent_path/../.github/workflows/templates/notify-on-pr.yml .github/workflows/
    
    mkdir -p .github/workflows/utils
    cp -r $parent_path/../.github/workflows/templates/utils/get-tracking-info.sh .github/workflows/utils/

    git add .
    git diff-index --quiet HEAD || git commit -m $ENV
    git push origin $ENV

    popd 
    rm -rf gitops
}

ensure_configs_repo() {    
    rm -rf configs
    check_repo $configs_repo_name || create_repo $configs_repo_name    
    git clone $gh_prefix/$configs_repo_name configs
}

ensure_src_repo() {    
    rm -rf src
    check_repo $src_repo_name || create_repo $src_repo_name
    git clone $gh_prefix/$src_repo_name src
    pushd src
    if  (( $(git branch -a | grep "remotes/origin/main" | wc -l) == 0)) ; then
        echo "# $src_repo_name" >> README.md                
        git add .
        git commit -m 'first commit'        
        git branch -M main
        git push -u origin main        
    fi
    popd
}


configure_configs_repo() {
    echo "Configuring Repository "$configs_repo_name  

    gh variable set MANIFESTS_REPO -b $gitops_repo_name -R $configs_repo_name
    gh variable set SRC_REPO -b $src_repo_name -R $configs_repo_name
    gh secret set CD_BOOTSTRAP_TOKEN -b $TOKEN -R $configs_repo_name
    gh repo edit $configs_repo_name --delete-branch-on-merge

    pushd configs

    ensure_branch $ENV

    if  (( $(find . -mindepth 1 -maxdepth 1 -type d ! -path '*.git*' | wc -l) == 0)) ; then
        mkdir -p rename_me
        touch rename_me/values.yaml
        echo "Application config values for a deployment target" > rename_me/Readme.md
    fi

    mkdir -p .github/workflows
    cp $parent_path/../.github/workflows/templates/notify-on-config-change.yml .github/workflows/

    git add .
    git diff-index --quiet HEAD || git commit -m $ENV
    git push origin $ENV
    
    popd 
    rm -rf configs
    
}

setup_gitops_repo() {
    ensure_gitops_repo
    configure_gitops_repo
}

setup_configs_repo() {
    ensure_configs_repo
    configure_configs_repo
}


configure_src_repo() {
    echo "Configuring Repository "$src_repo_name 
    
    gh variable set MANIFESTS_REPO -b $gitops_repo_name".git" -R $src_repo_name
    gh variable set CONFIGS_REPO -b $configs_repo_name -R $src_repo_name
    gh secret set CD_BOOTSTRAP_TOKEN -b $TOKEN -R $src_repo_name
    gh secret set AZURE_CREDENTIALS_SP -b "$AZURE_CREDENTIALS_SP" -R $src_repo_name    

    if gh variable list -R $src_repo_name | grep START_ENVIRONMENT; then
        echo "START_ENVIRONMENT already exists"
    else
        gh variable set START_ENVIRONMENT -b $ENV -R $src_repo_name
    fi 


    pushd src
    
    new_branch_name=feature/cd-setup
    ensure_branch $new_branch_name

    mkdir -p .github/workflows
    cp $parent_path/../.github/workflows/templates/ci.yml .github/workflows/
    cp $parent_path/../.github/workflows/templates/cd.yml .github/workflows/
    cp $parent_path/../.github/workflows/templates/post-deployment.yml .github/workflows/
    cp -r $parent_path/../.github/workflows/templates/utils .github/workflows/
    rm .github/workflows/utils/get-tracking-info.sh

    git add .
    if [[ `git status --porcelain | head -1` ]]; then
        git commit -m "cd"
        git push --set-upstream origin $new_branch_name

        gh pr create --base main --head $new_branch_name --title "GitOps CD setup" --body "GH Actions workflows for CD setup <br /> Utility scripts for GH Actions workflows"
    fi

    popd 
    rm -rf src

}

setup_src_repo() {
    ensure_src_repo
    configure_src_repo
}



check_prerequisites || print_prerequisites

check_gh_username
check_az_sub
authenticate_gh

setup_gitops_repo
setup_configs_repo
setup_src_repo
