#!/bin/bash

#Author: Paul Dardeau <paul.dardeau@intel.com>
#        Nandini Tata <nandini.tata@intel.com>
# Copyright (c) 2016 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.


################################################
# scripts to setup environment and install Swift
################################################


#*************General Information*************
# 1) /var/log/swift - /etc/rsyslog.d/10-swift.conf is the log file that enables rsyslog to write logs to /var/log/swift
# 2) /var/cache/swift - swift-recon dumps stats in the cache directory dedicated to each storage node
# 3) /var/run/swift - swift processes's pids are stored in /var/run/swift. 
# 4) /tmp/log/swift - a temporary directory used by some unit tests to run the profiler
# 5) memcached service stores user credentials along with the tokens. It is important to ensure its running before starting the swift services
# 6) This SAIO mimics the web solution  - 4 devices carved out 1 GB swift-disk and mounted as 4 loopback devices at /mnt/sdb1
#***************************************


# Ensures the script is being run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
   exit 1
fi

SWIFT_GROUP=swift

SWIFT_DISK_SIZE_GB="1"
SWIFT_DISK_BASE_DIR="/srv"
SWIFT_MOUNT_BASE_DIR="/mnt"
SWIFT_CACHE_BASE_DIR="/var/cache"

CLUSTER_COUNT=0

# good idea to have backup of fstab before we modify it
cp /etc/fstab /etc/fstab.insert.bak

for i in `more clusters.txt`; do
  
   CLUSTER_COUNT=$(expr ${CLUSTER_COUNT} + 1)

   SWIFT_USER=swift-${i}

   SWIFT_CONFIG_DIR="/etc/swift-${i}"
   SWIFT_RUN_DIR="/var/run/swift-${i}"
   SWIFT_PROFILE_LOG_DIR="/tmp/log/swift-${i}/profile"
   SWIFT_LOG_DIR="/var/log/swift-${i}"
   mkdir -p "${SWIFT_CONFIG_DIR}"
   mkdir -p "${SWIFT_DISK_BASE_DIR}"
   mkdir -p "${SWIFT_RUN_DIR}"
   mkdir -p "${SWIFT_PROFILE_LOG_DIR}"
   mkdir -p "${SWIFT_LOG_DIR}"

   chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_RUN_DIR}
   chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_PROFILE_LOG_DIR}
   chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_LOG_DIR}

   SWIFT_DISK="${SWIFT_DISK_BASE_DIR}/swift-${i}-disk"
   truncate -s "${SWIFT_DISK_SIZE_GB}GB" "${SWIFT_DISK}"
   mkfs.xfs -f "${SWIFT_DISK}"


   cat >> /etc/fstab << EOF
/srv/swift-${i}-disk /mnt/swift-${i} xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0
EOF

   SWIFT_MOUNT_POINT_DIR="${SWIFT_MOUNT_BASE_DIR}/swift-${i}"
   mkdir -p ${SWIFT_MOUNT_POINT_DIR}

   mount -a 

   for x in {1..4}; do
      echo "creating folders"
      mkdir "${SWIFT_MOUNT_POINT_DIR}/${x}"
   done

   for x in {1..4}; do
      SWIFT_DISK_DIR="${SWIFT_DISK_BASE_DIR}/swift-${i}-${x}"
      SWIFT_MOUNT_DIR="${SWIFT_MOUNT_POINT_DIR}/${x}"
      SWIFT_CACHE_DIR="${SWIFT_CACHE_BASE_DIR}/swift-${i}-${x}"

      mkdir -p "${SWIFT_CACHE_DIR}"
 
      ln -s ${SWIFT_MOUNT_DIR} ${SWIFT_DISK_DIR}
   #   used by swift recon to dump the stats to cache
       chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_CACHE_DIR}
   done

   mkdir -p ${SWIFT_DISK_DIR}/node/sdb1
   mkdir -p ${SWIFT_DISK_DIR}/node/sdb2
   mkdir -p ${SWIFT_DISK_DIR}/node/sdb3
   mkdir -p ${SWIFT_DISK_DIR}/node/sdb4 

   mkdir -p ${SWIFT_DISK_DIR}/node/sdb5
   mkdir -p ${SWIFT_DISK_DIR}/node/sdb6
   mkdir -p ${SWIFT_DISK_DIR}/node/sdb7
   mkdir -p ${SWIFT_DISK_DIR}/node/sdb8

   chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_DISK_DIR}
   chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_MOUNT_POINT_DIR}


   SWIFT_USER_HOME="/home/${SWIFT_USER}"
   SWIFT_USER_BIN="${SWIFT_USER_HOME}/.local/bin"
   #mkdir -p ${SWIFT_USER_BIN}

   SWIFT_LOGIN_CONFIG="${SWIFT_USER_HOME}/.bashrc"

   cd ${SWIFT_USER_HOME}

   EXPORT_TEST_CFG_FILE="export SWIFT_TEST_CONFIG_FILE=${SWIFT_CONFIG_DIR}/test.conf"
   grep "${EXPORT_TEST_CFG_FILE}" ${SWIFT_LOGIN_CONFIG}
   if [ "$?" -ne "0" ]; then
      echo "${EXPORT_TEST_CFG_FILE}" >> ${SWIFT_LOGIN_CONFIG}
   fi

   SWIFT_REPO_DIR="${SWIFT_USER_HOME}/swift"
   SWIFT_CLI_REPO_DIR="${SWIFT_USER_HOME}/python-swiftclient"

   if [ -d ${SWIFT_USER_HOME}/swift ]; then
      su - ${SWIFT_USER} -c 'cd swift && git pull'
   else
      su - ${SWIFT_USER} -c 'git clone https://github.com/openstack/swift'
   fi

   if [ -d ${SWIFT_USER_HOME}/python-swiftclient ]; then
      su - ${SWIFT_USER} -c 'cd python-swiftclient && git pull'
   else
      su - ${SWIFT_USER} -c 'git clone https://github.com/openstack/python-swiftclient'
   fi

   EXPORT_PATH="export PATH=${PATH}:${SWIFT_USER_BIN}"
   grep "${EXPORT_PATH}" ${SWIFT_LOGIN_CONFIG}
   if [ "$?" -ne "0" ]; then
      echo "${EXPORT_PATH}" >> ${SWIFT_LOGIN_CONFIG}
   fi

   echo "export PYTHONPATH=${SWIFT_USER_HOME}/swift" >> ${SWIFT_LOGIN_CONFIG}

# ************Updating config files************
   cp ${SWIFT_REPO_DIR}/test/sample.conf ${SWIFT_CONFIG_DIR}/test.conf
   cp ${SWIFT_REPO_DIR}/etc/memcache.conf-sample ${SWIFT_CONFIG_DIR}/memcache.conf
   cp ${SWIFT_REPO_DIR}/etc/swift-rsyslog.conf-sample ${SWIFT_CONFIG_DIR}/swift-rsyslog.conf
   
   cd ${SWIFT_REPO_DIR}/doc/saio/swift; cp -r * ${SWIFT_CONFIG_DIR}
   cd ${SWIFT_CONFIG_DIR}

   #updating memcache config
   sed -i 's/^\(#\)\( memcache_servers =.*:\)\(.*\)/echo "\2$((\3+'"${x}"'))"/ge' ${SWIFT_CONFIG_DIR}/memcache.conf
   #updating rsyslog parameters in its config
   sed -i 's/^\(#\)\(local\.\*.*\)/\2/g' ${SWIFT_CONFIG_DIR}/swift-rsyslog.conf 
   sed -i 's/\/var\/log\/swift/\/var\/log\/'${SWIFT_USER}'/g' ${SWIFT_CONFIG_DIR}/swift-rsyslog.conf

   #setting ports in configs
   PORT_INCREMENT=$(expr 100 \* ${CLUSTER_COUNT})
   find . -type f -exec sed -i 's/^bind_port = \(6[0-9]*\)/echo "bind_port = $((\1+'"${PORT_INCREMENT}"'))"/ge' {} \;
   #find . -type f -exec sed -i 's/^auth_port = \([0-9]*\)/echo "auth_port = $((\1+'"${PORT_INCREMENT}"'))"/ge' {} \;
   #find . -type f -exec sed -i 's/(8080)/echo "$((\1+'"${PORT_INCREMENT}"'))"/ge' {} \;
   
   PROXY_PORT=$(find . -name "proxy-server.conf" -exec sed -n 's/bind_port = \([0-9]*\)/\1/p' {} \;)
   NEW_PROXY_PORT=$(expr ${PROXY_PORT} + ${PORT_INCREMENT})
   find . -type f -exec sed -i 's/8080/'"${NEW_PORT}"'/g' {} \;
  
   #updating username in configs
   #find . -type f -exec sed -i 's/^user =.*/echo "user = '"${SWIFT_USER}"'"/ge' {} \;

   #updating devices and cache directories
   find . -type f -exec sed -i 's/\/var\/cache\/swift/\/var\/cache\/swift1/g' {} \;
   for x in {1..4} 
   do
      find . -type f -exec sed -i 's/\/srv\/'${x}'\/node/\/srv\/swift-'${i}'-'${x}'\/node/g' {} \;
      find . -type f -exec sed -i 's/\/var\/cache\/swift'${x}'/\/var\/cache\/swift-'${i}'-'${x}'/g' {} \;
   done
   cd -
   chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_CONFIG_DIR}
   find ${SWIFT_CONFIG_DIR}/ -name \*.conf | xargs sed -i "s/<your-user-name>/${SWIFT_USER}/"

# TODO********Updating logging**********
#   cp ${SWIFT_REPO_DIR}/doc/saio/rsyslog.d/10-swift.conf /etc/rsyslog.d/
#   sed -i '2 s/^#//' /etc/rsyslog.d/10-swift.conf

   cd ${SWIFT_CLI_REPO_DIR}
   su - ${SWIFT_USER} -c
   su - ${SWIFT_USER} -c 'yes | pip install -r requirements.txt'
   su - ${SWIFT_USER} -c 'yes | pip install -r test-requirements.txt'
   su - ${SWIFT_USER} -c 'yes | pip install -U pip tox pbr virtualenv setuptools'
   su - ${SWIFT_USER} -c 'apt-get install -y  libpython3.4-dev'
   su - ${SWIFT_USER} -c 'python setup.py install --user'
   su - ${SWIFT_USER} -c 'chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_CLI_REPO_DIR}'


   cd ${SWIFT_REPO_DIR}
   su - ${SWIFT_USER} -c 'yes | pip install -r requirements.txt'
   su - ${SWIFT_USER} -c 'yes | pip install -r test-requirements.txt'
   su - ${SWIFT_USER} -c 'yes | pip install PyECLib'
   su - ${SWIFT_USER} -c 'python setup.py install --user'
   su - ${SWIFT_USER} -c 'apt-get remove -y python-six'
   su - ${SWIFT_USER} -c 'yes | pip install -U six'
   su - ${SWIFT_USER} -c 'chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_REPO_DIR}'

   cd ${SWIFT_REPO_DIR}/doc/saio/bin; cp * ${SWIFT_USER_BIN};
   chown -R ${SWIFT_USER}:${SWIFT_GROUP} ${SWIFT_USER_BIN}; cd -

   sed -i "/find \/var\/log\/swift/d" ${SWIFT_USER_BIN}/resetswift
   sed -i 's/\/dev\/sdb1/\/srv\/swift-'${i}'-disk/g' ${SWIFT_USER_BIN}/resetswift
   sed -i 's/\/mnt\/sdb1/\/mnt\/swift-'${i}'/g' ${SWIFT_USER_BIN}/resetswift
   sed -i 's/\/var\/cache\/swift/\/var\/cache\/swift-'${i}'' ${SWIFT_USER_BIN}/resetswift
   for x in {1..4}; do
      sed -i 's/\/srv\/'${x}'\/node/\/srv\/swift-'${i}'-'${x}'\/node/g' ${SWIFT_USER_BIN}/resetswift
   done
EOF
done

