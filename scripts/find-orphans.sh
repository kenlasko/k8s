#!/bin/bash

# This script goes over each api-resource and compares the namespaces listed by the resources of that api-resource against 
# the list of existing namespaces, while printing the api-resource + namespace + resource name when it finds a namespace that is not in kubectl get ns.
#
# Useful for finding orphaned resources

current_namespaces=($(kubectl get ns --no-headers | awk '{print $1}'))
api_resources=($(kubectl api-resources --verbs=list --namespaced -o name))
for api_resource in ${api_resources[@]}; do
    while IFS= read -r line; do
        resource_namespace=$(echo $line | awk '{print $1}')
        resource_name=$(echo $line | awk '{print $2}')
        if [[ ! " ${current_namespaces[@]} " =~ " $resource_namespace " ]]; then
            echo "api-resource: ${api_resource} - namespace: ${resource_namespace} - resource name: ${resource_name}"
        fi
    done < <(kubectl get $api_resource -A --ignore-not-found --no-headers -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name")
done