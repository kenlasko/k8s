Configure external machine as a remote machine learning endpoint for Immich:

```
netsh interface portproxy add v4tov4 listenport=3003 listenaddress=0.0.0.0 connectport=3003 connectaddress=172.25.251.239
netsh advfirewall firewall add rule name="WSL Port 3003" dir=in action=allow protocol=TCP localport=3003
```