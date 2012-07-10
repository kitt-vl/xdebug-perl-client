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

sub new{
    my $class = shift;
    $class =  ref $class || $class;
    my $self = $class->SUPER::new(@_);
    
    unshift @{$self->session->breakpoints}, $self;
    return $self;
}

sub parse_cmd{
    my ($self, $cmd) = (shift, shift);
    
    my @opts = split /\s/, $cmd;
    shift @opts;
    unshift @opts, $self->session->lineno unless scalar @opts;
    
    $cmd = 'breakpoint_set';
    
    if(scalar @opts == 1)
    {
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
    }    
}

sub parse_xml{
    my ($self, $xml) = (shift, shift);
    my $dom = Mojo::DOM->new($xml);
    
    if(defined $dom->at('response') && defined $dom->response->{id})
    {
        $self->id($dom->response->{id});
        $self->state($dom->response->{state});
        $self->type($dom->response->{type});        
        if($self->type eq 'line')
        {
            $self->filename($dom->response->{filename});
            $self->lineno($dom->response->{lineno});
        }elsif($self->type eq 'call')
        {
            $self->function($dom->response->{function});
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
    }
    elsif($self->type eq 'call')
    {
        $cmd .= ' -m ' . $self->function;
    }
    
    return $cmd;
}

sub set{
    my $self = shift;
    my $cmd = $self->to_string;
    
    $self->session->debugger->on_data_send($cmd);
    
    my $xml = $self->session->debugger->server->listen;
    
    $self->session->debugger->ui->debug("breakpoint set:", $xml);
    
    my $dom = Mojo::DOM->new($xml);
    if(defined $dom->at('response') && defined $dom->response->{id})
    {
        $self->id($dom->response->{id});
        return $self;
    }
    else
    {
        $self->session->debugger->ui->debug("ERROR SET BREAKPOINT");
        return undef;
    }
}

sub update_info{
    my $self = shift;
    
    my $cmd = 'breakpoint_get -d ' . $self->id;    
    $self->session->debugger->on_data_send($cmd);
    
    my $xml = $self->session->debugger->server->listen;
    $self->session->debugger->ui->debug("breakpoint update_info:", $xml);
    
    $self->parse_xml($xml);
    
    unless($self->id)
    {
        $self->session->breakpoints->each(sub{
                                                my ($e, $cnt) = @_;
                                                if ($self eq $e)
                                                {
                                                    splice(@$self->session->breakpoints, $cnt - 1, 1);
                                                    $self = undef;
                                                    return $self;
                                                }
                                            });
    }
    
    return $self;
}

1;
