#!/bin/bash
# This script is used to get the argocd, prometheus & grafana urls & credentials
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo