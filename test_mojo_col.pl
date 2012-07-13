#!perl

use strict;
use warnings;

use Data::Dumper;
use Mojo::Collection; 
use Mojo::DOM;

=for test1
my $c = Mojo::Collection->new(qw/first second third fourth fifth sixth seventh second eiglast/); 
$c->each(
        sub{
            my($e,$cnt) = @_;
            #splice(@$c, $cnt -1,1) if ($e eq 'second' || $e eq 'fifth');            
            delete $c->[$cnt-1]  if ($e eq 'second' || $e eq 'fifth');  
            });

print Dumper($c);
=cut

my $xml = <<XML
<response xmlns="urn:debugger_protocol_v1" xmlns:xdebug="http://xdebug.org/dbgp/xdebug" command="eval" transaction_id="6">
    <property address="141883788" type="object" classname="Exception" children="1" numchildren="7" page="0" pagesize="32">
        <property name="message" facet="protected" address="156705480" type="string" size="0" encoding="base64">
            <![CDATA[]]>
        </property>
        <property name="string" facet="private" address="156705512" type="string" size="0" encoding="base64">
            <![CDATA[]]>
        </property>
        <property name="code" facet="protected" address="156705616" type="int">
            <![CDATA[0]]>
        </property>
        <property name="file" facet="protected" address="156706568" type="string" size="11" encoding="base64">
            <![CDATA[eGRlYnVnIGV2YWw=]]>
        </property>
        <property name="line" facet="protected" address="156706600" type="int">
            <![CDATA[1]]>
        </property>
        <property name="trace" facet="private" address="156706016" type="array" children="1" numchildren="1">
        </property>
        <property name="previous" facet="private" address="156705984" type="null">
        </property>
    </property>
</response>
XML
;

my $dom = Mojo::DOM->new($xml);
my $vars = $dom->find('property');

print Dumper($vars);
