# ABSTRACT: Op tree analysis for perl 5.38 to 5.42
# PODNAME: Pod::Coverage::More::Analyzer::Perl5_38

package Pod::Coverage::More::Analyzer::Perl5_38;

use 5.036;
use warnings FATAL => q{all};

use B ();

use parent 'Pod::Coverage::More::Analyzer::Perl5_36';

=head1 DESCRIPTION

Signatures compile as they do in 5.36, see L<Pod::Coverage::More::Analyzer::Perl5_36>.
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

# A method of the core class feature takes an implicit $self, which argcheck does not count.
sub finish_sub {
    my ( $self, $record ) = @_;
    $self->SUPER::finish_sub($record);
    return if !( $self->{cv}->CvFLAGS & B::CVf_IsMETHOD );
    $record->{method} = 1;
    foreach my $param ( @{ $record->{params} } ) {
        $param->{index}++ if $param->{source} eq q{signature};
    }
    $self->_add_invocant($record);
    return;
}

# Makes parameter 0 of a method its implicit $self.
sub _add_invocant {
    my ( $self, $rec ) = @_;
    my ($invocant) = grep { $_->{index} == 0 && ( $_->{name} // q{} ) eq q{$self} } @{ $rec->{params} };
    if ($invocant) {
        $invocant->{source} = q{invocant};
        return;
    }
    unshift @{ $rec->{params} }, { name => q{$self}, index => 0, source => q{invocant}, slurpy => 0, optional => 0 };
    return;
}

# The assignment of one value to a lexical scalar, whose target is the op's own pad entry.
sub _on_padsv_store {
    my ( $self, $op ) = @_;
    my ($value) = $self->op_kids($op);
    return unless $value;
    $self->_assign_from_args( $value, $self->_padname( $op->targ ) );
    return;
}

# The value of an assignment is the value assigned.
sub _classify_padsv_store {
    my ( $self, $op ) = @_;
    my ($value) = $self->op_kids($op);
    return { type => 'unknown', op => 'padsv_store' } if !$value;
    return $self->classify($value);
}

sub _classify_emptyavhv {
    my ( $self, $op ) = @_;
    return { type => ( $op->private & B::OPpEMPTYAVHV_IS_HV ) ? 'hashref' : 'arrayref' };
}

1;
