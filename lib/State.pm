package State;

use strict;
use warnings;

use Data::Dumper;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(%state $_state savestate);

our %state;
our $_state = \%state;

use Storable qw(lock_nstore retrieve);

END {savestate()};

sub savestate
{
	lock_nstore \%state, 'tv.state';
}

sub loadstate
{
	%state = %{retrieve('tv.state')} if (-e 'tv.state');
}

loadstate();

1;