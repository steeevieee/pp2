
# sudo apt install -y libyaml-perl libhttp-cache-transparent-perl libjson-xs-perl libdatetime-format-strptime-perl liblwp-useragent-determined-perl

cd /root/scrape

date > log

echo "Removing API files" >> log
find /root/scrape/cache -type f -size +1M -delete > /dev/null 2>&1
find /root/scrape/cache -type f -size -20k -delete > /dev/null 2>&1

echo "Removing TBA files" >> log
find /root/scrape/cache -type f -exec egrep -l "Url https://www.tvguide.co.uk/schedule/.*/tba/" {} \; -delete > /dev/null 2>&1

echo "Removing files without an episode where they should exist" >> log
PROGS=$(cat /root/scrape/clean.programmes | paste -sd'|' -)
find /root/scrape/cache -type f -exec grep -Lq '<p class="my-4 text-sm"' {} \; -exec egrep -l "Url https://www.tvguide.co.uk/schedule/.*/(${PROGS})/" {} \; -delete > /dev/null 2>&1

echo "Starting scraper" >> log
perl scrape.pl > output.xml

echo "Validating output" >> log
end=$(tail -n1 output.xml)
if [ "$end" == "</tv>" ]
then
  strings output.xml > xmltv.xml
  cat xmltv.xml | socat UNIX-CONNECT:/root/tvheadend/epggrab/xmltv.sock -
else
  echo "Output not valid" >> log
fi

date >> log
