# Introduction
[Home Assistant](https://github.com/home-assistant) is my chosen home management platform. It controls nearly every aspect of my home.

Most configuration is done via my [custom Helm chart](/helm/baseline).

# Requirements
* Must run on a specific node (currently NUC4), because it relies on attachments for monitoring the UPS and Zigbee/Z-Wave dongles.
* USB functionality depends on [Smarter Device Manager](/manifests/system/smarter-device-manager).
* Z-Wave functionality requires that [ZWaveAdmin](/manifests/homeops/zwaveadmin) is installed and functional.

# Restoring from Backup
Backups are stored in `homeassist/backups`. Additional backups are saved in `/share/backup/vol`. If a restore is required, run the following:
```
tar -xOf <backupname>.tar homeassistant.tar.gz | tar --strip-components=1 -zxf - -C <destination-folder>
```
