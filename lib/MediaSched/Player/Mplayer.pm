package MediaSched::Player::Mplayer;

use strict;
use warnings;

use Data::Dumper;
use POE qw(Session);
use MediaSched::MediaConfig;

# at the moment the mplayer plugin does it blockingly, i'm not controlling it async at all, which isn't a great idea

sub init_player {
  my ($self, $alias, $loop) = @_; 
  
  my $player_conf = get_config("player_conf");
  $player_conf //= {useedl=>1};
  my $ses = POE::Session->create(
  package_states => 
    [
      "Player::Mplayer" => [ qw(_start get_time new_file) ],
	],
	heap =>{alias => $alias, useedl=>$player_conf->{useedl},
		    loop => $loop,
	});
	
	POE::Kernel->post($loop, "playfile"); # start us up!
	return $ses;
}

sub _start {
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	
	$kernel->alias_set($heap->{alias});
}

sub get_time {
	# even though we are a POE event, we don't care at all about what they send us
	return time(); # we don't queue anything up so this always NOW
}

# new_file tells us that there's a new file to play
sub new_file {
	my ($kernel, $heap, $file) = @_[KERNEL, HEAP, ARG0];
	
	die "wtf" unless (defined($file) && $file ne "");

	if ($heap->{useedl} && -e "$file.edl")
	{
		system("mplayer", $file, "-edl", "$file.edl");
	}
	else
	{
		system("mplayer", "$file");
	}
	
	$kernel->post($heap->{loop}, "playfile");
}

1;