# List CSRs
oc get csr 

# JQ alternative to approve csr
#oc get csr -ojson | jq -r '.items[] | select(.status == {}) | .metadata.name' | xargs oc adm certificate approve

# AWK command to approve csr
oc get csr | awk '/Pending/{print $1}' | xargs oc adm certificate approve
