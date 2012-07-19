#!perl

use strict;
use warnings;

use Data::Dumper;
use Mojo::Collection; 
use Mojo::DOM;

=for test1
###1
my $c = Mojo::Collection->new(qw/first second third fourth fifth sixth seventh second eiglast/); 
$c->each(
        sub{
            my($e,$cnt) = @_;
            #splice(@$c, $cnt -1,1) if ($e eq 'second' || $e eq 'fifth');            
            delete $c->[$cnt-1]  if ($e eq 'second' || $e eq 'fifth');  
            });

print Dumper($c);
###2

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
=cut


my $data =<<'DATA_TEST'


7.2.3 feature_set

The feature set command allows a IDE to tell the debugger engine what additional capabilities it has. One example of this would be telling the debugger engine whether the IDE supports multiple debugger sessions (for threads, etc.). The debugger engine responds with telling the IDE whether it has enabled the feature or not.

Note: The IDE does not have to listen for additional debugger connections if it does not support debugging multiple sessions. debugger engines must handle connection failures gracefully.

arguments for feature_set include:

    -n 	feature_name
    -v 	value to be set

feature_set can be called at any time during a debug session to change values previously set. This allows a IDE to change encodings.

IDE

feature_set -i transaction_id -n feature-name -v value

debugger engine

<response command="feature_set"
          feature="feature_name"
          success="0|1"
          transaction_id="transaction_id"/>

7.5 continuation commands

resume the execution of the application.

run:
    starts or resumes the script until a new breakpoint is reached, or the end of the script is reached.
step_into:
    steps to the next statement, if there is a function call involved it will break on the first statement in that function
step_over:
    steps to the next statement, if there is a function call on the line from which the step_over is issued then the debugger engine will stop at the statement after the function call in the same scope as from where the command was issued
step_out:
    steps out of the current scope and breaks on the statement after returning from the current function. (Also called 'finish' in GDB)
stop:
    ends execution of the script immediately, the debugger engine may not respond, though if possible should be designed to do so. The script will be terminated right away and be followed by a disconnection of the network connection from the IDE (and debugger engine if required in multi request apache processes).
detach (optional):
    stops interaction with the debugger engine. Once this command is executed, the IDE will no longer be able to communicate with the debugger engine. This does not end execution of the script as does the stop command above, but rather detaches from debugging. Support of this continuation command is optional, and the IDE should verify support for it via the feature_get command. If the IDE has created stdin/stdout/stderr pipes for execution of the script (eg. an interactive shell or other console to catch script output), it should keep those open and usable by the process until the process has terminated normally.

The response to a continue command is a status response (see status above). The debugger engine does not send this response immediately, but rather when it reaches a breakpoint, or ends execution for any other reason.

IDE

run -i transaction_id

debugger engine

<response command="run"
          status="starting"
          reason="ok"
          transaction_id="transaction_id"/>

7.6 breakpoints

Breakpoints are locations or conditions at which a debugger engine pauses execution, responds to the IDE, and waits for further commands from the IDE. A failure in any breakpoint commands results in an error defined in section 6.5.

The following DBGP commands relate to breakpoints:

    breakpoint_set 	Set a new breakpoint on the session.
    breakpoint_get 	Get breakpoint info for the given breakpoint id.
    breakpoint_update 	Update one or more attributes of a breakpoint.
    breakpoint_remove 	Remove the given breakpoint on the session.
    breakpoint_list 	Get a list of all of the session's breakpoints.

There are six different breakpoints types:

    Type 	Req'd Attrs 	Description
    line 	filename, lineno 	break on the given lineno in the given file
    call 	function 	break on entry into new stack for function name
    return 	function 	break on exit from stack for function name
    exception 	exception 	break on exception of the given name
    conditional 	expression, filename 	break when the given expression is true at the given filename and line number or just in given filename
    watch 	expression 	break on write of the variable or address defined by the expression argument

A breakpoint has the following attributes. Note that some attributes are only applicable for some breakpoint types.

    type 	breakpoint type (see table above for valid types)
    filename 	The file the breakpoint is effective in. This must be a "file://" or "dbgp:" (See 6.7 Dynamic code and virtual files) URI.
    lineno 	Line number on which breakpoint is effective. Line numbers are 1-based. If an implementation requires a numeric value to indicate that lineno is not set, it is suggested that -1 be used, although this is not enforced.
    state 	Current state of the breakpoint. This must be one of enabled, disabled.
    function 	Function name for call or return type breakpoints.
    temporary 	Flag to define if breakpoint is temporary. A temporary breakpoint is one that is deleted after its first use. This is useful for features like "Run to Cursor". Once the debugger engine uses a temporary breakpoint, it should automatically remove the breakpoint from it's list of valid breakpoints.
    hit_count 	Number of effective hits for the breakpoint in the current session. This value is maintained by the debugger engine (a.k.a. DBGP client). A breakpoint's hit count should be increment whenever it is considered to break execution (i.e. whenever debugging comes to this line). If the breakpoint is disabled then the hit count should NOT be incremented.
    hit_value 	A numeric value used together with the hit_condition to determine if the breakpoint should pause execution or be skipped.
    hit_condition 	

    A string indicating a condition to use to compare hit_count and hit_value. The following values are legal:

    >=
        break if hit_count is greater than or equal to hit_value [default]
    ==
        break if hit_count is equal to hit_value
    %
        break if hit_count is a multiple of hit_value

    exception 	Exception name for exception type breakpoints.
    expression 	The expression used for conditional and watch type breakpoints

Breakpoints should be maintained in the debugger engine at an application level, not the thread level. Debugger engines that support thread debugging MUST provide breakpoint id's that are global for the application, and must use all breakpoints for all threads where applicable.

As for any other commands, if there is error the debugger engine should return an error response as described in section 6.5.
7.6.1 breakpoint_set

This command is used by the IDE to set a breakpoint for the session.

IDE to debugger engine:

breakpoint_set -i TRANSACTION_ID [<arguments...>] -- base64(expression)

where the arguments are:

    -t TYPE 	breakpoint type, see above for valid values [required]
    -s STATE 	breakpoint state [optional, defaults to "enabled"]
    -f FILENAME 	the filename to which the breakpoint belongs [optional]
    -n LINENO 	the line number (lineno) of the breakpoint [optional]
    -m FUNCTION 	function name [required for call or return breakpoint types]
    -x EXCEPTION 	exception name [required for exception breakpoint types]
    -h HIT_VALUE 	hit value (hit_value) used with the hit condition to determine if should break; a value of zero indicates hit count processing is disabled for this breakpoint [optional, defaults to zero (i.e. disabled)]
    -o HIT_CONDITION 	hit condition string (hit_condition); see hit_condition documentation above; BTW 'o' stands for 'operator' [optional, defaults to '>=']
    -r 0|1 	Boolean value indicating if this breakpoint is temporary. [optional, defaults to false]
    -- EXPRESSION 	code expression, in the language of the debugger engine. The breakpoint should activate when the evaluated code evaluates to true. [required for conditional breakpoint types]

An example breakpoint_set command for a conditional breakpoint could look like this:

breakpoint_set -i 1 -t line -f test.pl -n 20 -- base64($x > 3)

A unique id for this breakpoint for this session is returned by the debugger engine. This session breakpoint id is used by the IDE to identify the breakpoint in other breakpoint commands. It is up to the engine on how to handle multiple "similar" breakpoints, such as a double breakpoint on a specific file/line combination - even if other parameters such as hit_value/hit_condition are different.

debugger engine to IDE:

<response command="breakpoint_set"
          transaction_id="TRANSACTION_ID"
          state="STATE"
          id="BREAKPOINT_ID"/>

where,

    BREAKPOINT_ID 	is an arbitrary string that uniquely identifies this breakpoint in the debugger engine.
    STATE 	the initial state of the breakpoint as set by the debugger engine

7.6.2 breakpoint_get

This command is used by the IDE to get breakpoint information from the debugger engine.

IDE to debugger engine:

breakpoint_get -i TRANSACTION_ID -d BREAKPOINT_ID

where,

    BREAKPOINT_ID 	is the unique session breakpoint id returned by breakpoint_set.

debugger engine to IDE:

<response command="breakpoint_get"
          transaction_id="TRANSACTION_ID">
    <breakpoint id="BREAKPOINT_ID"
                type="TYPE"
                state="STATE"
                filename="FILENAME"
                lineno="LINENO"
                function="FUNCTION"
                exception="EXCEPTION"
                expression="EXPRESSION"
                hit_value="HIT_VALUE"
                hit_condition="HIT_CONDITION"
                hit_count="HIT_COUNT">
        <expression>EXPRESSION</expression>
    </breakpoint>
</response>

where each breakpoint attribute is only required if its value is relevant. E.g., the <expression/> child element need only be included if there is an expression defined, the function attribute need only be included if this is a function breakpoint.
7.6.3 breakpoint_update

This command is used by the IDE to update one or more attributes of a breakpoint that was already set on the debugger engine via breakpoint_set.

IDE to debugger engine:

breakpoint_update -i TRANSACTION_ID -d BREAKPOINT_ID [<arguments...>]

where the arguments are as follows. All arguments are optional, however at least one argument should be present. See breakpoint_set for a description of each argument:

    -s 	STATE
    -n 	LINENO
    -h 	HIT_VALUE
    -o 	HIT_CONDITION

debugger engine to IDE:

<response command="breakpoint_update"
          transaction_id="TRANSACTION_ID"/>

7.6.4 breakpoint_remove

This command is used by the IDE to remove the given breakpoint. The debugger engine can optionally embed the remove breakpoint as child element.

IDE to debugger engine:

breakpoint_remove -i TRANSACTION_ID -d BREAKPOINT_ID

debugger engine to IDE:

<response command="breakpoint_remove"
          transaction_id="TRANSACTION_ID"/>

7.6.5 breakpoint_list

This command is used by the IDE to get breakpoint information for all breakpoints that the debugger engine has.

IDE to debugger engine:

breakpoint_list -i TRANSACTION_ID

debugger engine to IDE:

<response command="breakpoint_list"
          transaction_id="TRANSACTION_ID">
    <breakpoint id="BREAKPOINT_ID"
                type="TYPE"
                state="STATE"
                filename="FILENAME"
                lineno="LINENO"
                function="FUNCTION"
                exception="EXCEPTION"
                hit_value="HIT_VALUE"
                hit_condition="HIT_CONDITION"
                hit_count="HIT_COUNT">
        <expression>EXPRESSION</expression>
    </breakpoint>
    <breakpoint ...>...</breakpoint>
    ...
</response>

7.7 stack_depth

IDE

stack-depth -i transaction_id

debugger engine

<response command="stack_depth"
          depth="{NUM}"
          transaction_id="transaction_id"/>



DATA_TEST
;


open(PAGER, '| more');
print PAGER $data;
