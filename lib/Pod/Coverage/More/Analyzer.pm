# ABSTRACT: Infer arguments, return values and termination of subs from their compiled op trees
# PODNAME: Pod::Coverage::More::Analyzer

package Pod::Coverage::More::Analyzer;

use 5.036;
use warnings FATAL => 'all';

use B          ();
use List::Util qw{any};

# The pad and SV helpers return an explicit undef because their callers put them in hash constructors,
# where a bare return would give an empty list and shift every pair after it.

=head1 SYNOPSIS

    use Pod::Coverage::More::Analyzer;

    my $analyzer = Pod::Coverage::More::Analyzer->new();
    my $subs     = $analyzer->analyze_package('Pod::Coverage::More::Analyzer');
    my @params   = map { $_->{name} } @{ $subs->{analyze_sub}{params} };

=head1 DESCRIPTION

Reads the op tree that perl compiled for each sub of a package, by way of L<B>.
This sees the same program that perl runs, so it also covers subs that have no source of their own,
such as closures assigned to globs, constants and accessors that were built with a string eval.

The op tree changes between perl versions.
C<new> returns an object of the subclass for the running perl,
and each subclass adds handlers for the ops of its version set.
This class handles the ops that all supported versions share.
L<B::Deparse> is the reference for how each op of each perl version is meant to be read.

The analysis is best effort.
It reports what the op tree shows, and it marks what it cannot resolve with the type C<unknown>.

=head1 SUPPORTED PERLS

5.36 and later releases.
Development perls (odd minor versions, such as 5.43.x) are not supported:
their ops can change from one development release to the next.

=over 4

=item 5.36 - L<Pod::Coverage::More::Analyzer::Perl5_36>

=item 5.38 to 5.42 - L<Pod::Coverage::More::Analyzer::Perl5_38>

=item 5.44 and later - L<Pod::Coverage::More::Analyzer::Perl5_44>

=back

Each version set inherits from the one before it, and adds or replaces the handlers for the ops that changed.

=cut

# Lowest perl version of each version set, highest first.
our @BACKENDS = (
    [ 5.044 => 'Pod::Coverage::More::Analyzer::Perl5_44' ],
    [ 5.038 => 'Pod::Coverage::More::Analyzer::Perl5_38' ],
    [ 5.036 => 'Pod::Coverage::More::Analyzer::Perl5_36' ],
);

# The ops whose names say what kind of value they read or produce.
our %NUMERIC_OPS = map { $_ => 1 } qw{
  add subtract multiply divide modulo pow negate abs int sqrt
  lt gt le ge eq ne ncmp preinc predec postinc postdec
  i_add i_subtract i_multiply i_divide i_modulo i_negate
  i_lt i_gt i_le i_ge i_eq i_ne i_ncmp i_preinc i_predec i_postinc i_postdec
};
our %STRING_OPS = map { $_ => 1 } qw{
  concat multiconcat seq sne slt sgt sle sge scmp
  lc uc lcfirst ucfirst length substr index rindex match subst split
};
our %TERMINATORS = map { $_ => 1 } qw{
  CORE::GLOBAL::die CORE::GLOBAL::exit
  Carp::croak Carp::confess Carp::cluck
};
our %BOOLEAN_OPS = map { $_ => 1 } qw{
  not defined exists
  lt gt le ge eq ne i_lt i_gt i_le i_ge i_eq i_ne
  slt sgt sle sge seq sne
};
our %NUMBER_OPS = map { $_ => 1 } qw{
  add subtract multiply divide modulo pow negate abs int sqrt ncmp scmp
  i_add i_subtract i_multiply i_divide i_modulo i_negate i_ncmp
  length index rindex time
};
our %STRING_RESULT_OPS = map { $_ => 1 } qw{
  concat multiconcat stringify join sprintf lc uc lcfirst ucfirst substr ref
};
our %LIST_OPS            = map { $_ => 1 } qw{ sort grepwhile mapwhile keys values reverse split };
our $HELEM               = B::opnumber(q{helem});
our @HASH_MDEREF_ACTIONS = (
    B::MDEREF_HV_pop_rv2hv_helem(),          B::MDEREF_HV_gvsv_vivify_rv2hv_helem(),
    B::MDEREF_HV_padsv_vivify_rv2hv_helem(), B::MDEREF_HV_vivify_rv2hv_helem(),
    B::MDEREF_HV_padhv_helem(),              B::MDEREF_HV_gvhv_helem(),
);

=head1 METHODS

=head2 new

Returns an analyzer object of the subclass that handles the running perl.

Dies when the running perl is older than the oldest supported version set.

=cut

sub new {
    my ($class) = @_;
    my $backend = $class eq __PACKAGE__ ? backend_for($]) : $class;
    if ( $backend ne $class ) {
        ( my $file = "$backend.pm" ) =~ s{::}{/}gxsaa;
        require $file;
    }
    return bless( {}, $backend );
}

=head2 backend_for(VERSION)

Returns the name of the subclass that handles the perl VERSION, given in the numeric form of C<$]>.

Dies when no subclass handles VERSION.

=cut

sub backend_for {
    my ($version) = @_;
    foreach my $backend (@BACKENDS) {
        return $backend->[1] if $version >= $backend->[0];
    }
    die "Perl $version is not supported, the oldest supported perl is $BACKENDS[-1][0]\n";
}

=head2 analyze_package(PACKAGE)

Returns a HASHREF that maps the name of each sub defined in PACKAGE to the record that C<analyze_sub> returns.
PACKAGE must already be loaded.

Subs that PACKAGE imported from another package are left out.

=cut

sub analyze_package {
    my ( $self, $package ) = @_;

    my %subs;

    # The symbol table of a package named at run time.
    no strict 'refs';
    foreach my $name ( sort keys %{"${package}::"} ) {
        next if $name =~ m/::\z/xsaa;
        next unless defined &{"${package}::$name"};
        my $code = \&{"${package}::$name"};

        my $cv = B::svref_2object($code);
        next if _defined_in($cv) ne $package;

        $subs{$name} = $self->analyze_sub( $code, $name, $package );
    }
    return \%subs;
}

=head2 analyze_sub(CODEREF, NAME, PACKAGE)

Returns a HASHREF with what the op tree of CODEREF shows:

=over 4

=item B<name>, B<package> - STRING - NAME and PACKAGE as given

=item B<kind> - STRING - C<perl>, C<xs> or C<constant>

=item B<value> - SCALAR - the value of a constant

=item B<file>, B<line> - STRING, INTEGER - where the body starts

=item B<generated> - BOOLEAN - true when the sub has no source file of its own, or it was installed under a different name

=item B<params> - ARRAYREF - one HASHREF per parameter, in order: C<name> (undef when it has none), C<index>, C<source> (C<shift>, C<list>, C<element> or C<signature>), C<slurpy>, C<optional>, C<default> and C<keys>

=item B<usage> - HASHREF - per lexical variable, how the body uses it: C<hashref>, C<arrayref>, C<coderef>, C<numeric>, C<string>, C<methods> and C<keys>

=item B<returns> - ARRAYREF - one HASHREF per value the sub can return, with C<type>, C<line> and C<implicit>, plus details per type

=item B<dies> - ARRAYREF - one HASHREF per explicit termination, with C<via>, C<line> and C<caught>

=back

=cut

sub analyze_sub {
    my ( $self, $code, $name, $package ) = @_;

    my $cv  = B::svref_2object($code);
    my %rec = (
        name      => $name,
        package   => $package,
        file      => $cv->FILE,
        generated => ( $cv->GV->NAME ne $name || $cv->FILE =~ m/\A\(eval/xsaa ) ? 1 : 0,
        params    => [],
        usage     => {},
        returns   => [],
        dies      => [],
    );

    if ( $cv->CvFLAGS & B::CVf_CONST ) {
        $rec{kind}  = 'constant';
        $rec{value} = $code->();
        push @{ $rec{returns} }, _sv_evidence( B::svref_2object( \$rec{value} ) );
        return \%rec;
    }
    if ( $cv->XSUB ) {
        $rec{kind} = 'xs';
        return \%rec;
    }
    $rec{kind} = 'perl';

    # The state of one walk lives on a copy of the analyzer, which shares its caches.
    $self->{handlers}    //= $self->op_handlers;
    $self->{classifiers} //= $self->op_classifiers;
    my $walker = bless {
        %$self,
        cv        => $cv,
        rec       => \%rec,
        shifted   => 0,
        consumed  => {},
        line_of   => {},
        line      => undef,
        signature => undef,
      },
      ref $self;

    $walker->_walk( $cv->ROOT, [] );
    push @{ $rec{returns} }, map { +{ %$_, implicit => 1 } } $walker->_implicit_returns( $cv->ROOT );
    $walker->finish_sub( \%rec );

    @{ $rec{params} } = sort { $a->{index} <=> $b->{index} } @{ $rec{params} };
    foreach my $param ( @{ $rec{params} } ) {
        next unless defined $param->{name};
        my $keys = $rec{usage}{ $param->{name} }{keys};
        $param->{keys} = [@$keys] if $keys;
    }
    return \%rec;
}

=head2 finish_sub(RECORD)

Called once the op tree of a sub was walked, before the parameters are sorted.
Subclasses override it to add what only the whole tree shows.  The default does nothing.

=cut

sub finish_sub {
    return;
}

=head2 op_handlers

Returns a HASHREF that maps op names to the methods that the walk calls for each op of that name,
with the op and the ARRAYREF of its ancestors, nearest last.
Subclasses add the ops of their version set to what this returns.

=cut

sub op_handlers {
    return {
        nextstate  => \&_on_cop,
        dbstate    => \&_on_cop,
        sassign    => \&_on_sassign,
        aassign    => \&_on_aassign,
        shift      => \&_on_shift,
        aelemfast  => \&_on_aelemfast,
        padsv      => \&_on_pad,
        padav      => \&_on_pad,
        padhv      => \&_on_pad,
        multideref => \&_on_multideref,
        helem      => \&_on_helem,
        exists     => \&_on_exists,
        delete     => \&_on_exists,
        entersub   => \&_on_entersub,
        return     => \&_on_return,
        die        => \&_on_die,
        exit       => \&_on_die,
    };
}

=head2 op_classifiers

Returns a HASHREF that maps op names to methods that C<classify> calls for them, ahead of its own rules.
Subclasses add the value-producing ops of their version set here, as they add walk handlers in C<op_handlers>.
The default has none.

=cut

sub op_classifiers {
    return {};
}

=head2 op_kids(OP)

Returns the kids of OP, in order, for the handlers of subclasses.

=cut

sub op_kids {
    my ( undef, $op ) = @_;
    return _kids($op);
}

# The package the sub was compiled in, as opposed to the one it was imported into.
sub _defined_in {
    my ($cv) = @_;
    my $gv = $cv->GV;
    return '' if B::class($gv) ne 'GV';
    return $gv->STASH->NAME;
}

# These subs walk an op tree, which is as deep as the nesting of the source, and so recursion is their natural form.
## no critic (Subroutines::ProhibitTailRecursion)

sub _walk {
    my ( $self, $op, $ancestors ) = @_;
    return if !$$op;

    $self->{line_of}{$$op} = $self->{line};

    my $handler = $self->{handlers}{ $op->name };
    $self->$handler( $op, $ancestors ) if $handler;

    my @kids = $self->op_kids($op);
    return unless @kids;
    push @$ancestors, $op;
    foreach my $kid (@kids) {
        $self->_walk( $kid, $ancestors );
    }
    pop @$ancestors;
    return;
}

# The values a sub returns when control reaches its end without a return statement.
sub _last_values {
    my ( $self, $op ) = @_;
    return () if !$op || !$$op;
    my $name = $op->name;

    if ( $name eq 'lineseq' || $name eq 'scope' || $name eq 'leave' || $name eq 'null' ) {
        my @kids;
        foreach my $kid ( _significant_kids($op) ) {
            push @kids, $kid unless $kid->name eq 'nextstate' || $kid->name eq 'dbstate' || $kid->name eq 'enter';
        }
        return ()                   if !@kids && $name ne 'null';
        return $self->classify($op) if !@kids;

        # A null op that wraps one expression is that expression.
        return $self->_last_values( $kids[-1] ) if $name ne 'null' || @kids == 1;
        return $self->classify($op);
    }
    if ( $name eq 'cond_expr' ) {
        my ( undef, $then, $else ) = _kids($op);
        return ( $self->_last_values($then), $self->_last_values($else) );
    }
    if ( $name eq 'and' || $name eq 'or' || $name eq 'dor' ) {

        # if (COND) { BODY } without an else: COND's value when the body does not run.
        my ( $cond, $body ) = _kids($op);
        return ( $self->classify($cond), $self->_last_values($body) );
    }
    return () if $name eq 'return' || $name eq 'die' || $name eq 'exit' || $name eq 'stub';

    my $line = $self->{line_of}{$$op};
    return ( { type => 'unknown', op => 'loop', line => $line } ) if $name eq 'leaveloop';
    return map { +{ %$_, line => $line } } $self->classify($op);
}

=head2 classify(OP)

Returns the evidence that OP, an op that produces a value, gives about that value.
This is a list of HASHREFs, one per alternative, because an expression such as C<COND ? A : B> has more than one.

The C<type> of each is one of C<undef>, C<empty>, C<number>, C<string>, C<boolean>, C<hashref>, C<arrayref>, C<coderef>, C<ref>,
C<object>, C<variable>, C<call>, C<method>, C<list>, C<context> or C<unknown>.

=cut

sub classify {
    my ( $self, $op ) = @_;
    $op = _unwrap($op);
    my $name = $op->name;

    my $classifier = $self->{classifiers}{$name};
    return $self->$classifier($op) if $classifier;

    return _sv_evidence( $self->_const_sv($op) ) if $name eq 'const';
    return { type => 'undef' }    if $name eq 'undef';
    return { type => 'hashref' }  if $name eq 'anonhash';
    return { type => 'arrayref' } if $name eq 'anonlist';
    return { type => 'coderef' }  if $name eq 'anoncode';
    return { type => 'context' }  if $name eq 'wantarray';

    return $self->_classify_refgen($op) if $name eq 'srefgen' || $name eq 'refgen';
    return $self->_classify_bless($op)  if $name eq 'bless';

    if ( $name eq 'scalar' ) {
        my ($kid) = _significant_kids($op);
        return { type => 'unknown', op => $name } if !$kid;
        my $kname = _unwrap($kid)->name;
        return { type => 'number' } if $kname eq 'padav' || $kname eq 'rv2av';
        return $self->classify($kid);
    }
    if ( $name eq 'padsv' || $name eq 'padav' || $name eq 'padhv' ) {
        return { type => 'variable', name => $self->_padname( $op->targ ) };
    }
    if ( $name eq 'sassign' ) {
        my ($value) = _kids($op);
        return $self->classify($value);
    }
    if ( $name eq 'cond_expr' ) {
        my ( $cond, $then, $else ) = _kids($op);

        # wantarray ? LIST : SCALAR says which value goes with which context.
        if ( _unwrap($cond)->name eq 'wantarray' ) {
            return (
                ( map { +{ %$_, context => 'list' } } $self->classify($then) ),
                ( map { +{ %$_, context => 'scalar' } } $self->classify($else) ),
            );
        }
        return ( $self->classify($then), $self->classify($else) );
    }
    if ( $name eq 'or' || $name eq 'dor' || $name eq 'and' ) {
        my @evidence;
        foreach my $kid ( _kids($op) ) {
            push @evidence, $self->classify($kid);
        }
        return @evidence;
    }
    if ( $name eq 'entersub' ) {
        my ($target) = $self->_call_target($op);
        return $target // { type => 'call' };
    }
    return { type => 'boolean' } if $BOOLEAN_OPS{$name};
    return { type => 'number' }  if $NUMBER_OPS{$name};
    return { type => 'string' }  if $STRING_RESULT_OPS{$name};
    return { type => 'list' }    if $LIST_OPS{$name};
    return { type => 'unknown', op => $name };
}

## use critic

sub _kids {
    my ($op) = @_;
    return () unless $op->flags & B::OPf_KIDS;
    my @kids;
    for ( my $kid = $op->first; $$kid; $kid = $kid->sibling ) {
        push @kids, $kid;
        last unless $kid->moresib;
    }
    return @kids;
}

# Kids that do something, as opposed to list markers and optimized-away ops.
sub _significant_kids {
    my ($op) = @_;
    my @significant;
    foreach my $kid ( _kids($op) ) {
        my $name = $kid->name;
        next if $name eq 'pushmark' || $name eq 'padrange';
        next if $name eq 'null' && !( $kid->flags & B::OPf_KIDS );
        push @significant, $kid;
    }
    return @significant;
}

# Unwrap ex-list and similar null ops that have one kid.
sub _unwrap {
    my ($op) = @_;
    while ( $op->name eq 'null' ) {
        my @kids = _significant_kids($op);
        last if @kids != 1;
        $op = $kids[0];
    }
    return $op;
}

sub _padname {
    my ( $self, $targ ) = @_;
    return undef if !$targ;
    my $padname = $self->{cv}->PADLIST->ARRAYelt(0)->ARRAYelt($targ);
    return undef if !$padname || B::class($padname) eq 'SPECIAL';
    return $padname->PVX;
}

sub _padval {
    my ( $self, $index ) = @_;
    return $self->{cv}->PADLIST->ARRAYelt(1)->ARRAYelt($index);
}

# Under threaded perls, GVs and constants live in the pad instead of the op.
sub _gv {
    my ( $self, $op ) = @_;
    return B::class($op) eq 'PADOP' ? $self->_padval( $op->padix ) : $op->gv;
}

sub _const_sv {
    my ( $self, $op ) = @_;
    my $sv = $op->sv;
    $sv = $self->_padval( $op->targ ) unless $$sv;
    return $sv;
}

sub _sv_value {
    my ($sv) = @_;
    my $class = B::class($sv);
    return undef if $class eq 'SPECIAL' || $class eq 'NULL';
    my $flags = $sv->FLAGS;
    return $sv->PV if $flags & B::SVf_POK;
    return $sv->NV if $flags & B::SVf_NOK;
    return $sv->IV if $flags & B::SVf_IOK;
    return undef;
}

sub _sv_evidence {
    my ($sv) = @_;
    my $class = B::class($sv);
    return { type => 'undef' } if $class eq 'SPECIAL' || $class eq 'NULL';
    my $flags = $sv->FLAGS;
    return { type => 'string', value => $sv->PV }        if $flags & B::SVf_POK;
    return { type => 'number', value => _sv_value($sv) } if $flags & ( B::SVf_IOK | B::SVf_NOK );
    return { type => 'undef' };
}

sub _fullname {
    my ($gv) = @_;
    return undef if B::class($gv) ne 'GV';
    return $gv->STASH->NAME . '::' . $gv->NAME;
}

# The name of the sub a call goes to, where it was defined rather than where it was imported to,
# so that an imported croak reads as Carp::croak.
sub _sub_fullname {
    my ($gv) = @_;
    return undef if B::class($gv) ne 'GV';
    my $cv = $gv->CV;
    if ( $$cv && B::class($cv) eq 'CV' ) {
        my $origin = $cv->GV;
        return _fullname($origin) if B::class($origin) eq 'GV' && $origin->NAME ne '__ANON__';
    }
    return _fullname($gv);
}

sub _is_args_array {
    my ( $self, $op ) = @_;
    $op = _unwrap($op);
    return 0 unless $op->name eq 'rv2av';
    my ($gvop) = _kids($op);
    return 0 unless $gvop && $gvop->name eq 'gv';
    my $gv = $self->_gv($gvop);
    return ( _fullname($gv) // '' ) eq 'main::_';
}

# A shift or pop of @_.  With no argument, the op has no kids at all.
sub _is_args_shift {
    my ( $self, $op ) = @_;
    $op = _unwrap($op);
    return 0 unless $op->name eq 'shift';
    my @kids = _kids($op);
    return 1 if !@kids;
    return $self->_is_args_array( $kids[0] );
}

sub _usage_of {
    my ( $self, $var ) = @_;
    return $self->{rec}{usage}{$var} //= {};
}

sub _add_param {
    my ( $self, %param ) = @_;
    my $params = $self->{rec}{params};
    return if defined $param{name}  && any { ( $_->{name} // '' ) eq $param{name} } @$params;
    return if !defined $param{name} && any { $_->{index} == $param{index} } @$params;
    $param{slurpy} //= ( defined $param{name} && $param{name} =~ m/\A[@%]/xsaa ) ? 1 : 0;
    push @$params, \%param;
    return;
}

sub _on_cop {
    my ( $self, $op ) = @_;
    $self->{line} = $op->line;
    $self->{rec}{line} //= $op->line;
    return;
}

sub _assign_from_args {
    my ( $self, $value, $target_name ) = @_;
    $value = _unwrap($value);
    if ( $self->_is_args_shift($value) ) {
        $self->{consumed}{$$value} = 1;
        $self->_add_param( name => $target_name, index => $self->{shifted}++, source => 'shift' );
    }
    elsif ( $value->name eq 'aelemfast' && $self->_is_args_elem($value) ) {
        $self->{consumed}{$$value} = 1;
        $self->_add_param( name => $target_name, index => _elem_index($value), source => 'element' );
    }
    return;
}

# The assignment of one value to a lexical scalar: the value is the first kid, and the target the last.
sub _on_sassign {
    my ( $self, $op ) = @_;
    my @kids = _kids($op);
    return if @kids != 2;
    my $target = _unwrap( $kids[1] );
    return unless $target->name eq 'padsv';
    $self->_assign_from_args( $kids[0], $self->_padname( $target->targ ) );
    return;
}

# A list assignment to lexicals, from @_ or from one shift of it.
sub _on_aassign {
    my ( $self, $op )  = @_;
    my ( $rhs,  $lhs ) = _kids($op);
    return unless $rhs && $lhs;

    my @values = _significant_kids($rhs);
    my @targets;
    foreach my $kid ( _significant_kids($lhs) ) {
        push @targets, $kid if $kid->name =~ m/\Apad[ash]v\z/xsaa;
    }
    return if @values != 1 || !@targets;

    if ( $self->_is_args_array( $values[0] ) ) {
        foreach my $target (@targets) {
            my $name = $self->_padname( $target->targ );
            if ( $target->name eq 'padsv' ) {
                $self->_add_param( name => $name, index => $self->{shifted}++, source => 'list' );
            }
            else {
                $self->_add_param( name => $name, index => $self->{shifted}, source => 'list' );
                last;
            }
        }
    }
    elsif ( $self->_is_args_shift( $values[0] ) ) {
        $self->{consumed}{ ${ _unwrap( $values[0] ) } } = 1;
        $self->_add_param( name => $self->_padname( $targets[0]->targ ), index => $self->{shifted}++, source => 'shift' );
    }
    return;
}

# A shift of @_ that is not assigned to a variable, as in shift->method.
sub _on_shift {
    my ( $self, $op ) = @_;
    return if $self->{consumed}{$$op};
    return unless $self->_is_args_shift($op);
    $self->_add_param( name => undef, index => $self->{shifted}++, source => 'shift' );
    return;
}

sub _is_args_elem {
    my ( $self, $op ) = @_;
    my $gv = $self->_gv($op);
    return ( _fullname($gv) // '' ) eq 'main::_';
}

sub _elem_index {
    my ($op) = @_;
    return unpack( 'c', pack( 'C', $op->private ) );
}

# $_[N] used directly.
sub _on_aelemfast {
    my ( $self, $op ) = @_;
    return if $self->{consumed}{$$op};
    return unless $self->_is_args_elem($op);
    my $index = _elem_index($op);
    return if $index < 0;
    $self->_add_param( name => undef, index => $index, source => 'element' );
    return;
}

sub _on_pad {
    my ( $self, $op, $ancestors ) = @_;
    my $var    = $self->_padname( $op->targ ) // return;
    my $parent = $ancestors->[-1]             // return;
    my $pname  = $parent->name;

    # A declaration of the variable is not a use of it.
    return if $op->private & B::OPpLVAL_INTRO;

    my $usage = $self->_usage_of($var);
    if    ( $pname eq 'rv2hv' )    { $usage->{hashref}  = 1 }
    elsif ( $pname eq 'rv2av' )    { $usage->{arrayref} = 1 }
    elsif ( $pname eq 'rv2cv' )    { $usage->{coderef}  = 1 }
    elsif ( $NUMERIC_OPS{$pname} ) { $usage->{numeric}  = 1 }
    elsif ( $STRING_OPS{$pname} )  { $usage->{string}   = 1 }
    return;
}

sub _add_key {
    my ( $self, $var, $key ) = @_;
    return if !defined $var || !defined $key;
    my $usage = $self->_usage_of($var);
    $usage->{keys} //= [];
    push @{ $usage->{keys} }, $key unless any { $_ eq $key } @{ $usage->{keys} };
    return;
}

# $h->{a}[0], $o{size}, exists $o{verbose} and the like, compiled into one op.
sub _on_multideref {
    my ( $self, $op ) = @_;
    my @items   = $op->aux_list( $self->{cv} );
    my $actions = shift @items;
    my $first   = 1;
    my $var;

    while (1) {
        my $action = $actions & B::MDEREF_ACTION_MASK;
        if ( $action == B::MDEREF_reload ) {
            $actions = shift @items;
            next;
        }
        my $is_hash = any { $action == $_ } @HASH_MDEREF_ACTIONS;

        if ( $action == B::MDEREF_AV_padav_aelem || $action == B::MDEREF_HV_padhv_helem ) {
            $var = $self->_padname( shift @items );
        }
        elsif ( $action == B::MDEREF_AV_padsv_vivify_rv2av_aelem || $action == B::MDEREF_HV_padsv_vivify_rv2hv_helem ) {
            $var = $self->_padname( shift @items );
            $self->_usage_of($var)->{ $is_hash ? 'hashref' : 'arrayref' } = 1 if defined $var;
        }
        elsif ($action == B::MDEREF_AV_gvav_aelem
            || $action == B::MDEREF_HV_gvhv_helem
            || $action == B::MDEREF_AV_gvsv_vivify_rv2av_aelem
            || $action == B::MDEREF_HV_gvsv_vivify_rv2hv_helem ) {
            shift @items;
            $var = undef;
        }
        elsif ( !$first ) {

            # A deeper level of a chain that started at $var: it says nothing more about $var itself.
            $var = undef;
        }

        my $index = $actions & B::MDEREF_INDEX_MASK;
        last if $index == B::MDEREF_INDEX_none;
        my $key = shift @items;
        if ( $index == B::MDEREF_INDEX_const ) {
            $self->_add_key( $var, ref $key ? _sv_value($key) : $key ) if $is_hash;
        }

        last if $actions & B::MDEREF_FLAG_last;
        $actions >>= B::MDEREF_SHIFT;
        $first = 0;
    }
    return;
}

# $o{name} or $h->{name} when perl did not fold it into a multideref.
sub _on_helem {
    my ( $self, $op )  = @_;
    my ( $hash, $key ) = _kids($op);
    return unless $hash && $key && $key->name eq 'const';
    my $var;
    if ( $hash->name eq 'padhv' ) {
        $var = $self->_padname( $hash->targ );
    }
    elsif ( $hash->name eq 'rv2hv' ) {
        my ($ref) = _kids($hash);
        $var = $self->_padname( $ref->targ ) if $ref && $ref->name eq 'padsv';
    }
    $self->_add_key( $var, _sv_value( $self->_const_sv($key) ) );
    return;
}

# exists $o{name} or delete $o{name} when perl did not fold it into a multideref:
# the hash element is then a null op that was a helem.
sub _on_exists {
    my ( $self, $op ) = @_;
    my ($elem) = _kids($op);
    return if !$elem;
    return if $elem->name ne q{null} || $elem->targ != $HELEM;
    $self->_on_helem($elem);
    return;
}

sub _call_target {
    my ( $self, $op ) = @_;
    my @args = _significant_kids($op);
    @args = _significant_kids( $args[0] ) if @args == 1 && $args[0]->name eq 'null';
    my $target = pop @args;
    return ( undef, \@args ) if !$target;

    if ( $target->name eq 'method_named' ) {
        my $sv = $target->meth_sv;
        $sv = $self->_padval( $target->targ ) unless $$sv;
        return ( { type => 'method', method => _sv_value($sv) }, \@args );
    }
    if ( $target->name eq 'method' ) {
        return ( { type => 'method', method => undef }, \@args );
    }
    my $cvop = _unwrap($target);
    $cvop = _unwrap( ( _kids($cvop) )[0] ) if $cvop->name eq 'rv2cv' && _kids($cvop);
    if ( $cvop->name eq 'gv' ) {
        return ( { type => 'call', function => _sub_fullname( $self->_gv($cvop) ) }, \@args );
    }
    if ( $cvop->name eq 'padsv' ) {
        return ( { type => 'call', coderef => $self->_padname( $cvop->targ ) }, \@args );
    }
    return ( { type => 'call' }, \@args );
}

sub _on_entersub {
    my ( $self, $op, $ancestors ) = @_;
    my ( $target, $args ) = $self->_call_target($op);
    return if !$target;

    if ( $target->{type} eq 'method' ) {
        $self->_add_method_use( $args->[0], $target->{method} );
        $self->_add_death( 'throw', $ancestors ) if ( $target->{method} // '' ) eq 'throw';
        return;
    }
    if ( defined $target->{coderef} ) {
        $self->_usage_of( $target->{coderef} )->{coderef} = 1;
        return;
    }
    if ( defined $target->{function} && $TERMINATORS{ $target->{function} } ) {
        $self->_add_death( $target->{function}, $ancestors );
    }
    return;
}

# Records METHOD as called on the variable that INVOCANT reads, when it reads one.
sub _add_method_use {
    my ( $self, $invocant, $method ) = @_;
    return if !$invocant || !defined $method;
    $invocant = _unwrap($invocant);
    return if $invocant->name ne 'padsv';
    my $var = $self->_padname( $invocant->targ ) // return;

    my $usage = $self->_usage_of($var);
    $usage->{methods} //= [];
    push @{ $usage->{methods} }, $method unless any { $_ eq $method } @{ $usage->{methods} };
    return;
}

sub _add_death {
    my ( $self, $via, $ancestors ) = @_;
    push @{ $self->{rec}{dies} }, {
        via    => $via,
        line   => $self->{line},
        caught => _is_caught($ancestors) ? 1 : 0,
    };
    return;
}

# Inside eval {} or the try block of try/catch, but not inside its catch block.
sub _is_caught {
    my ($ancestors) = @_;
    foreach my $ancestor ( reverse @$ancestors ) {
        my $name = $ancestor->name;
        return 1 if $name eq 'leavetry';
        return 0 if $name eq 'catch';
        return 1 if $name eq 'leavetrycatch' || $name eq 'entertrycatch';
    }
    return 0;
}

sub _on_die {
    my ( $self, $op, $ancestors ) = @_;
    $self->_add_death( $op->name, $ancestors );
    return;
}

sub _on_return {
    my ( $self, $op ) = @_;
    my @values = _significant_kids($op);
    my $line   = $self->{line};
    my @evidence;
    if ( !@values ) {
        @evidence = ( { type => 'empty' } );
    }
    elsif ( @values == 1 ) {
        @evidence = $self->classify( $values[0] );
    }
    else {
        my @items;
        foreach my $value (@values) {
            push @items, [ $self->classify($value) ];
        }
        @evidence = ( { type => 'list', count => scalar(@values), items => \@items } );
    }
    push @{ $self->{rec}{returns} }, map { +{ %$_, line => $line, implicit => 0 } } @evidence;
    return;
}

sub _implicit_returns {
    my ( $self, $op ) = @_;
    $op = $op->first if $op->name eq 'leavesub';
    return $self->_last_values($op);
}

sub _classify_refgen {
    my ( $self, $op ) = @_;
    my ($kid) = _significant_kids($op);
    $kid = _unwrap($kid) if $kid;
    my $kname = $kid ? $kid->name : '';
    return { type => 'coderef' }  if $kname eq 'anoncode';
    return { type => 'arrayref' } if $kname eq 'padav' || $kname eq 'rv2av';
    return { type => 'hashref' }  if $kname eq 'padhv' || $kname eq 'rv2hv';
    return { type => 'ref' };
}

sub _classify_bless {
    my ( $self, $op )    = @_;
    my ( undef, $class ) = _significant_kids($op);
    return { type => 'object', class => $self->{rec}{package} } if !$class;
    $class = _unwrap($class);
    return { type => 'object', class => _sv_value( $self->_const_sv($class) ) } if $class->name eq 'const';

    # bless REF, $class  or  bless REF, ref($proto) || $proto: the class comes from a variable.
    my $from = $class->name eq 'or' ? _unwrap( ( _kids($class) )[-1] ) : $class;
    return { type => 'object', class => undef, class_from => $self->_padname( $from->targ ) } if $from->name eq 'padsv';
    return { type => 'object', class => undef };
}

1;

=head1 SEE ALSO

L<B>

L<B::Deparse>

=cut
