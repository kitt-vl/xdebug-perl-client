#!perl

use strict;
use warnings;

use Data::Dumper;
use Mojo::Collection; 


my $c = Mojo::Collection->new(qw/first second third fourth fifth sixth seventh second eiglast/); 
$c->each(
        sub{
            my($e,$cnt) = @_;
            #splice(@$c, $cnt -1,1) if ($e eq 'second' || $e eq 'fifth');            
            delete $c->[$cnt-1]  if ($e eq 'second' || $e eq 'fifth');  
            });

print Dumper($c);
