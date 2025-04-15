package MediaSched::State;

# ABSTRACT: turns baubles into trinkets

use strict;
use warnings;

use MediaSched::MediaConfig;
use Sereal qw/write_sereal_file read_sereal_file/;
use Feature::Compat::Try;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(%state $_state savestate);

our %state;
my $state_file = get_config('statefile');

END {savestate()}; # make sure to save the state whenever we close

sub savestate
{
  write_sereal_file($state_file, \%state);
}

sub loadstate
{
  if (-e get_config('statefile')) {
    try {
      %state = read_sereal_file($state_file)->%*;
    } catch($e) {
      warn "Failed to read state file, keeping blank state, will overwrite: $e";
    }
  }
}

loadstate();

1;
