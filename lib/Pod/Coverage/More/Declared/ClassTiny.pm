# ABSTRACT: Declarations of the attributes of Class::Tiny classes
# PODNAME: Pod::Coverage::More::Declared::ClassTiny

package Pod::Coverage::More::Declared::ClassTiny;

use 5.036;
use warnings FATAL => q{all};

use Pod::Coverage::More::Declared;

use Types::Standard qw{InstanceOf};

=head1 DESCRIPTION

Reads the attributes of a class that L<Class::Tiny> built.
Each attribute declares an accessor and an optional named parameter of the constructor C<new>.
Class::Tiny has no types and no required attributes, so these declarations have neither.

=head1 METHODS

=cut

# Whether L<Class::Tiny> built C<package>.
# @param   package  Str  the name of the package
# @returns Bool
# @example next if !Pod::Coverage::More::Declared::ClassTiny->applies_to('Some::Class');
sub applies_to {
    my ( $class, $package ) = @_;
    return ( $INC{'Class/Tiny.pm'} && $package->isa('Class::Tiny::Object') ) ? 1 : 0;
}

# The declarations of the subs of C<package> that C<names> lists, as L<Pod::Coverage::More::Declared> describes them.
# @param   package  Str            the name of the package
# @param   names    ArrayRef[Str]  the names of the subs
# @returns HashRef  from the name of each declared sub to its declaration
# @example my $declared = Pod::Coverage::More::Declared::ClassTiny->declarations( 'Some::Class', ['new'] );
sub declarations {
    my ( $class, $package, $names ) = @_;
    my %own        = map { $_ => 1 } @$names;
    my @attributes = Class::Tiny->get_all_attributes_for($package);
    my %declared;

    foreach my $attribute (@attributes) {
        next if !$own{$attribute};
        $declared{$attribute} = {
            via       => 'Class::Tiny',
            role      => 'accessor',
            attribute => $attribute,
            params    => [
                Pod::Coverage::More::Declared->invocant,
                { name => undef, index => 1, type => undef, optional => 1, invocant => 0 },
            ],
            returns => [],
        };
    }
    if ( $own{new} ) {
        $declared{new} = {
            via    => 'Class::Tiny',
            role   => 'constructor',
            params => [
                Pod::Coverage::More::Declared->invocant,
                map { { name => undef, named => $_, type => undef, optional => 1, invocant => 0 } } @attributes,
            ],
            returns => [ InstanceOf [$package] ],
        };
    }
    return \%declared;
}

1;
