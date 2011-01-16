package State;

use strict;
use warnings;

use Config;

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
	lock_nstore \%state, $Config::options{statefile};
}

sub loadstate
{
	%state = %{retrieve($Config::options{statefile})} if (-e $Config::options{statefile});
}

loadstate();

1;