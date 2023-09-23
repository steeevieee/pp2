# scrape

* It's driven by scrape.yml
* It pulls most of the details from the API, but can't get episode details or a useful description
* It pulls the programme details page for episode details and a useful description, but this makes it much slower
  * Someone was asking them for the API swagger/spec, have they responded ?
  * Does anyone have a way of getting the API to include these details ?

## scrape.yml
* Set the region, platform and number of days you want to scrape
* Set a list of channels
  * Clean name
  * ID that it's known as
  * Guide channel that your PVR knows it as
  * (Optional) Offset which takes the original channel data and creates a new channel with everything +offset hours
 
## clean.programmes
A list of programmes where you're expecting episode numbers to appear but they don't always appear. These are matched in the cache and removed before the main run.

## do
* Removes the old API files
* Removes any programmes that are TBA
* Removes anything matching clean.programmes
* Generates the listing
* If it's okay, send it to the PVR (needs customising for your own purpose)

## To Do (but not by me)
Here's a non-exhaustive list of things that need to be fixed, but I don't have the time to do it...
* seems to sanitize all programme names into acceptable uris so far, but there may be more cases that need fixing
* handle when the clocks change
* pull more that description and episode number from the details page
* allow parameters to be passed in
* offset days
* handle a `configure` parameter so that the config file can be generated
* make it all work inside the XMLTV framework
* find out if the subtitle does exist somewhere, as I've not found it yet
* better comments on the code
* category mapping, as the ones that come back match my PVR anyway
