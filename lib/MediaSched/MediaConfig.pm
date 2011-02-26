package MediaSched::MediaConfig;

# ABSTRACT: turns baubles into trinkets

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(get_config);

use Data::Dumper;
use YAML qw(LoadFile);

my %options = (
	defaultlist => ".", # play first storage directory
	storage => $ENV{HOME}."/media/",
	statefile => $ENV{HOME}."/.mediasched.state",
);
my $initconf;

sub init_config {
	#hardcoded location in current directory, might change this to something a little more flexible, or at least parse @ARGV for an alternate, not important right now
	my $cf= eval qw{LoadFile("config.yml");};
	$cf //= {}; # make a blank default

	#check some things we need
	if (ref($cf) ne "HASH") {
		die "Invalid Configuration: see README for an example";
	}

	%options = (%options, %$cf); # put it in the hash, looks nicer later
	print Dumper(\%options);
	$initconf=1;
}

sub get_config {
	init_config() unless ($initconf);
	
	return $options{shift()}; # return what they wanted
}

1;