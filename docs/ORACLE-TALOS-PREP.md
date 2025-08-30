# Oracle Cloud Talos Node Prep
I use Oracle Cloud to host my single node Talos cluster. Oracle does not have a built-in Talos image, so these are the steps to create your own.

1. Download ARM64 Talos Oracle image from https://omni.ucdialplans.com and place in /home/ken/
2. Create image metadata file and save as ```image_metadata.json```
```
{
    "version": 2,
    "externalLaunchOptions": {
        "firmware": "UEFI_64",
        "networkType": "PARAVIRTUALIZED",
        "bootVolumeType": "PARAVIRTUALIZED",
        "remoteDataVolumeType": "PARAVIRTUALIZED",
        "localDataVolumeType": "PARAVIRTUALIZED",
        "launchOptionsSource": "PARAVIRTUALIZED",
        "pvAttachmentVersion": 2,
        "pvEncryptionInTransitEnabled": true,
        "consistentVolumeNamingEnabled": true
    },
    "imageCapabilityData": null,
    "imageCapsFormatVersion": null,
    "operatingSystem": "Talos",
    "operatingSystemVersion": "1.8.1",
    "additionalMetadata": {
        "shapeCompatibilities": [
            {
                "internalShapeName": "VM.Standard.A1.Flex",
                "ocpuConstraints": null,
                "memoryConstraints": null
            }
        ]
    }
}
```
3. Create .oci image for Oracle
```
xz --decompress oracle-arm64-omni-onprem-omni-v1.8.1.qcow2.xz
tar zcf talos-oracle-arm64.oci oracle-arm64.qcow2 image_metadata.json
```
4. Copy image to [Oracle storage bucket](https://cloud.oracle.com/object-storage/buckets?region=ca-toronto-1)
5. [Import custom image](https://cloud.oracle.com/compute/images?region=ca-toronto-1) to Oracle cloud
6. Edit image capabilities and set ```Boot volume type``` and ```Local data volume``` to ```PARAVIRTUALIZED```
7. [Create instance](https://cloud.oracle.com/compute/instances?region=ca-toronto-1) using custom image
8. Open all inbound firewall ports from home network
9. Set Oracle public IP address on [Unifi port forwarding](https://unifi.ucdialplans.com/network/default/settings/security/port-forwarding)
