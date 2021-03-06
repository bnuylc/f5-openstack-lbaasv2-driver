#!/usr/bin/env bash

set -ex

OS_CONTROLLER_IP=`/tools/bin/tlc --sid ${TEST_SESSION} symbols \
    | grep openstack_controller1ip_data_direct \
    | awk '{print $3}' | xargs`
SSH_CMD="ssh -i /home/jenkins/.ssh/id_rsa_testlab -o StrictHostKeyChecking=no testlab@${OS_CONTROLLER_IP}"
BIGIP_IP=`${SSH_CMD} "cat /home/testlab/ve_mgmt_ip"`
BIGIP_IP=${BIGIP_IP%%[[:cntrl:]]}
NETWORK_TYPES=${TEST_TENANT_NETWORK_TYPE}
AGENT_LOC=git+https://github.com/F5Networks/f5-openstack-agent.git@${BRANCH}
DRIVER_LOC=git+https://github.com/F5Networks/f5-openstack-lbaasv2-driver.git@${BRANCH}
NEUTRON_DRIVER_LOC=https://raw.githubusercontent.com/F5Networks/neutron-lbaas/${RBANCH}/neutron_lbaas/drivers/f5/driver_v2.py

# Since we don't do anything special in the __init__.py file, we can pull it from anywhere for now
NEUTRON_INIT_LOC=https://raw.githubusercontent.com/F5Networks/neutron-lbaas/v9.1.0/neutron_lbaas/drivers/f5/__init__.py

EXTRA_VARS="agent_pkg_location=${AGENT_LOC} driver_pkg_location=${DRIVER_LOC} neutron_lbaas_driver_location=${NEUTRON_DRIVER_LOC}"
EXTRA_VARS="${EXTRA_VARS} neutron_lbaas_init_location=${NEUTRON_INIT_LOC} restart_all_neutron_services=true remote_user=testlab"
EXTRA_VARS="${EXTRA_VARS} f5_global_routed_mode=${GLOBAL_ROUTED_MODE} bigip_netloc=${BIGIP_IP} agent_service_name=f5-openstack-agent.service"
EXTRA_VARS="${EXTRA_VARS} use_barbican_cert_manager=True neutron_lbaas_shim_install_dest=/usr/lib/python2.7/site-packages/neutron_lbaas/drivers/f5"

if [[ $TEST_OPENSTACK_CLOUD == 'undercloud' ]]; then
    GLOBAL_ROUTED_MODE=False
    if [[ $NETWORK_TYPES == 'vlan' ]]; then
        ADVERTISED_TUNNEL_TYPES=""
    else
        ADVERTISED_TUNNEL_TYPES=${NETWORK_TYPES}
    fi
    EXTRA_VARS="${EXTRA_VARS} advertised_tunnel_types=${ADVERTISED_TUNNEL_TYPES}"
else
    GLOBAL_ROUTED_MODE=True
fi

echo [hosts] > ansible_conf.ini
echo "${OS_CONTROLLER_IP} ansible_ssh_common_args='-o StrictHostKeyChecking=no' host_key_checking=False ansible_connection=ssh ansible_ssh_user=testlab ansible_ssh_private_key_file=/home/jenkins/f5-openstack-lbaasv2-driver/id_rsa_testlab" >> ansible_conf.ini

git clone -b ${TEST_OPENSTACK_DISTRO} https://github.com/f5devcentral/f5-openstack-ansible.git
docker run -e EXTRA_VARS="${EXTRA_VARS}" -it --volumes-from d42d4ff9281b -w `pwd`\
 docker-registry.pdbld.f5net.com/f5/openstack/ansible/microservice:1db6f8999731\
 ansible-playbook -v\
 --inventory-file=/home/jenkins/f5-openstack-lbaasv2-driver/systest/scripts/ansible_conf.ini\
 --extra-vars "${EXTRA_VARS}"\
 /home/jenkins/f5-openstack-lbaasv2-driver/systest/scripts/f5-openstack-ansible/playbooks/agent_driver_deploy.yaml
