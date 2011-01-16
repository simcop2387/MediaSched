package Calendar;

use strict;
use warnings;

use MediaConfig;

use Data::Dumper;
use Data::ICal;
use LWP::UserAgent;
use DateTime;
use DateTime::Format::ISO8601;	

#no need to recreate this all the time
my $ua = LWP::UserAgent->new();

sub get_calendar {
	my $res = $ua->get(get_config("calendar"));
	
	if ($res->is_success()) {
		return $res->content();
	} else {
		die "Couldn't get calendar: ".$res->status_line."\n".$res->content();
	}
}

sub get_sched {
	my $time = shift; # get the time we're asked about
	my $ical = get_calendar();
	my $calendar = Data::ICal->parse(data => $ical);
	
}

1;