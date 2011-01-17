#!/usr/bin/perl

# This is a simple script, just around for starting the kernel and setting up the environment, will eventually pull config stuff from @ARGV

use strict;
use warnings;

use lib './lib';

use POE;
use Loop; # this does the real work

POE::Kernel->run();