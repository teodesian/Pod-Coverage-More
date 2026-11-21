# ABSTRACT: Op tree analysis for perl 5.38 to 5.42
# PODNAME: Pod::Coverage::More::Analyzer::v5_38

package Pod::Coverage::More::Analyzer::v5_38;

use strict;
use warnings;

use B ();

use parent 'Pod::Coverage::More::Analyzer::v5_36';

# Op flags are bit fields, so reading them takes bitwise operators.
## no critic (ProhibitBitwiseOperators)

=head1 DESCRIPTION

Signatures compile as they do in 5.36, see L<Pod::Coverage::More::Analyzer::v5_36>.
It adds the C<//=> and C<||=> defaults of signature parameters, which the private flags of C<argdefelem> mark,
and two ops that 5.36 does not have:

=over 4

=item C<padsv_store> - C<my $x = EXPR> in one op, where the target is the op's own pad entry instead of a second kid.
5.38 to 5.42 use it in any context.  5.44 uses it only where the value of the assignment is not used.

=item C<emptyavhv> - an empty C<[]> or C<{}>, with a private flag that says which.

=back

=cut

sub op_handlers {
    my ($self) = @_;
    return {
        %{ $self->SUPER::op_handlers() },
        padsv_store => \&_on_padsv_store,
    };
}

sub op_classifiers {
    my ($self) = @_;
    return {
        %{ $self->SUPER::op_classifiers() },
        padsv_store => \&_classify_padsv_store,
        emptyavhv   => \&_classify_emptyavhv,
    };
}

sub default_mode {
    my ( $self, $argdefelem ) = @_;
    return '//=' if $argdefelem->private & B::OPpARG_IF_UNDEF;
    return '||=' if $argdefelem->private & B::OPpARG_IF_FALSE;
    return '=';
}

# my $x = shift;
sub _on_padsv_store {
    my ( $self, $op ) = @_;
    my ($value) = Pod::Coverage::More::Analyzer::_kids($op);
    return unless $value;
    $self->_assign_from_args( $value, $self->_padname( $op->targ ) );
    return;
}

# return my $x = EXPR;  is the value of EXPR.
sub _classify_padsv_store {
    my ( $self, $op ) = @_;
    my ($value) = Pod::Coverage::More::Analyzer::_kids($op);
    return { type => 'unknown', op => 'padsv_store' } if !$value;
    return $self->classify($value);
}

sub _classify_emptyavhv {
    my ( $self, $op ) = @_;
    return { type => ( $op->private & B::OPpEMPTYAVHV_IS_HV ) ? 'hashref' : 'arrayref' };
}

1;
