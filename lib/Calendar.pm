package Calendar;

use strict;
use warnings;
use feature qw(switch);

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
	
	die $calendar->error_message() unless $calendar;
	# FIX THIS TO ACCEPT $TIME!
	my $nowdt = DateTime->now();
	
	#collect all the events possible
	my @events;
	
	for my $event (@{$calendar->entries}) {
		next unless $event->ical_entry_type eq 'VEVENT';
    	my $dtstart = $iso8601->parse_datetime( _prop($event, 'DTSTART') );
    	my $dtend   = $iso8601->parse_datetime( _prop($event, 'DTEND') );
    	
    	if (my $rrule = _prop($event, "rrule")) {
    		print "REPEAT: $rrule :: "._prop($event, "description")."\n\n";
    		
    		my ($freq) = ($rrule =~ /FREQ=([^;]+)/g);
    		
    		if ($rrule =~ /UNTIL/) {
    			my ($_until) = ($rrule =~ /UNTIL=([^;]+)/g);
    			my $until = $iso8601->parse_datetime($_until);
    			
    			next if ($until < $nowdt); # we can throw this date out now if we're already past the date 
    		}
    		
    		given ($freq) {
    			when ("DAILY") {
    			}
    			when ("WEEKLY") {
    				my %dow = (SU => 7, MO => 1, TU => 2, WE => 3, TH => 4, FR => 5, SA => 6);
    				my @days = map {$dow{$_}} split(/,/, ($rrule =~ /BYDAY=([$;]+)/));
    				
    				for ($now
    			}
    		}
    	} else {
    		# range is [$dtstart, $dtend) that way a new event can start at $dtend without a conflict
    		if ($nowdt >= $dtstart && $nowdt < $dtend) {
    		  push @events, $event;
    		}
    	}
	}
}

# borrowed from Data::ICal example
sub _prop {
    my($event, $key) = @_;
    my $v = $event->property($key) or return;
    $v->[0]->value;
}

1;