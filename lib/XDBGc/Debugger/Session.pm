package XDBGc::Debugger::Session;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;
use Mojo::DOM;

has _tid => 0;
has initial_file => undef;
has current_file => undef;
has lineno => 1;
has status => '';
has source_cache => sub { my %x = (); return \%x; };

sub update{
    my ($self, $dom) = (shift, shift);
    
    if( defined $dom->at('init') && defined $dom->init->{fileuri} )
    {
        $self->initial_file($dom->init->{fileuri});
        $self->current_file($dom->init->{fileuri});
    }
    
    if( defined $dom->at('response') )
    {
        $self->status($dom->response->{status}) if defined $dom->response->{status};
        $self->current_file($dom->response->{fileuri}) if defined $dom->response->{fileuri};
        $self->lineno($dom->response->{lineno}) if defined $dom->response->{lineno};
    }
    
    if( defined (my $node = $dom->at('message')) )
    {
        $self->status($node->{status}) if defined $node->{status};
        $self->current_file($node->{filename}) if defined $node->{filename};
        $self->lineno($node->{lineno}) if defined $node->{lineno};
    }
}

1;

