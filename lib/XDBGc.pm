use strict;
use warnings;
use utf8;
########################################################################
package XDBGc;
use Mojo::Base -base;
use constant {
        REDO_READ_COMMAND => 1
};

sub log{
    @_ = map { defined($_) ? $_ :'<undef>'}  @_;
    
	my $msg = "@{[ @_ ]}";
	utf8::decode($msg);
	say "[@{[ ~~localtime ]}]: $msg";	 
}

1;
########################################################################
