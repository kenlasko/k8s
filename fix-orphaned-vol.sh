#!/bin/bash
while true
do
    badvol=$(journalctl -f -n 1 | grep -m 1 '"There were many similar errors. Turn up verbosity to see them." err="orphaned pod' | sed -nE 's/^.*\\"([a-f0-9\-]+)\\"\ found.*$/\1/p')
    echo "Badvol is $badvol"
    find /var/lib/kubelet/pods/$badvol/volumes/kubernetes.io~csi/. -name vol_data.json -delete
done
