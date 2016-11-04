Multi-Swift
===========

What
----
What does it take to be able to run multiple Swift clusters on shared hardware?

Assumptions
-----------
- Each cluster would have dedicated disk drives for storing data
- Only testing with 'tempauth' at this time

Why
---
Why would anyone want to do this? To reduce costs. For the same reasons that the
following support running multiple instances:
- relational databases
- web servers
- application servers

How
---
Each cluster must have its own ports, code base and configuration files. In the case of using
'tempauth' (default auth system for Swift), each cluster must be given its own
memcached instance. Each cluster should also have some indicator to use for syslog
entries so that individual log messages can be associated with a specific cluster.

When
----
The work on this idea was carried at the beginning of the Newton release cycle.

Who
---
This approach would likely be of interest to enterprises that are:
- deploying small to medium size Swift clusters
- highly sensitive to deployment costs (server hardware, per OS chargebacks)
- requiring some separation between different business units or departments

Alternatives
------------
- dedicated hardware deployments for each cluster
- virtualized servers running on common cluster hardware (separate OS instances)
- Docker/LXC containers per cluster running on shared host/parent
- multi-tenancy within Swift etc.

Example
-------
- Marketing department needs to store blobs (audio, images, video clips) for various
advertising campaigns
- Finance department needs to store scanned images of invoices, receipts,
contracts, etc.
- Suppose marketing department files must be stored in separate cluster due to
legal or regulatory requirements
- 1 set of servers for shared infrastructure
- Set up 2 Swift clusters - a 'Marketing' Swift cluster and a 'Finance' Swift
cluster
- Each cluster gets their own disk drives for storing data
    - Marketing: /srv/swift-mkt-disk
    - Finance: /srv/swift-fin-disk
- Swift Configuration files path
    - /etc/swift-mkt/swift.conf
    - /etc/swift-fin/swift.conf
    ...
- Proxy Ports
    - Marketing: 8180
    - Finance: 8280
- Storage Ports
    - Marketing: port ranges 61** - 61**
    - Finance: port ranges 62** - 62**
- Memcached
    - Marketing memcached running on port 11212
    - Finance memcached running on port 11213
- Run Directory
    - Marketing: /var/run/swift-mkt
    - Finance: /var/run/swift-fin
- Cache Directory
    - Marketing: /var/cache/swift-mkt*
    - Finance: /var/cache/swift-fin*
- Logs
    - Marketing: /var/log/swift-mkt
    - Finance: /var/log/swift-fin

Installation Process
-------------------
This project includes set of bash scripts with comments inline to install Swift All in One. This setup mimics the layout of [SAIO - Swift All In One](http://docs.openstack.org/developer/swift/development_saio.html)

- This project has custom code that enables passing the swift configuration directory as an environment variable "SWIFT_ROOT" that is set using the openrc file. Similarly, swift run dir "SWIFT_RUN_DIR" is set.
- Scripts such as "remakerings" and "resetswift" have been modified to suit the installation style
- openrc file contains crutial information to export into the environment before starting Swift services
- These changes enable us to have two separately cloned Swift repos with separate python-swiftclients configured to run on shared hardware

These scripts as targeted and tested for Ubuntu 14.04

##Order of execution:

```bash
1. sudo ./sys_swift_check_users.sh
2. sudo ./sys_swift_install_deps.sh
3. sudo ./sys_swift_setup.sh
4. sudo ./make_openrc.sh
```

At this point, multiple Swift clusters are installed. To get started using multiple instances, execute the following:

```bash
1. sudo su swift-<dept>
2. source ~/openrc
3. cd; ./start_swift.sh
```

##Remove Swift:

```bash
1. sudo ./stop_swift.sh
2. sudo ./sys_swift_remove.sh
```
