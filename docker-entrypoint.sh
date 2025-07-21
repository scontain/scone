#!/bin/bash

source /scone-registry.env

mkdir -p ~/.kube

cp /kubeconfig ~/.kube/config

cd $HOME

git clone https://github.com/scontain/scone.git

~/scone/scripts/prerequisite_check.sh

alias k=kubectl
exec "$@"