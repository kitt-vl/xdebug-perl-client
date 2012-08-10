#!perl

use strict;
use warnings;
use feature 'say';
use Data::Dumper;
use EV;
 
# TIMERS
 
my $w = EV::timer 3, 0, sub {
   say "is called after 3";
};
EV::run EV::RUN_NOWAIT;

say 'MAIN CODE';
