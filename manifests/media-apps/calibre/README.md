[Calibre-Web-Automated](https://github.com/crocodilestick/Calibre-Web-Automated) is a tool to manage ebooks used in our Kobo devices and is available via https://books.ucdialplans.com. Not only does it allow for web-based management of ebooks, it can also [automatically sync ebooks to Kobo e-readers](https://github.com/janeczku/calibre-web/wiki/Kobo-Integration).

For this to work, the Kobo e-reader needs to be connected to a PC so its folders/files can be viewed and edited. 
1. Connect the Kobo to a PC and select **Connect**.
2. Navigate to the `.kobo/Kobo` folder and edit the `Kobo eReader.conf` file
3. Under the `[OneStoreServices]` section, search for a line that starts with `api_endpoint`. 
4. Replace the default `api_endpoint=https://storeapi.kobo.com` with the URL and token generated in the user's account section. Will look something like `https://books.ucdialplans.com/kobo/<LongToken>`
5. Save the file and unplug the e-reader
6. Press the `Sync` button and wait for the sync to complete.

The book library is stored on the NAS in the `media/books` folder. 

Also included is a book downloader that integrates with Calibre-Web-Automated, which uses the [Calibre Web Automated Book Downloader](https://github.com/calibrain/calibre-web-automated-book-downloader) to download books. Downloaded books are automatically added to the Calibre library. Accessible via https://book-dl.ucdialplans.com

Most configuration is done via my [custom Helm chart](/helm/baseline)