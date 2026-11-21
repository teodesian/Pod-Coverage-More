package Analyzed;

# Subs written in the idioms that Pod::Coverage::More::Analyzer must read without a signature.
# Each sub exercises one idiom; t/Pod-Coverage-More-Analyzer.t states what the analyzer must report for it.

use strict;
use warnings;

use Carp qw{croak};
use Scalar::Util qw{blessed};

use constant LIMIT => 5;
use constant GREETING => 'hello';

sub shifted {
    my $self = shift;
    my $name = shift;
    return $name;
}

sub listed {
    my ( $self, $first, @rest ) = @_;
    return scalar(@rest);
}

sub named {
    my $self = shift;
    my %opts = @_;
    return $opts{size} + $opts{count} if exists $opts{verbose};
    return $self->frob( $opts{name} );
}

sub hashref_arg {
    my ( $self, $args ) = @_;
    return $args->{alpha}[0];
}

sub elements {
    return $_[0] + $_[1];
}

sub shift_method {
    return shift->frob;
}

sub uses {
    my ( $num, $str, $code, $obj ) = @_;
    my $total = $num + 1;
    my $label = $str . 'x';
    $code->($total);
    $obj->render($label);
    return;
}

sub anon_inside {
    my $x = shift;
    my $f = sub { return shift };
    return $f->($x);
}

sub constructor {
    my ( $class, %args ) = @_;
    return bless {%args}, ref($class) || $class;
}

sub fixed_class {
    return bless( [], 'Some::Class' );
}

sub one_arg_bless {
    return bless {};
}

sub branches {
    my ($x) = @_;
    if ($x) {
        return 1;
    }
    else {
        return 'no';
    }
}

sub ternary {
    my ($x) = @_;
    return $x ? [] : undef;
}

sub empty_hashref {
    return {};
}

sub fall_through {
    my ($x) = @_;
    if ($x) {
        'yes';
    }
    else {
        { a => 1 };
    }
}

sub bare_return {
    return;
}

sub listy {
    return ( 1, 2, 3 );
}

sub context {
    return wantarray ? (1) : 0;
}

sub calls {
    return listed(@_);
}

sub dies {
    my ($x) = @_;
    die "bad" unless $x;
    croak("worse") if $x < 0;
    eval { die "caught" };
    return 1;
}

{
    no warnings 'once';
    *generated = sub { my ($q) = @_; return [$q] };
}

# Built the way Moo builds its accessors: from a string, with no source file.
eval 'sub evaled { my ($self, $value) = @_; return $value }; 1' or die $@;

1;
