# ABSTRACT: Write the POD of each sub from its blurb and the analysis of its code
# PODNAME: Pod::Coverage::More::Generator

package Pod::Coverage::More::Generator;

use 5.036;
use warnings FATAL => q{all};
use re q{/xsaa};

use Module::Runtime qw{module_notional_filename};
use mro;

use Pod::Coverage::More;
use Pod::Coverage::More::Blurb;
use Pod::Coverage::More::Documentation;

=head1 SYNOPSIS

    use Pod::Coverage::More::Generator;

    my $generator = Pod::Coverage::More::Generator->new( package => 'Pod::Coverage::More::Generator' );
    print $generator->pod;

=head1 DESCRIPTION

Writes a POD section for each public sub that has a blurb, as L<Pod::Coverage::More::Blurb> reads it,
and no POD of its own or of a parent class.  An override of a sub that a parent class has a blurb for gets none either,
because the section of the parent documents it.  A sub without a blurb gets no section:
the blurb is how a sub opts in, as C<# ABSTRACT:> is how a module does.

A section says what the blurb says, and fills in what the code declares where the blurb is silent:

=over 4

=item The arguments are the parameters of the sub, and the keys of a hash of named arguments.
A sub whose code shows no parameters, as a stub, takes the arguments of its blurb.

=item The type of an argument is the type in its C<@param>, or else the type that the code declares.

=item The return value is the C<@returns>, or else the type that the code declares,
or else the types of the values that it returns for certain, as literals and C<bless> into a class.

=back

The result of an operator and the uses of a variable are only probable, so they are never written.
The sections follow the forms that L<Pod::Coverage::More::Documentation> reads, so that L<Pod::Coverage::More> can check them.

=head1 METHODS

=cut

# A generator for the package C<package>, which must be loaded.
# @param   package  Str  the name of the package
# @param   file     Str  optional: the file to read the blurbs from, by default the file that the package was loaded from
# @returns Object  the generator, a Pod::Coverage::More::Generator object
# @example my $generator = Pod::Coverage::More::Generator->new( package => 'Some::Module', file => 'lib/Some/Module.pm' );
sub new {
    my ( $class, %args ) = @_;
    my $package = $args{package};
    my $file    = $args{file} // $INC{ module_notional_filename($package) };
    return bless( { package => $package, file => $file, coverage => Pod::Coverage::More->new( package => $package ) }, $class );
}

# One section per sub that gets one, in the order of the names of the subs:
# a HASHREF with C<name>, the name of the sub, and C<pod>, the text of its section, which starts with a C<=head2>.
# @returns the sections, as a list
# @example my @sections = $generator->sections;
sub sections {
    my ($self)   = @_;
    my $coverage = $self->{coverage};
    my $blurbs   = defined $self->{file} ? Pod::Coverage::More::Blurb->read_file( $self->{file} ) : {};
    my $analysis = $coverage->analysis;
    my @sections;
    foreach my $name ( sort $coverage->public_subs ) {
        my $blurb = $blurbs->{$name} or next;
        next if $coverage->section_for($name) || $self->_parent_has_blurb($name);
        push @sections, { name => $name, pod => _section( $name, $blurb, $analysis->{$name} ) };
    }
    return @sections;
}

# Whether a parent class has a blurb for the sub NAME, which becomes its section when the parent is woven.
sub _parent_has_blurb {
    my ( $self, $name ) = @_;
    foreach my $parent ( @{ mro::get_linear_isa( $self->{package} ) } ) {
        next if $parent eq $self->{package};
        my $file = $INC{ module_notional_filename($parent) } or next;
        $self->{parent_blurbs}{$parent} //= Pod::Coverage::More::Blurb->read_file($file);
        return 1 if $self->{parent_blurbs}{$parent}{$name};
    }
    return 0;
}

# The text of all the sections, one after another.
# @returns Str  the POD, or the empty string when no sub gets a section
# @example my $pod = $generator->pod;
sub pod {
    my ($self) = @_;
    return join q{}, map { $_->{pod} } $self->sections;
}

# The POD of one sub, from its BLURB and the analysis REC of its code.
sub _section {
    my ( $name, $blurb, $rec ) = @_;
    my @args = _arguments( $blurb, $rec );
    my $pod  = "=head2 $name" . ( @args ? '(' . join( ', ', map { $_->{name} } @args ) . ')' : q{} ) . "\n\n";
    foreach my $paragraph ( @{ $blurb->{description} } ) {
        $pod .= "$paragraph\n\n";
    }

    if (@args) {
        $pod .= "=over 4\n\n";
        foreach my $arg (@args) {
            my @parts = ( $arg->{name}, $arg->{type} ? $arg->{type}->display_name : (), $arg->{description} ne q{} ? $arg->{description} : () );
            $pod .= '=item ' . join( ' - ', @parts ) . "\n\n";
        }
        $pod .= "=back\n\n";
    }

    my $returns = _returns( $blurb, $rec );
    $pod .= "$returns\n\n" if defined $returns;
    foreach my $throws ( @{ $blurb->{throws} } ) {
        $pod .= _sentence( $throws =~ $Pod::Coverage::More::Documentation::TERMINATION ? $throws : "Dies $throws" ) . "\n\n";
    }
    foreach my $example ( @{ $blurb->{examples} } ) {
        $pod .= join( "\n", map { "    $_" } @$example ) . "\n\n";
    }
    return $pod;
}

# The arguments of the heading: the parameters, or the keys of a hash of named arguments, with what the blurb and the code say of each.
sub _arguments {
    my ( $blurb, $rec ) = @_;
    my %documented;
    foreach my $param ( @{ $blurb->{params} } ) {
        $documented{ Pod::Coverage::More::Documentation->bare_name( $param->{name} ) } = $param;
    }
    my @names;
    foreach my $param ( @{ $rec->{params} || [] } ) {
        next if !defined $param->{name} || $param->{source} eq 'invocant' || $param->{name} =~ m/\A\$(?:self|class|proto)\z/;
        if ( $param->{name} =~ m/\A%/ && $param->{keys} ) {
            push @names, map { [ $_, undef ] } @{ $param->{keys} };
            next;
        }
        push @names, [ Pod::Coverage::More::Documentation->bare_name( $param->{name} ), $param ];
    }
    if ( !@names ) {
        foreach my $param ( @{ $blurb->{params} } ) {
            push @names, [ Pod::Coverage::More::Documentation->bare_name( $param->{name} ), undef ];
        }
    }

    my @args;
    foreach my $entry (@names) {
        my ( $name, $param ) = @$entry;
        my $documented = $documented{$name} // {};
        push @args, {
            name        => $name,
            type        => $documented->{type}        // ( $param ? $param->{declared} : undef ),
            description => $documented->{description} // q{},
        };
    }
    return @args;
}

# The paragraph of the return value, or undef when neither the blurb nor what the code shows for certain says anything.
sub _returns {
    my ( $blurb, $rec ) = @_;
    my $stated      = $blurb->{returns}      // {};
    my $description = $stated->{description} // q{};
    my @types       = $stated->{type} ? ( $stated->{type} ) : _code_return_types($rec);
    return if !@types && $description eq q{};

    my $text = 'Returns';
    $text .= q{ } . join( q{ or }, _type_texts(@types) ) if @types;
    $text .= ( @types ? q{, } : q{ } ) . $description    if $description ne q{};
    return _sentence($text);
}

# The return types that the code declares, or else those that its literals and objects show for certain.
sub _code_return_types {
    my ($rec) = @_;
    return if !$rec;
    my @declared = @{ $rec->{declared}{returns} || [] };
    return @declared if @declared;
    my ( @types, %seen );
    foreach my $returned ( @{ $rec->{returns} } ) {
        next if $returned->{weak} || !$returned->{constraint} || $returned->{type} eq 'empty';
        push @types, $returned->{constraint} if !$seen{ $returned->{constraint}->display_name }++;
    }
    return @types;
}

# Constraints as the POD writes them in a Returns paragraph: an instance of one class in prose, a union as its alternatives,
# and any other by its name.  Type::Tiny flattens a union of unions, so its members are no unions.
sub _type_texts {
    my (@types) = @_;
    my @texts;
    foreach my $type (@types) {
        my @members = $type->isa('Type::Tiny::Union') ? @{ $type->type_constraints } : ($type);
        foreach my $member (@members) {
            push @texts, $member->isa('Type::Tiny::Class') ? 'a ' . $member->class . ' object' : $member->display_name;
        }
    }
    return @texts;
}

sub _sentence {
    my ($text) = @_;
    $text =~ s/\s+\z//;
    $text = ucfirst $text;
    return $text =~ m/[.!?]\z/ ? $text : "$text.";
}

1;

=head1 SEE ALSO

L<Pod::Coverage::More::Blurb>

L<Pod::Coverage::More>

=cut
