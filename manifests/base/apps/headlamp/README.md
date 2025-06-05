# Summary
[Headlamp](https://github.com/headlamp-k8s/headlamp) is an easy-to-use and extensible Kubernetes web UI. 

To access it, you need a service account authentication token, which can be obtained by running:
```
kubectl -n kube-system get secret kubeapi-service-account-secret \
          -o jsonpath="{.data.token}" | base64 -d; echo
```