#!/bin/bash
# generate-kargo-applicationset.sh
# This script generates the ApplicationSet with inline credentials
# Usage: ./generate-kargo-applicationset.sh > appset-apps-with-generated-values.yaml

set -euo pipefail

echo "# Generated ApplicationSet with inline Kargo credentials"
echo "# Generated at: $(date)"
echo "# WARNING: This contains sensitive values - handle with care"
echo ""

# Generate credentials using Kargo's official method
pass=$(openssl rand -base64 48 | tr -d "=+/" | head -c 32)
hashed_pass=$(htpasswd -bnBC 10 "" "$pass" | tr -d ':\n')
signing_key=$(openssl rand -base64 48 | tr -d "=+/" | head -c 32)

echo "# IMPORTANT: Save this admin password: $pass" >&2

# Generate the ApplicationSet with embedded values
cat << EOF
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: infra-apps
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=zero"]
  generators:
    - list:
        elements:
          - name: cert-manager
            chart: cert-manager
            repo: https://charts.jetstack.io
            namespace: cert-manager
            targetRevision: "*"
            needsParameters: true
          - name: external-secrets-operator
            chart: external-secrets
            repo: https://charts.external-secrets.io
            namespace: external-secrets
            targetRevision: "*"
          - name: kargo
            chart: kargo
            repo: ghcr.io/akuity/kargo-charts
            namespace: kargo
            targetRevision: "*"
            needsCustomValues: true
  template:
    metadata:
      name: "{{.name}}"
    spec:
      project: default
      source:
        repoURL: "{{.repo}}"
        chart: "{{.chart}}"
        targetRevision: "{{.targetRevision}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  templatePatch: |
    spec:
      source:
        helm:
          {{- if .needsParameters }}
          parameters:
            - name: crds.enabled
              value: "true"
          {{- end }}
          {{- if .needsCustomValues }}
          valuesObject:
            api:
              adminAccount:
                # SECURITY: Generated inline at build time
                # Admin password: $pass
                passwordHash: "$hashed_pass"
                tokenSigningKey: "$signing_key"
                tokenTTL: 24h
              oidc:
                enabled: false
            controller:
              logLevel: INFO
              argocd:
                integrationEnabled: true
                namespace: argocd
          {{- end }}
EOF
