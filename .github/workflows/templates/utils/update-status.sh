#!/bin/bash

# Updates git commit status for the commit in $GITHUB_REPOSITORY for the commit in $PROMOTED_COMMIT_ID 

# Usage:
# update-status.sh STATUS DESCRIPTION CONTEXT
# Example:
# update-status.sh "success" "Tested" "d2" 


set -eo pipefail  # fail on error

STATUS=$1
DESCRIPTION=$2
CONTEXT=$3

gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    /repos/$GITHUB_REPOSITORY/statuses/$PROMOTED_COMMIT_ID \
    -f state=$STATUS \
-f target_url='' \
-f description="$DESCRIPTION" \
-f context="$CONTEXT"
