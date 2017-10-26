#!/bin/bash

DIR=${1-.}

bosh add-blob ${DIR}/aci-containers-controller aci-cf-controller/aci-containers-controller

bosh add-blob ${DIR}/aci-containers-host-agent aci-cf-host-agent/aci-containers-host-agent

bosh add-blob ${DIR}/agent-ovs_1.5.0*~trusty_amd64.deb agent-ovs/agent-ovs_1.5.0~trusty_amd64.deb
bosh add-blob ${DIR}/libmodelgbp_1.5.0*~trusty_amd64.deb agent-ovs/libmodelgbp_1.5.0~trusty_amd64.deb
bosh add-blob ${DIR}/libopflex_1.5.0*~trusty_amd64.deb agent-ovs/libopflex_1.5.0~trusty_amd64.deb
bosh add-blob ${DIR}/libuv1_1.8.0*~trusty_amd64.deb agent-ovs/libuv1_1.8.0~trusty_amd64.deb

bosh add-blob ${DIR}/opflex-agent-cni opflex-cni/opflex-agent-cni

bosh add-blob ${DIR}/openvswitch-common_2.6.0*_amd64.deb ovs_2.6.0/openvswitch-common_2.6.0_amd64.deb
bosh add-blob ${DIR}/openvswitch-switch_2.6.0*_amd64.deb ovs_2.6.0/openvswitch-switch_2.6.0_amd64.deb

