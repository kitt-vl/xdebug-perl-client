package XDBGc::Debugger;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;
use Mojo::DOM;
use Mojo::Util qw/b64_decode b64_encode/;

use XDBGc; #log, constants
use XDBGc::Debugger::Server;
use XDBGc::Debugger::UI;
use XDBGc::Debugger::Session;
use XDBGc::Debugger::Breakpoint;

has server => sub { my $self = shift; return XDBGc::Debugger::Server->new(debugger => $self ); };    
has session => sub { my $self = shift; return XDBGc::Debugger::Session->new(debugger => $self); };
has ui => sub { my $self = shift;  XDBGc::Debugger::UI->new(debugger => $self); };
has debug_mode => 1;

sub on_data_send{
    my ($self, $cmd, $data) = (shift, shift, shift);
	
    $cmd = $self->process_request($cmd);
    return XDBGc::REDO_READ_COMMAND if $cmd eq XDBGc::REDO_READ_COMMAND;
    
    $self->session->_tid( $self->session->_tid()+1 );
    
    $cmd .= ' -i ' . $self->session->_tid  . ' -- ' ;
    $cmd .= b64_encode($data) if defined $data;
    $cmd .= chr(0);
        
    $self->send_data_raw($cmd);
    return 0;
}

sub send_data_raw{
        my ($self,$cmd) = (shift, shift);
        
        $self->ui->debug("send_data_raw: EMPTY COMMAND") unless $cmd;        
        return unless $cmd;
        
        my $res = $self->server->client->send($cmd);		
        $self->ui->debug("send_data_raw: cmd '$cmd' sended " , $res, ', len ' . length($cmd));
}
    
sub on_data_recv{
    my ($self,$xml) = (shift, shift);
    
    $self->process_response($xml);
}

# outgoing command from IDE to server
sub process_request{
    my ($self,$cmd) = (shift, shift);
	
    return XDBGc::REDO_READ_COMMAND unless $cmd;
    
	$self->server->shutdown if $cmd =~ /^quit/;	
    $self->server->shutdown if $cmd =~ /^q$/;	
    
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
    
    if($cmd =~ /^L$/)
    {
        $self->ui->print_breakpoints_list;
        return XDBGc::REDO_READ_COMMAND;
    }
    
    $cmd = 'step_into'  if ($cmd =~ /^s$/);   
    $cmd = 'step_over'  if ($cmd =~ /^n$/);    
    $cmd = 'step_out'   if ($cmd =~ /^r$/);    
    $cmd = 'run'    if ($cmd =~ /^c$/);  
    
    if($cmd =~ /^b\s/)
    {
        my $bp = $self->command_breakpoint_set($cmd);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if($cmd =~ /^B\s+(\d+)/)
    {
        my $bp = $self->command_breakpoint_remove($1);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if($cmd =~ /^T\s+(\d+)/ || $cmd =~ /^T$/)
    {
		
        my $bp = $self->command_stack_get($1);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if($cmd =~ /^x\s+(.+)/)
    {
        my $bp = $self->command_eval($1);
        return XDBGc::REDO_READ_COMMAND;
    }
       
    if($cmd =~ /^o\s+(.+)/)
    {
        my $bp = $self->command_option($1);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if($cmd =~ /^V\s+(\d+)/ || $cmd =~ /^V$/)
    {
        my $bp = $self->command_context_get($1);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    return $cmd; 
}
sub process_response{
    my ($self,$xml) = (shift, shift);
    $self->session->update($xml);
    
    my $dom = Mojo::DOM->new($xml);
    
    if (defined $dom->at('init'))
    {
        my @lines = $self->command_get_source();
        $self->on_data_send('step_into');
        $xml = $self->server->listen;
        $self->session->update($xml);
        $self->ui->print_window;
        return;
    }
    
    if(defined(my $response = $dom->at('response')) && defined $dom->response->{command})
    {
        my $cmd = $response->{command};
        
        $self->ui->print_window if ($cmd =~ /(step_into|step_over|step_out|return)/);
        
        return;
    }

    $self->ui->debug("UNEMPLIMENTED XDEBUG engine answer:\n$xml");

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

        #TODO How to effective determine sources line separator WIN\UNIX\MAC?
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

sub command_breakpoint_set{
	my ($self, $cmd) = (shift, shift);
	my $bp = XDBGc::Debugger::Breakpoint->new(session => $self->session);
	$bp->parse_cmd( $cmd );
	$bp->set;
        
	return $bp;
}

sub command_breakpoint_remove{
    my ($self, $id) = (shift, shift);
    my $bp = XDBGc::Debugger::Breakpoint->new( id => $id , session => $self->session);
    $bp->remove if (defined $bp);
    
    return $bp;
}

sub command_stack_get{
	my ($self, $depth) = (shift, shift);
	my $cmd = 'stack_get';
	$cmd .= ' -d ' . $depth if defined $depth;
	
	$self->on_data_send($cmd);
	my $xml = $self->server->listen;
	
	$self->ui->print_stack_list($xml);
	
	return 1;
}

sub command_eval{
    my ($self, $data) = (shift, shift);
    my $cmd = 'eval';

    $self->on_data_send($cmd, $data);
    
    my $xml = $self->server->listen;
	
	$self->ui->print_eval($xml, $data);
    
    return 1;
}

sub command_option{
    my ($self, $data) = (shift, shift);
     
    my @opt = split /\s/, $data;

    my $option = shift @opt;
    my $value = join ' ', @opt;
    my ($cmd, $xml);
    
    $self->command_option_set($option, $value) if $value;
    
    #$self->ui->debug('command_option: option = ', $option, ' value = ', $value);
    $self->command_option_get($option);
    
    return 1;
    
}

sub command_option_set{
    my ($self, $option, $value) = (shift, shift, shift);
    my $cmd = 'feature_set -n ' . $option . ' -v ' . $value;
    
    $self->on_data_send($cmd);
    my $xml = $self->server->listen;
    return 1;
}

sub command_option_get{
    my ($self, $option) = (shift, shift);
    my $cmd = 'feature_get';
    
    $cmd .= ' -n ' . $option;
    
    $self->on_data_send($cmd);
	my $xml = $self->server->listen;
    
    $self->ui->print_option($xml);
    return 1;
}
    
    
sub command_context_get{
    my ($self, $num) = (shift, shift);
    my $cmd = 'context_get';
    
    $cmd .= ' -d ' . $num if defined $num;
    
    $self->on_data_send($cmd);
	my $xml = $self->server->listen;
    
    $self->ui->print_context($xml);
    
    return 1;
}
1;
