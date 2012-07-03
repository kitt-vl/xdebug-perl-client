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
    
    $self->print_window;
    
	my $cmd = $self->_term->readline('<' . $self->prompt . ':' . $self->debugger->session->status . '>');
	
	$self->log("term_read_command: $cmd");
	
	return $cmd;	
}

sub print_window{
    my $self = shift;
    my @list = $self->debugger->command_get_source($self->debugger->session->current_file, $self->min_lineno, $self->max_lineno);
    say @list;
}

sub max_lineno{
        my ($self, $file) = @_;
        $file = $self->debugger->session->current_file unless $file;
        
        my $half_win = int($self->window_size/2);
        my @list = $self->debugger->command_get_source($file);
        
        my $max_file = scalar @list;
        my $max_win = $self->debugger->session->lineno + $half_win ;
        my $max  =  $max_win > $max_file ? $max_file : $max_win;
        
        $self->log("max_lineno: $max");
        return $max;
}

sub min_lineno{
        my ($self) = @_;
        
        my $half_win = int($self->window_size/2);

        my $min_win = $self->debugger->session->lineno - $half_win;
        my $min =  $min_win > 0 ? $min_win : 0;
        
        $self->log("min_lineno: $min");
        return $min;
}
1;
