use strict;
use warnings;

use Test::More tests => 6;
use lib 'lib';

use_ok 'XDBGc';
use_ok 'XDBGc::Debugger';
use_ok 'XDBGc::Debugger::Server';
use_ok 'XDBGc::Debugger::Session';
use_ok 'XDBGc::Debugger::Breakpoint';
use_ok 'XDBGc::Debugger::UI';

