#!/bin/bash

set -e

export ROOT_DIR=`pwd`

export TASKS_DIR=$(dirname $BASH_SOURCE)
export PIPELINE_DIR=$(cd $TASKS_DIR/../../ && pwd)
export FUNCTIONS_DIR=$(cd $PIPELINE_DIR/functions && pwd)

export OVA_ISO_PATH='/root/ISOs/CHGA'

source $FUNCTIONS_DIR/copy_ovas.sh
source $FUNCTIONS_DIR/create_hosts.sh

# Default installer name to be used for tags
if [ "$NSX_T_INSTALLER" == "" ]; then
	NSX_T_INSTALLER='nsx-t-gen'
fi

function check_status_up {
	ip_set=$1
	type_of_resource=$2
	status_up=true

	resources_down_count=0
	resources_configured=$(echo $ip_set | sed -e 's/,/ /g' | awk '{print NF}' )
	for resource_ip in $(echo $ip_set | sed -e 's/,/ /g' )
	do
		# no netcat on the docker image
		#status=$(nc -vz ${resource_ip} 22 2>&1 | grep -i succeeded || true)
		# following hangs on bad ports
		#status=$( </dev/tcp/${resource_ip}/22 && echo true || echo false)
		timeout 15 bash -c "(echo > /dev/tcp/${resource_ip}/22) >/dev/null 2>&1"
		status=$?
		if [ "$status" != "0" ]; then
			status_up=false
			resources_down_count=$(expr $resources_down_count + 1)
		fi
	done

	if [ "$status_up" == "true" ]; then
		(>&2 echo "All VMs of type ${type_of_resource} up, total: ${resources_configured}")
		echo "true"
		return
	fi

  if [ "$resources_down_count" != "$resources_configured" ]; then
      (>&2 echo "Mismatch in number of VMs of type ${type_of_resource} that are expected to be up!!")
      (>&2 echo "Configured ${type_of_resource} VM total: ${resources_configured}, VM down: ${resources_down_count}")
      (>&2 echo "Delete pre-created vms of type ${type_of_resource} and start over!!")
      (>&2 echo "If the vms are up and accessible and suspect its a timing issue, restart the job again!!")
      (>&2 echo "Exiting now !!")
      exit -1
  else
      (>&2 echo "All VMs of type ${type_of_resource} down, total: ${resources_configured}")
      (>&2 echo "  Would need to deploy ${type_of_resource} ovas")
	fi

	echo "false"
	return
}

function modify_ansible_tasks_for_unified_appliance {

    sed -i 's/Deploy controller/Deploy controller-manager/g' basic_topology.yml

    # ctlr-manager deployment is uses nsxt_controller_manager_auto_deployment module
    sed -i 's/nsxt_controllers/nsxt_controller_manager_auto_deployment/g' basic_topology.yml
    sed -i 's/roles: CONTROLLER/roles: [CONTROLLER, MANAGER]/g' basic_topology.yml

    # nsxt_controller_manager_auto_deployment module uses vc_name rather than id
    sed -i 's/vc_id/vc_name/g; s/compute_manager.id/compute_manager_name/g' basic_topology.yml

    # Clustering config is deprecated as of 2.4.0
    sed -i '/clustering_config/,+3 d' basic_topology.yml

    # DNS server needs to be specified for static IPs
    DNS_SERVER="\"{{hostvars[\'localhost\'].dns_server}}\""
    sed -i "/hostvars\[item\].prefix_length/a \ \ \ \ \ \ \ \ \ \ \ \ dns_servers: [$DNS_SERVER]" basic_topology.yml
}

DEBUG=""
if [ "$enable_ansible_debug_int" == "true" ]; then
  DEBUG="-vvv"
fi

create_hosts
cp ${PIPELINE_DIR}/tasks/install-nsx-t/get_mo_ref_id.py ./
python get_mo_ref_id.py --host $vcenter_ip_int --user $vcenter_username_int --password $vcenter_password_int

cp hosts.out ${PIPELINE_DIR}/nsxt_yaml/basic_topology.yml ${PIPELINE_DIR}/nsxt_yaml/vars.yml nsxt-ansible/
cd nsxt-ansible

if [[ "$unified_appliance_int" == "true" ]]; then
    modify_ansible_tasks_for_unified_appliance
fi

# Deploy the ovas if its not up
echo "Installing ovftool"
install_ovftool

cp ${PIPELINE_DIR}/tasks/install-nsx-t/turn_off_reservation.py ./
cp ${PIPELINE_DIR}/tasks/config-nsx-t-extras/*.py ./

exit 1

ansible-playbook $DEBUG -i hosts.out basic_topology.yml
STATUS=$?

if [[ $STATUS != 0 ]]; then
	echo "Deployment of NSX failed, vms failed to come up!!"
	echo "Check error logs"
	echo ""
	exit $STATUS
else
	echo "Deployment of NSX is succcessfull!! Continuing with rest of configuration!!"
	echo ""
fi

echo "Successfully finished with Install!!"

exit 0
