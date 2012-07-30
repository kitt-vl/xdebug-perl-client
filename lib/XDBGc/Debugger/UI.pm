package XDBGc::Debugger::UI;
use strict;
use warnings;
use utf8;

use Carp;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::Util qw/b64_decode/;
use Term::ReadLine;
use IO::Pager::Unbuffered;


has _term => sub { Term::ReadLine->new('', \*STDIN, \*STDOUT); };
has prompt => 'XDBGc';
has debugger => undef;
has window_size => 10;
has use_pager => 0;

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

	carp "\n\n[DEBUG @{[ ~~localtime ]}]: $msg";	 
}


sub term_read_command{
	my $self = shift;

	my $cmd = $self->_term->readline('<' . $self->prompt . ':' . $self->debugger->session->status . '>');
	
    $cmd =~ s/^\s+//;
    $cmd =~ s/\s+$//;
    
    $self->use_pager( $cmd =~ s{^\|}{} );
    
    $cmd =~ s/^\s+//;    
    
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
    
    my $info = '';
    $info .= $self->debugger->session->current_file if $self->debugger->session->current_file;
    $info .= ' , line ' . $self->debugger->session->lineno if $self->debugger->session->lineno;
    say $info if $info;
}

sub max_lineno{
        my ($self, $file) = @_;
        $file = $self->debugger->session->current_file unless $file;
        
        my $half_win = int($self->window_size/2);
        my @list = @{$self->debugger->command_get_source($file)};
        
        my $max_file = scalar @list;
        my $max_win = $self->debugger->session->lineno + $half_win ;
        $max_win = $self->window_size > $max_win ? $self->window_size : $max_win;
        my $max  =  $max_win > $max_file ? $max_file : $max_win;
        
        #$self->debug("max_lineno: $max");
        return $max;
}

sub min_lineno{
        my ($self) = @_;
        
        my $half_win = int($self->window_size/2);

        my $min_win = $self->debugger->session->lineno - $half_win;
        
        my $min =  $min_win > 0 ? $min_win : 1;
        
        #$self->debug("min_lineno: $min");
        return $min;
}

sub print_breakpoints_list{
    my $self = shift;
    
    say "\nList of breakpoints:";
    for my $bp (@{$self->debugger->session->breakpoints})
    {
        $bp->update_info;
        
        my $res = " ID: " . $bp->id ;
        if($bp->type eq 'line')
        {
			$res  .= ' ' . $bp->filename if $bp->filename;
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
    
sub print_stack_list{
	my ($self, $xml) = (shift, shift);
	
	my $dom = Mojo::DOM->new($xml);
	my $col = $dom->find('stack');
	
	say "\nStacktrace:";
	for my $stack (@$col)
	{
		my $res = '{' . $stack->{level} . '} ';
        $res .= ' type ' . $stack->{type} unless $stack->{type} eq 'file';
        
        $res .= ' "' . $stack->{where} . '"' if(defined $stack->{where});
		if($stack->{type} eq 'file')
		{
			$res .= ' in ' . $stack->{filename} . ' lineno ' . $stack->{lineno};
		}
        
		say $res;
	
	}
} 

sub print_eval{
    my ($self, $xml, $data) = (shift, shift, shift);
    
    my $dom = Mojo::DOM->new($xml);
    my $var = $dom->at('response > property');
    
    unless(defined $var)
    {
        $self->debug('print_eval: EMPTY ANSWER ("response > property" not found) ');
        return;
    }
    
    #$self->print_var($var, 0, $data, $use_pager);
    my $res = $self->parse_var($var, 0, $data);
    $self->use_pager ? $self->print_pager($res) : say $res;
} 

sub parse_var{
    my ($self, $var, $level, $data) = (shift, shift, shift, shift);
    $level = 0 unless defined $level;
    
    my $res = "\t" x $level;
    $res .= uc $var->{type};
    $res .= ':' . $var->{classname} if defined $var->{classname};
    
    my $name = $var->{name};
    $name = $data unless defined $name;
    $name = '<?>' unless defined $name;
    
    $res .= "\t" . $name . ' = ';
    if(defined $var->{numchildren} && $var->{numchildren} > 0)
    {
        $res .= '('. $var->{numchildren} . ' item(s))';
        
        for my $child (@{$var->children})
        {
            $res .=  "\n" . $self->parse_var($child, $level+1) ;
        }
        return $res;        
    }
    else
    {
        my $val = defined $var->{encoding} && $var->{encoding} eq 'base64' ? b64_decode($var->text) : $var->text;
        
        $val = 'NULL' if $var->{type} eq 'null' ;
        
        $val = '0' if $var->{type} =~ /int|float|bool/ and !$val;
        
        $val = '"' . $val . '"' if $var->{type} eq 'string';
        
        $res .= $val;        
        return $res ;
    }
    
}

sub print_var{
    my ($self, $var, $level, $data, $use_pager) = (shift, shift, shift, shift, shift);
    $level = 0 unless defined $level;
    
    my $res = "\t" x $level;
    $res .= uc $var->{type};
    $res .= ':' . $var->{classname} if defined $var->{classname};
    
    my $name = $var->{name};
    $name = $data unless defined $name;
    $name = '<?>' unless defined $name;
    
    $res .= "\t" . $name . ' = ';
    if(defined $var->{numchildren} && $var->{numchildren} > 0)
    {
        $res .= '('. $var->{numchildren} . ' item(s))';
        
        say $res;
        
        for my $child (@{$var->children})
        {
            $self->print_var($child, $level+1);
        }
        return;        
    }
    else
    {
        my $val = defined $var->{encoding} && $var->{encoding} eq 'base64' ? b64_decode($var->text) : $var->text;
        
        $val = 'NULL' if $var->{type} eq 'null' ;
        
        $val = '0' if $var->{type} =~ /int|float|bool/ and !$val;
        
        $val = '"' . $val . '"' if $var->{type} eq 'string';
        
        $res .= $val ;        
       
        say $res;
    }
    
}  

sub print_option{
    my ($self, $xml) = (shift, shift);
    
    my $dom = Mojo::DOM->new($xml);
    my $node = $dom->at('response');
    my $res = '';
    
    $res .= $node->{feature_name} . ' = ' . $node->text;
    $res .= '0' unless $node->text;
    $res .= ' (not supported)' unless $node->{supported};
    say $res;
    
}

sub print_context{
    my ($self, $xml, $data) = (shift, shift, shift);
    
    my $dom = Mojo::DOM->new($xml);
    my $col = $dom->find('response > property');
    
    for my $var(@{$col})
    {
        $self->print_var($var, 0, $data);
    }
}

sub print_pager{
    my ($self, $data) = (shift, shift);

    my $token = new IO::Pager::Unbuffered;
    $token->print($data);
    
    $self->use_pager(0);
}

sub print_error{
    my ($self, $dom) = (shift, shift);
    my $res = '';
    my $message = $dom->at('response > error > message');
    my $response = $dom->at('response');
    
    $res .= 'Command "' . $response->{command} . '" error: ' if $response->{command};
    $res .= $message->text if $message->text;
    
    say $res if $res;
}
1;
