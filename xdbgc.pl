#!perl
use strict;
use warnings;
use utf8;
########################################################################
package XDBGc;
use Mojo::Base -base;

sub log{
    @_ = map { defined($_) ? $_ :'<undef>'}  @_;
    
	my $msg = "@{[ @_ ]}";
	utf8::decode($msg);
	say "[@{[ ~~localtime ]}]: $msg";	 
}
1;
########################################################################
package XDBGc::server;
use Mojo::Base -base;
use IO::Socket::INET;
use Net::hostent; 

has port => 9000;
has host => 'localhost';
has server => sub { undef; };
has client => sub { undef; };
has _max_conn => 5;
has _on_data_handler => sub { undef; };

############
sub start{
	my $self = shift;
	die "Server already started" if defined $self->server;
	
	eval{
		local $@;
		my $server = IO::Socket::INET->new( Proto     => 'tcp',
                                            LocalPort => $self->port,
                                            LocalAddr => $self->host,
                                            Listen    => $self->_max_conn,
                                            Reuse     => 1);
					
		XDBGc::log("Can't start server: ", $@) if $@;
		$self->server($server);			
	};
	die unless $self->server;

	return $self;	
}

sub on_data{
		my ($self,$xml) = (shift,shift);
		XDBGc::log("on_data  :", $xml);
        
        &$self->_on_data_handlerif($xml)  if defined $self->_on_data_handler && ref $self->_on_data_handler eq 'CODE'        
}

sub shutdown{
	my $self = shift;
	$self->client->close if $self->client;
	$self->server->close if $self->server;
	XDBGc::log( "Program shutdown'ed(0)");
	exit 0;	
}

sub accept{
	my $self = shift;
    XDBGc::log("Server waiting for connections...");
	if(my $client = $self->server->accept) 
	{
		$self->client($client);
		$self->client->autoflush(1);

		my $hostinfo = gethostbyaddr($self->client->peeraddr);
		
		XDBGc::log("Connect from ", $hostinfo->name || $self->client->peerhost);
		
		#$self->client->close;	
		return 1;
	}	
}

sub listen{
		my $self = shift;
		my ($data,$xml);
		while (defined(my $char = $self->client->getc)) 
		{
            last unless ord $char;
			$data .= $char;					
		}		
		$self->client->read($xml,$data+1) if $data;		
		#XDBGc::log("listen: read ", $data+1, " bytes ");
		$self->on_data($xml) if $xml;
		return $xml;
}
1;
########################################################################
package XDBGc::debugger;
use utf8;
use Mojo::Base -base;
use Mojo::DOM;
use Term::ReadLine;

has _term => sub { Term::ReadLine->new('', \*STDIN, \*STDOUT); };
has server => sub { XDBGc::server->new; };
has _tid => 0;

sub term_read_command{
	my $self = shift;
	my $prompt = "XDBGc: ";
	my $cmd = $self->_term->readline($prompt);
	
	XDBGc::log("term_read_command: $cmd");
	
	$self->on_command($cmd);	
}

sub on_command{
	my ($self,$cmd) = (shift, shift);
	
	$self->server->shutdown if $cmd =~ /^quit/;	
    
    $self->_tid( $self->_tid()+1 );
    
    $cmd .= ' -i ' . $self->_tid .' -- '.chr(0);
        
    my $res = $self->server->client->send($cmd);		
    XDBGc::log("on_command: cmd '$cmd' sended $res, len " . length($cmd));
}
	
1;
########################################################################
package main;
use utf8;

my $db = XDBGc::debugger->new;
$db->server->start;

while($db->server->accept)
{
	while( my $xml = $db->server->listen)
	{
			$db->term_read_command();
	}
    XDBGc::log('Debug session ended, waiting for new connections');
}
 
XDBGc::log( "Program teminated(0)" );
