package MediaSched::Player::MPD;

use strict;
use warnings;

use Data::Dumper;
use POE qw(Session);
use MediaSched::MediaConfig;

use Audio::MPD;

sub init_player {
  my ($self, $alias, $loop) = @_; 
  
  my %player_conf = (host => "localhost", port => 6600, queuelength=>1800, queuesongs=>3);
  %player_conf =(%player_conf, %{get_config("player_conf")});
  
  my $mpd = Audio::MPD->new(\%player_conf); # use the same hash from the yaml, this will let you pass additional options if they ever exist
  
  my $ses = POE::Session->create(
  package_states => 
    [
      "MediaSched::Player::MPD" => [ qw(_start get_time new_file tick checkplay removeold get_queue get_songs) ],
	],
	heap =>{alias => $alias, player_conf=>\%player_conf,
		    loop => $loop, mpd => $mpd,
	});
}

sub _start {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	
	$kernel->alias_set($heap->{alias});
	$kernel->yield("tick"); # start picking a song
	$kernel->delay_add(checkplay => 15); # wait 15 seconds, then try to force playing, might make this optional
}

sub checkplay {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	my $mpd = $heap->{mpd};
	
	$mpd->play(); # tell it to play right away, just in case
}

sub tick {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	my $queuelength = $kernel->call($heap->{alias}, "get_queue");
	my $queuesongs = $kernel->call($heap->{alias}, "get_songs");
	
	if ($queuelength < $heap->{player_conf}{queuelength} || $queuesongs < $heap->{player_conf}{queuesongs}) {
		$kernel->post($heap->{loop}, "playfile");
	}
	
	$kernel->yield("removeold");
	
	$kernel->delay_add(tick => 60); # setup the next check
}

sub removeold { # get rid of stuff already played
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	my $mpd = $heap->{mpd};

    my $song = $mpd->current();

    if ($song->pos >=1) { # we're not on the first song anymore, it is numbered 0
       $mpd->playlist->delete($song->pos - 1);  # remove the previous song, even if there is multiple we'll catch them fast enough (assuming that the average clip length is > 60 seconds) # NTS: fix this assumption at some point
    }
}

sub get_queue {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	my $mpd = $heap->{mpd};
	
	print "Get_queue\n";

    my $total = 0;

    for ($mpd->playlist->as_items())
    {
      print "T: $total\n";
      $total+=$_->time();
    }
   
    return $total;
}

sub get_songs {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	my $mpd = $heap->{mpd};

    my $items = $mpd->playlist->as_items();
   
    return $items;
}

sub get_time {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	my $mpd = $heap->{mpd};
	
	my $time = time();
	$time += $kernel->call($_[SESSION], "get_queue");
	
	return $time; # we don't queue anything up so this always NOW
}

# new_file tells us that there's a new file to play
sub new_file {
	my ($kernel, $heap, $file) = @_[KERNEL, HEAP, ARG0, ARG1];
	my $mpd = $heap->{mpd};
	
	my $basename;
	my @storage = @{get_config("storage")};
	
	#we have to strip the storage directory off, or mpd won't find the files! yuck
	for my $dir (@storage) {
		if ($file =~ /^$dir/) {
			$basename = $file;
			$basename =~ s|^$dir||;
			$basename =~ s|^/+||; # remove any extra / that got added, NORMAL programs don't care about extra /, but MPD is "SPECIAL"
			last;
		}
	}
	
	#die "wtf" unless (defined($file) && $file ne "");
	
	eval {$mpd->playlist->add($basename);}; # eval to ignore missing files, no need to make my life miserable because of a bad playlist
	warn "on file $basename: $@" if $@; # display the error if it had one
}

1;