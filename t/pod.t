use strict;
use warnings;

use Scalar::Util qw{reftype};
use Test::More;
use Test::Pod 'tests' => 14;
use Test::Pod::Coverage;
use Pod::Coverage::More;

#TODO findbin to get into t/

use Quux;
use Xenu;

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
ok($res->{'status'},"Got correct arg coverage for test module Quux");
is($res->{'message'}, undef, "No message provided when everything is OK");

note "Verify arg type coverage is adequate";
$res = $pc->coverage_argument_types();
is(reftype($res),'HASH',"Coverage arguments types returns hashref");
ok($res->{'status'},"Got correct arg type coverage for test module Quux");
is($res->{'message'}, undef, "No message provided when everything is OK");

