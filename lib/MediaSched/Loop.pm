package Loop;

use strict;
use warnings;
use feature qw{switch};

use State;
use MediaConfig;
use Log;
use Lists;

use POE qw(Session);

my $ses = POE::Session->create(
  package_states => 
    [
      Loop => [ qw(_start playfile) ],
	],
	heap =>{});

sub _start
{
	my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
	
	my $player_name = get_config("player");
	eval "use Player::$player_name;";
	
	die $@ if $@;
	
	my $player = "Player::$player_name"->init_player('Player', $session);
	
	$heap->{player} = $player;
}

sub playfile
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	
	my $nexttime = $kernel->call(Player=>get_time=>);
	my ($file, $basename) = $kernel->call(Lists=>getepisode=>$nexttime);
	print "Posted a file! $file\n";
	
	$kernel->post(Player=> new_file => $file, $basename);
}