#!/usr/bin/python
import json
import sys

ApiPort=sys.argv[1]
SystemDomain=sys.argv[2]


with open( '/var/vcap/jobs/route_registrar/config/registrar_settings.json' ) as f:
   dictRoute = json.load(f)

dictControllerRoute = dict()
dictControllerRoute['name'] = 'networking-aci-api'
dictControllerRoute['port'] = int(ApiPort)
dictControllerRoute['registration_interval'] = '10s'
dictControllerRoute['tags'] = {}
dictControllerRoute['tags']['component'] = 'aci'
dictControllerRoute['uris'] = []
dictControllerRoute['uris'].append(SystemDomain+'/networking-aci')


if not (any(d['name'] == 'networking-aci-api' for d in dictRoute['routes'])):
   dictRoute['routes'].append(dictControllerRoute)
   with open('/var/vcap/jobs/route_registrar/config/registrar_settings.json','w') as f:
      json.dump(dictRoute, f)
