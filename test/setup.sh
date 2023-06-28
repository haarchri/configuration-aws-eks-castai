#!/usr/bin/env bash
set -aeuo pipefail

echo "Running setup.sh"
echo "Waiting until configuration package is installed..."
${KUBECTL} wait configuration.pkg platform-ref-castai --for=condition=Installed --timeout 5m
echo "Waiting until configuration package is healthy..."
${KUBECTL} wait configuration.pkg platform-ref-castai --for=condition=Healthy --timeout 5m


echo "Creating aws cloud credential secret..."
${KUBECTL} -n crossplane-system create secret generic aws-creds --from-literal=credentials="${UPTEST_CLOUD_CREDENTIALS}" \
    --dry-run=client -o yaml | ${KUBECTL} apply -f -

echo "Creating castai cloud credential secret..."
${KUBECTL} -n crossplane-system create secret generic castai-creds --from-literal=credentials="${CASTAI_CLOUD_CREDENTIALS}" \
    --dry-run=client -o yaml | ${KUBECTL} apply -f -

echo "Waiting for all pods to come online..."
"${KUBECTL}" -n crossplane-system wait --for=condition=Available deployment --all --timeout=5m

echo "Waiting for all XRDs to be established..."
kubectl wait xrd --all --for condition=Established

echo "Creating a default aws provider config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-creds
      key: creds
EOF

echo "Creating a default castai provider config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: castai.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: castai-creds
      key: credentials
EOF