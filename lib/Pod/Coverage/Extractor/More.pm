# ABSTRACT: Utility library for Pod::Coverage::More
# PODNAME: Pod::Coverage::Extractor::More
package Pod::Coverage::Extractor::More;

use 5.036;
use warnings FATAL => q{all};

use Test::Deep::NoTest qw{eq_deeply};
use parent 'Pod::Parser';

# Set to print what each heading was parsed into, for debugging.
our $DEBUG = 0;

our @TYPES = qw{SCALAR SCALARREF ARRAY ARRAYREF HASH HASHREF CODEREF TYPEGLOBREF OBJECT STRING INTEGER FLOAT BOOLEAN MIXED};

# An argument list in parentheses, as it may follow a function name in a heading.
our $ARGLIST = qr/\(\s*[\$|\\|@|%|&|\*|\w*,|\w*|\w*\s*]+\s*\)/xsaa;

=head1 DESCRIPTION

Routines to extract subroutine names, arguments and their types (among other things) from a pod stream.

=cut

=head1 METHODS

Pod::Parser calls these for each paragraph of the POD.  They record what they find in the object,
under C<function_maps>, C<identifiers> and C<current_function_map>.

=head2 command(COMMAND, TEXT)

Reads the functions and the argument lists of a C<=head2>, C<=head3> or C<=head4>,
and the argument and its type of an C<=item>.  Returns nothing.

=cut

sub command {
    my ( $self, $command, $text ) = @_;
    return $self->_item($text)    if $command eq 'item';
    return $self->_heading($text) if $command =~ m/\Ahead[234]/xsaa;
    return;
}

# An =item names an argument of the functions of the heading above it, and maybe its type.
sub _item {
    my ( $self, $text ) = @_;

    #TODO: Be a bit safer here...
    my @arg_indices = keys( %{ $self->{'current_function_map'}->{'args'} } );
    return if !defined $arg_indices[0];

    my $arg_type_list = {};
    my @args          = @{ $self->{'current_function_map'}->{'args'}->{ $arg_indices[0] } };
    foreach my $arg (@args) {
        $arg = lc($arg);
        if ( lc($text) =~ m/$arg/xsaa ) {

            #Check if it has a type declared
            $arg_type_list->{$arg} = '';
            foreach my $type ( map { lc } @TYPES ) {
                if ( lc($text) =~ m/\b$type\b/xsaa ) {
                    $arg_type_list->{$arg} = $type;
                    last;
                }
            }
            last;
        }
    }

    #Parse text, get types
    foreach my $frow ( @{ $self->{'function_maps'} } ) {

        #XXX Not particularly optimized, but do you really care for POD tests?
        if ( eq_deeply( $frow, $self->{'current_function_map'} ) ) {
            $frow->{'arglist'} = {} if !exists( $frow->{'arglist'} );
            @{ $frow->{'arglist'} }{ keys %$arg_type_list } = values %$arg_type_list;
            last;
        }
    }
    return;
}

# A heading names one or more functions, each maybe followed by its argument list.
sub _heading {
    my ( $self, $text ) = @_;

    $text =~ s/[;#]//gxsaa;    #Strip semicolons, hashes that's stupid to use in your POD line
    my @args = map { ( my $subj = $_ ) =~ s/\s//gxsaa; $subj } ( $text =~ m/\(\s*([\$|\\|@|%|&|\*|\w*,|\w*|\w*\s*]+)\s*\)/gxsaa );
    my @funcs_with_args = ( $text =~ m/(\w*)\s*$ARGLIST/gxsaa );

    my $text_with_only_functions = $text;
    $text_with_only_functions =~ s/(?:$ARGLIST)//gxsaa;       #Strip args
    $text_with_only_functions =~ s/\w+(?:::\w+)*:://gxsaa;    #Strip full qualification
    $text_with_only_functions =~ s/\$\w+->//gxsaa;            # Strip method call on object

    # it's wrapped in a pod style B<>, or some other formatting, strip it
    $text_with_only_functions =~ s/[[:upper:]]<//gxsaa;
    $text_with_only_functions =~ tr/>//d;

    my @all_funcs;

    #Handle nimrods who separate functions with whitespace
    if ( index( $text_with_only_functions, q{,} ) >= 0 ) {
        $text_with_only_functions =~ s/\s*//gxsaa;    #Strip whitespace
        @all_funcs = split( m/,/xsaa, $text_with_only_functions );
    }
    else {
        $text_with_only_functions =~ s/\A\s*//xsaa;    #Strip leading whitespace
        $text_with_only_functions =~ s/\s*\z//xsaa;    #Strip trailing whitespace
        @all_funcs = split( m/\s/xsaa, $text_with_only_functions );
    }

    my %has_args           = map  { $_ => 1 } @funcs_with_args;
    my @funcs_without_args = grep { !$has_args{$_} } @all_funcs;
    _debug(
        "$text_with_only_functions\n",
        @args               ? "Found args: @args\n"                        : (),
        @funcs_with_args    ? "Found funcs w/args:  @funcs_with_args\n"    : (),
        @funcs_without_args ? "Found funcs wo/args: @funcs_without_args\n" : (),
    );

    if ( scalar(@funcs_with_args) == scalar(@args) ) {
        my %fargs;
        @fargs{@funcs_with_args} = map { [ split( m/,/xsaa, $_ ) ] } @args;
        $self->{'current_function_map'} = {
            'all'    => \@all_funcs,
            'noargs' => \@funcs_without_args,
            'args'   => \%fargs
        };

    }
    else {
        warn "Mismatch between detected arglist and functions with args list.  This is a bug.";
    }

    $self->{'function_maps'} = [] if !exists( $self->{'function_maps'} );
    push @{ $self->{'function_maps'} }, $self->{'current_function_map'};
    push @{ $self->{'identifiers'} },   @all_funcs;
    return;
}

=head2 textblock(TEXT)

Records a paragraph that mentions a return value, or one that mentions how the function terminates,
against the functions of the heading above it.  Returns 1.

=cut

sub textblock {
    my ( $self, $text ) = @_;
    return 1 if $text !~ m/\S/xsaa;

    if ( $text =~ m/return/ixsaa ) {
        $text =~ s/return[^\n]//gixsaa;
        my $is_class = $text =~ s/(?:object|instance|class|new)//gixsaa ? 'CLASS ' : '';
        $text =~ s/\s//gxsaa;
        $self->{'current_function_map'}->{'returns'} = $is_class . $text;
    }
    elsif ( $text =~ m/die|terminate|croak|confess|exit/ixsaa ) {
        $self->{'current_function_map'}->{'terms'} = $text;
    }
    return 1;
}

sub _debug {
    my (@lines) = @_;
    return if !$DEBUG;
    print @lines;
    return;
}

1;
