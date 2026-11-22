# ABSTRACT: Read the comment above each sub, which says what POD cannot be inferred from its code
# PODNAME: Pod::Coverage::More::Blurb

package Pod::Coverage::More::Blurb;

use 5.036;
use warnings FATAL => q{all};
use re q{/xsaa};

use Types::Standard qw{InstanceOf};

use Pod::Coverage::More::Types qw{type_named};

=head1 SYNOPSIS

    use Pod::Coverage::More::Blurb;

    my $blurbs = Pod::Coverage::More::Blurb->read_file( $INC{'Pod/Coverage/More/Blurb.pm'} );
    my $resize = $blurbs->{read_file};

=head1 DESCRIPTION

A blurb is the block of comment lines directly above a sub, with no blank line between them and the sub,
as C<# ABSTRACT:> is the comment that names what a module is for:

    # Resize the image to fit the box.
    # @param   width   Int  in pixels
    # @param   height  Int  in pixels
    # @returns Image::Thing  the resized copy
    # @throws  when either size is not positive
    # @example my $small = $image->resize( 100, 50 );
    sub resize {

The text before the first tag describes the sub; a comment line with nothing on it starts a new paragraph.
Each tag starts a line, and a line without one continues the tag above it:

=over 4

=item C<@param NAME TYPE DESCRIPTION> - an argument.  NAME may have its sigil.

=item C<@returns TYPE DESCRIPTION> - the return value; C<@return> is the same tag

=item C<@throws DESCRIPTION> - how the sub fails; C<@dies> is the same tag

=item C<@example CODE> - one line of an example; consecutive lines make one example

=back

TYPE is optional.  It is a type word or a type expression that C<type_named> of L<Pod::Coverage::More::Types> reads,
such as C<Int>, C<ArrayRef[Str]> or C<HashRef|Undef>, or the name of a loaded package, which means an instance of it.
A word that is neither starts the description.

A blurb sits above C<sub>, and above the keywords C<method>, C<fun> and C<func> that the class feature,
L<Object::Pad>, L<Function::Parameters> and L<Kavorka> define.

=head1 PERL::CRITIC

An C<@example> line is code in a comment, on purpose.  The policy L<Perl::Critic::Policy::Bangs::ProhibitCommentedOutCode>
reports such a line as commented-out code when it has an assignment, as C<# @example my $four = double(2);> has.
If your profile enables that policy, set its pattern so that a comment that starts with C<@example> is no code:

    [Bangs::ProhibitCommentedOutCode]
    commentedcoderegex = \A(?!\#\s*\@example\b).*\$[A-Za-z_].*=

This is the default pattern of the policy, anchored at the start of the comment.
An assignment in any other comment is still code.

=head1 BLURBS

C<read_file> and C<read_string> return a HASHREF from the name of each sub with a blurb to a HASHREF with:

=over 4

=item B<description> - ARRAYREF - the paragraphs of the text before the first tag

=item B<params> - ARRAYREF - one HASHREF per C<@param>, with C<name>, as written, C<type>, a L<Type::Tiny> constraint or undef,
and C<description>

=item B<returns> - HASHREF or undef - the C<@returns>, with C<type> and C<description>

=item B<throws> - ARRAYREF - the descriptions of the C<@throws> tags

=item B<examples> - ARRAYREF - one ARRAYREF of code lines per example

=item B<line> - INTEGER - the line of the sub

=back

=head1 METHODS

=head2 read_file(FILE)

Returns the blurbs of the subs in FILE.  Dies when FILE cannot be read.

    my $blurbs = Pod::Coverage::More::Blurb->read_file('lib/Some/Module.pm');

=cut

sub read_file {
    my ( $class, $file ) = @_;
    open( my $fh, '<', $file ) or die "Cannot read $file: $!\n";
    local $/;
    my $source = <$fh>;
    close($fh) or die "Cannot close $file: $!\n";
    return $class->read_string($source);
}

=head2 read_string(SOURCE)

Returns the blurbs of the subs in the perl source SOURCE.

    my $blurbs = Pod::Coverage::More::Blurb->read_string($source);

=cut

our $SUB_LINE = qr/\A\s*(?:sub|method|fun|func)\s+(?:\w+::)*(\w+)\b/;

sub read_string {
    my ( $class, $source ) = @_;
    my @lines = split m/\n/, $source;
    my %blurbs;
    my @comment;
    my $in_pod = 0;
    foreach my $index ( 0 .. $#lines ) {
        my $line = $lines[$index];
        last if $line =~ m/\A__(?:END|DATA)__\b/;
        if ( $line =~ m/\A=(\w+)/ ) {
            $in_pod  = $1 ne 'cut';
            @comment = ();
            next;
        }
        next if $in_pod;
        if ( $line =~ m/\A\s*\#(?!\#)[ ]?(.*)\z/ ) {
            push @comment, $1;
            next;
        }
        if ( my ($name) = $line =~ $SUB_LINE ) {
            $blurbs{$name} = { %{ _parse(@comment) }, line => $index + 1 } if @comment;
        }
        @comment = ();
    }
    return \%blurbs;
}

# The handlers of the tags, which each record what the rest of a tagged line says.
our %TAG_HANDLERS = (
    param   => \&_tag_param,
    returns => \&_tag_returns,
    return  => \&_tag_returns,
    throws  => \&_tag_throws,
    dies    => \&_tag_throws,
    example => \&_tag_example,
);

# The blurb that the comment LINES make, without their #.
sub _parse {
    my (@lines) = @_;
    my $state = {
        blurb     => { description => [], params => [], returns => undef, throws => [], examples => [] },
        paragraph => q{},
        current   => undef,
        last_tag  => q{},
    };
    foreach my $line (@lines) {
        my ( $tag, $rest ) = $line =~ m/\A\s*\@(\w+)\b\s*(.*)\z/;
        my $handler = defined $tag ? $TAG_HANDLERS{ lc $tag } : undef;
        if ( !$handler ) {
            _untagged( $state, $line );
            next;
        }
        $handler->( $state, $rest );
        $state->{last_tag} = lc $tag;
    }
    _end_paragraph($state);
    my $blurb = $state->{blurb};
    $blurb->{throws} = [ map { $_->{description} } @{ $blurb->{throws} } ];
    return $blurb;
}

# A line without a tag continues the tag above it, or else the description.
sub _untagged {
    my ( $state, $line ) = @_;
    $state->{last_tag} = q{};
    if ( my $current = $state->{current} ) {
        if ( $current->{example} ) { push @{ $current->{example} }, $line }
        else                       { $current->{description} = _join( $current->{description}, $line ) }
        return;
    }
    if ( $line =~ m/\A\s*\z/ ) {
        _end_paragraph($state);
        return;
    }
    $state->{paragraph} = _join( $state->{paragraph}, $line );
    return;
}

sub _end_paragraph {
    my ($state) = @_;
    push @{ $state->{blurb}{description} }, $state->{paragraph} if $state->{paragraph} ne q{};
    $state->{paragraph} = q{};
    return;
}

sub _tag_param {
    my ( $state, $rest )  = @_;
    my ( $name,  $after ) = $rest =~ m/\A(\S+)\s*(.*)\z/;
    return if !defined $name;
    my ( $type, $description ) = _type_and_description($after);
    $state->{current} = { name => $name, type => $type, description => $description };
    push @{ $state->{blurb}{params} }, $state->{current};
    return;
}

sub _tag_returns {
    my ( $state, $rest )        = @_;
    my ( $type,  $description ) = _type_and_description($rest);
    $state->{current} = $state->{blurb}{returns} = { type => $type, description => $description };
    return;
}

sub _tag_throws {
    my ( $state, $rest ) = @_;
    $state->{current} = { description => $rest };
    push @{ $state->{blurb}{throws} }, $state->{current};
    return;
}

# Consecutive @example lines make one example.
sub _tag_example {
    my ( $state, $rest ) = @_;
    my $examples = $state->{blurb}{examples};
    if ( $state->{last_tag} eq 'example' && @$examples ) {
        push @{ $examples->[-1] }, $rest;
    }
    else {
        push @$examples, [$rest];
    }
    $state->{current} = { example => $examples->[-1] };
    return;
}

sub _join {
    my ( $text, $more ) = @_;
    $more =~ s/\A\s+|\s+\z//g;
    return $more if $text eq q{};
    return $text if $more eq q{};
    return "$text $more";
}

# The type that the first word of TEXT names, if it names one, and the rest of TEXT as the description.
sub _type_and_description {
    my ($text) = @_;
    my ( $word, $rest ) = $text =~ m/\A(\S+)\s*(.*)\z/;
    return ( undef, q{} ) if !defined $word;
    my $type = type_named($word);
    $type //= InstanceOf [$word] if _is_package($word);
    return ( undef, $text =~ s/\A[-:\s]+//r ) if !$type;
    return ( $type, $rest =~ s/\A[-:\s]+//r );
}

# Whether WORD names a loaded package, as a class name in place of a type means an instance of that class.
sub _is_package {
    my ($word) = @_;
    return 0 if $word !~ m/\A[[:upper:]]\w*(?:::\w+)*\z/;
    return 1 if index( $word, q{::} ) >= 0;
    return exists $main::{"${word}::"} ? 1 : 0;
}

1;

=head1 SEE ALSO

L<Pod::Coverage::More::Generator>

=cut
