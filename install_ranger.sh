# Define variables
hostname=`hostname -I | xargs`
installpath=/usr/lib/ranger

ranger_download_version=ranger-2.4.0
ranger_admin_server=$ranger_download_version-admin
mysql_version=mysql-connector-java-8.0.26

#sudo yum -y update
#sudo yum install java-1.8.0 -y
#sudo yum install mysql -y
#sudo yum install python3 -y

cd /tmp

# Download all tar and jar files

# rm -rf $ranger_admin_server
sudo tar -xvf $ranger_admin_server.tar.gz

cp $mysql_version.jar $installpath

export JAVA_HOME=/usr/lib/jvm/jre

# Install apache ranger
sudo rm -rf $installpath
sudo mkdir -p $installpath/hadoop
cd $installpath
cp /tmp/$mysql_version.jar .


# Database default values
DB_ROOT_USERNAME=admin
db_root_password=Admin2024
db_host_name=apache-ranger-database-v3.ct606emys10u.ap-southeast-2.rds.amazonaws.com
RDS_RANGER_SCHEMA_DBNAME=rangerdb
RDS_RANGER_SCHEMA_DBUSER=rangeradmin
RDS_RANGER_SCHEMA_DBPASSWORD=rangeradmin
RANGER_ADMIN_UI_PASSWORD=Admin2024
# AUDIT_STORE=

_generateSQLGrantsAndCreateUser()
{
    touch ~/generate_grants.sql
    HOSTNAMEI=`hostname -I`
    HOSTNAMEI=`echo ${HOSTNAMEI}`
    cat >~/generate_grants.sql <<EOF
CREATE USER IF NOT EXISTS '${RDS_RANGER_SCHEMA_DBUSER}'@'localhost' IDENTIFIED BY '${RDS_RANGER_SCHEMA_DBPASSWORD}';
CREATE DATABASE IF NOT EXISTS ${RDS_RANGER_SCHEMA_DBNAME};
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'localhost';
CREATE USER IF NOT EXISTS '${RDS_RANGER_SCHEMA_DBUSER}'@'%' IDENTIFIED BY '${RDS_RANGER_SCHEMA_DBPASSWORD}';
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'%';
CREATE USER IF NOT EXISTS '${RDS_RANGER_SCHEMA_DBUSER}'@'${HOSTNAMEI}' IDENTIFIED BY '${RDS_RANGER_SCHEMA_DBPASSWORD}';
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'${HOSTNAMEI}';
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'${HOSTNAMEI}' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
exit
EOF

}
_setupMySQLDatabaseAndPrivileges()
{
    HOSTNAMEI=`hostname -I`
    cat ~/generate_grants.sql
    mysql -h ${db_host_name} -u ${DB_ROOT_USERNAME} -p${db_root_password} < ~/generate_grants.sql
    echo $?
}

echo "calling _generateSQLGriantsAndCreateUser"
_generateSQLGrantsAndCreateUser

echo "calling _setupMySQLDatabaseAndPrivileges"
_setupMySQLDatabaseAndPrivileges

cd /tmp/$ranger_admin_server

sudo sed -i "s|SQL_CONNECTOR_JAR=.*|SQL_CONNECTOR_JAR=$installpath/$mysql_version.jar|g" install.properties
sudo sed -i "s|db_root_user=.*|db_root_user=${DB_ROOT_USERNAME}|g" install.properties
sudo sed -i "s|db_root_password=.*|db_root_password=${db_root_password}|g" install.properties
sudo sed -i "s|db_host=.*|db_host=${db_host_name}|g" install.properties
sudo sed -i "s|db_name=.*|db_name=${RDS_RANGER_SCHEMA_DBNAME}|g" install.properties
sudo sed -i "s|db_user=.*|db_user=${RDS_RANGER_SCHEMA_DBUSER}|g" install.properties
sudo sed -i "s|db_password=.*|db_password=${RDS_RANGER_SCHEMA_DBPASSWORD}|g" install.properties
sudo sed -i "s|rangerAdmin_password=.*|rangerAdmin_password=${RANGER_ADMIN_UI_PASSWORD}|g" install.properties
sudo sed -i "s|rangerTagsync_password=.*|rangerTagsync_password=${RANGER_ADMIN_UI_PASSWORD}|g" install.properties
sudo sed -i "s|rangerUsersync_password=.*|rangerUsersync_password=${RANGER_ADMIN_UI_PASSWORD}|g" install.properties
sudo sed -i "s|keyadmin_password=.*|keyadmin_password=${RANGER_ADMIN_UI_PASSWORD}|g" install.properties
sudo sed -i "s|audit_db_password=.*|audit_db_password=rangerlogger|g" install.properties
sudo sed -i "s|audit_store=.*|audit_store=solr|g" install.properties
sudo sed -i "s|audit_solr_urls=.*|audit_solr_urls=http://localhost:8983/solr/ranger_audits|g" install.properties
# sudo sed -i "s|policymgr_external_url=.*|policymgr_external_url=http://$hostname:6080|g" install.properties
# sudo sed -i "s|audit_store=.*|audit_store=${AUDIT_STORE}|g" install.properties

certs_path="/tmp/emr-certs"

#current_hostname=$(hostname -f)
current_hostname=$(TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/local-hostname)
# sudo hostname $current_hostname

HTTP_URL=https://localhost:6182
ranger_agents_certs_path="${certs_path}/ranger-agents"
ranger_server_certs_path="${certs_path}/ranger-server"
# solr_certs_path="${certs_path}/solr-client"

ranger_admin_keystore_alias="rangeradmin"
ranger_admin_keystore_password="changeit"
ranger_admin_keystore_location="/etc/ranger/admin/conf/ranger-admin-keystore.jks"
ranger_admin_truststore_location="$JAVA_HOME/lib/security/cacerts"
ranger_admin_truststore_password="changeit"

truststore_plugins_alias="rangerplugin"
# truststore_solr_alias="solrTrust"
truststore_admin_alias="rangeradmin"

sudo mkdir -p /etc/ranger/admin/conf

#Setup Keystore for RangerAdmin
openssl pkcs12 -export -in ${ranger_server_certs_path}/trustedCertificates.pem -inkey ${ranger_server_certs_path}/privateKey.pem -chain -CAfile ${ranger_server_certs_path}/trustedCertificates.pem -name ${ranger_admin_keystore_alias} -out ${ranger_server_certs_path}/keystore.p12 -password pass:${ranger_admin_keystore_password}
keytool -delete -alias ${ranger_admin_keystore_alias} -keystore ${ranger_admin_keystore_location} -storepass ${ranger_admin_keystore_password} -noprompt || true
sudo keytool -importkeystore -deststorepass ${ranger_admin_keystore_password} -destkeystore ${ranger_admin_keystore_location} -srckeystore ${ranger_server_certs_path}/keystore.p12 -srcstoretype PKCS12 -srcstorepass ${ranger_admin_keystore_password}
#sudo chown ranger:ranger -R /etc/ranger

#Setup Truststore - add agent cert to Ranger Admin
keytool -delete -alias ${truststore_plugins_alias} -keystore ${ranger_admin_truststore_location} -storepass changeit -noprompt || true
sudo keytool -import -file ${ranger_agents_certs_path}/trustedCertificates.pem -alias ${truststore_plugins_alias} -keystore ${ranger_admin_truststore_location} -storepass changeit -noprompt

# if [ "$cloudwatch_audits" = false ] ; then
#     #Setup Truststore - add Solr cert to Ranger Admin
#     keytool -delete -alias ${truststore_solr_alias} -keystore ${ranger_admin_truststore_location} -storepass changeit -noprompt || true
#     sudo keytool -import -file ${solr_certs_path}/trustedCertificates.pem -alias ${truststore_solr_alias} -keystore ${ranger_admin_truststore_location} -storepass changeit -noprompt
# fi

#Setup Truststore - add RangerServer cert
keytool -delete -alias ${truststore_admin_alias} -keystore ${ranger_admin_truststore_location} -storepass changeit -noprompt || true
sudo keytool -import -file ${ranger_server_certs_path}/trustedCertificates.pem -alias ${truststore_admin_alias} -keystore ${ranger_admin_truststore_location} -storepass changeit -noprompt

# #Setup Keystore SOLR

# if [ "$cloudwatch_audits" = false ] ; then
#     sudo mkdir -p /etc/solr/conf
#     openssl pkcs12 -export -in ${solr_certs_path}/certificateChain.pem -inkey ${solr_certs_path}/privateKey.pem -chain -CAfile ${solr_certs_path}/trustedCertificates.pem -name ${solr_keystore_alias} -out ${solr_certs_path}/keystore.p12 -password pass:${solr_keystore_password}
#     keytool -delete -alias ${solr_keystore_alias} -keystore ${solr_keystore_location} -storepass ${solr_keystore_password} -noprompt  || true
#     sudo keytool -importkeystore -deststorepass ${solr_keystore_password} -destkeystore ${solr_keystore_location} -srckeystore ${solr_certs_path}/keystore.p12 -srcstoretype PKCS12 -srcstorepass ${solr_keystore_password}
# fi


# SSL conf
sudo sed -i "s|policymgr_external_url=.*|policymgr_external_url=https://$current_hostname:6182|g" install.properties
sudo sed -i "s|policymgr_http_enabled=.*|policymgr_http_enabled=false|g" install.properties
sudo sed -i "s|policymgr_https_keystore_file=.*|policymgr_https_keystore_file=${ranger_admin_keystore_location}|g" install.properties
sudo sed -i "s|policymgr_https_keystore_keyalias=.*|policymgr_https_keystore_keyalias=${ranger_admin_keystore_alias}|g" install.properties
sudo sed -i "s|policymgr_https_keystore_password=.*|policymgr_https_keystore_password=${ranger_admin_keystore_password}|g" install.properties

sudo sed -i "s|POLICY_MGR_URL =.*|POLICY_MGR_URL=https://$current_hostname:6182|g" install.properties
sudo sed -i "s|POLICY_MGR_URL=.*|POLICY_MGR_URL=https://$current_hostname:6182|g" install.properties

sudo chmod +x setup.sh
sh setup.sh
