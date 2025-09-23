
## Testing action
Run this from inside DMH pod:
```
dmh-cli action test --kind mail --data "{\"message\": \"Are you still alive?\n\nEither login to Home Assistant or visit:\nhttps://dead-man-hand.ucdialplans.com/api/alive\", \"subject\": \"DMH Inactivity Alert\", \"destination\":[\"ken.lasko@gmail.com\"]"}
```

## Prompt after inactivity
```
dmh-cli action add --comment "Prompt for inactivity" --kind mail --process-after 24 --min-interval 20 --data "{\"message\": \"Are you still alive?\n\nEither login to Home Assistant or visit:\nhttps://dead-man-hand.ucdialplans.com/api/alive\", \"subject\": \"DMH Inactivity Alert\", \"destination\":[\"ken.lasko@gmail.com\"]"}
```
