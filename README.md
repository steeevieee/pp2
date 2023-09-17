# scrape

* It's driven by scrape.yml
* It pulls most of the details from the API, but can't get episode details or a useful description
* It pulls the programme details page for episode details and a useful description, but this makes it much slower
  * Someone was asking them for the API swagger/spec, have they responded ?
  * Does anyone have a way of getting the API to include these details ?

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
