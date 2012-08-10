package XDBGc::Debugger::Server;
use strict;
use warnings;
use utf8;

use Mojo::Base -base;
use IO::Socket::INET;
use Net::hostent; 

has port => 9000;
has host => 'localhost';
has server => sub { undef; };
has client => sub { undef; };
has _max_conn => 5;
has debugger => undef;

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
					
		$self->debugger->ui->log("Can't start server: ", $@) if $@;
		$self->server($server);			
	};
	die unless $self->server;

	return $self;	
}

sub shutdown{
	my $self = shift;
	$self->client->close if $self->client;
	$self->server->close if $self->server;
	$self->debugger->ui->log( "Program shutdown'ed(0)");
	#exit 0;	
}

sub accept{
	my $self = shift;
    $self->debugger->ui->log("Server waiting for connections...");
	if(my $client = $self->server->accept) 
	{
		$self->client($client);
		$self->client->autoflush(1);

		my $hostinfo = gethostbyaddr($self->client->peeraddr);
		
		$self->debugger->ui->log("Connect from ", $hostinfo->name || $self->client->peerhost);

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
        
        $self->debugger->ui->debug("Server listen: ", $xml);
        
		return $xml;
}
1;
