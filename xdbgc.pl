use strict;
use warnings;
use utf8;

package XDBGc;
use Mojo::Base -base;


sub log{
	my $msg = "@{[ @_ ]}";
	utf8::decode($msg);
	say "[@{[ ~~localtime ]}]: $msg";	 
}
1;
########################################################################
package XDBGc::server;
use IO::Socket::INET;
use Mojo::Base -base;
use Net::hostent; 
use Encode;
use Term::ReadLine;

has port => 9000;
has host => 'localhost';
has server => sub { undef; };
has client => sub { undef; };
has _max_conn => 5;
has _tid => 0;
has _term => sub { Term::ReadLine->new; };

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
	
	XDBGc::log("Server waiting for connentions...");
	return $self;	
}

sub on_data{
		my ($self,$xml) = (shift,shift);
		XDBGc::log("on_data  :", $xml);
}

sub term_command_read{
	my $self = shift;
	my $prompt = "xDBGc: ";
	while ( defined ($_ = $self->_term->readline($prompt)) ) 
	{
	  XDBGc::log("READ TERM HERE... $_");
		$self->_send_command($_);
	}
}
	
sub _send_command{
		my $self = shift;
		my $cmd = shift;
		$self->_tid($self->_tid() + 1);
		$cmd .= ' -i ' . $self->_tid;
		$self->client->send($cmd);
		
}

sub accept{
	my $self = shift;
	my $xml;
	
	if(my $client = $self->server->accept) 
	{
		$self->client($client);
		$self->client->autoflush(1);

		my $hostinfo = gethostbyaddr($self->client->peeraddr);
		
		XDBGc::log("Connect from ", $hostinfo->name || $self->client->peerhost);

		my $data;
		while (ord(my $_ = $self->client->getc)!=0) 
		{
			$data .= $_;					
		}		
		$self->client->read($xml,$data+1);		
		
		
		$self->on_data($xml);	
		
		#$self->client->close;	
		return 1;
	}
	else
	{
		return 0;
	}	
}
1;
########################################################################

my $serv = XDBGc::server->new;

$serv->start;

while($serv->accept)
{
		$serv->term_command_read();
}

 
say "Program teminated(0)";
