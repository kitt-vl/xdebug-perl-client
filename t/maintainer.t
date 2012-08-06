use strict;
use warnings;


use Test::More tests => 13;
use Mojo::UserAgent;
use Mojo::DOM;
use lib 'lib';
use feature qw/say/;

use_ok 'XDBGc';
use_ok 'XDBGc::Debugger';
use_ok 'XDBGc::Debugger::Server';
use_ok 'XDBGc::Debugger::Session';
use_ok 'XDBGc::Debugger::Breakpoint';
use_ok 'XDBGc::Debugger::UI';

my $test_host = 'http://localhost';
my $test_path = 'xdbgc_test';
my $test_file = 'index.php';
my $test_param = '?XDEBUG_SESSION_START=1';
my $test_uri = join '/', ($test_host, $test_path, $test_file);
my $debug_uri = join '/', ($test_host, $test_path, $test_file, $test_param);

my $ua = Mojo::UserAgent->new;
my $tx = $ua->get($test_uri);
like $tx->res->body, qr/This is xdebug-perl-client test script/, 'Has web server with php and xdebug';

##main test start here
my $db;
$db = XDBGc::Debugger->new;
$db->debug_mode(0);

isa_ok $db, 'XDBGc::Debugger', 'Right class';

##connect with ua

$db->server->start; 


#my $ext_t = threads->create( sub {
        
    #sleep 3;
    #my $ua = Mojo::UserAgent->new;
    #my $tx = $ua->get($debug_uri);
    ##is $tx->res->code, 200, 'Debug session successfully finish';
#});
#my $delay = Mojo::IOLoop->delay;
  
#$delay->begin;
#$ua->on(start => sub { sleep 1;});
my $res = $ua->get($debug_uri);




while($db->server->accept)
{
	while( my $xml = $db->server->listen)
	{
            
            my $dom = Mojo::DOM->new($xml);
            my $init = $dom->at('init');
            ok $init, 'Init node exists';
			is $init->{language}, 'PHP', 'Right program language';
            like $init->{fileuri}, qr/xdbgc\_test\/index\.php$/, 'Right debug URL';
            #11
            $db->on_data_recv($xml);
            
            like $db->session->initial_file, qr/xdbgc\_test\/index\.php$/,  'Right db->session initial file';
            like $db->session->current_file, qr/xdbgc\_test\/index\.php$/,  'Right db->session current file';
            #while(1)
            #{
                #my $cmd = $db->ui->term_read_command();  
                #$cmd = $db->parse_cmd($cmd);
                #redo if $cmd eq XDBGc::REDO_READ_COMMAND;
                          
                #my $res = $db->on_data_send($cmd);
                #last unless $res;
            #}
            
            $db->server->shutdown;
            last;
	}
    #$db->ui->log('Debug session ended, waiting for new connections');
}
 


