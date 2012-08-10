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

has server => sub { XDBGc::Debugger::Server->new(debugger => shift ); };    
has session => sub { XDBGc::Debugger::Session->new(debugger => shift); };
has ui => sub { XDBGc::Debugger::UI->new(debugger => shift); };
has debug_mode => 1;

sub on_data_send{
    my ($self, $cmd, $data) = (shift, shift, shift);
    
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
sub parse_cmd{
    my ($self,$cmd) = (shift, shift);
	
    return XDBGc::REDO_READ_COMMAND unless $cmd;
    
    $self->server->shutdown and exit 0 if $cmd =~ /^q$/;	
    
    if ($cmd =~ /^debug 1$/)
    {
        $self->debug_mode(1);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if ($cmd =~ /^debug 0$/)
    {
        $self->debug_mode(0);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if ($cmd =~ /^o\s+win\s+(\d+)$/)
    {
        $self->ui->window_size($1);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if($cmd =~ /^L$/)
    {
        $self->ui->print_breakpoints_list;
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if($cmd =~ /^b/)
    {
        $cmd =~ /^b\s+/;
        my $bp = $self->command_breakpoint_set($cmd);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if($cmd =~ /^B\s+(\d+|\*)/)
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
    
    if($cmd =~ /^v$/)
    {
        my $bp = $self->ui->print_window;
        return XDBGc::REDO_READ_COMMAND;
    }
    
    if ($cmd =~ /^s$/)
     {
        $self->command_step_into;
        return XDBGc::REDO_READ_COMMAND;
     }
     
     if($cmd =~ /^n$/)
     {
        #$cmd = 'step_over' ;
        $self->command_step_over;
        return XDBGc::REDO_READ_COMMAND;
     } 
        
    if ($cmd =~ /^r$/)
    {
        $cmd = 'step_out';
        return $cmd;
    }
    
    #run until lineno or function
    if ($cmd =~ /^c(:?\s+(\w+))?$/)
    {
        $self->command_continue($1);
        return XDBGc::REDO_READ_COMMAND;
    }
    
    unless($self->debug_mode)
    {
        $self->ui->log('Unknown command "' . $cmd . '"');
        return XDBGc::REDO_READ_COMMAND;
    }
    return $cmd; 
}
sub process_response{
    my ($self,$xml) = (shift, shift);
    return unless $xml;
    $self->session->update($xml);
    
    my $dom = Mojo::DOM->new($xml);
    
    if (defined $dom->at('init'))
    {
        $self->command_option_set('max_data', 16777216);
        $self->command_option_set('max_children', 1024);
        $self->command_option_set('max_depth', 1024);
        
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
        
        $self->ui->print_window if ($cmd =~ /(step_into|step_over|step_out|return|run)/);
        
        return;
    }

    $self->ui->debug("UNEMPLIMENTED XDEBUG engine answer:\n$xml");

}

sub command_step_over{
    my $self = shift;
	my $cmd = 'step_over';
	
	$self->on_data_send($cmd);
	my $xml = $self->server->listen;
    $self->on_data_recv($xml);

}

sub command_step_into{
    my $self= shift;
	my $cmd = 'step_into';
	
	$self->on_data_send($cmd);
	my $xml = $self->server->listen;
    $self->on_data_recv($xml);

}

sub command_continue{
    my ($self, $till) = (shift, shift);
    my $bp = $self->command_breakpoint_set($till, 1) if defined $till;
    
	my $cmd = 'run';
	$self->on_data_send($cmd);
    
	my $xml = $self->server->listen;
    $self->on_data_recv($xml);

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
	my ($self, $cmd, $is_temp) = (shift, shift, shift);
	my $bp = XDBGc::Debugger::Breakpoint->new(session => $self->session,is_temprory => $is_temp);
	$bp->parse_cmd( $cmd );
	$bp->set;
        
	return $bp;
}

sub command_breakpoint_remove{
    my ($self, $id) = (shift, shift);
    if($id eq '*')
    {
        for my $bp (@{$self->session->breakpoints})
        {
            $bp->remove;
        }
    }
    else
    {
        my $bp = XDBGc::Debugger::Breakpoint->new( id => $id , session => $self->session);
        $bp->remove if (defined $bp);
    }

}

sub command_stack_get{
	my ($self, $depth) = (shift, shift);
	my $cmd = 'stack_get';
	$cmd .= ' -d ' . $depth if defined $depth;
	
	$self->on_data_send($cmd);
	my $xml = $self->server->listen;
	
	$self->ui->print_stack_list($xml);
	
    my $dom = Mojo::DOM->new($xml);
	my $col = $dom->find('stack');
    
    return $col;
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
    
    my $dom = Mojo::DOM->new($xml);    
    $self->ui->print_error($dom) if $dom->at('error');
    
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
