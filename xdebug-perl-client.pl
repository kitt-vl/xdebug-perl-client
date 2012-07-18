#!perl
package main;
use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/lib";

use XDBGc::Debugger;
#русский текст
my $db = XDBGc::Debugger->new;
$db->server->start;

while($db->server->accept)
{
	while( my $xml = $db->server->listen)
	{
            $db->on_data_recv($xml);
			
            while(1)
            {
                my $cmd = $db->ui->term_read_command();  
                $cmd = $db->parse_cmd($cmd);
                redo if $cmd eq XDBGc::REDO_READ_COMMAND;
                          
                my $res = $db->on_data_send($cmd);
                last unless $res;
            }
	}
    $db->ui->log('Debug session ended, waiting for new connections');
}
 
$db->ui->log( "Program teminated(0)" );

