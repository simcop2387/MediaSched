#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Storable qw(retrieve);

print Dumper(retrieve(@ARGV));

