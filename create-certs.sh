#!/bin/bash


set -euo pipefail
set -x

mkdir -p /tmp/emr-tls/
cd /tmp/emr-tls/

# sudo yum -y install java-1.8.0
# sudo yum -y remove java-1.7.0-openjdk
# sudo yum -y install openssl-devel

AWS_REGION='ap-southeast-2'


configured_region=$(tr '[:upper:]' '[:lower:]' <<< "$AWS_REGION")
echo "Using region $configured_region"

if [[ $configured_region = "us-east-1" ]]; then
  DEFAULT_EC2_REALM='ec2.internal'
  echo "AWS region is us-east-1, will use EC2 realm as $DEFAULT_EC2_REALM"
else
   DEFAULT_EC2_REALM="$configured_region.compute.internal"
   echo "AWS region is NOT us-east-1, will use EC2 realm as $DEFAULT_EC2_REALM"
fi
ranger_plugin_certs_path="./ranger-agents"
solr_certs_path="./solr-client"
keystore_location="./ranger-plugin-keystore.jks"
keystore_alias=rangerplugin
keystore_password="changeit"
truststore_location="./ranger-plugin-truststore.jks"
ranger_server_certs_path="./ranger-server"
truststore_password="changeit"
truststore_ranger_server_alias="rangeradmin"
secret_mgr_ranger_plugin_private_key="emr/rangerGAagentkey"
secret_mgr_ranger_plugin_cert="emr/rangerPluginCert"
secret_mgr_ranger_admin_private_key="emr/rangerServerPrivateKey"
secret_mgr_ranger_admin_server_cert="emr/rangerGAservercert"
ranger_admin_server_private_key_exists="false"
ranger_admin_server_cert_exists="false"
ranger_plugin_private_key_exists="false"
ranger_plugin_cert_exists="false"
ranger_solr_cert_exists="false"
ranger_solr_key_exists="false"
ranger_solr_trust_store_exists="false"

certs_subject="/C=US/ST=TX/L=Dallas/O=EMR/OU=EMR/CN=*.$DEFAULT_EC2_REALM"

generate_certs() {
  DIR_EXISTS="false"
  if [ -d "$1" ]; then
    echo "$1 directory exists, will not recreate certs"
    DIR_EXISTS="true"
  fi
#  rm -rf $1
  if [[ $DIR_EXISTS == "false" ]]; then
    rm -rf $1
    mkdir -p $1
    pushd $1
    openssl req -x509 -newkey rsa:4096 -keyout privateKey.pem -out certificateChain.pem -days 1095 -nodes -subj ${certs_subject}
    cp certificateChain.pem trustedCertificates.pem
    zip -r -X ../$1.zip certificateChain.pem privateKey.pem trustedCertificates.pem
    #  rm -rf *.pem
    popd
  fi
}
rm -rf ${keystore_location}
rm -rf ${truststore_location}
rm -rf ${keystore_location}
generate_certs ranger-server
generate_certs ranger-agents
generate_certs solr-client
generate_certs emr-certs


# Generate KeyStore and TrustStore for the Ranger plugins
# Keystore
openssl pkcs12 -export -in ${ranger_plugin_certs_path}/certificateChain.pem -inkey ${ranger_plugin_certs_path}/privateKey.pem -chain -CAfile ${ranger_plugin_certs_path}/trustedCertificates.pem -name ${keystore_alias} -out ${ranger_plugin_certs_path}/keystore.p12 -password pass:${keystore_password}
keytool -importkeystore -deststorepass ${keystore_password} -destkeystore ${keystore_location} -srckeystore ${ranger_plugin_certs_path}/keystore.p12 -srcstoretype PKCS12 -srcstorepass ${keystore_password} -noprompt

# Truststore
rm -rf ${truststore_location}
keytool -import -file ${ranger_server_certs_path}/certificateChain.pem -alias ${truststore_ranger_server_alias} -keystore ${truststore_location} -storepass ${truststore_password} -noprompt
