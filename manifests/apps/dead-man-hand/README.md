# Summary
[Dead Man Hand](https://github.com/bkupidura/dead-man-hand) is a tool that is designed to perform actions after the owner hasn't checked in for an extended period of time.  It presumes something catastrophic has happened to the user.  I've configured this to send my wife an email with my financial details after I don't access Home Assistant for 2 weeks.

If that happens, I'm presumed to be dead or incapacitated. Grim, I know.

I've configured Home Assistant via `Browser-Mod` to trigger an automation every time I visit Home Assistant to send an "I'm Alive" message to DMH. As long as I keep visiting Home Assistant at least once every 2 weeks, nothing should trigger.

If I don't visit Home Assistant for a week, DMH will start sending me daily emails until I either open Home Assistant (triggering the automation) or directly visiting https://dmh.ucdialplans.com/api/alive. If I don't respond for a total of 2 weeks, the email to my wife will be sent.

## Script Update
I have the message text securely stored in my NixOS secrets that can be used to create a new action (can't modify the existing one) should my financial info need updating.

The [~/nixos/config/sops.nix](https://github.com/kenlasko/nixos-wsl/blob/main/config/sops.nix) NixOS flake makes the content available to the host OS as a file in `/run/secrets`

To modify the contents:
1. Edit the `secrets.yaml` using SOPS: `sops --config ~/nixos/.sops.yaml ~/nixos/config/secrets.yaml`
2. Search for the `dmh-email-message` text
3. Make the necessary modifications and save the contents
4. Run `sudo nixos-rebuild switch` to update the decrypted file

The action is already active in the pod. This script is only necessary if changes are made to the financial details. To replace the existing action:
1. EXEC into the `dead-man-hand-0` pod either via [K9S](https://github.com/derailed/k9s) or via `kubectl exec -it -n dmh dead-man-hand-0 -- sh`
2. Run `dmh-cli action ls` to get a list of current actions. There should be two. One is a reminder action. The other is the email to my wife.
3. Find the UUID for the wife email action and run `dmh-cli action delete --uuid <ENTERUUIDHERE>`
4. From the base OS, run the `~/nixos/scripts/dmh-create-action.sh` script with the updated instructions. You should get a message back that says `Action created successfully`

## Testing action
Run this from inside DMH pod:
```
dmh-cli action test --kind mail --data "{\"message\": \"Are you still alive?\n\nEither login to Home Assistant or visit:\nhttps://dead-man-hand.ucdialplans.com/api/alive\", \"subject\": \"DMH Inactivity Alert\", \"destination\":[\"tferguson@contoso.com\"]"}
```

## Prompt after inactivity
Configures an alert to be sent after x number of hours/days to remind me to check-in. Should only trigger if Home Assistant isn't updating DMH via the automation I've created for this. 

Run this from inside DMH pod:
```
dmh-cli action add --comment "Prompt for inactivity" --kind mail --process-after 48 --min-interval 20 --data "{\"message\": \"Are you still alive?\n\nEither login to Home Assistant or visit:\nhttps://dmh.ucdialplans.com/api/alive\", \"subject\": \"DMH Inactivity Alert\", \"destination\":[\"tferguson@contoso.com\"]"}
```
