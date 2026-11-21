use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";

use Scalar::Util qw{reftype};
use Test::More;
use Test::Pod 'tests' => 17;
use Test::Pod::Coverage;
use Pod::Coverage::More;

use Quux;
use Xenu;
use Ret;

#Make sure parent is still sane
my @pobjfiles = map { $INC{$_} } ('Quux.pm');
foreach my $pm (@pobjfiles) {
    pod_file_ok($pm);
}

my @modules = ('Quux', 'Xenu');
foreach my $mod (@modules) {
    note "Verify base Pod::Coverage OK";
    pod_coverage_ok($mod);
    note "Verify Pod::Coverage functionality in Pod::Coverage::More works";
    pod_coverage_ok($mod, { coverage_class => 'Pod::Coverage::More' });
}

note "Verify arg coverage is adequate";
my $pc = Pod::Coverage::More->new(package => 'Quux');
my $res = $pc->coverage_arguments();
is(reftype($res),'HASH',"Coverage arguments returns hashref");
ok($res->{'status'},"Got correct arg coverage for test module Quux");
is($res->{'message'}, undef, "No message provided when everything is OK");

$pc = Pod::Coverage::More->new(package => 'Xenu');
$res = $pc->coverage_arguments();
is(reftype($res),'HASH',"Coverage arguments returns hashref");
ok($res->{'status'},"Got correct arg coverage for test module Xenu");
is($res->{'message'}, undef, "No message provided when everything is OK");

note "Verify arg type coverage is adequate";
my ($caseGroup) = grep { grep { $_ eq q{testCaseInsensitivitySigs} } @{ $_->{all} } }
    @{ $pc->_get_more_pods->{function_maps} };
my %xenuTypes = %{ $caseGroup->{arglist} };
is($xenuTypes{cat}, q{scalarref}, "A SCALARREF item is not read as SCALAR");
is($xenuTypes{goat}, q{arrayref}, "An ARRAYREF item is not read as ARRAY");
is($xenuTypes{pig}, q{hashref}, "A hashref item is not read as HASH");
$res = $pc->coverage_argument_types();
is(reftype($res),'HASH',"Coverage arguments types returns hashref");
ok($res->{'status'},"Got correct arg type coverage for test module Xenu");
is($res->{'message'}, undef, "No message provided when everything is OK");

note "Verify return type coverage is adequate";
$pc = Pod::Coverage::More->new(package => 'Ret');
$res = $pc->coverage_return_types();
#diag explain $res;
