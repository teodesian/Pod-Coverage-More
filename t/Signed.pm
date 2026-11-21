package Signed;

# Subs with signatures, which each version set of perl compiles into different ops.
# t/Pod-Coverage-More-Analyzer.t states what Pod::Coverage::More::Analyzer must report for each.

use v5.36;

sub plain ( $x, $y ) {
    return $x + $y;
}

sub defaults ( $x, $y = 5 ) {
    return $x;
}

sub slurpy_array ( $x, @rest ) {
    return scalar(@rest);
}

sub slurpy_hash ( $x, %opts ) {
    return $opts{size};
}

sub placeholder ( $, $y ) {
    return $y;
}

sub empty () {
    return 1;
}

1;
