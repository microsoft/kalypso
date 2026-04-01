# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#!/bin/bash
echo $1

baserepo_template="baserepo-template.yaml"

set -euo pipefail
cat $baserepo_template | envsubst > $1

