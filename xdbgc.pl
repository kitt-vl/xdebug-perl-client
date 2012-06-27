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
	my $cmd = $self->_term->readline($prompt);
	
	XDBGc::log("READ TERM HERE... $cmd");
	
	$self->_command($cmd );
	
}
	
sub _command{
	my ($self,$cmd) = (shift, shift);
	
	$self->shutdown if $cmd =~ /^quit/;
	
	$self->_send_command($cmd);
}

sub _send_command{
		my ($self, $cmd) = (shift, shift);
		
		$self->_tid( $self->_tid()+1 );
		$cmd .= ' -i ' . $self->_tid ." ".chr(0);
		my $res = $self->client->send($cmd);		
		XDBGc::log("_send_command: sended $res, len " . length($cmd));
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

	
	if(my $client = $self->server->accept) 
	{
		$self->client($client);
		$self->client->autoflush(1);

		my $hostinfo = gethostbyaddr($self->client->peeraddr);
		
		XDBGc::log("Connect from ", $hostinfo->name || $self->client->peerhost);
		
		#$self->client->close;	
		return 1;
	}
	else
	{
		return 0;
	}	
}

sub listen{
		my $self = shift;
		my ($data,$xml);
		while (ord(my $_ = $self->client->getc)!=0) 
		{
			$data .= $_;					
		}		
		$self->client->read($xml,$data+1);		
		#XDBGc::log("listen: read ", $data+1, " bytes ");
		$self->on_data($xml);
		return $xml;
}
1;
########################################################################

my $serv = XDBGc::server->new;

$serv->start;

if ($serv->accept)
{
	while( my $xml = $serv->listen)
	{
			#XDBGc::log("main: xml ", $xml);
			$serv->term_command_read();
	}
}

 
XDBGc::log( "Program teminated(0)" );
