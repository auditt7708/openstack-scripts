source install-parameters.sh
source admin_openrc.sh

if [ $# -lt 7 ]
	then
		echo "Correct Syntax: $0 <nova-db-password> <mysql-username> <mysql-password> <controller-host-name> <admin-tenant-password> <nova-password> <rabbitmq-password>"
		exit 1
fi

echo "Configuring MySQL for Nova..."
mysql_command="CREATE DATABASE IF NOT EXISTS nova; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$1'; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$1';"
echo "MySQL Command is:: "$mysql_command
mysql -u "$2" -p"$3" -e "$mysql_command"

keystone user-create --name nova --pass $6
echo_and_sleep "Creating Nova User in KeyStone" 10
keystone user-role-add --user nova --tenant service --role admin

keystone service-create --name nova --type compute --description "OpenStack Compute"
echo_and_sleep "Called service-create for Nova Compute" 10

keystone endpoint-create \
--service-id $(keystone service-list | awk '/ compute / {print $2}') \
--publicurl http://$4:8774/v2/%\(tenant_id\)s \
--internalurl http://$4:8774/v2/%\(tenant_id\)s \
--adminurl http://$4:8774/v2/%\(tenant_id\)s \
--region regionOne

echo_and_sleep "Configuring NOVA Conf File..." 3
crudini --set /etc/nova/nova.conf database connection mysql://nova:$1@$4/nova

crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf DEFAULT rabbit_host $4
crudini --set /etc/nova/nova.conf DEFAULT rabbit_password $7
crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
crudini --set /etc/nova/nova.conf DEFAULT my_ip `hostname -I`
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen `hostname -I`
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address `hostname -I`

crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$4:5000/v2.0
crudini --set /etc/nova/nova.conf keystone_authtoken identity_uri http://$4:35357
crudini --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/nova/nova.conf keystone_authtoken admin_user nova
crudini --set /etc/nova/nova.conf keystone_authtoken admin_password $6

crudini --set /etc/nova/nova.conf glance host $4

echo_and_sleep "Populate Image Nova Database..." 5
nova-manage db sync
echo_and_sleep "Restarting Nova Service..." 5
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

echo_and_sleep "Removing Nova MySQL-Lite Database..." 5
rm -f /var/lib/nova/nova.sqlite
echo_and_sleep "About to print Keystone Service..." 3
print_keystone_service_list