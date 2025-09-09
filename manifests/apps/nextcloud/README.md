# Introduction
[Nextcloud](https://github.com/nextcloud) is an open-source platform for file storage, collaboration, and syncing that you can self-host as a private alternative to cloud services like Google Drive, Microsoft OneDrive or Dropbox.

I installed this after getting fed up with paying Microsoft over $100 a year for slow and sometimes buggy file syncing. Since I really wasn't using the MS Office suite to the same degree I used to, I elected to move to Nextcloud. It was a good decision.

All my documents on my Windows PC are quickly and reliably synced to Nextcloud, which stores the data on my NAS. QNAP HBS3 is used to replicate this data from my primary RAID-1 SSD drive pool to a backup drive in the same NAS along with my media drive. The data is backed up using [Backblaze S3](https://secure.backblaze.com/b2_buckets.htm) storage for less than 1/4 the cost of Microsoft OneDrive. 

[Collabora](https://github.com/collabora) is used for cloud-based app access (like Excel, Word etc). It works very well for my needs.

Nextcloud requires [MariaDB](/manifests/database/mariadb) and [Redis](/manifests/database/redis) to run.