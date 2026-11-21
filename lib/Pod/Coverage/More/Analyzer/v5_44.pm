# ABSTRACT: Op tree analysis for perl 5.44 and later
# PODNAME: Pod::Coverage::More::Analyzer::v5_44

package Pod::Coverage::More::Analyzer::v5_44;

use strict;
use warnings;

use B ();

use parent 'Pod::Coverage::More::Analyzer::v5_38';

=head1 DESCRIPTION

Keeps the ops of L<Pod::Coverage::More::Analyzer::v5_38>, and replaces the ops that signatures compile into.
This version set compiles a signature into
one C<multiparam> op that lists every parameter,
then one C<paramtest> op, with a C<paramstore> kid, per parameter that has a default.

See C<deparse_multiparam> in the L<B::Deparse> of these perls for the reference reading of these ops.

=cut

sub op_handlers {
    my ($self) = @_;
    my %handlers = %{ $self->SUPER::op_handlers() };
    delete @handlers{qw{argcheck argelem}};
    return {
        %handlers,
        multiparam => \&_on_multiparam,
        paramtest  => \&_on_paramtest,
    };
}

# The placeholders that v5_36 fills in from argcheck are listed in multiparam itself.
sub finish_sub {
    return;
}

sub _on_multiparam {
    my ( $self, $op ) = @_;
    my ( $min, $max, $slurpy, @rest ) = $op->aux_list( $self->{cv} );
    my @padix = splice( @rest, 0, $max );
    my ($slurpy_padix) = @rest;

    foreach my $index ( 0 .. $#padix ) {
        $self->_add_param(
            name     => $self->_padname( $padix[$index] ),
            index    => $index,
            source   => 'signature',
            optional => ( $index >= $min ) ? 1 : 0,
        );
    }
    if ($slurpy) {
        $self->_add_param(
            name     => $self->_padname($slurpy_padix),
            index    => $max,
            source   => 'signature',
            slurpy   => 1,
            optional => 1,
        );
    }
    return;
}

# The default of the parameter whose pad entry is the op's own.
sub _on_paramtest {
    my ( $self, $op ) = @_;
    my ($store) = Pod::Coverage::More::Analyzer::_kids($op);
    return unless $store && $store->name eq 'paramstore';

    my $mode = '=';
    $mode = '//=' if $op->private == B::OPpPARAM_IF_UNDEF;
    $mode = '||=' if $op->private == B::OPpPARAM_IF_FALSE;

    my ($expr) = Pod::Coverage::More::Analyzer::_kids($store);
    my $default = { mode => $mode, value => ( $expr && $expr->name ne 'stub' ) ? [ $self->classify($expr) ] : [] };

    my $name = $self->_padname( $op->targ );
    foreach my $param ( @{ $self->{rec}{params} } ) {
        $param->{default} = $default if defined $param->{name} && defined $name && $param->{name} eq $name;
    }
    return;
}

1;
