# ABSTRACT: The Type::Tiny constraints that the evidence of an analysis amounts to
# PODNAME: Pod::Coverage::More::Types

package Pod::Coverage::More::Types;

use 5.036;
use warnings FATAL => q{all};
use re q{/xsaa};

use Exporter qw{import};
use Type::Registry;
use Type::Tiny::Intersection;
use Type::Tiny::Union;
use Types::Standard qw{Any ArrayRef Bool CodeRef GlobRef HasMethods HashRef InstanceOf Int Num Object Ref ScalarRef Str Undef};

our @EXPORT_OK = qw{type_of_value type_of_usage type_named};

=head1 SYNOPSIS

    use Pod::Coverage::More::Types qw{type_of_value type_of_usage type_named};

    my $returned = type_of_value( { type => 'object', class => 'Some::Class' } );    # InstanceOf["Some::Class"]
    my $used     = type_of_usage( { hashref => 1, methods => ['render'] } );        # HashRef&HasMethods["render"]
    my $named    = type_named('ArrayRef[Int]');

=head1 DESCRIPTION

L<Pod::Coverage::More::Analyzer> records evidence about values: what a sub returns, and how it uses each variable.
This module states that evidence as L<Type::Tiny> constraints, so that the types that the code shows,
the types that a class builder or a signature declares, and the types that the POD names can be compared as types.

Each function returns undef when the evidence says nothing about the type.

=head1 FUNCTIONS

=head2 type_of_value(EVIDENCE)

Returns the constraint that a value satisfies, from one HASHREF of evidence that C<classify> of L<Pod::Coverage::More::Analyzer> returns.
A number whose evidence has a true C<integer>, such as the count of an array, is an C<Int>.

=cut

sub type_of_value {
    my ($evidence) = @_;
    my $type = $evidence->{type};

    if ( $type eq 'number' ) {
        my $value = $evidence->{value};
        return Int if $evidence->{integer};
        return ( defined $value && $value =~ m/\A-?\d+\z/ ) ? Int : Num;
    }
    return Str  if $type eq 'string';
    return Bool if $type eq 'boolean' || $type eq 'context';

    # An empty return gives undef to a caller that wants one value.
    return Undef if $type eq 'undef' || $type eq 'empty';

    return HashRef  if $type eq 'hashref';
    return ArrayRef if $type eq 'arrayref';
    return CodeRef  if $type eq 'coderef';
    return Ref      if $type eq 'ref';
    if ( $type eq 'object' ) {
        return defined $evidence->{class} ? InstanceOf [ $evidence->{class} ] : Object;
    }
    return;
}

=head2 type_of_usage(USAGE)

Returns the constraint that a variable must satisfy for the uses that the HASHREF USAGE records,
as C<analyze_sub> of L<Pod::Coverage::More::Analyzer> reports them.

Each kind of reference, and use as a number or as a string, is one alternative,
because different branches of a sub can use one variable in different ways.
The methods called on the variable apply to all of them.

=cut

sub type_of_usage {
    my ($usage) = @_;
    my @alternatives;
    push @alternatives, HashRef  if $usage->{hashref};
    push @alternatives, ArrayRef if $usage->{arrayref};
    push @alternatives, CodeRef  if $usage->{coderef};

    # Perl makes a string of a number, so a variable used as both is a string.
    if    ( $usage->{string} )  { push @alternatives, Str }
    elsif ( $usage->{numeric} ) { push @alternatives, Num }

    my $type;
    $type = $alternatives[0]                                             if @alternatives == 1;
    $type = Type::Tiny::Union->new( type_constraints => \@alternatives ) if @alternatives > 1;

    my @methods = @{ $usage->{methods} || [] };
    return $type if !@methods;
    my $duck = HasMethods [@methods];
    return $duck if !$type;
    return Type::Tiny::Intersection->new( type_constraints => [ $type, $duck ] );
}

# The type words of the POD that Pod::Coverage::More has always read, in lower case.
our %POD_WORDS = (
    scalar      => Any,
    mixed       => Any,
    string      => Str,
    integer     => Int,
    float       => Num,
    boolean     => Bool,
    object      => Object,
    scalarref   => ScalarRef,
    arrayref    => ArrayRef,
    hashref     => HashRef,
    coderef     => CodeRef,
    typeglobref => GlobRef,
    array       => ArrayRef,
    hash        => HashRef,
);

=head2 type_named(NAME)

Returns the constraint that NAME names.  NAME is either a type word of the POD that L<Pod::Coverage::More> reads,
in any case, such as C<HASHREF> or C<integer>, or a type expression of L<Types::Standard>, such as C<ArrayRef[Int]>.
A word for a container, C<ARRAY> or C<HASH>, names a reference to one.

=cut

sub type_named {
    my ($name) = @_;
    return if !defined $name;
    my $word = $POD_WORDS{ lc $name };
    return $word if $word;

    my $registry = Type::Registry->for_class(__PACKAGE__);
    $registry->add_types('Types::Standard') if !$registry->simple_lookup('Str');
    my $type = eval { $registry->lookup($name) };
    return $type;
}

1;

=head1 SEE ALSO

L<Type::Tiny>

L<Types::Standard>

=cut
