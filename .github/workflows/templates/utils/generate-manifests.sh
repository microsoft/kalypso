#!/bin/bash

# Usage:
# generate-manifests.sh FOLDER_WITH_MANIFESTS FOLDER_WITH_CONFIGS GENERATED_MANIFESTS_FOLDER

# Example:
# generate-manifests.sh "/manifests" "/configs" "/generated-manifests"

# Generates manifests from Helm charts in the FOLDER_WITH_MANIFESTS using values.yaml files in the FOLDER_WITH_CONFIGS and
# saves them in the GENERATED_MANIFESTS_FOLDER

FOLDER_WITH_MANIFESTS=$1
FOLDER_WITH_CONFIGS=$2
GENERATED_MANIFESTS_FOLDER=$3

echo $FOLDER_WITH_MANIFESTS
echo $FOLDER_WITH_CONFIGS
echo $GENERATED_MANIFESTS_FOLDER

set -euo pipefail

gen_manifests_file_name='gen_manifests.yaml'
values_file_name='values.yaml'


mkdir -p $GENERATED_MANIFESTS_FOLDER

# Substitute env variables in Helm yaml files in the manifest folder
# e.g. "image_name: $IMAGE_NAME" -> "image_name: gitops.azurecr.io/agent:1.0.0"
for file in `find $FOLDER_WITH_MANIFESTS -type f \( -name "values.yaml" \)`; do envsubst <"$file" > "$file"1 && mv "$file"1 "$file"; done


cd $FOLDER_WITH_CONFIGS
for dir in `find . -type d \( ! -name . \)`; do
    # Generate manifests for every leaf folder with values.yaml
    # All values.yaml files in the path to the leaf folder are merged into one values.yaml
    if [ -z "$(find $dir -mindepth 1 -type d \( ! -name . \))" ] && [ -f $dir/$values_file_name ]; then
        manifests_dir=$GENERATED_MANIFESTS_FOLDER/$dir
        mkdir -p $manifests_dir   
        path=$dir
        while [[ $path != $FOLDER_WITH_CONFIGS ]];
        do                      
            # if there is any values.yaml in $path flush its content to manifests_dir
            if [ -f $path/$values_file_name ]; then
                touch $manifests_dir/$values_file_name
                cat $path/$values_file_name  $manifests_dir/$values_file_name  > tmp_val && cat tmp_val > $manifests_dir/$values_file_name && rm tmp_val
                echo >> $manifests_dir/$values_file_name
            fi            
            path="$(readlink -f "$path"/..)"
        done
        # Generate manifests out of helm chart
        envsubst <"$manifests_dir/$values_file_name" > "$manifests_dir/$values_file_name"1 && mv "$manifests_dir/$values_file_name"1 "$manifests_dir/$values_file_name"
        helm template "$FOLDER_WITH_MANIFESTS" -f $manifests_dir/$values_file_name > $manifests_dir/$gen_manifests_file_name && \
        cat $manifests_dir/$gen_manifests_file_name
        if [ $? -gt 0 ]
          then
            echo "Could not render manifests"
            exit 1
        fi

        pushd $manifests_dir 
        
        # Generate kustomization.yaml
        kustomize create --autodetect
        popd

        # # Generate deployment descriptor
        # deployment_target=$(echo $manifests_dir | rev | cut -d'/' -f1 | rev)
        
        # mkdir -p $manifests_dir/descriptor
        # $GITHUB_WORKSPACE/.github/workflows/utils/generate-deployment-descriptor.sh  $deployment_target $manifests_dir/descriptor/$deployment_descriptor_file_name $GITHUB_WORKSPACE/$deployment_descriptor_template

        rm $manifests_dir/$values_file_name
    fi
done

