package MediaSched::Log;

# ABSTRACT: turns baubles into trinkets

use strict;
use warnings;

use Data::Dumper;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(debug);

our $debuglevel = 3;

sub debug
{
 my $level = shift;
 if ($debuglevel >= $level)
 {
   print @_, "\n";
 }
}