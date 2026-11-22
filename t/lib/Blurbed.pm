package Blurbed;

# Subs with blurbs and no POD, for t/Pod-Coverage-More-Generator.t to generate POD for and check it.

use 5.036;
use warnings FATAL => q{all};

# The @example lines of the blurbs are code in comments, which is what they are for.
## no critic (Bangs::ProhibitCommentedOutCode)

=head1 NAME

Blurbed - subs that a blurb documents

=head2 documented

Documented by hand, so it gets no generated section.

    Blurbed::documented();

=cut

sub documented {
    return;
}

# Double a number.
# @param   count   Num  what to double
# @returns Num  twice the count
# @example my $four = Blurbed::double(2);
sub double {
    my ($count) = @_;
    return $count * 2;
}

# Make a widget from named options.
# @param  size    Int  how big
# @param  colour  Str  what colour
# @throws when the size is negative
# @example my $widget = Blurbed->make( size => 3, colour => 'red' );
sub make {
    my ( $class, %opts ) = @_;
    die "negative\n" if $opts{size} < 0;
    return bless { size => $opts{size}, colour => $opts{colour} }, $class;
}

# Says yes.
# @example Blurbed::yes();
sub yes {
    return 1;
}

# A default that subclasses override, which ignores its argument.
# @param  record  HashRef  what to work on
# @example $object->hook( {} );
sub hook {
    return;
}

# Maybe a widget.
# @param   x  Any  whether to make one
# @example my $widget = Blurbed::maybe(1);
sub maybe {
    my ($x) = @_;
    return $x ? bless( {}, 'Blurbed' ) : undef;
}

sub plain {
    return 2;
}

1;
