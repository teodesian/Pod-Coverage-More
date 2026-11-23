# ABSTRACT: Declarations of the signatures of Kavorka
# PODNAME: Pod::Coverage::More::Declared::Kavorka

package Pod::Coverage::More::Declared::Kavorka;

use 5.036;
use warnings FATAL => q{all};

use Package::Stash;

=head1 DESCRIPTION

Reads the signature of each sub that a keyword of L<Kavorka> made, through C<< Kavorka->info >>:
the invocants, the positional and the named parameters, which are optional, and the type of each.

=head1 METHODS

=cut

# Whether L<Kavorka> is loaded, so that it can have declared subs of C<package>.
# @param   package  Str  the name of the package
# @returns Bool
# @example next if !Pod::Coverage::More::Declared::Kavorka->applies_to('Some::Class');
sub applies_to {
    return $INC{'Kavorka.pm'} ? 1 : 0;
}

# The declarations of the subs of C<package> that C<names> lists, as L<Pod::Coverage::More::Declared> describes them.
# @param   package  Str            the name of the package
# @param   names    ArrayRef[Str]  the names of the subs
# @returns HashRef  from the name of each declared sub to its declaration
# @example my $declared = Pod::Coverage::More::Declared::Kavorka->declarations( 'Some::Class', ['new'] );
sub declarations {
    my ( $class, $package, $names ) = @_;
    my $stash = Package::Stash->new($package);
    my %declared;
    foreach my $name (@$names) {
        my $info  = Kavorka->info( $stash->get_symbol("&$name") ) or next;
        my $index = 0;
        my @params;
        foreach my $param ( @{ $info->signature->params } ) {
            my %where = $param->named ? ( named => $param->named_names->[0] ) : ( index => $index++ );
            push @params, {
                name     => $param->name,
                type     => $param->type,
                optional => $param->optional ? 1 : 0,
                invocant => $param->invocant ? 1 : 0,
                %where,
            };
        }
        $declared{$name} = {
            via     => 'Kavorka',
            role    => $info->keyword eq 'method' ? 'method' : 'function',
            params  => \@params,
            returns => [],
        };
    }
    return \%declared;
}

1;
