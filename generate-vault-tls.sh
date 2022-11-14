#!/usr/bin/env bash
#
# 1. Create key
openssl genrsa -out ./vault.key 2048

# 2. Create CSR
cat > ./csr.conf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = vault
DNS.2 = vault.default
DNS.3 = vault.default.svc
DNS.4 = vault.default.svc.cluster.local
DNS.5 = vault-0
DNS.6 = vault-0.default
DNS.7 = vault-0.default.pod
DNS.8 = vault-0.default.pod.cluster.local
DNS.9 = vault-1
DNS.10 = vault-1.default
DNS.11 = vault-1.default.pod
DNS.12 = vault-1.default.pod.cluster.local
DNS.13 = vault-2
DNS.14 = vault-2.default
DNS.15 = vault-2.default.pod
DNS.16 = vault-2.default.pod.cluster.local
DNS.17 = vault-2
DNS.18 = vault-2.default
DNS.19 = vault-2.default.pod
DNS.20 = vault-2.default.pod.cluster.local
DNS.21 = vault-active
DNS.22 = vault-active.default
DNS.23 = vault-active.default.svc
DNS.24 = vault-active.default.svc.cluster.local
DNS.21 = vault-standby
DNS.22 = vault-standby.default
DNS.23 = vault-standby.default.svc
DNS.24 = vault-standby.default.svc.cluster.local
IP.1 = 127.0.0.1
EOF

openssl req -new -key ./vault.key \
  -subj "/O=system:nodes/CN=system:node:vault.default.svc" \
  -out ./server.csr \
  -config ./csr.conf

# 3. Create certificate
cat > ./csr.yaml << EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: vault-csr
spec:
  groups:
  - system:authenticated
  request: $(cat ./server.csr | base64 | tr -d '\r\n')
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kubectl create -f ./csr.yaml
kubectl certificate approve vault-csr

# 4. Create secret
kubectl get csr vault-csr -o jsonpath='{.status.certificate}' | openssl base64 -d -A -out ./vault.crt
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | \
  base64 -d > ./vault.ca
kubectl create secret generic vault-tls \
  --from-file=vault.key=./vault.key \
  --from-file=vault.ca=./vault.ca \
  --from-file=vault.crt=./vault.crt
