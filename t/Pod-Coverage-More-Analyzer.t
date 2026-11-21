use strict;
use warnings;

use Test2::V1 -i;
use Test2::Plugin::NoWarnings;

use FindBin;
use lib $FindBin::Bin;
use FindBin::libs;

use Analyzed;
use Signed;

use Pod::Coverage::More::Analyzer;

# Short forms of a record, so a failure shows every difference on one line each.
sub params_of {
    my ($rec) = @_;
    return [
        map {
            ( $_->{name} // '?' ) . "#$_->{index}:$_->{source}"
                . ( $_->{optional} ? ' optional' : '' )
                . ( $_->{default}  ? " default $_->{default}{mode}" : '' )
                . ( $_->{keys}     ? " keys @{$_->{keys}}" : '' )
        } @{ $rec->{params} }
    ];
}

sub returns_of {
    my ($rec) = @_;
    return [
        map {
            my $r = $_;
            join ' ', $r->{type},
                map { defined $r->{$_} ? "$_=$r->{$_}" : () } qw{value class class_from name function method coderef context op count}
        } @{ $rec->{returns} }
    ];
}

subtest backend_for => sub {
    like( dies { Pod::Coverage::More::Analyzer::backend_for(5.034) }, qr/not supported/, "5.34 is older than the oldest version set" );
    like( dies { Pod::Coverage::More::Analyzer::backend_for(5.035999) }, qr/not supported/, "the last 5.35 is still older than the oldest version set" );
    is( Pod::Coverage::More::Analyzer::backend_for(5.036), 'Pod::Coverage::More::Analyzer::v5_36', "5.36 has its own set" );
    is( Pod::Coverage::More::Analyzer::backend_for(5.036003), 'Pod::Coverage::More::Analyzer::v5_36', "5.36 maintenance releases stay in it" );
    is( Pod::Coverage::More::Analyzer::backend_for(5.038), 'Pod::Coverage::More::Analyzer::v5_38', "5.38 starts the padsv_store set" );
    is( Pod::Coverage::More::Analyzer::backend_for(5.042004), 'Pod::Coverage::More::Analyzer::v5_38', "5.42 is the last of the padsv_store set" );
    is( Pod::Coverage::More::Analyzer::backend_for(5.044), 'Pod::Coverage::More::Analyzer::v5_44', "5.44 starts the multiparam set" );
    is( Pod::Coverage::More::Analyzer::backend_for(5.046), 'Pod::Coverage::More::Analyzer::v5_44', "later perls fall into the newest set" );
};

subtest new => sub {
    my $analyzer = Pod::Coverage::More::Analyzer->new;
    is( ref($analyzer), Pod::Coverage::More::Analyzer::backend_for($]), "new returns the backend for the running perl $]" );
};

my $analyzer = Pod::Coverage::More::Analyzer->new;

subtest analyze_package => sub {
    my $subs = $analyzer->analyze_package('Analyzed');
    ok( !exists $subs->{croak},   "croak, imported from Carp, is left out" );
    ok( !exists $subs->{blessed}, "blessed, imported from Scalar::Util, is left out" );
    ok( exists $subs->{generated}, "a closure assigned to a glob is included" );
    is( [ grep { $subs->{$_}{name} ne $_ } keys %$subs ], [], "every record carries the name it is filed under" );
};

my $subs = $analyzer->analyze_package('Analyzed');

subtest constants => sub {
    is( $subs->{LIMIT}{kind}, 'constant', "use constant gives a constant" );
    is( returns_of( $subs->{LIMIT} ), ['number value=5'], "a numeric constant returns its number" );
    is( returns_of( $subs->{GREETING} ), ['string value=hello'], "a string constant returns its string" );
};

subtest positional_parameters => sub {
    is( params_of( $subs->{shifted} ), [ '$self#0:shift', '$name#1:shift' ], "each shift takes the next index" );
    is( params_of( $subs->{listed} ), [ '$self#0:list', '$first#1:list', '@rest#2:list' ], "a list assignment from \@_ ends with its slurpy array" );
    is( params_of( $subs->{elements} ), [ '?#0:element', '?#1:element' ], "\$_[N] used directly gives unnamed parameters" );
    is( params_of( $subs->{shift_method} ), ['?#0:shift'], "shift->method gives an unnamed parameter" );
    is( params_of( $subs->{anon_inside} ), ['$x#0:shift'], "the shift inside a nested anonymous sub belongs to that sub" );
    is( params_of( $subs->{generated} ), ['$q#0:list'], "a closure assigned to a glob has its parameters read" );
    ok( $subs->{generated}{generated}, "a closure assigned to a glob is marked generated" );
    ok( !$subs->{shifted}{generated}, "a named sub is not marked generated" );
    is( params_of( $subs->{evaled} ), [ '$self#0:list', '$value#1:list' ], "a sub built by string eval has its parameters read" );
    ok( $subs->{evaled}{generated}, "a sub built by string eval is marked generated" );
};

subtest named_parameters => sub {
    is( params_of( $subs->{named} ), [ '$self#0:shift', '%opts#1:list keys verbose size count name' ], "keys read from a hash of named arguments, by exists, in arithmetic and as call arguments" );
    is( params_of( $subs->{hashref_arg} ), [ '$self#0:list', '$args#1:list keys alpha' ], "keys read through a hashref parameter" );
    ok( $subs->{hashref_arg}{usage}{'$args'}{hashref}, "a parameter dereferenced as a hash is used as a hashref" );
};

subtest usage => sub {
    my $usage = $subs->{uses}{usage};
    ok( $usage->{'$num'}{numeric}, "a variable added to is used as a number" );
    ok( $usage->{'$str'}{string},  "a variable concatenated is used as a string" );
    ok( $usage->{'$code'}{coderef}, "a variable called is used as a coderef" );
    is( $usage->{'$obj'}{methods}, ['render'], "a variable that methods are called on records them" );
    ok( !$usage->{'$num'}{string}, "a variable only used as a number is not used as a string" );
};

subtest returns => sub {
    is( returns_of( $subs->{shifted} ), ['variable name=$name'], "a returned variable is named" );
    is( returns_of( $subs->{listed} ), ['number'], "scalar(\@array) returns a number" );
    is( returns_of( $subs->{bare_return} ), ['empty'], "return with no value" );
    is( returns_of( $subs->{listy} ), ['list count=3'], "a list of three values" );
    is( returns_of( $subs->{branches} ), [ 'number value=1', 'string value=no' ], "one value per return in an if/else" );
    is( returns_of( $subs->{ternary} ), [ 'arrayref', 'undef' ], "both branches of a ternary, one an empty []" );
    is( returns_of( $subs->{empty_hashref} ), ['hashref'], "an empty {} is a hashref" );
    is( returns_of( $subs->{fall_through} ), [ 'string value=yes', 'hashref' ], "the last statement of each branch when there is no return" );
    ok( ( grep { $_->{implicit} } @{ $subs->{fall_through}{returns} } ) == 2, "values from falling off the end are marked implicit" );
    is( returns_of( $subs->{context} ), [ 'number value=1 context=list', 'number value=0 context=scalar' ], "wantarray says which value goes with which context" );
    is( returns_of( $subs->{calls} ), ['call function=Analyzed::listed'], "a returned call names the function" );
    is( returns_of( $subs->{named} ), [ 'number', 'method method=frob' ], "a returned method call names the method" );
    is( returns_of( $subs->{anon_inside} ), ['call coderef=$f'], "a returned call of a coderef names the variable" );
};

subtest objects => sub {
    is( returns_of( $subs->{fixed_class} ), ['object class=Some::Class'], "bless with a literal class" );
    is( returns_of( $subs->{one_arg_bless} ), ['object class=Analyzed'], "bless with one argument blesses into the package" );
    is( returns_of( $subs->{constructor} ), ['object class_from=$class'], "bless into ref(\$class) || \$class takes the class from \$class" );
};

subtest dies => sub {
    is( $subs->{dies}{dies}, [
        { via => 'die',         line => 121, caught => 0 },
        { via => 'Carp::croak', line => 122, caught => 0 },
        { via => 'die',         line => 123, caught => 1 },
    ], "die, an imported croak, and a die inside eval" );
    is( $subs->{shifted}{dies}, [], "a sub with no explicit termination" );
};

subtest signatures => sub {
    my $signed = $analyzer->analyze_package('Signed');
    is( params_of( $signed->{plain} ), [ '$x#0:signature', '$y#1:signature' ], "two mandatory parameters" );
    is( params_of( $signed->{defaults} ), [ '$x#0:signature', '$y#1:signature optional default =' ], "a parameter with a default is optional" );
    is( $signed->{defaults}{params}[1]{default}{value}, [ { type => 'number', value => 5 } ], "the value of a literal default" );
    is( params_of( $signed->{slurpy_array} ), [ '$x#0:signature', '@rest#1:signature optional' ], "a slurpy array" );
    is( params_of( $signed->{slurpy_hash} ), [ '$x#0:signature', '%opts#1:signature optional keys size' ], "a slurpy hash and the keys read from it" );
    ok( $signed->{slurpy_hash}{params}[1]{slurpy}, "a slurpy hash is marked slurpy" );
    is( params_of( $signed->{placeholder} ), [ '?#0:signature', '$y#1:signature' ], "a placeholder parameter has no name" );
    is( params_of( $signed->{empty} ), [], "an empty signature has no parameters" );
};

subtest signature_defaults_5_38 => sub {
    skip_all("perl $] cannot compile the //= and ||= defaults that 5.38 added") if $] < 5.038;
    require Signed538;
    my $signed = $analyzer->analyze_package('Signed538');
    is( params_of( $signed->{defaults} ), [
        '$x#0:signature',
        '$z#1:signature optional default //=',
        '$w#2:signature optional default ||=',
    ], "a default for an undef argument and a default for a false argument" );
    is( $signed->{defaults}{params}[1]{default}{value}, [ { type => 'string', value => 'z' } ], "the value of a //= default" );
    is( $signed->{defaults}{params}[2]{default}{value}, [ { type => 'arrayref' } ], "the value of a ||= default" );
};

done_testing;
