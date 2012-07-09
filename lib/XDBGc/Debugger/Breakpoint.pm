package XDBGc::Debugger::Breakpoint;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;

has session => undef;
has id => 0;
has type => '';
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

sub parse{
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

1;
