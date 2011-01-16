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
my $iso8601 = DateTime::Format::ISO8601->new;

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
	my $calendar = Data::ICal->new(data => $ical);
	
	for my $event ($calendar->entries) {
		next unless $event->ical_entry_type eq 'VEVENT';
    	$event->{__dtstart} = $iso8601->parse_datetime( _prop($event, 'DTSTART') );
    	$event->{__dtend}   = $iso8601->parse_datetime( _prop($event, 'DTEND') );
    
		print Dumper($event);
	}
}

# borrowed from Data::ICal example
sub _prop {
    my($event, $key) = @_;
    my $v = $event->property($key) or return;
    $v->[0]->value;
}

1;