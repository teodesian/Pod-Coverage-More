# ABSTRACT: Declarations of the signatures of Function::Parameters
# PODNAME: Pod::Coverage::More::Declared::FunctionParameters

package Pod::Coverage::More::Declared::FunctionParameters;

use 5.036;
use warnings FATAL => q{all};

use Package::Stash;

=head1 DESCRIPTION

Reads the signature of each sub that a keyword of L<Function::Parameters> made, through C<Function::Parameters::info>:
the invocants, the positional and the named parameters, which are optional, and the type of each.

=head1 METHODS

=head2 applies_to(PACKAGE)

Returns true when Function::Parameters is loaded.

=cut

sub applies_to {
    return $INC{'Function/Parameters.pm'} ? 1 : 0;
}

=head2 declarations(PACKAGE, NAMES)

Returns the declarations of the subs of PACKAGE that the ARRAYREF NAMES lists, as L<Pod::Coverage::More::Declared> describes them.

=cut

sub declarations {
    my ( $class, $package, $names ) = @_;
    my $stash = Package::Stash->new($package);
    my %declared;
    foreach my $name (@$names) {
        my $info  = Function::Parameters::info( $stash->get_symbol("&$name") ) or next;
        my $index = 0;
        my @params;
        my @positional = ( [ [ $info->invocants ], { invocant => 1 } ], [ [ $info->positional_required ], {} ], [ [ $info->positional_optional ], { optional => 1 } ] );
        foreach my $group (@positional) {
            my ( $list, $extra ) = @$group;
            foreach my $param (@$list) {
                push @params, _param( $param, index => $index++, %$extra );
            }
        }
        my @named = ( [ [ $info->named_required ], {} ], [ [ $info->named_optional ], { optional => 1 } ] );
        foreach my $group (@named) {
            my ( $list, $extra ) = @$group;
            foreach my $param (@$list) {
                push @params, _param( $param, named => _key($param), %$extra );
            }
        }
        push @params, _param( $info->slurpy, index => $index, optional => 1 ) if $info->slurpy;
        $declared{$name} = {
            via     => 'Function::Parameters',
            role    => $info->keyword eq 'method' ? 'method' : 'function',
            params  => \@params,
            returns => [],
        };
    }
    return \%declared;
}

sub _param {
    my ( $param, %where ) = @_;
    return { name => $param->name, type => $param->type, optional => 0, invocant => 0, %where };
}

# The key of a named parameter is its name without the sigil.
sub _key {
    my ($param) = @_;
    return substr( $param->name, 1 );
}

1;
