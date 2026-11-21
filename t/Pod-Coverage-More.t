#!perl

use 5.036;
use warnings FATAL => q{all};
use re q{/xsaa};

use Test2::V1 -i;    ## no critic (ProhibitUnusedImports) -i imports every tool, which the policy cannot see
use Test2::Plugin::NoWarnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Pod::Coverage::More;

# The fixtures, whose POD disagrees with their subs.
require Mistyped;
require Documented;

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

subtest coverage_report => sub {
    my $report = Pod::Coverage::More->new( package => 'Documented' )->coverage_report;
    my %failures;
    foreach my $name ( keys %$report ) {
        foreach my $check ( grep { $_ ne q{examples} } keys %{ $report->{$name}{failures} } ) {
            push @{ $failures{$name} }, map { "[$check] $_" } @{ $report->{$name}{failures}{$check} };
        }
    }
    is( $failures{good},                         [],                                                                                                                    "POD that says everything passes every check" );
    is( $failures{narrower},                     [],                                                                                                                    "a documented type narrower than the declared one passes" );
    is( $failures{maybe_return},                 [],                                                                                                                    "documented return types that cover every returned type pass" );
    is( $failures{first_of},                     [],                                                                                                                    "an item whose name starts with another argument documents its own argument" );
    is( $failures{woven},                        [],                                                                                                                    "a section under =method passes, and a deeper heading stays part of it" );
    is( $failures{overloaded_double},            [],                                                                                                                    "a documented object passes against the result of an operator, which overloading can make an object" );
    is( $failures{weak_contradicted},            ['[returns] Return type mismatch for weak_contradicted: returns Num (line 217), documented as HashRef'],               "but the result of an operator still fails against a type of another kind" );
    is( $failures{broader},                      ['[argument_types] Type mismatch for arg count of broader: documented Num, but Type::Tiny declares Int'],              "a documented type broader than the declared one fails" );
    is( $failures{contradicted},                 ['[argument_types] Type mismatch for arg list of contradicted: documented HashRef, but the code uses it as ArrayRef'], "a documented type of another kind than the code uses fails" );
    is( $failures{undocumented_return},          ['[returns] No return value documented for undocumented_return'],                                                      "a sub that returns a value must say so" );
    is( $failures{wrong_return},                 ['[returns] Return type mismatch for wrong_return: returns ArrayRef (line 101), documented as HashRef'],               "a returned type that the documented ones do not cover fails" );
    is( $failures{says_nothing},                 ['[returns] says_nothing is documented to return nothing, but it returns a value'],                                    "POD that says it returns nothing must be right" );
    is( $failures{dies_quietly},                 ['[termination] dies_quietly can terminate (die at line 138), but its POD does not say so'],                           "a sub that dies must say so" );
    is( $failures{second_of},                    ['[argument_types] No type declared for arg dog of second_of'],                                                        "an item whose type is not a type has no type, and documents only its own argument" );
    is( $report->{good}{failures}{examples},     [],                                                                                                                    "a verbatim call is an example" );
    is( $report->{narrower}{failures}{examples}, ['No example of narrower in its POD'],                                                                                 "a section with no verbatim call has no example" );
};

subtest coverage_methods => sub {
    my $pc = Pod::Coverage::More->new( package => 'Documented' );
    is( $pc->coverage_termination->{status},                                                      0,                                                                             "coverage_termination fails when one sub fails it" );
    is( $pc->coverage_termination->{message},                                                     "dies_quietly can terminate (die at line 138), but its POD does not say so\n", "and gives each message on a line" );
    is( $pc->coverage_return_types->{status},                                                     0,                                                                             "coverage_return_types reports the returns check" );
    is( $pc->coverage_examples->{status},                                                         0,                                                                             "coverage_examples reports the examples check" );
    is( Pod::Coverage::More->new( package => 'No::Such::Package' )->coverage_arguments->{status}, 0,                                                                             "a package with no POD fails" );
};

done_testing;
