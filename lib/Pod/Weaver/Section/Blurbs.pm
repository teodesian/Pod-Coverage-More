# ABSTRACT: Weave the POD of each sub that has a blurb, from its blurb and its code
# PODNAME: Pod::Weaver::Section::Blurbs

package Pod::Weaver::Section::Blurbs;

use 5.036;
use warnings FATAL => q{all};

use Moose;
with 'Pod::Weaver::Role::Section';

use Capture::Tiny qw{capture};
use Pod::Elemental;
use Pod::Elemental::Element::Nested;
use Pod::Elemental::Transformer::Pod5;

=head1 SYNOPSIS

    use Pod::Weaver;

    # With [Blurbs] in the weaver.ini of the current directory, as USAGE shows.
    my $weaver = Pod::Weaver->new_from_config( { root => q{.} } );

=head1 USAGE

In F<weaver.ini>, where the section of the subs belongs:

    [Blurbs]
    header = METHODS

and above each sub, a blurb, as L<Pod::Coverage::More::Blurb> describes it:

    # Double a number.
    # @param   count  Num  what to double
    # @returns Num  twice the count
    # @example my $four = double(2);
    sub double {

=head1 DESCRIPTION

Adds the sections that L<Pod::Coverage::More::Generator> writes for the subs of the woven module:
one for each public sub that has a blurb and no POD of its own or of a parent class.
They go under the C<head1> named C<header>, which is C<METHODS> by default:
into the one that the POD has already, whether a section before this one wove it or a later one such as C<[Leftovers]> will,
or else into a new one where this section stands in F<weaver.ini>.

The generator compiles the module to analyze it.  So that a module that is being built never loads into
the process of the build, it runs in a child perl, with the directory that the module is in on C<@INC>, as F<lib>.
The module must compile, and its prerequisites must be installed.

=head1 ATTRIBUTES

=head2 header

The name of the C<head1> that the sections go under: C<METHODS> by default.

=cut

has header => ( is => 'ro', isa => 'Str', default => 'METHODS' );

=head1 METHODS

=cut

# Adds the generated sections of the module that C<input> describes to C<document>, as L<Pod::Weaver::Role::Section> asks.
# @param   document  Pod::Elemental::Document  the POD that is woven
# @param   input     HashRef  with C<filename>, the path of the module from the current directory, and C<ppi_document>, the module as L<PPI> reads it
# @returns nothing
# @throws  when the child perl cannot load the module
# @example $section->weave_section( $document, { filename => 'lib/Some/Module.pm', ppi_document => $ppi } );
sub weave_section {
    my ( $self, $document, $input ) = @_;
    my $file    = $input->{filename}                    or return;
    my $package = _package_of( $input->{ppi_document} ) or return;

    my $pod = _generate( $package, $file );
    return if $pod eq q{};

    my $generated = Pod::Elemental->read_string("=pod\n\n${pod}=cut\n");
    Pod::Elemental::Transformer::Pod5->new->transform_node($generated);
    my @elements = @{ $generated->children };

    # The POD that a section such as [Leftovers] has not moved yet is still in the input document.
    foreach my $pod ( grep { defined } $document, $input->{pod_document} ) {
        foreach my $element ( @{ $pod->children } ) {
            next if !$element->isa('Pod::Elemental::Element::Nested') || $element->command ne 'head1' || $element->content ne $self->header;
            push @{ $element->children }, @elements;
            return;
        }
    }
    push @{ $document->children }, Pod::Elemental::Element::Nested->new( { command => 'head1', content => $self->header, children => \@elements } );
    return;
}

# The first package that the PPI document declares.
sub _package_of {
    my ($ppi) = @_;
    return if !$ppi;
    my $statement = $ppi->find_first('PPI::Statement::Package') or return;
    return $statement->namespace;
}

# The generated POD of PACKAGE, which FILE holds, from a child perl that loads it.
our $CHILD = <<'PERL';
my ( $package, $file, $root ) = @ARGV;
unshift @INC, $root;
( my $module = "$package.pm" ) =~ s{::}{/}g;
require $module;
require Pod::Coverage::More::Generator;
print Pod::Coverage::More::Generator->new( package => $package, file => $file )->pod;
PERL

sub _generate {
    my ( $package, $file ) = @_;
    ( my $module = "$package.pm" ) =~ s{::}{/}gxsaa;
    my $root = $file =~ s{/?\Q$module\E\z}{}xsaar;
    $root = q{.} if $root eq q{} || $root eq $file;

    local $ENV{PERL5LIB} = join q{:}, grep { !ref } @INC;

    # A child perl, so that the module that is being built never loads into the build.
    my ( $out, $err, $status ) = capture { system( $^X, '-e', $CHILD, $package, $file, $root ) };    ## no critic (logicLAB::ProhibitShellDispatch)
    die "Cannot generate the POD of $package from $file: $err" if $status != 0;
    return $out;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Pod::Coverage::More::Generator>

L<Pod::Coverage::More::Blurb>

L<Pod::Weaver>

=cut
