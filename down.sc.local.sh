#!/usr/bin/env sh
# Stop the Stack Car local development stack. Data (named volumes) is preserved.
#
# Usage:
#   sh down.sc.local.sh
set -e

sc down
sc proxy down

