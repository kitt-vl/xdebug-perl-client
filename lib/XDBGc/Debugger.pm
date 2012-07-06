package XDBGc::Debugger;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;
use Mojo::DOM;
use Mojo::Util qw/b64_decode/;

use XDBGc; #log, constants
use XDBGc::Debugger::Server;
use XDBGc::Debugger::UI;
use XDBGc::Debugger::Session;

has server => sub { my $self = shift; return XDBGc::Debugger::Server->new(debugger => $self ); };    
has session => sub { my $self = shift; return XDBGc::Debugger::Session->new(debugger => $self); };
has ui => sub { my $self = shift;  XDBGc::Debugger::UI->new(debugger => $self); };
has debug_mode => 1;

sub on_data_send{
    my ($self,$cmd) = (shift, shift);
	
    $cmd = $self->process_request($cmd);
    return XDBGc::REDO_READ_COMMAND if $cmd eq XDBGc::REDO_READ_COMMAND;
    
    $self->session->_tid( $self->session->_tid()+1 );
    
    $cmd .= ' -i ' . $self->session->_tid  . ' -- ' . chr(0);
        
    $self->send_data_raw($cmd);
    return 0;
}

sub send_data_raw{
        my ($self,$cmd) = (shift, shift);
        
        $self->ui->debug("send_data_raw: EMPTY COMMAND") unless $cmd;        
        return unless $cmd;
        
        my $res = $self->server->client->send($cmd);		
        $self->ui->debug("send_data_raw: cmd '$cmd' sended $res, len " . length($cmd));
}
    
sub on_data_recv{
    my ($self,$xml) = (shift, shift);
    
    $self->process_response($xml);
}

sub process_request{
    my ($self,$cmd) = (shift, shift);
	
    return XDBGc::REDO_READ_COMMAND unless $cmd;
    
	$self->server->shutdown if $cmd =~ /^quit/;	
    if ($cmd =~ /^list/)
    {
        $self->command_get_source;
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if ($cmd =~ /^debug 1/)
    {
        $self->debug_mode(1);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if ($cmd =~ /^debug 0/)
    {
        $self->debug_mode(0);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    $cmd = 'step_into'    if ($cmd =~ /^s$/);   
    $cmd = 'step_over'  if ($cmd =~ /^n$/);    
    $cmd = 'step_out'  if ($cmd =~ /^r$/);    
    $cmd = 'run'  if ($cmd =~ /^c$/);  
    $cmd = 'breakpoint_set'  if ($cmd =~ /^b\s/);
    
    return $cmd; 
}
sub process_response{
    my ($self,$xml) = (shift, shift);
    my $dom = Mojo::DOM->new($xml);
    

    $self->session->update($dom);
    
    $self->ui->debug("process_response:\n$xml");
    
    if (defined $dom->at('init'))
    {
        my @lines = $self->command_get_source();
        $self->on_data_send('step_into');
        $self->server->listen;
        return;
    }
    
    if(defined $dom->at('response') && defined $dom->response->{command})
    {
        my $cmd = $dom->response->{command};
        
        return;
    }

    $self->ui->debug("Unimplemented XDEBUG engine answer:\n$xml");

}

sub command_get_source{
    my ($self, $file, $line_start, $line_end) = @_;
    $file = $self->session->current_file unless $file;
    $line_start = 0 unless defined $line_start;
    
    unless (defined  $self->session->source_cache->{$file})
    {        
        my $cmd = 'source';

        $cmd .= ' -f ' . $file if $file;
        $cmd .= ' -b ' . $line_start if $line_start;
        $cmd .= ' -e ' . $line_end if $line_end;
        
        $self->on_data_send($cmd);
        
        my $xml = $self->server->listen;
        
        my $dom = Mojo::DOM->new($xml);
        my $list = '';
        if(defined (my $node = $dom->at('response')))
        {
            $list = b64_decode $node->text;
        }
        else
        {
            $self->ui->debug('command_get_source: NO ANY SOURCE RETURNED');
        }
        
        #$self->ui->log('command_get_source: \n' . $list);
        #TODO How to really determine sources line separator?
        my @lines = split /\r?\n/, $list;
        $self->session->source_cache->{$file} = \@lines;
    }
    
    $line_end = scalar @{$self->session->source_cache->{$file}} unless defined $line_end;
    my @part_list;
    my $cnt = 0;
    
    for my $line (@{$self->session->source_cache->{$file}})
    {
        $cnt++;
        next if $cnt < $line_start;
        last if $cnt > $line_end;
        push @part_list, $line;
    } 
    return  \@part_list;
    
}
1;
