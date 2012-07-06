package XDBGc::Debugger::Breakpoint;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;

has type => undef;
has filename => undef;
has lineno => undef;
