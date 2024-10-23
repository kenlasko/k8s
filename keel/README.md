# Summary
[Keel](https://github.com/keel-hq/keel) is a tool for automatically updating the images used by pods. It handles any image that isn't managed via Helm. Every **2 hours**, Keel will check for updated images for all monitored apps. If an update is found, Keel will delete the pod, which should trigger a pull of the newer image. This assumes `imagePullPolicy: Always`. 

For a pod to be monitored by Keel, it requires the following annotations:
```
metadata:
  annotations:
    keel.sh/policy: force
    keel.sh/match-tag: "true"
    keel.sh/trigger: poll
```

Notifications about upgrades are sent to email and Slack.