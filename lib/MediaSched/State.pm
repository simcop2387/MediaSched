package MediaSched::State;

# ABSTRACT: turns baubles into trinkets

use strict;
use warnings;

use MediaSched::MediaConfig;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(%state $_state savestate);

our %state;
#this is kept around for legacy reasons, there's still code that uses the old name
our $_state = \%state;

use Storable qw(lock_nstore retrieve);

END {savestate()}; # make sure to save the state whenever we close

sub savestate
{
	lock_nstore \%state, get_config("statefile");
}

sub loadstate
{
	%state = %{retrieve(get_config("statefile"))} if (-e get_config("statefile"));
}

loadstate();

1;