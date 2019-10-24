set -u

ETH_DEV=ens192
NGINX_DIRECTORY=.
NGINX_HOST=$(ip addr show dev ${ETH_DEV} | awk '/inet /{print $2}' | sed 's,/[0-9]*$,,')
NGINX_PORT=8000

create_ifcfg(){
  cat > ${NGINX_DIRECTORY}/${HOST}-ens192 << EOF
DEVICE=ens192
BOOTPROTO=none
ONBOOT=yes
NETMASK=${NETMASK}
IPADDR=${IP}
GATEWAY=${GATEWAY}
PEERDNS=yes
DNS1=${DNS1}
DNS2=${DNS2}
IPV6INIT=no
EOF

  ENO2=$(cat ${NGINX_DIRECTORY}/${HOST}-ens192 | base64 -w0)
  rm ${NGINX_DIRECTORY}/${HOST}-ens192

  cat > ${NGINX_DIRECTORY}/${HOST}-ifcfg-ens192.json << EOF
{
  "append" : false,
  "mode" : 420,
  "filesystem" : "root",
  "path" : "/etc/sysconfig/network-scripts/ifcfg-ens192",
  "contents" : {
    "source" : "data:text/plain;charset=utf-8;base64,${ENO2}",
    "verification" : {}
  },
  "user" : {
    "name" : "root"
  },
  "group": {
    "name": "root"
  }
},
EOF

#  cat > ${NGINX_DIRECTORY}/${HOST}-eno1 << EOF
#DEVICE=eno1
#BOOTPROTO=none
#ONBOOT=no
#EOF
#  ENO1=$(cat ${NGINX_DIRECTORY}/${HOST}-eno1 | base64 -w0)
#  rm ${NGINX_DIRECTORY}/${HOST}-eno1
#  cat > ${NGINX_DIRECTORY}/${HOST}-ifcfg-eno1.json << EOF
#{
#  "append" : false,
#  "mode" : 420,
#  "filesystem" : "root",
#  "path" : "/etc/sysconfig/network-scripts/ifcfg-eno1",
#  "contents" : {
#    "source" : "data:text/plain;charset=utf-8;base64,${ENO1}",
#    "verification" : {}
#  },
#  "user" : {
#    "name" : "root"
#  },
#  "group": {
#    "name": "root"
#  }
#},
#EOF

# Hostname was originally prefixed with "${CLUSTER_NAME}-"
cat > ${NGINX_DIRECTORY}/${HOST}-hostname << EOF
${HOST}.${DOMAIN_NAME}
EOF
  HN=$(cat ${NGINX_DIRECTORY}/${HOST}-hostname | base64 -w0)
  rm ${NGINX_DIRECTORY}/${HOST}-hostname
  cat > ${NGINX_DIRECTORY}/${HOST}-hostname.json << EOF
{
  "append" : false,
  "mode" : 420,
  "filesystem" : "root",
  "path" : "/etc/hostname",
  "contents" : {
    "source" : "data:text/plain;charset=utf-8;base64,${HN}",
    "verification" : {}
  },
  "user" : {
    "name" : "root"
  },
  "group": {
    "name": "root"
  }
},
EOF
}

# Disable set hostname via reverse lookup
# Common to all hosts
cat > ${NGINX_DIRECTORY}/hostname-mode << EOF
[main]
hostname-mode=none
EOF
  HM=$(cat ${NGINX_DIRECTORY}/hostname-mode | base64 -w0)
  rm ${NGINX_DIRECTORY}/hostname-mode
  cat > ${NGINX_DIRECTORY}/hostname-mode.json << EOF
{
  "append" : false,
  "mode" : 420,
  "filesystem" : "root",
  "path" : "/etc/NetworkManager/conf.d/hostname-mode.conf",
  "contents" : {
    "source" : "data:text/plain;charset=utf-8;base64,${HM}",
    "verification" : {}
  },
  "user" : {
    "name" : "root"
  },
  "group": {
    "name": "root"
  }
},
EOF

modify_ignition(){
  cp -u ${NGINX_DIRECTORY}/${TYPE}.ign ${NGINX_DIRECTORY}/${HOST}.ign.orig
  #jq '.storage.files += [inputs]' ${NGINX_DIRECTORY}/${HOST}.ign.orig ${NGINX_DIRECTORY}/${HOST}-hostname.json ${HOST}-ifcfg-eno2.json ${NGINX_DIRECTORY}/hostname-mode.json > ${NGINX_DIRECTORY}/${HOST}.ign # ${HOST}-ifcfg-eno1.json
  cat ${NGINX_DIRECTORY}/${HOST}-hostname.json ${HOST}-ifcfg-ens192.json ${NGINX_DIRECTORY}/hostname-mode.json > inf.json
  if [ "${TYPE}" != "bootstrap" ]; then
    sed -i '$s/,//' inf.json
  fi
  python -m json.tool < ${NGINX_DIRECTORY}/${HOST}.ign.orig | awk -v inf=inf.json '/storage.: \{\}/{print "    \"storage\": { \"files\": [";while(getline<inf){print};print "   ] },";next}; //; /files.:/{while(getline<inf){print}}' > ${NGINX_DIRECTORY}/${HOST}.ign
  rm -f ${NGINX_DIRECTORY}/${HOST}-hostname.json ${HOST}-ifcfg-eno1.json ${HOST}-ifcfg-ens192.json inf.json

  # Now create bootstrap append file
  cat > append-bootstrap-${HOST}.ign <<EOF
{
    "ignition": {
        "config": {
            "append": [
                {
                    "source": "http://${NGINX_HOST}:${NGINX_PORT}/${NGINX_DIRECTORY}/${HOST}.ign",
                    "verification": {}
                }
            ]
        },
        "timeouts": {},
        "version": "2.1.0"
    },
    "networkd": {},
    "passwd": {},
    "storage": {},
    "systemd": {}
}
EOF

  # And convert ignition file to base64
  base64 -w0 ${NGINX_DIRECTORY}/append-bootstrap-${HOST}.ign > ${NGINX_DIRECTORY}/append-bootstrap-${HOST}.64

}

TYPE="bootstrap"
HOST=${BOOTSTRAP_NAME}
IP=${BOOTSTRAP_IP}
create_ifcfg
modify_ignition

TYPE="master"
HOST=${MASTER0_NAME}
IP=${MASTER0_IP}
create_ifcfg
modify_ignition

HOST=${MASTER1_NAME}
IP=${MASTER1_IP}
create_ifcfg
modify_ignition

HOST=${MASTER2_NAME}
IP=${MASTER2_IP}
create_ifcfg
modify_ignition

TYPE="worker"
HOST=${WORKER0_NAME}
IP=${WORKER0_IP}
create_ifcfg
modify_ignition

HOST=${WORKER1_NAME}
IP=${WORKER1_IP}
create_ifcfg
modify_ignition

HOST=${WORKER2_NAME}
IP=${WORKER2_IP}
create_ifcfg
modify_ignition

HOST=${WORKER3_NAME}
IP=${WORKER3_IP}
create_ifcfg
modify_ignition

# Now convert master and worker files to base64
base64 -w0 ${NGINX_DIRECTORY}/master.ign > ${NGINX_DIRECTORY}/master.64
base64 -w0 ${NGINX_DIRECTORY}/worker.ign > ${NGINX_DIRECTORY}/worker.64

