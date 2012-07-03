#!perl
package main;
use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/lib";

use XDBGc::Debugger;

my $db = XDBGc::Debugger->new;
$db->server->start;

while($db->server->accept)
{
	while( my $xml = $db->server->listen)
	{
            $db->on_data_recv($xml);
			my $cmd = $db->ui->term_read_command();
            $db->on_data_send($cmd) if $cmd;
	}
    $db->ui->log('Debug session ended, waiting for new connections');
}
 
$db->ui->log( "Program teminated(0)" );

