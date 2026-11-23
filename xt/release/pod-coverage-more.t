#!perl

=head1 DESCRIPTION

The POD of this dist, as Pod::Weaver writes it from the blurbs, passes the checks of the dist itself.
It runs over the built dist, because only the build has that POD.

=cut

use 5.036;
use warnings FATAL => q{all};

use Test2::V1 -i;    ## no critic (ProhibitUnusedImports) -i imports every tool, which the policy cannot see
use Test2::Plugin::NoWarnings;

use Test::Pod::Coverage::More qw{all_pod_coverage_more_ok};

# In a subtest, which all_pod_coverage_more_ok plans, so that the test of NoWarnings is not in its plan.
subtest 'the POD of every module' => sub {
    all_pod_coverage_more_ok();
};

done_testing;
