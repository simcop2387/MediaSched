package MediaSched::Loop;

use strict;
use warnings;
use feature qw{switch};

use MediaSched::State;
use MediaSched::MediaConfig;
use MediaSched::Log;
use MediaSched::Lists;

use POE qw(Session);

my $ses = POE::Session->create(
  package_states => 
    [
      "MediaSched::Loop" => [ qw(_start playfile) ],
	],
	heap =>{});

#is there a cleaner way to do the loading? maybe
sub _start
{
	my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
	
	my $player_name = get_config("player");
    eval "use MediaSched::Player::$player_name;";
	
	die $@ if $@;
	
    my $player = "MediaSched::Player::$player_name"->init_player('Player', $session);
	
	$heap->{player} = $player;
}

sub playfile
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	
	my $nexttime = $kernel->call(Player=>get_time=>);
	my ($file, $basename) = $kernel->call(Lists=>getepisode=>$nexttime);
	print "Posted a file! $file\n";
	
	$kernel->post(Player=> new_file => $file, $basename);
        MediaSched::State::savestate();
}
