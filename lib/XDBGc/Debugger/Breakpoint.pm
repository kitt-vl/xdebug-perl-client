package XDBGc::Debugger::Breakpoint;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;
use Mojo::DOM;


has session => undef;
has id => 0;
has type => '';
has state => '';
has filename => undef;
has lineno => undef;
has function => undef;
has is_temprory => 0;
has expression => undef;

sub new{
    my $class = shift;
    $class =  ref $class || $class;
    my $self = $class->SUPER::new(@_);
    
    if($self->id)
    {
        $self = $self->session->breakpoints->first( sub{ $_->id == $self->id } );
    }
    else
    {
        unshift @{$self->session->breakpoints}, $self unless $self->is_temprory;
    }    
    
    return $self;
}

sub parse_cmd{
    my ($self, $cmd) = (shift, shift);
    
    my @opts = split /\s/, $cmd;
    shift @opts;
    
    
    $cmd = 'breakpoint_set';
    if($opts[0] eq 'file')
    {
        shift @opts;
        my $filename = shift @opts;
        $self->filename($self->session->cwd .'/' . $filename);
    }
    
    unshift @opts, $self->session->lineno unless scalar @opts;

    my $where = shift @opts;
    $where = $self->session->lineno unless $where;
    
    if($where =~ /^\d+$/) #on line number
    {
        $self->type('line');
        $self->lineno($where);
    }
    else #on function call
    {
        $self->type('call');
        $self->function($where);
    }  
    
    #all that remain is expression of conditional bp
    if(scalar @opts)            
    {
        my $expr = join ' ', @opts; 
        $self->expression($expr);
    }
  
}

sub parse_xml{
    my ($self, $xml) = (shift, shift);
    my $dom = Mojo::DOM->new($xml);
    my $node = $dom->at('response breakpoint');
    $node = $dom->at('response') unless defined $node;
    
    if(defined $node && defined $node->{id})
    {
        $self->id($node->{id});
        $self->state($node->{state});
        $self->type($node->{type});        
        if(defined $self->type && $self->type eq 'line')
        {
            $self->filename($node->{filename});
            $self->lineno($node->{lineno});
        }elsif(defined $self->type && $self->type eq 'call')
        {
            $self->function($node->{function});
        }
    }
        
    return $self;
}

sub to_string{
    my $self = shift;
    my $cmd = 'breakpoint_set -t ' . $self->type ;
    if($self->type eq 'line')
    {
        $cmd .= ' -n ' . $self->lineno;
        $self->filename($self->session->current_file) unless $self->filename;
        $cmd .= ' -f ' . $self->filename;
    }
    elsif($self->type eq 'call')
    {
        $cmd .= ' -m ' . $self->function;
    }
    
    $cmd .= ' -r 1' if $self->is_temprory;
      
      
    
    return $cmd;
}

sub set{
    my $self = shift;
    
    $self->session->debugger->on_data_send($self->to_string, $self->expression);
    
    my $xml = $self->session->debugger->server->listen;
  
    $self->parse_xml($xml);
    $self->update_info;
    
    return $self;
}

sub update_info{
    my $self = shift;
    
    my $cmd = 'breakpoint_get -d ' . $self->id;    
    $self->session->debugger->on_data_send($cmd);
    
    my $xml = $self->session->debugger->server->listen;
    
    $self->parse_xml($xml);
    
    $self->_remove_from_session unless $self->id;

    return $self;
}

sub _remove_from_session{
    my $self = shift;
    
    $self->session->breakpoints->each(sub{
                                            my ($e, $cnt) = @_;
                                            splice(@{$self->session->breakpoints}, $cnt - 1, 1) if ($self eq $e);                                                
                                        });
    return $self;
}

sub _remove_from_server{
    my $self = shift;
    
    my $cmd = 'breakpoint_remove -d ' . $self->id;    
    $self->session->debugger->on_data_send($cmd);
    
    my $xml = $self->session->debugger->server->listen;
    
    return $self;
}

sub remove{
    my $self = shift;
    $self->_remove_from_server;
    $self->_remove_from_session;
    
    return $self;
}
1;
