#!/bin/bash
#Script to modify the default project template to allow Pods to accept connections from other Pods in the same Project
#but reject all other connections from Pods in other projects.

oc project openshift-config
sleep 3
oc create -f template.yaml
sleep 3
oc patch project.config.openshift.io/cluster --type merge --patch '{"spec":{"projectRequestTemplate":{"name":"project-request"}}}'
echo -e "\nScript Completed\n\n"

