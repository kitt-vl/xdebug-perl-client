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

sub debug{
    
    my $self = shift;
    return unless $self->debugger->debug_mode;
    
    @_ = map { defined($_) ? $_ :'<undef>'}  @_;
    
	my $msg = "@{[ @_ ]}";
	utf8::decode($msg);

	say "[DEBUG @{[ ~~localtime ]}]: $msg";	 
}


sub term_read_command{
	my $self = shift;
    
    $self->print_window;
    
    my $info = '';
    $info .= $self->debugger->session->current_file if $self->debugger->session->current_file;
    $info .= ' , line ' . $self->debugger->session->lineno if $self->debugger->session->lineno;
    say $info if $info;
    
	my $cmd = $self->_term->readline('<' . $self->prompt . ':' . $self->debugger->session->status . '>');
	
	$self->debug("term_read_command: $cmd");
	
	return $cmd;	
}

sub print_window{
    my $self = shift;
    my ($min, $max, $current);
    
    $min = $self->min_lineno;
    $max = $self->max_lineno;
    $current = $self->debugger->session->lineno;
    my @list = @{$self->debugger->command_get_source($self->debugger->session->current_file, $min, $max)};
    
    print "\n\n";
    for(@list)
    {
		
		if($min == $current)
		{
			say "$min: ==> $_";	
		}
		else
		{
			say "$min:\t$_";
		}
		
		$min++;
	}
}

sub max_lineno{
        my ($self, $file) = @_;
        $file = $self->debugger->session->current_file unless $file;
        
        my $half_win = int($self->window_size/2);
        my @list = @{$self->debugger->command_get_source($file)};
        
        my $max_file = scalar @list;
        my $max_win = $self->debugger->session->lineno + $half_win ;
        my $max  =  $max_win > $max_file ? $max_file : $max_win;
        
        $self->debug("max_lineno: $max");
        return $max;
}

sub min_lineno{
        my ($self) = @_;
        
        my $half_win = int($self->window_size/2);

        my $min_win = $self->debugger->session->lineno - $half_win;
        my $min =  $min_win > 0 ? $min_win : 1;
        
        $self->debug("min_lineno: $min");
        return $min;
}

sub print_list_breakpoints{
    my $self = shift;
    
    for my $bp (@{$self->debugger->session->breakpoints})
    {
        my $res = " ID: " . $bp->id ;
        if($bp->type eq 'line')
        {
            $res  .= ' on line ' . $bp->lineno;
        }
        elsif($bp->type eq 'call')
        {
            $res  .= ' on call function  ' . $bp->function;
        }
        else
        {
            $res  .= ' of UNKNOWN type ' . $bp->type;
        }
        
        say $res;
    }
    
}
    
    
1;
