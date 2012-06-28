#!perl
package main;
use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/lib";

use XDBGc;
use XDBGc::Debugger;

my $db = XDBGc::Debugger->new;
$db->server->start;

while($db->server->accept)
{
	while( my $xml = $db->server->listen)
	{
			$db->term_read_command();
	}
    XDBGc::log('Debug session ended, waiting for new connections');
}
 
XDBGc::log( "Program teminated(0)" );

