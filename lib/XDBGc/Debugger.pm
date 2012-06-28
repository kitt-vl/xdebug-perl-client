package XDBGc::Debugger;
use strict;
use warnings;
use utf8;
use Mojo::Base -base;
use Mojo::DOM;
use Term::ReadLine;
use XDBGc::Server;

has _term => sub { Term::ReadLine->new('', \*STDIN, \*STDOUT); };
has server => sub { XDBGc::Server->new; };
has _tid => 0;

sub term_read_command{
	my $self = shift;
	my $prompt = "XDBGc: ";
	my $cmd = $self->_term->readline($prompt);
	
	XDBGc::log("term_read_command: $cmd");
	
	$self->on_command($cmd);	
}

sub on_command{
	my ($self,$cmd) = (shift, shift);
	
	$self->server->shutdown if $cmd =~ /^quit/;	
    
    $self->_tid( $self->_tid()+1 );
    
    $cmd .= ' -i ' . $self->_tid .' -- '.chr(0);
        
    my $res = $self->server->client->send($cmd);		
    XDBGc::log("on_command: cmd '$cmd' sended $res, len " . length($cmd));
}
	
1;
