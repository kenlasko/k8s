# Summary
[VolSync](https://github.com/backube/volsync) is a tool for backing up or replicating PVs to other locations. Its not terribly important as most of my PVs are hosted on the NAS and are backed up via NAS tools. 

One area where this could be useful is to streamline restoring from a cluster/NAS disaster where I'm having to start from scratch. Theoretically, I could stand up a new NAS and bootstrap the cluster using backups made with VolSync. 

Things stopping me from doing this:
* Believe that I can only backup to S3. I have limited free space available on Oracle and Cloudflare. Don't think I can do this without incurring costs.
* Having a combo NAS/cluster disaster is hopefully a very rare occurance. Probably not worth the effort.