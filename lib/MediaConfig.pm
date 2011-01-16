package MediaConfig;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(get_config);

use Data::Dumper;
use YAML qw(LoadFile);

my %options;

sub init_config {
	#hardcoded location in current directory, might change this to something a little more flexible, or at least parse @ARGV for an alternate, not important right now
	my $cf = LoadFile("config.yml");
	print Dumper($cf);

	#check some things we need
	if (ref($cf) ne "HASH" || !$cf->{defaultlist} || !$cf->{statefile} || !$cf->{storage}) {
		die "Invalid Configuration: see README for an example";
	}

	%options = %$cf; # put it in the hash, looks nicer later

	print Dumper(\%options);
}

sub get_config {
	init_config() unless (%options);
	
	return $options{shift()}; # return what they wanted
}

1;