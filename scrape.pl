#!/usr/bin/perl

use YAML::XS 'LoadFile';
use HTTP::Cache::Transparent;
use HTML::TreeBuilder 5 -weak;
use LWP::UserAgent::Determined;
use JSON::XS;
use POSIX qw(strftime);
use Date::Parse;

my $HTML_URL		= 'https://www.tvguide.co.uk';
my $API_URL		= 'https://api.tvguide.co.uk';
my $PLATFORM_URL        = $API_URL . '/platforms';
my $REGION_URL          = $API_URL . '/regions';
my $SCHEDULE_URL        = $API_URL . '/schedules';
my $CONFIG_FILE         = 'scrape.yml';

# Load config
my $config = LoadFile($CONFIG_FILE);

# Set up cache
HTTP::Cache::Transparent::init( {
	BasePath => $config->{cachedir},
	NoUpdate => 60 * 60 * 24 * $config->{days},
	MaxAge => 24 * $config->{days},
} );

# Create user agent
my $browser = LWP::UserAgent::Determined->new;
$browser->agent('Mozilla/5.0');
$browser->timing('5,10,90');
$http_codes_hr = $browser->codes_to_determinate();
$http_codes_hr->{524} = 1;

# Set output to be unbuffered
BEGIN{ $| = 1; }

# Print header block
print_header();

# Print channel block
print_channels();

# Lookup platform and region ids from strings
my $platform_id = get_platform_id($config->{platform});
my $region_id = get_region_id($platform_id, $config->{region});

# Get all the json schedule data for all channels for all days in one blob
my $data_blob = get_all_data();

# Get the listings from th eblob for each channel
my $channels = $config->{channels};
for my $channel (@$channels) {
    my $offset = 0;
    my $category = '';
    if (defined($channel->{offset})) { $offset = $channel->{offset}; }
    if (defined($channel->{category})) { $category = $channel->{category}; }
    get_listings($channel->{id}, $channel->{guide}, $offset, $category);
}

# Print footer block
print_footer();

# start_time is 00:00:00 today
# end_time is 23:59:59 in (today + config{days})
# grabs all the available data, doesn't seem to fail if you request too many days
sub get_all_data {
    my $start_time = strftime("%FT00:00:00.000Z", localtime);
    my $end_time = strftime("%FT23:59:59.999Z", localtime(time() + ($config->{days} * 86400)));
    my $url = $SCHEDULE_URL . '?start=' . $start_time . '&end=' . $end_time . '&platformId=' . $platform_id . '&regionId=' . $region_id;
    my $response = $browser->get($url);
    die "Can't get $url -- ", $response->status_line
        unless $response->is_success;
    return decode_json($response->content);
}

# for each channel
#   parse the json blob for the schedule of programmes
#     for each program
#       clean up the title
#       convert start/end to xmltv format
#       work out the html page for the program
#       get the html page (should also go into the cache)
#       grab the relevant info from the html
#       TODO: only grabbing summary/category/episode as that's all I need
#       print out the details
sub get_listings {
	my ($channel_id, $guide_name, $offset, $cat) = @_;
    $offset = $offset * 3600;
    for my $item (@$data_blob) {
        if ($item->{id} eq $channel_id) {
            $schedules = $item->{schedules};
            for my $program (@$schedules) {
                my $epispode_string = '';
		my $category = '';
                $encoded_title = sanitize_title_uri($program->{title});
		if ($encoded_title eq "tba") { next; }
		if ($encoded_title eq "close") { next; }
                $details_url = $HTML_URL . '/schedule/' . $program->{id} . '/' . $encoded_title . '/';
                $start = strftime("%Y%m%d%H%M%S +0000", localtime(str2time(substr($program->{start_at}, 0, 18)) + $offset));
                $end = strftime("%Y%m%d%H%M%S +0000", localtime(str2time(substr($program->{end_at}, 0, 18)) + $offset));
                my $response = $browser->get($details_url);
                die "Can't get $details_url -- ", $response->status_line
                    unless $response->is_success;
                my $tree = HTML::TreeBuilder->new;
                $tree->parse($response->content);
		my $summary_entity = $tree->look_down('_tag' => 'div', 'class' => 'mx-auto max-w-prose p-4 text-white')->look_down('_tag' => 'p');
		my $summary = $summary_entity ? $summary_entity->as_text : $program->{title};
#                my $summary = $tree->look_down('_tag' => 'div', 'class' => 'mx-auto max-w-prose p-4 text-white')->look_down('_tag' => 'p')->as_text || die "Failed on " . $details_url . "\n";
		if ($cat eq '')
		{
                        $category = $tree->look_down('_tag' => 'div', 'class' => 'mx-auto max-w-prose p-4 text-white')->look_down('_tag' => 'div', 'class' => 'rounded-full bg-neutral-600 px-2')->as_text;
                        $category =~ s{/}{ / }g;
		}
		else
		{	
                        $category = $cat;
		}
                my $series_entity = $tree->look_down('_tag' => 'div', 'class' => 'mx-auto max-w-prose p-4 text-white')->look_down('_tag' => 'p', 'class' => 'my-4 text-sm');
                my $series_string = $series_entity ? $series_entity->as_text : '';
                if ($series_string ne '') {
                    my ($showsxx, $showexx, $showeof) = ( $series_string =~ /^(?:(?:Series|Season) (\d+)(?:[., :]+)?)?(?:Episode (\d+)(?: of (\d+))?)?/ );
                    $epispode_string = make_ns_epnum($showsxx, $showexx, $showeof);
                }
                print "  <programme start=\"" . $start . "\" channel=\"" . $guide_name . "\" stop=\"". $end . "\">\n";
                print "    <title lang=\"en\">" . sanitize_string($program->{title}) . "</title>\n";
                print "    <desc lang=\"en\">" . sanitize_string($summary) . "</desc>\n";
                print "    <category>" . $category . "</category>\n";
                if ($epispode_string ne '') { print "    <episode-num system=\"xmltv_ns\">" . $epispode_string . "</episode-num>\n"; }
                print "  </programme>\n";
                $tree = $tree->delete;
            }
        }
    }
}

# Grabbed this from the project, but haven't found anything in the source that's part x/y so removed that bit
sub make_ns_epnum {
		my ($s, $e, $e_of) = @_;
	        $s-- if (defined $s && $s > 0);
		$e-- if (defined $e && $e > 0);
		my $episode_ns = '';
		$episode_ns .= $s if defined $s;
		$episode_ns .= '.';
		$episode_ns .= $e if defined $e;
		$episode_ns .= '/'.$e_of if defined $e_of;
		$episode_ns .= '.';
		return $episode_ns;
}

# The programme url has a cleaned version of the title, all lower case, certain characters removed
sub sanitize_title_uri {
	my ($string) = @_;
    my $tmp = lc($string);
    $tmp =~ s/ /-/g;
    $tmp =~ s/\'//g;
    $tmp =~ s/\,//g;
    $tmp =~ s/\://g;
    $tmp =~ s/\///g;
    return $tmp;         
}

sub sanitize_string {
	my ($string) = @_;
    my %ESCAPES = (
        '&' => '&amp;',
        '<' => '&lt;',
        '>' => '&gt;',
        '"' => '&quot;',
    );
    $string =~ s/([&<>"])/$ESCAPES{$1}/ge;
    return $string;
}

# Queries the api interface for all platforms, returns the id where the string matches
sub get_platform_id {
	my ($platform_string) = @_;
    my $response = $browser->get($PLATFORM_URL);
    die "Can't get $PLATFORM_URL -- ", $response->status_line
        unless $response->is_success;
    my $json = decode_json($response->content);
    for my $item (@$json){
        if ($item->{title} eq $platform_string) {
            return $item->{id};
        }
    }
    return 0;
}

# Queries the api interface for all regions for said platform, returns the id where the string matches
sub get_region_id {
	my ($platform_id, $region_string) = @_;
    my $response = $browser->get($REGION_URL);
    die "Can't get $REGION_URL -- ", $response->status_line
        unless $response->is_success;
    my $json = decode_json($response->content);
    for my $item (@$json){
        if (($item->{title} eq $region_string) && ($item->{platform_id} eq $platform_id)) {
            return $item->{id};
        }
    }
    return 0;
}

sub print_header {
    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print "<!DOCTYPE tv SYSTEM \"xmltv.dtd\">\n";
    print "<tv source-info-url=\"https://www.tvguide.co.uk/\" source-info-name=\"TV Guide UK\" generator-info-name=\"tv_grab_uk_tvguide\" generator-info-url=\"http://wiki.xmltv.org/index.php/XMLTVProject\">\n";
}

sub print_footer {
    print "</tv>\n";
}

sub print_channels {
    my $channels = $config->{channels};
    for my $channel (@$channels) {
        print "  <channel id=\"" . $channel->{guide} . "\">\n";
        print "    <display-name lang=\"en\">" . $channel->{name} . "</display-name>\n";
        print "  </channel>\n";
    }
}
