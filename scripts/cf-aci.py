#!/usr/bin/python

import json
import os
import sys
import requests

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# import httplib
# httplib.HTTPConnection.debuglevel = 1

HOSTNAME = ""
BASE_URL = "/networking-aci"

def refresh_auth():
    #invoke_cmd("cf org system")
    pass

def get_token():
    return invoke_cmd("cf oauth-token")

def invoke_cmd(cmd):
    _, out, _ = os.popen3(cmd)
    return out.readline().rstrip()

def invoke_http(func, path, token, body, base=BASE_URL):
    url = HOSTNAME + base + path
    headers = {'Authorization': token}
    r = func(url,
             headers=headers,
             data=json.dumps(body) if body else None,
             verify=False)
    if r.status_code == 200:
        return 200, r.json()
    return r.status_code, None

class NotAuthenticated(Exception):
    pass

def raise_or_log(status):
    if status == 401:
        raise NotAuthenticated
    print "Failed, HTTP status %d" % status

def main():
    if len(sys.argv) < 2:
        print "No command specified"
        print_help("")
        return
    cmd = sys.argv[1]
    args = sys.argv[2:] if len(sys.argv) > 2 else []
    if cmd in ['-h', '--help']:
        print_help("")
        return
    if not args or '-h' in args or '--help' in args:
        print_help(cmd)
        return

    get_api_url()
    if not HOSTNAME:
        print "Unable to determine CloudFoundry API endpoint"
        return
    try:
        execute_cmd(cmd, args)
    except NotAuthenticated:
        refresh_auth()
        execute_cmd(cmd, args)

COMMANDS = {
    "app-vip": ("<app-name>", "Get virtual IP of an app"),
    "epg-app": ("<app-name>", "Get EPG annotation of an app"),
    "epg-space": ("<space-name>", "Get EPG annotation of a space"),
    "epg-org": ("<org-name>", "Get EPG annotation of an org"),
    "set-epg-app": ("<app-name> <EPG-name>", "Set EPG annotation on an app"),
    "set-epg-space": ("<app-name> <EPG-name>", "Set EPG annotation on a space"),
    "set-epg-org": ("<app-name> <EPG-name>", "Set EPG annotation on an org"),
    "unset-epg-app": ("<app-name>", "Remove EPG annotation of an app"),
    "unset-epg-space": ("<space-name>", "Remove EPG annotation of a space"),
    "unset-epg-org": ("<org-name>", "Remove EPG annotation of an org"),
    "app-ext-ip": ("<app-name>", "Get external IP of an app"),
    "set-app-ext-ip": ("<app-name> <IP-address>", "Set external IP on an app"),
    "unset-app-ext-ip": ("<app-name>", "Remove external IP of an app"),
}

def print_help(cmd):
    info = COMMANDS.get(cmd) if cmd else None
    if not info:
        if cmd:
            print "Unknown command %s" % cmd
        print "Available commands:"
        for k in sorted(COMMANDS.keys()):
            info = COMMANDS[k]
            print "\t%s %s\t%s" % (k, info[0], info[1])
        return
    print "Usage: %s %s" % (cmd, info[0])
    print "       %s" % info[1]

def execute_cmd(cmd, args):
    if cmd == "app-vip":
        get_app_vip(cmd, args)
    elif cmd in ["epg-app", "epg-space", "epg-org"]:
        get_epg_annotation(cmd, args)
    elif cmd in ["set-epg-app", "set-epg-space", "set-epg-org"]:
        set_epg_annotation(cmd, args, False)
    elif cmd in ["unset-epg-app", "unset-epg-space", "unset-epg-org"]:
        set_epg_annotation(cmd, args, True)
    elif cmd in ["app-ext-ip"]:
        get_app_ext_ip(cmd, args)
    elif cmd in ["set-app-ext-ip"]:
        set_app_ext_ip(cmd, args, False)
    elif cmd in ["unset-app-ext-ip"]:
        set_app_ext_ip(cmd, args, True)
    elif cmd in ["allow-access", "add-network-policy"]:
        change_access(cmd, args, False)
    elif cmd in ["remove-access", "remove-network-policy"]:
        change_access(cmd, args, True)
    else:
        print "Unknown command " + cmd

def get_obj_guid(kind, name):
    out = invoke_cmd('cf %s %s --guid' % (kind, name))
    #print >>sys.stderr, "%s %s -> %s" % (kind, name, out)
    return out if (out and "FAILED" not in out) else ""

def get_app_vip(cmd, args):
    if len(args) < 1:
        print "Insufficient arguments for command " + cmd
        return
    guid = resolve_app_name(args[0])
    if not guid:
        print "App " + args[0] + " not found"
        return
    token = get_token()
    status, msg = invoke_http(requests.get, "/app_vip/" + guid, token, None)
    if status == 200:
        print "%s: %s" % (args[0], ",".join(msg["ip"]))
    elif status == 404:
        print "No virtual IP found"
    else:
        raise_or_log(status)

def get_epg_annotation(cmd, args):
    if len(args) < 1:
        print "Insufficient arguments for command " + cmd
        return
    kind = "app"
    if "space" in cmd:
        kind = "space"
    elif "org" in cmd:
        kind = "org"
    guid = resolve_app_name(args[0]) if kind == "app" else get_obj_guid(kind, args[0])
    if not guid:
        print kind + " " + args[0] + " not found"
        return
    token = get_token()
    status, msg = invoke_http(requests.get, "/epg/" + kind + "/" + guid, token, None)
    if status == 200:
        print "%s %s: %s" % (kind, args[0], msg["value"])
    elif status == 404:
        print "No EPG annotation found"
    else:
        raise_or_log(status)

def set_epg_annotation(cmd, args, delete):
    if len(args) < (1 if delete else 2):
        print "Insufficient arguments for command " + cmd
        return
    kind = "app"
    if "space" in cmd:
        kind = "space"
    elif "org" in cmd:
        kind = "org"
    guid = resolve_app_name(args[0]) if kind == "app" else get_obj_guid(kind, args[0])
    if not guid:
        print kind + " " + args[0] + " not found"
        return
    token = get_token()
    status, msg = invoke_http(requests.delete if delete else requests.put,
                              "/epg/" + kind + "/" + guid, token,
                              None if delete else dict(value=args[1]))
    if status == 204:
        print "OK"
    else:
        raise_or_log(status)

def get_app_ext_ip(cmd, args):
    if len(args) < 1:
        print "Insufficient arguments for command " + cmd
        return
    guid = resolve_app_name(args[0])
    if not guid:
        print "App " + args[0] + " not found"
        return
    token = get_token()
    status, msg = invoke_http(requests.get, "/app_ext_ip/" + guid, token, None)
    if status == 200:
        print "%s: %s" % (args[0], ",".join(msg["ip"]))
    elif status == 404:
        print "No external IP found"
    else:
        raise_or_log(status)

def set_app_ext_ip(cmd, args, delete):
    if len(args) < (1 if delete else 2):
        print "Insufficient arguments for command " + cmd
        return
    guid = resolve_app_name(args[0])
    if not guid:
        print "App " + args[0] + " not found"
        return
    token = get_token()
    status, msg = invoke_http(requests.delete if delete else requests.put,
                              "/app_ext_ip/" + guid, token,
                              None if delete else dict(ip=[args[1]]))
    if status == 204:
        print "OK"
    else:
        raise_or_log(status)

def change_access(cmd, args, delete):
    if 'access' in cmd and len(args) < 6:
        print "Insufficient arguments for command " + cmd
        return
    elif len(args) < 7:
        print "Insufficient arguments for command " + cmd
        return
    if 'network-policy' in cmd:
        if args[1] != '--destination-app':
            print "Expected --destination-app as 2nd parameter, found " + args[1]
            return
        del args[1]
    if args[2] != "--protocol":
        print "Expected --protocol as 3rd parameter, found " + args[2]
        return
    if args[4] != "--port":
        print "Expected --port as 5th parameter, found " + args[4]
        return
    src = resolve_app_name(args[0])
    if not src:
        print "App " + args[0] + " not found"
        return
    dst = resolve_app_name(args[1])
    if not dst:
        print "App " + args[1] + " not found"
        return
    proto = args[3]
    port = int(args[5])
    bod = dict(policies=[dict(source=dict(id=src),
                              destination=dict(id=dst,
                                               protocol=proto,
                                               ports=dict(start=port, end=port)))])
    token = get_token()
    status, msg = invoke_http(requests.post,
                              "/networking/v1/external/policies" + ("/delete" if delete else ""),
                              token,
                              bod,
                              base="")
    if status == 200:
        print "OK"
    else:
        raise_or_log(status)

def resolve_app_name(app):
    if ':' in app:
        parts = app.split(':', 2)
        sp_guid = get_obj_guid("space", parts[0])
        if not sp_guid:
            return ""
        token = get_token()
        status, msg = invoke_http(requests.get,
                                  "/v2/apps?q=space_guid:" + sp_guid + "&q=name:" + parts[1],
                                  token,
                                  "",
                                  base="")
        if status == 200 and len(msg["resources"]) > 0:
            #print >>sys.stderr, "App response: %s " % msg
            return msg["resources"][0]["metadata"]["guid"]
        else:
            return ""
    return get_obj_guid("app", app)

def get_api_url():
    global HOSTNAME
    cf_home = os.environ.get("CF_HOME", os.environ["HOME"])
    try:
        fp = open(cf_home + "/.cf/config.json")
        if fp:
           cfg = json.load(fp)
           HOSTNAME = cfg.get("Target")
    except Exception as e:
        print "%s" % e

if __name__ == '__main__':
    main()
