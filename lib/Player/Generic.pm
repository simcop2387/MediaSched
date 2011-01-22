package Player::Generic;

package Player::Mplayer;

use strict;
use warnings;

use Data::Dumper;
use POE qw(Session);
use MediaConfig;

# at the moment the mplayer plugin does it blockingly, i'm not controlling it async at all, which isn't a great idea

sub init_player {
  my ($self, $alias, $loop) = @_; 

  my %player_conf = %{get_config("player_config")};
  
  die "You need to tell us which command you want to run for the Generic player plugin" if (!$player_conf{binary});
  
  my $ses = POE::Session->create(
  package_states => 
    [
      "Player::Generic" => [ qw(_start get_time new_file) ],
	],
	heap =>{alias => $alias,
		    loop => $loop, player_conf => \%player_conf
	});
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
	
	# this isn't something required, just me debugging
	die "wtf" unless (defined($file) && $file ne "");
	
    my @args = map {s/%f/$file/g} split(" ",$heap->{player_conf}{args}); 	
	
	# if we didn't have a %f then we need to add it to the end
	push @args, $file if ($heap->{player_conf}{args} !~ /%f/);
	
	system($heap->{player_conf}{binary}, @args);
	
	$kernel->post($heap->{loop}, "playfile");
}

1;