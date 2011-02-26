package MediaSched::Calendar;

# ABSTRACT: turns baubles into trinkets

use strict;
use warnings;
use feature qw(switch);

use MediaSched::MediaConfig;

use Data::Dumper;
use Data::ICal;
use LWP::UserAgent::POE; # for async http at least
use DateTime;
use DateTime::Format::ISO8601;	

use POE qw(Session);

use Carp qw(cluck);

my $ses = POE::Session->create(
  package_states => 
    [
      "MediaSched::Calendar" => [ qw(_start get_sched) ],
	],);

#no need to recreate this all the time
my $ua = LWP::UserAgent::POE->new();
my $iso8601 = DateTime::Format::ISO8601->new;

sub _start {
	my ($kernel, $heap) = @_[KERNEL, HEAP];

	$kernel->alias_set("Calendar");
}

sub get_calendar {
	my $res = $ua->get(get_config("calendar"));
	
	if ($res->is_success()) {
		return $res->content();
	} else {
		die "Couldn't get calendar: ".$res->status_line."\n".$res->content();
	}
}

sub get_sched {
	my $time = $_[ARG0]; # get the time we're asked about
	my $ical = get_calendar();
	my $calendar = Data::ICal->new(data => $ical);
	
	die $calendar->error_message() unless $calendar;
	# FIX THIS TO ACCEPT $TIME!
	my $nowdt = DateTime->now();
	$nowdt->set_time_zone(get_config("timezone"));
	
	#collect all the events possible
	my @events;
	
	for my $event (@{$calendar->entries}) {
		next unless $event->ical_entry_type eq 'VEVENT';
    	my $dtstart = $iso8601->parse_datetime( _prop($event, 'DTSTART') );
    	my $dtend   = $iso8601->parse_datetime( _prop($event, 'DTEND') );
    	
    	#set the time zone
    	$_->set_time_zone(get_config("timezone")) for ($dtstart, $dtend);
    	
    	# create a subref for this, makes code cleaner below
    	my $checkandadd = sub {
    		if (_checktimeonly($nowdt, $dtstart, $dtend, $event)) {
    			push @events, $event;
    		}
    	};
    	
    	#check if we've even come up to the start time, otherwise just throw it out
    	next if ($nowdt < $dtstart); # commented out to make it process them all for testing
    	
    	#are we a repeating entry?
    	if (my $rrule = _prop($event, "rrule")) {
    		print "REPEAT: $rrule :: "._prop($event, "description")."\n\n";
    		
    		my ($freq) = ($rrule =~ /FREQ=([^;]+)/g);
    		
    		# does the repeat end at some point?
    		if ($rrule =~ /UNTIL/) {
    			my ($_until) = ($rrule =~ /UNTIL=([^;]+)/g);
    			my $until = $iso8601->parse_datetime($_until);
    			
    			next if ($until < $nowdt); # we can throw this date out now if we're already past the date 
    		}
    		
    		given ($freq) {
    			when ("DAILY") {
    				if ($rrule =~ /INTERVAL=(\d+)/) {
    					my $inter = $1;
    					my ($now, $start) = ($nowdt->clone(), $dtstart->clone());
    				
    					# truncate the times off, this way we can count the days correctly and not have horrible fractional parts to deal with
    					$_->truncate(to => "day") for ($now, $start);
    				
    					my $dur = $now - $start;
    					
    					if ($dur->days() % $inter == 0) { # we're on the interval now
    						$checkandadd->();
    					} 
    				} else {
    					$checkandadd->();
    				}
    			}
    			when ("WEEKLY") {
    				my %dow = (SU => 7, MO => 1, TU => 2, WE => 3, TH => 4, FR => 5, SA => 6);
    				my @days = map {$dow{$_}} split(/,/, ($rrule =~ /BYDAY=([$;]+)/));
    				
    				my $dow = $nowdt->dow();
    				
    				if (grep {$_ == $dow} @days) { # are we the right day of week?
    				   $checkandadd->();
    				}
    			}
    			when ("MONTHLY") {
    				
    				if ($rrule =~ /BYDAY=(\d)(\w\w)/) {
    					my %dow = (SU => 7, MO => 1, TU => 2, WE => 3, TH => 4, FR => 5, SA => 6);
    					my ($num, $day) = ($1, $dow{$2});
    					
    					my $month = $nowdt->clone()->truncate(to => "month");
    					
    					#this bit is borrowed from the DateTime wiki, to calculate the "$num{st,nd,rd,th} $day" of the month
						my $dow = $month->day_of_week();
						$month->add(
    						days  => ( $day - $dow + 7 ) % 7,
    						weeks => $num - 1
						);
						
						# did we get today? if we did then we're on the right one
						if ($nowdt->clone()->truncate(to=>"day") == $month) {
							$checkandadd->();
						}
    				} elsif ($rrule =~ /BYMONTHDAY=(\d+)/) {
    					my $day = $1;

    					# this check is very simple, check if we're the same day of the month as above
    					if ($nowdt->day() == $day) {
    						$checkandadd->();
    					}
    				} else { die "Unhandled repeat type: $rrule"; }
       			}
    			when ("YEARLY") {
    				if ($rrule =~ /INTERVAL=(\d+)/) {
    					my $inter = $1;
    					my ($now, $start) = ($nowdt->clone(), $dtstart->clone());
    				
    					# truncate the times off, this way we can count the days correctly and not have horrible fractional parts to deal with
    					$_->truncate(to => "year") for ($now, $start);
    				
    					my $dur = $now - $start;
    					
    					if ($dur->years() % $inter == 0) { # we're on the interval now
    						$checkandadd->();
    					} 
    				} else {
    					$checkandadd->();
    				}
    			}
    		}
    	} else {
    		# range is [$dtstart, $dtend) that way a new event can start at $dtend without a conflict
    		if ($nowdt >= $dtstart && $nowdt < $dtend) {
    		  print "Got non repeating event!\n";
    		  _printentry($event);
    		  push @events, $event;
    		}
    	}
	}
	
	print Dumper(\@events);
	# in case we've got more than one event, we're going to sort them by creation time
	my @sevents = map {$_->[1]} sort {$a->[0] cmp $b->[0]} map {[_prop($_, "dtstart"), $_]} @events;
	_printentry($_) for (@sevents);
#	sleep(30);

    sleep(10);
    
    if (@sevents) {
    	return (_prop($sevents[0], "description"), _prop($sevents[0], "uid"))
    }
}

# borrowed from Data::ICal example
sub _prop {
    my($event, $key) = @_;
    print Dumper(\@_);
    my $v = $event->property($key) or return;
    $v->[0]->value;
}

sub _checktimeonly {
	my ($now, $_start, $_end, $entry) = @_;
	my ($start, $end) = ($_start->clone(), $_end->clone()); # clone them since we need to alter them
	
	for ($start, $end) {
		$_->set_year($now->year());
		$_->set_month($now->month());
		$_->set_day($now->day());
	}
	
	_printentry($entry);
	print "CHECKTIME: ", $now->hms(), " ", $start->hms(), "-", $end->hms(), "\n";
	
	if ($now >= $start && $now < $end) {
		return 1;
	} else {
		return 0;
	}
}

sub _printentry {
	my $entry = shift;
	
	return unless defined $entry;
	
	print "---\n",
	      _prop($entry, "summary"), "\n",
	      _prop($entry, "uid"), "\n",
	      _prop($entry, "created"), " ", _prop($entry, "dtstart"), "-", _prop($entry, "dtend"), "\n",
	      _prop($entry, "rrule"), "\n",
	      _prop($entry, "description"), "\n\n";
}

1;