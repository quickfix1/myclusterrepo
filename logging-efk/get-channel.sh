# Gets the channel value required for creating the subscription object
oc get packagemanifest elasticsearch-operator -n openshift-marketplace -o jsonpath='{.status.channels[].name}'
