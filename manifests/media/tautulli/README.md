# Summary
[Tautulli](https://github.com/Tautulli/Tautulli) is a Plex activity monitor. It tracks who watched what and when. Useful for when we are trying to figure out if we've already seen a movie/show.

# Next Season Downloader
I made a script sourced from a [Reddit post](https://www.reddit.com/r/Overseerr/comments/1ct5ua6/automation_of_approving_additional_seasons_if_a/) and defined in an [external secret](base/external-secrets.yaml) that will tell [Seerr](/manifests/media/seerr) to download the next season of a show after 70% of the current season's shows have been watched. Keeps my drive from filling up with stuff that's not needed at the time. 

## Integration Steps
1. In Tautulli, go to `Settings` and then `Notification Agents`
2. Click `Add a new notification agent` and select `Script`
3. Set the `Script Folder` to `/scripts` [based on the volume where the secret is mounted](base/values.yaml)
4. Set the `Script File` to the `./season-fetcher.py` script
5. Set the `Script Timeout` to `30`
6. Add the following `Description`: 
    ```
    Initiates downloading the next season of a TV show as the previous season is being watched
    ```
7. On the `Triggers` tab, select `Watched`
8. On the `Arguments` tab, select `Watched` and enter the following argument:
    ```
    <episode>{show_name} {episode_num00} {season_num00} {library_name} {themoviedb_id} {user_email}</episode>
    ```
9. Click `Save`