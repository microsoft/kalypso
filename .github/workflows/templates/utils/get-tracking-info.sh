#!/bin/bash

# Usage:
#   get-tracking-info.sh


# Reads the tracking information (PROMOTED_COMMIT_ID, IMAGE_NAME) from the .github/tracking folder and 
# "promoted" label from the GitOps PR
# Sets the environment variables for the GitHub Actions workflow to use.

PROMOTED_COMMIT_ID=$(cat .github/tracking/Promoted_Commit_Id)
echo "PROMOTED_COMMIT_ID=$PROMOTED_COMMIT_ID" >> $GITHUB_ENV

IMAGE_TAG=$(cat .github/tracking/Image_tag)
echo "IMAGE_TAG=$IMAGE_TAG" >> $GITHUB_ENV  
VERSION=$(cat .github/tracking/Version)
echo "VERSION=$VERSION" >> $GITHUB_ENV

gh pr list --search $COMMIT_ID --state merged --label promoted

promoted=$(gh pr list --search $COMMIT_ID --state merged --label promoted)
if [[ -z "$promoted" ]]; then
    PROMOTION='n'
    echo "PROMOTION=$PROMOTION" >> $GITHUB_ENV
fi         

echo $PROMOTION