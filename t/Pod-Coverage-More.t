#!perl

use 5.036;
use warnings FATAL => q{all};
use re q{/xsaa};

use Test2::V1 -i;    ## no critic (ProhibitUnusedImports) -i imports every tool, which the policy cannot see
use Test2::Plugin::NoWarnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Pod::Coverage::More;

# The fixture, whose POD disagrees with its subs.
require Mistyped;

# The messages of a result, one per line, in a stable order: they come out in hash order.
sub messages_of {
    my ($result) = @_;
    return [ sort split m/^/m, $result->{message} // '' ];
}

subtest coverage_arguments => sub {
    my $result = Pod::Coverage::More->new( package => 'Mistyped' )->coverage_arguments;
    is( $result->{status}, 0, "an argument that the sub does not take fails" );
    is(
        messages_of($result),
        ["Var Mismatch for function wrong_name: colour not in color\n"],
        "the message names the function, the argument and the parameters"
    );
};

subtest coverage_argument_types => sub {
    my $result = Pod::Coverage::More->new( package => 'Mistyped' )->coverage_argument_types;
    is( $result->{status}, 0, "arguments with wrong or missing types fail" );
    is(
        messages_of($result),
        [
            "No type declared for arg size of untyped\n",
            "Type mismatch for arg count of wrong_type: got hash, expected scalar\n",
            "Var Type Mismatch for function wrong_sigil: \@items not in \$items\n",
            "Var colour not documented whatsoever for wrong_name!\n",
            "Var second not documented whatsoever for missing_item!\n",
        ],
        "one message for each kind of mistake"
    );
};

done_testing;
