package Config;

use strict;
use warnings;

use YAML;

our %options;

# hardcoded location in current directory, might change this to something a little more flexible, or at least parse @ARGV for an alternate, not important right now
my $cf = LoadFile("config.yml");

#check some things we need
if (ref($cf) ne "HASH" && !$cf->{defaultlist} && !$cf->{statefile} && !$cf->{storage}) {
	die "Invalid Configuration: see README for an example";
}

%options = $cf; # put it in the hash, looks nicer later

1;