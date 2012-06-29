package XDBGc::Debugger;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;
use Mojo::DOM;

use XDBGc; #log
use XDBGc::Debugger::Server;
use XDBGc::Debugger::UI;
use XDBGc::Debugger::Session;

has server => sub { my $self = shift; return XDBGc::Debugger::Server->new(debugger => $self ); };    
has session => sub { my $self = shift; return XDBGc::Debugger::Session->new(debugger => $self); };
has ui => sub { my $self = shift;  XDBGc::Debugger::UI->new(debugger => $self); };

sub on_data_send{
    my ($self,$cmd) = (shift, shift);
	
	$self->server->shutdown if $cmd =~ /^quit/;	
    
    $self->session->_tid( $self->session->_tid()+1 );
    
    $cmd .= ' -i ' . $self->session->_tid .' -- '.chr(0);
        
    $self->send_data_raw($cmd);
}

sub send_data_raw{
        my ($self,$cmd) = (shift, shift);
        my $res = $self->server->client->send($cmd);		
        $self->ui->log("send_data_raw: cmd '$cmd' sended $res, len " . length($cmd));
}
    
sub on_data_recv{
    my ($self,$xml) = (shift, shift);
    
    $self->process_response($xml);
}

sub process_response{
    my ($self,$xml) = (shift, shift);
    my $dom = Mojo::DOM->new($xml);
    

    $self->session->update($dom);
    
    $self->ui->log("process_response:\n$xml");
    
    return if defined $dom->at('init');
    
    if(defined $dom->at('response') && defined $dom->response->{command})
    {
        my $cmd = $dom->response->{command};
        
        
        return;
    }

    $self->ui->log("Unimplemented XDEBUG engine answer:\n$xml");

}

1;
