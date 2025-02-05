!/usr/bin/env bash
set -eou pipefail


NAMESPACE="openebs"
ROOT_CA_NAME="root-ca"
CERT_DIR="$(dirname "$0")/certs"

rm -rf "${CERT_DIR}"
mkdir -p "${CERT_DIR}"

# Server configurations
declare -A SERVERS=(
    ["io-engine-server"]="io-engine"
    ["agent-core-server"]="agent-core"
    ["api-rest-server"]="api-rest"
)

rm -rf "${CERT_DIR}"
mkdir -p "${CERT_DIR}"

# Create a self-signed root CA (if not already created)
echo "Creating a self-signed root CA"
openssl genrsa -out "${CERT_DIR}/ca.key" 4096
openssl req -x509 -new -nodes -key "${CERT_DIR}/ca.key" -sha256 -days 3650 -out "${CERT_DIR}/ca.crt" -subj "/CN=${ROOT_CA_NAME}" -addext "subjectAltName=DNS:${NAMESPACE}-${ROOT_CA_NAME}-${NAMESPACE}.svc.cluster.local,DNS:${NAMESPACE}-${ROOT_CA_NAME},DNS:${NAMESPACE}-${ROOT_CA_NAME}-${NAMESPACE}.svc"

# Function to create TLS certificates and secrets for servers
create_server_cert_and_secret() {
    local server_name=$1
    local app_name=$2
    local cert_secret_name="${app_name}-tls"

    echo "Creating TLS certificate for ${server_name}"
    openssl genrsa -out "${CERT_DIR}/${server_name}.key" 4096
    openssl req -new -key "${CERT_DIR}/${server_name}.key" -out "${CERT_DIR}/${server_name}.csr" -subj "/CN=${NAMESPACE}-${app_name}" -addext "subjectAltName=DNS:${NAMESPACE}-${app_name}-${NAMESPACE}.svc.cluster.local,DNS:${NAMESPACE}-${app_name},DNS:${NAMESPACE}-${app_name}-${NAMESPACE}.svc"
    openssl x509 -req -in "${CERT_DIR}/${server_name}.csr" -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" -CAcreateserial -out "${CERT_DIR}/${server_name}.crt" -days 3650 -sha256 -extfile <(printf "subjectAltName=DNS:${NAMESPACE}-${app_name}-${NAMESPACE}.svc.cluster.local,DNS:${NAMESPACE}-${app_name},DNS:${NAMESPACE}-${app_name}-${NAMESPACE}.svc")

    # Convert the private key to PKCS#1 format if necessary
    echo "Verifying the RSA key format for ${server_name}"
    if grep -q "BEGIN PRIVATE KEY" "${CERT_DIR}/${server_name}.key"; then
        echo "Converting key to RSA format for ${server_name}"
        openssl rsa -in "${CERT_DIR}/${server_name}.key" -out "${CERT_DIR}/${server_name}-rsa.key"
        mv "${CERT_DIR}/${server_name}-rsa.key" "${CERT_DIR}/${server_name}.key"
    else
        echo "Key is already in RSA format for ${server_name}"
    fi

# Create a Kubernetes secret
    echo "Creating a Kubernetes secret for ${server_name}"
    kubectl create secret generic ${cert_secret_name} \
        --from-file=tls.crt="${CERT_DIR}/${server_name}.crt" \
        --from-file=tls.key="${CERT_DIR}/${server_name}.key" \
        --from-file=ca.crt="${CERT_DIR}/ca.crt" \
        -n ${NAMESPACE}
}

# Generate certificates and secrets for each server
for server_name in "${!SERVERS[@]}"; do
    app_name="${SERVERS[${server_name}]}"
    create_server_cert_and_secret "${server_name}" "${app_name}"
done

echo "All certificates and secrets have been created successfully!"

# Prompt to delete certificates locally
read -p "Do you want to delete the generated certificates locally? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Deleting the generated certificates locally..."
  rm -rf "${CERT_DIR}"
  echo "Certificates deleted."
else
  echo "Certificates retained."
fi