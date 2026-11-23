# ABSTRACT: Test that the POD of a module says what each sub takes, returns, and how it fails
# PODNAME: Test::Pod::Coverage::More

package Test::Pod::Coverage::More;

use 5.036;
use warnings FATAL => q{all};

use Exporter qw{import};
use Test::Builder;
use Test::Pod::Coverage ();

use Pod::Coverage::More;

# A test module exports its test functions, as Test::More and Test::Pod::Coverage do.
our @EXPORT = qw{pod_coverage_more_ok all_pod_coverage_more_ok};    ## no critic (Modules::ProhibitAutomaticExportation)

=head1 SYNOPSIS

    use Test::More;
    use Test::Pod::Coverage::More;

    pod_coverage_more_ok( 'Pod::Coverage::More', { checks => [qw{arguments returns termination}] } );

    done_testing;

=head1 DESCRIPTION

Runs the checks of L<Pod::Coverage::More> as tests: one test per module,
which fails with one diagnostic line per thing that the POD does not cover.

=head1 OPTIONS

Each function takes an optional HASHREF of options.  C<checks> is an ARRAYREF of the names of the checks to run,
from THE CHECKS of L<Pod::Coverage::More>, and all of them by default.
Every other option goes to C<new> of L<Pod::Coverage>, such as C<trustme> and C<also_private>.

=head1 FUNCTIONS

=head2 pod_coverage_more_ok(MODULE, OPTIONS, NAME)

Runs one test, named NAME or "POD coverage of MODULE": it passes when the POD documents each public sub of MODULE,
as L<Pod::Coverage> counts, and each sub that it documents passes the checks that OPTIONS names.
A module with no public subs passes, as L<Test::Pod::Coverage> rates it.

=over 4

=item MODULE - Str - the name of the module

=item OPTIONS - HashRef - optional: the options that OPTIONS describes

=item NAME - Str - optional: the name of the test

=back

Returns true when the test passed.

    pod_coverage_more_ok( 'Some::Module', { checks => ['arguments'] }, 'the arguments of Some::Module' );

=cut

our $TEST = Test::Builder->new;

sub pod_coverage_more_ok {
    my ( $module, $options, $name ) = @_;
    my %args   = %{ $options // {} };
    my $checks = delete( $args{checks} ) // \@Pod::Coverage::More::CHECKS;
    $name //= "POD coverage of $module";

    my $pc     = Pod::Coverage::More->new( package => $module, %args );
    my $rating = $pc->coverage;
    my @failures;
    if ( !defined $rating ) {
        my $why = $pc->why_unrated // 'it could not be rated';
        push @failures, "$module: $why" if $why ne 'no public symbols defined';
    }
    elsif ( $rating < 1 ) {
        push @failures, map { "$module: $_ is not documented" } sort $pc->naked;
    }

    my $report = $pc->coverage_report // {};
    foreach my $sub ( sort keys %$report ) {
        foreach my $check (@$checks) {
            push @failures, map { "$module: $_" } @{ $report->{$sub}{failures}{$check} || [] };
        }
    }

    my $ok = $TEST->ok( !@failures, $name );
    foreach my $failure (@failures) {
        $TEST->diag($failure);
    }
    return $ok;
}

=head2 all_pod_coverage_more_ok(OPTIONS)

Runs C<pod_coverage_more_ok> for each module under F<blib>, or else under F<lib>, as L<Test::Pod::Coverage> finds them,
and plans that many tests when nothing planned them yet.

=over 4

=item OPTIONS - HashRef - optional: the options that OPTIONS describes, for every module

=back

Returns true when every test passed.

    all_pod_coverage_more_ok( { checks => [ 'arguments', 'returns' ] } );

=cut

sub all_pod_coverage_more_ok {
    my ($options) = @_;
    my @modules = Test::Pod::Coverage::all_modules();
    $TEST->plan( tests => scalar @modules ) if !$TEST->has_plan;
    my $ok = 1;
    foreach my $module (@modules) {
        $ok = 0 if !pod_coverage_more_ok( $module, $options );
    }
    return $ok;
}

1;

=head1 SEE ALSO

L<Pod::Coverage::More>

L<Test::Pod::Coverage>

=cut
