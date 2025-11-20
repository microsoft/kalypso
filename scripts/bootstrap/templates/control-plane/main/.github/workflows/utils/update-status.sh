# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#!/bin/bash
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
