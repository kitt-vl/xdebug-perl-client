use strict;
use warnings;
use utf8;

package XDBGc::Server;
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
        
        &$self->_on_data_handler($xml)  if defined $self->_on_data_handler && ref $self->_on_data_handler eq 'CODE'        
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
