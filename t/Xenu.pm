package Xenu;

use strict;
use warnings;

=head1 DESCRIPTION

Module for testing out Pod::Coverage::More

=head1 FUNCTIONS

=head2 testSignature(dog,cat)

Test that names in sigs under strategy 1 are successfully found.

=over 4

=item dog - string: name of dog

=item cat - integer: number of cats needed to screw in lightbulb

=back

=head2 testCaseInsensitivitySigs(DOG,CAT,GOAT,pig,llama,alpaca,chicken,rabbit,snake,horse,farmer)

Test that names in signatures are lc'd, and that the types are correct using method 1.

=over 4

=item DOG - SCALAR

=item CAT - SCALARREF

=item GOAT - ARRAYREF

=item PIG - hashref

=item llama - coderef

=item alpaca - typeglobref

=item chicken - INTEGER

=item rabbit - BOOLEAN

=item snake - FLOAT

=item horse - OBJECT

=item farmer - STRING

=back

=head2 testArraySigs1(input)

=over 4

=item INPUT (array) - list it out

=back

=head2 testHashSigs1(input)

=over 4

=item INPUT (HASH) - get baked

=back

=head2 testScalarSigs($dog,\$human,\@cat,\%cow,\&chupacabra,\*xenomorph)

=head2 testArraySigs(@input)

=head2 testHashSigs(%input)

Test that the names in signatures are correctly searched for, and that the types are correct using method 2.

=cut

sub testSignature {
    my ($dog,$cat) = @_;
}

sub testScalarSigs {
    my ($dog,$human,$cat,$cow,$chupacabra,$xenomorph) = @_;
}

sub testArraySigs {
    my @input = @_;
}

sub testHashSigs {
    my %input = shift;
}

#Functions can't be passed directly to functions
#Neither can typeglobs.

sub testCaseInsensitivitySigs {
    my ($dog,$cat,$goat,$pig,$llama,$alpaca,$chicken,$rabbit,$snake,$horse,$farmer) = @_;
}

sub testArraySigs1 {
    my @input = @_;
}

sub testHashSigs1 {
    my %input = @_;
}

1;
