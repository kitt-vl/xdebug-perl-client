package XDBGc::Debugger::UI;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;
use Mojo::DOM;
use Term::ReadLine;


has _term => sub { Term::ReadLine->new('', \*STDIN, \*STDOUT); };
has prompt => 'XDBGc';
has debugger => undef;
has window_size => 10;

sub log{
    my $self = shift;
    
    @_ = map { defined($_) ? $_ :'<undef>'}  @_;
    
	my $msg = "@{[ @_ ]}";
	utf8::decode($msg);

	say "[@{[ ~~localtime ]}]: $msg";	 
}


sub term_read_command{
	my $self = shift;
    my $info = '';
    $info .= $self->debugger->session->current_file if $self->debugger->session->current_file;
    $info .= ' , line ' . $self->debugger->session->lineno if $self->debugger->session->lineno;
    say $info if $info;
    
	my $cmd = $self->_term->readline('<' . $self->prompt . ':' . $self->debugger->session->status . '>');
	
	$self->log("term_read_command: $cmd");
	
	return $cmd;	
}


1;
