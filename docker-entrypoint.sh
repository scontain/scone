#!/bin/bash

set -euo pipefail

cd $HOME

git clone https://github.com/scontain/scone.git

# Execute the command passed to the container
exec "$@"
