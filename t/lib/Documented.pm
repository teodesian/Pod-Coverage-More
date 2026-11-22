package Documented;

# One sub per case of the checks of Pod::Coverage::More.  t/Pod-Coverage-More.t states the failures of each.

use 5.036;
use warnings FATAL => q{all};

use Types::Standard qw{assert_Int assert_Num};

=head1 FUNCTIONS

=head2 good(count, label)

=over 4

=item count - Int - how many

=item label - Str - what to call them

=back

Returns Str.  Dies when the label is empty.

    my $text = Documented::good( 3, 'apples' );

=cut

sub good {
    my ( $count, $label ) = @_;
    assert_Int($count);
    die "label is empty\n" if $label eq q{};
    return "$label: $count";
}

=head2 narrower(count)

=over 4

=item count - Int - documented narrower than the Num that the code checks

=back

=cut

sub narrower {
    my ($count) = @_;
    assert_Num($count);
    return;
}

=head2 broader(count)

=over 4

=item count - Num - documented broader than the Int that the code checks

=back

=cut

sub broader {
    my ($count) = @_;
    assert_Int($count);
    return;
}

=head2 contradicted(list)

=over 4

=item list - HashRef - documented as a hash reference, used as an array reference

=back

Returns Int.

=cut

sub contradicted {
    my ($list) = @_;
    return scalar @$list;
}

=head2 undocumented_return

Says nothing about what it returns.

=cut

sub undocumented_return {
    return 1;
}

=head2 wrong_return

Returns HashRef.

=cut

sub wrong_return {
    return [];
}

=head2 maybe_return(flag)

=over 4

=item flag - Bool - whether to return the hash reference

=back

Returns HashRef or undef.

=cut

sub maybe_return {
    my ($flag) = @_;
    return $flag ? {} : undef;
}

=head2 says_nothing

Returns nothing.

=cut

sub says_nothing {
    return 1;
}

=head2 dies_quietly

Never mentions how it fails.

=cut

sub dies_quietly {
    die "always\n";
}

=head2 first_of(cat, catalog), second_of(dog)

=over 4

=item catalog - Str - an argument whose name starts with that of another

=item cat - Int - documented after the longer name

=item dog - number of cats, with no type

=back

=cut

sub first_of {
    my ( $cat, $catalog ) = @_;
    return;
}

sub second_of {
    my ($dog) = @_;
    return;
}

=method woven(size)

=over 4

=item size - Int - documented under a command of Pod::Weaver

=back

=head3 Caveats

A deeper heading stays part of the section.

Returns Int.

=cut

sub woven {
    my ($size) = @_;
    return $size;
}

=head2 overloaded_double(x)

=over 4

=item x - Any - a number, or an object of a class that overloads multiplication

=back

Returns a Money object.

=cut

sub overloaded_double {
    my ($x) = @_;
    return $x * 2;
}

=head2 weak_contradicted(x)

=over 4

=item x - Num - the number

=back

Returns HashRef.

=cut

sub weak_contradicted {
    my ($x) = @_;
    return $x + 1;
}

=head2 shouty(%ARGS)

The arguments in upper case, as POD often writes them.

=cut

sub shouty {
    my (%args) = @_;
    return;
}

=head2 flag(x)

=over 4

=item x - Any - anything

=back

Returns Bool.

=cut

sub flag {
    my ($x) = @_;
    return $x ? 1 : 0;
}

=head2 not_flag

Returns Bool.

=cut

sub not_flag {
    return 5;
}

=head2 field_reader(colour)

=over 4

=item colour - Str - a field of the object, which is no argument

=back

Returns the colour.

=cut

sub field_reader {
    my ($self) = @_;
    return $self->{colour};
}

=head2 stub(thing)

A default that a subclass overrides, which ignores its argument.

=cut

sub stub {
    return;
}

=head2 empty_signature(thing)

Its signature says that it takes nothing.

=cut

sub empty_signature () {
    return;
}

1;
