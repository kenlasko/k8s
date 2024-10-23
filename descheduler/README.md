# Introduction
[Descheduler](https://github.com/kubernetes-sigs/descheduler) is a tool that tries to balance pods across nodes to make sure none are over/under-provisioned.

In this implementation, Descheduler is used for the following:
* Balancing pods across all worker nodes. Especially useful after node restarts
* Delete pods that have restarted more than 10 times

All are defined in [values.yaml](/descheduler/values.yaml)