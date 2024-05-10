# Define variables
hostname=`hostname -I | xargs`
installpath=/usr/lib/ranger

ranger_download_version=ranger-2.4.0
ranger_admin_server=$ranger_download_version-admin
mysql_version=mysql-connector-java-8.0.26

sudo yum -y update
sudo yum install java-1.8.0 -y
sudo yum install mysql -y
sudo yum install python3 -y

cd /tmp

# Download all tar and jar files

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
db_host_name=
RDS_RANGER_SCHEMA_DBNAME=rangerdb
RDS_RANGER_SCHEMA_DBUSER=rangeradmin
RDS_RANGER_SCHEMA_DBPASSWORD=rangeradmin
RANGER_ADMIN_UI_PASSWORD=Admin2024


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
sudo sed -i "s|audit_db_password=.*|audit_db_password=rangerlogger|g" install.properties
sudo sed -i "s|audit_store=.*|audit_store=solr|g" install.properties
sudo sed -i "s|audit_solr_urls=.*|audit_solr_urls=http://localhost:8983/solr/ranger_audits|g" install.properties
sudo sed -i "s|policymgr_external_url=.*|policymgr_external_url=http://$hostname:6080|g" install.properties

sudo chmod +x setup.sh
sh setup.sh
