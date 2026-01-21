#!/bin/bash

echo "Installing Linkerd on AKS..."

# Install CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin

# Validate
linkerd check --pre

# Install
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
linkerd check

# Install viz
linkerd viz install | kubectl apply -f -

# Inject into ecommerce namespace
kubectl annotate namespace ecommerce linkerd.io/inject=enabled
kubectl delete pods --all -n ecommerce

echo "✅ Linkerd installed!"
echo "Open dashboard: linkerd viz dashboard"