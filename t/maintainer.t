use strict;
use warnings;


use Test::More tests => 35;
use Mojo::UserAgent;
use Mojo::DOM;
use Mojo::IOLoop;
use lib 'lib';
use feature qw/say/;
use Data::Dumper;

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

$db->server->start; 

$ua->inactivity_timeout(1);
$tx = $ua->get($debug_uri);


if($db->server->accept)
{
    say 'BEFORE LISTEN';
	if( my $xml = $db->server->listen)
	{
            
            say 'IN LISTEN';
            my $dom = Mojo::DOM->new($xml);
            my $init = $dom->at('init');
            
            ok $init, 'Init node exists';
			is $init->{language}, 'PHP', 'Right program language';
            like $init->{fileuri}, qr/xdbgc\_test\/index\.php$/, 'Right debug URL';

            $db->on_data_recv($xml);
            
            like $db->session->initial_file, qr/xdbgc\_test\/index\.php$/,  'Right db->session initial file';
            like $db->session->current_file, qr/xdbgc\_test\/index\.php$/,  'Right db->session current file';
            
            is $db->session->status, 'break', 'Right status';
            
            #stack size test
            is $db->command_stack_get->size, 1, 'Rigth stack size';
            
            #step_over test
            is $db->session->lineno, 3, 'Right stop on first script line';
             
            $db->command_step_over;
            is $db->session->lineno, 4, 'Right step over function';
                        
            $db->command_step_over;
            is $db->session->lineno, 42, 'Right step over';
            
            $db->command_step_over;
            is $db->session->lineno, 44, 'Right step over';
            
            $db->command_step_over;
            is $db->session->lineno, 46, 'Right step over';
            $db->command_step_over;
            
            #step_into test
            $db->command_step_into;
            is $db->session->lineno, 6, 'Right step into function';
            
            #stack size test
            is $db->command_stack_get->size, 2, 'Rigth stack size';           
           
            #step_into test
            $db->command_continue(32);
            is $db->session->lineno, 32, 'Right continue till lineno'; 
            
            #step_over test
            $db->command_step_over;
            is $db->session->lineno, 34, 'Right step over function';
            
            $db->command_step_over;
            is $db->session->lineno, 40, 'Right step over function';
            is $db->session->status, 'break', 'Right status';
            
            $db->command_continue();
            is $db->session->status, 'stopping', 'Right status';
            
            $db->command_continue();


	}
    #$db->ui->log('Debug session ended, waiting for new connections');
}


$tx = $ua->get($debug_uri);
if($db->server->accept)
{
    say 'BEFORE LISTEN';
	if( my $xml = $db->server->listen)
	{
        $db->on_data_recv($xml);
        is $db->session->status, 'break', 'Right status';
        
        my $bp = $db->command_breakpoint_set('test1');
        is $bp->type, 'call', 'Rigth breakpoin type (on function call)';
        is $db->session->breakpoints->size, 1, 'Right breakpoint count';
        
        $db->command_continue();
        is $db->session->status, 'break', 'Right status';
        is $db->session->lineno, 6, 'Right step over function';
        
        
        $db->command_continue();
        
        is $db->session->status, 'break', 'Right status';
        is $db->session->lineno, 6, 'Right step over function';
        
        
        $db->command_continue();
        is $db->session->status, 'stopping', 'Right status';
        
    }
}        

$db->server->shutdown;
#say Dumper($tx);
 


