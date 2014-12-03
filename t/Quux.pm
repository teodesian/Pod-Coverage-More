package Quux;

use strict;
use warnings;

=head1 SYNOPSIS

Module for testing out Pod::Coverage::More

=head1 FUNCTIONS

=head2 someFunction

Test function with no args

=cut

sub someFunction {
    return "HOO HAA";
}

=head2 some_other_function(arg,arg2)

Test function with underscores

=cut

sub some_other_function {
    my ($arg,$arg2) = @_;
}

=head2 someFunctionWithArgs(nugs,gravy,milk)

Test arg'd function

=cut

sub someFunctionWithArgs {
    my ($nugs,$gravy,$milk) = @_;
    print "$nugs, $gravy, $milk\n";
}

=head2 fun1(arg0,arg1),fun2(arg2,arg3)

Test multiple arg'd functions

=cut

sub fun1 {
    my ($arg0,$arg1) = @_;
}
sub fun2 {
    my ($arg2,$arg3) = @_;
}

=head2 fun3(arg1,arg2),fun4,fun5(arg)

Test mixed arg/no arg

=cut

sub fun3 {
    my ($arg1,$arg2) = @_;
}
sub fun4 {}
sub fun5 {
    my $arg = shift;
}

=head2 Quux::fullyQualifiedFunction(arg)

Test fully qualified names

=cut

sub fullyQualifiedFunction {
    my $arg = shift;
}


=head2 B<formattedFunction>,B<formattedFunctionWithArgs (foo,bar)>,B<Quux::qualifiedFormattedFunction(arg)>

Test POD formatting

=cut

sub formattedFunction {}
sub formattedFunctionWithArgs {
    my ($foo,$bar) = @_;
}
sub qualifiedFormattedFunction {
    my $arg = shift;
}

=head2 tidiedFunction ( arg1 , arg2 )

Test whitespace oddities

=cut

sub tidiedFunction {
    my ($arg1,$arg2) = @_;
}

=head2 $qx->someMethod(arr)

Test lines that are dressed up as method calls

=cut

sub someMethod {
    my $arr = shift;
}

=head2 semiColon;,semiColonWithArgs(whee,zap)

Test lines with semicolons

=cut

sub semiColon {}
sub semiColonWithArgs {
    my ($whee,$zap) = @_;
}

=head2 wsSep wsSep2(whee, zap, tickle) wsSep3(poo) wsSep4( goo, quux ) wsSep5

Test separating functions by space.

=cut

sub wsSep {}
sub wsSep2{
    my ($whee,$zap,$tickle) = @_;
}
sub wsSep3{
    my $poo = $_;
}
sub wsSep4{
    my ($goo,$quux) = @_;
}
sub wsSep5{}

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

__END__


