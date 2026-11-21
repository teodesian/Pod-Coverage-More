# ABSTRACT: Op tree analysis for perl 5.36
# PODNAME: Pod::Coverage::More::Analyzer::v5_36

package Pod::Coverage::More::Analyzer::v5_36;

use strict;
use warnings;

use parent 'Pod::Coverage::More::Analyzer';

=head1 DESCRIPTION

Adds the ops that this version set compiles signatures into:
one C<argcheck> op with the counts of parameters,
then one C<argelem> op per named parameter, with an C<argdefelem> kid when it has a default.

See C<deparse_argops> in the L<B::Deparse> of these perls for the reference reading of these ops.

5.38 to 5.42 compile signatures the same way, so L<Pod::Coverage::More::Analyzer::v5_38> inherits this.
In 5.36, C<my $x = EXPR> is always an C<sassign> op, which the base class reads.

=cut

sub op_handlers {
    my ($self) = @_;
    return {
        %{ $self->SUPER::op_handlers() },
        argcheck => \&_on_argcheck,
        argelem  => \&_on_argelem,
    };
}

# A placeholder parameter ($ or $=) has no argelem op, so only argcheck's count shows it.
sub finish_sub {
    my ( $self, $rec ) = @_;
    my $signature = $self->{signature} or return;
    my %seen      = map { $_->{index} => 1 } @{ $rec->{params} };
    foreach my $index ( 0 .. $signature->{params} - 1 ) {
        next if $seen{$index};
        $self->_add_param(
            name     => undef,
            index    => $index,
            source   => 'signature',
            optional => ( $index >= $signature->{mandatory} ) ? 1 : 0,
        );
    }
    return;
}

sub _on_argcheck {
    my ( $self, $op ) = @_;
    my ( $params, $optional, $slurpy ) = $op->aux_list( $self->{cv} );
    $self->{signature} = { params => $params, mandatory => $params - $optional, slurpy => $slurpy };
    return;
}

sub _on_argelem {
    my ( $self, $op ) = @_;
    my $index = $op->string( $self->{cv} );
    my $name  = $self->_padname( $op->targ );
    my %param = (
        name     => $name,
        index    => $index,
        source   => 'signature',
        optional => ( $index >= ( $self->{signature}{mandatory} // 0 ) ) ? 1 : 0,
    );

    my ($default) = Pod::Coverage::More::Analyzer::_kids($op);
    if ( $default && $default->name eq 'argdefelem' ) {
        $param{default} = { mode => $self->default_mode($default), value => [ $self->classify( $default->first ) ] };
    }
    $self->_add_param(%param);
    return;
}

=head2 default_mode(ARGDEFELEM)

Returns how the default of a signature parameter applies, from its C<argdefelem> op.
5.36 has only C<=>, a default for a missing argument.

=cut

sub default_mode {
    return '=';
}

1;
