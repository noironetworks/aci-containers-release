#!/bin/bash

if ! [ -x "$(command -v sshpass)" ]; then
  echo 'Error: sshpass is not installed.' >&2
  exit 1
fi

function print_help {
   echo "Usage: $(basename $0) [-u] [-h] <host> <username> <password>"
   echo
   echo "Positional parameters"
   echo "  host        Name or IP address of OpsManager"
   echo "  username    Name of local user on OpsManager with sudo privileges"
   echo "  password    Password of local user"
   echo
   echo "Options"
   echo "  -u          Undo the patch"
   echo "  -h, --help  Display usage"
   exit 0
}

UNDO=0
for arg do
   shift
   if [[ $arg == "-h" || $arg == "--help" ]]; then
      print_help
   elif [[ $arg == "-u" ]];then
      UNDO=1
   else
      set -- "$@" "$arg"
   fi
done

if [ $# -lt  3 ]; then
    print_help
fi

HOME=/home/tempest-web/tempest
sshpass -p "$3" ssh -q $2@$1 "cat > /tmp/aci-patch.diff" <<ENDOFPATCH
--- web/app/models/tempest/manifests/product_manifest_generator.rb
+++ web/app/models/tempest/manifests/product_manifest_generator.rb
@@ -174,6 +174,7 @@
       end

       def vip_network(job)
+        return [{'name' => 'apic-infra'}] if job.template.name =~ /diego_cell$/
         return [] unless job.floating_ips.present?

         [
@@ -219,6 +220,11 @@
           extra_env['vapp'] = @installation.infrastructure.vapp_name(@product.identifier)
         end

+        if job.template.name =~ /diego_cell$/
+          extra_env['bosh'] ||= {}
+          extra_env['bosh']['ipv6'] = {'enable' => true}
+        end
+
         extra_env
       end
     end
ENDOFPATCH

if [[ $UNDO -eq 0 ]]; then
   sshpass -p "$3" ssh -q -t $2@$1 "cd $HOME; echo \"$3\" | sudo -p \"\" -k -S patch -p0 -b -N -r - -i /tmp/aci-patch.diff"
else
   sshpass -p "$3" ssh -q -t $2@$1 "cd $HOME; echo \"$3\" | sudo -p \"\" -k -S cp web/app/models/tempest/manifests/product_manifest_generator.rb.orig web/app/models/tempest/manifests/product_manifest_generator.rb"
fi

if [ $? -eq 0 ];then
   sshpass -p "$3" ssh -q -t $2@$1 "echo \"$3\" | sudo -p \"\" -k -S service tempest-web restart"
fi
