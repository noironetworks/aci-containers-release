#!/usr/bin/python

import argparse
import base64
import json
import requests
import sys
import yaml

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

#import httplib
#httplib.HTTPConnection.debuglevel = 1

HOSTNAME = ""
ACI_PLUGIN_TILE_TYPE = 'aci-cni-plugin-tile'

def invoke_http(func, path, auth, params, data=None):
    url = HOSTNAME + path
    headers = {'Accept': 'application/json;charset=utf-8'}
    if auth:
        headers['Authorization'] = auth
    if params:
        headers['Content-Type'] = 'x-www-form-urlencoded'
    if data:
        headers['Content-Type'] = 'application/json; charset=utf-8'
    r = func(url,
             headers=headers,
             params=params,
             data=json.dumps(data) if data is not None else None,
             verify=False)
    if r.status_code == 200:
        return 200, r.json()
    return r.status_code, None

def get_access_token(opsman_user, opsman_pwd):
    auth = "Basic " + base64.b64encode("opsman:")
    payload = dict(grant_type='password',
                   username=opsman_user,
                   password=opsman_pwd)
    code, out = invoke_http(requests.post, "/uaa/oauth/token", auth, payload)
    if code == 200:
        tok = out.get('access_token')
        if tok:
            return "Bearer " + tok
    else:
        print "Failed to fetch access-token - (HTTP code %s) %s" % (code, out)

def get_aci_tile_product_guid(token):
    code, out = invoke_http(requests.get, "/api/v0/staged/products", token,
                            None)
    if code != 200:
        print "Failed to get product GUID - (HTTP code %s) %s" % (code, out)
        return None
    aci_prod = [p for p in out if p['type'] == ACI_PLUGIN_TILE_TYPE]
    if aci_prod:
        return aci_prod[0]['guid']
    print "Product for ACI tile (%s) not found" % ACI_PLUGIN_TILE_TYPE

def ip_pool_xform(key, value):
    return {key + "_start": value[0]["start"],
            key + "_end": value[0]["end"]}

def prepare_aci_tile_config(config_yaml_file):
    file = open(config_yaml_file, 'r')
    cfg = yaml.load(file)
    transforms = {
        'apic_dvs': None,
        'apic_infra_portgroup': None,
        'apic_node_portgroup': None,
        'apic_node_subnet': None,
        'network_ip_pool': ip_pool_xform,
        'network_app_vip_pool': ip_pool_xform,
        'network_app_dynamic_ext_ip_pool': ip_pool_xform,
        'network_app_static_ext_ip_pool': ip_pool_xform,
        'network_node_service_ip_pool': ip_pool_xform,
    }
    out = {}

    def prop_key(k): return ".properties." + k
    def prop_value(v):
        return dict(value=(",".join(v) if isinstance(v, list) else v))

    for k, v in cfg.iteritems():
        if k not in transforms:
            out[prop_key(k)] = prop_value(v)
            continue
        f = transforms[k]
        if f:
            new_dict = f(k, v)
            out.update({prop_key(nk): prop_value(nv)
                        for nk, nv in new_dict.iteritems()})
    return dict(properties=out)

def update_aci_tile_config(product_guid, token, cfg):
    code, out = invoke_http(requests.put,
        "/api/v0/staged/products/%s/properties" % product_guid,
        token, None, data=cfg)
    if code != 200:
        print "Failed to set ACI tile properties - (HTTP code %s) %s" % (
            code, out)

def main():
    global HOSTNAME
    op = argparse.ArgumentParser()
    op.add_argument("host",
                    help="Name or IP Address of OpsManager")
    op.add_argument("user",
                    help="OpsManager Admin user name")
    op.add_argument("password",
                    help="OpsManager Admin user password")
    op.add_argument("config_file",
                    help="Name of config file created by acc_provision")
    args = op.parse_args(sys.argv[1:])
    if args:
        HOSTNAME = "https://" + args.host
        cfg = prepare_aci_tile_config(args.config_file)
        token = get_access_token(args.user, args.password)
        if not token:
            sys.exit(1)
        prod_guid = get_aci_tile_product_guid(token)
        if not prod_guid:
            sys.exit(1)
        if cfg:
            update_aci_tile_config(prod_guid, token, cfg)

if __name__ == '__main__':
    main()
