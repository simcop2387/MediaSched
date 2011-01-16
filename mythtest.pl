#!/usr/bin/perl

#package Television;

use strict;
use warnings;

use lib './lib';

use Mythtv;
use POE;
use Data::Dumper;

use State;
use Lists;
use Log;

my $ses = POE::Session->create(
  package_states => 
    [
      "main"=> [ qw(_start playfile) ],
	],
	heap => {} );

POE::Kernel->run();

sub _start
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];

	#my $file = Lists::getepisode();
	#my $file = $kernel->call("Mythtv", "matchshow", "Family Guy");
	#print Dumper $file;
	$kernel->yield("playfile");	
}

sub playfile
{
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	
	my $file = $kernel->call(Lists=>getepisode=>);
	
	debug 2, "Playing file :: $file";
	savestate(); #make sure we save it, that way we don't have issues
	die "wtf" unless (defined($file) && $file ne "");

	if (-e "$file.edl")
	{
		system("mplayer", $file, "-edl", "$file.edl");
	}
	else
	{
		system("mplayer", "$file");
	}

	$kernel->yield(playfile=>);
}
