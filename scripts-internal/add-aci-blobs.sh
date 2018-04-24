#!/bin/bash

DIR=${1-.}

bosh add-blob ${DIR}/aci-containers-controller_1.9.0~trusty*_amd64.deb aci-cf-controller/aci-containers-controller_1.9.0~trusty_amd64.deb
bosh add-blob ${DIR}/aci-containers-host-agent_1.9.0~trusty*_amd64.deb aci-cf-host-agent/aci-containers-host-agent_1.9.0~trusty_amd64.deb
bosh add-blob ${DIR}/opflex-agent-cni_1.9.0~trusty*_amd64.deb opflex-cni/opflex-agent-cni_1.9.0~trusty_amd64.deb

bosh add-blob ${DIR}/libmodelgbp_1.8.0*~trusty_amd64.deb agent-ovs/libmodelgbp_1.8.0~trusty_amd64.deb
bosh add-blob ${DIR}/libopflex_1.8.0*~trusty_amd64.deb agent-ovs/libopflex_1.8.0~trusty_amd64.deb
bosh add-blob ${DIR}/libopflex-agent_1.8.0*~trusty_amd64.deb agent-ovs/libopflex-agent_1.8.0~trusty_amd64.deb
bosh add-blob ${DIR}/opflex-agent_1.8.0*~trusty_amd64.deb agent-ovs/opflex-agent_1.8.0~trusty_amd64.deb
bosh add-blob ${DIR}/opflex-agent-renderer-openvswitch_1.8.0*~trusty_amd64.deb agent-ovs/opflex-agent-renderer-openvswitch_1.8.0~trusty_amd64.deb
bosh add-blob ${DIR}/libuv1_1.8.0*~trusty_amd64.deb agent-ovs/libuv1_1.8.0~trusty_amd64.deb
bosh add-blob ${DIR}/libnoiro-openvswitch_2.6.0*_amd64.deb agent-ovs/libnoiro-openvswitch_2.6.0_amd64.deb

bosh add-blob ${DIR}/openvswitch-common_2.6.0*_amd64.deb openvswitch/openvswitch-common_2.6.0_amd64.deb
bosh add-blob ${DIR}/openvswitch-switch_2.6.0*_amd64.deb openvswitch/openvswitch-switch_2.6.0_amd64.deb

