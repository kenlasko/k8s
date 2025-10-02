> [!WARNING] 
> I wasn't really using Gitea, so I've elected to remove it. At some point, I may restore this, but will likely move to the open-source replacement [Forgejo](https://github.com/forgejo)

# Summary
[Gitea](https://github.com/go-gitea/gitea) is a self-hosted Git repository. Its not actively used, but acts as a sort of backup in case something happens to Github. All my Github repositories are regularly pulled from Github and synced to Gitea, by following [this process](https://docs.gitea.com/usage/repo-mirror#pulling-from-a-remote-repository).

For more insurance against Github issues, I also use [Gickup](https://github.com/cooperspencer/gickup) to regularly backup my Github repositories to a local backup. It is also regularly backed up to Cloudflare S3 storage via [Volsync](/manifests/system/volsync).

With all of these options, I should be able to recover from a Github disaster.

Most configuration is done via my [custom Helm chart](/helm/baseline).

However, seeing how I just never use it, I removed it for the time being.