# ABSTRACT: Make sure your POD covers more ground than just subroutines
# PODNAME: Pod::Coverage::More

package Pod::Coverage::More;

use 5.036;
use warnings FATAL => q{all};
use re q{/xsaa};

use Pod::Find    qw(pod_where);
use Clone        qw{clone};
use List::Util   qw{any none};
use Scalar::Util qw{reftype};

use parent 'Pod::Coverage';

use Pod::Coverage::Extractor::More;
use Pod::Coverage::More::Analyzer;

# Set to print what the parse and the coverage found, for debugging.
our $TRACE_ALL = 0;

=head1 DESCRIPTION

Extends Pod::Coverage to handle more things, like whether you are specifying args for your subroutines and whether that matches up with the subroutine's use of @_.

Will also optionally check that you describe your arguments (name them sometime before the next sub is mentioned), and optionally check whether you list it's expected type(s).

Also checks for a description of the return value(s) and it's expected type(s).

Also checks for descriptions of the function possibly causing termination incidents (croak/die,etc).

Also can check for examples in your POD.

For multiple functions described on one line, you can separate them with commas or spaces.  But for arguments, you must use commas; wouldn't want to confuse the copypasters out there.

=head1 SYNOPSIS

   use Pod::Coverage::More;

   my $pc    = Pod::Coverage::More->new(package => 'Quux');
   my $acov  = $pc->coverage_arguments();
   my $atcov = $pc->coverage_argument_types();


=head1 OVERRIDDEN METHODS

=head2 coverage

Should do the same thing as Pod::Coverage, but with a slightly more complex algorithm for getting arguments, et cetera.
Much like Pod::Coverage, it supports multiple functions being described per line.

You should use this if you want to have the rest of the functions here work too, as it has a significant caveat.

=head3 CAVEAT:

item commands are parsed as arguments to subroutines, not as subroutine entries.  This makes strategy 1) in coverage_argument_types possible.
It makes sense to me, given arguments are I<items> in I<lists>.

=cut

sub coverage {
    my $self = shift;

    my $package  = $self->{package};
    my $pod_info = $self->_get_more_pods;

    _trace_dump($pod_info);

    return unless $pod_info;

    my %symbols = map { $_ => 0 } $self->_get_syms($package);

    if ( !%symbols && $self->{why_unrated} ) {

        # _get_syms failed violently
        return;
    }

    print "tying shoelaces\n" if $TRACE_ALL;
    my @pods = @{ $pod_info->{'identifiers'} || [] };
    for my $pod (@pods) {
        $symbols{$pod} = 1 if exists $symbols{$pod};
    }

    foreach my $sym ( keys %symbols ) {
        $symbols{$sym} = 1 if $self->_trustme_check($sym);
    }

    # stash the results for later
    $self->{symbols} = \%symbols;

    _trace_dump($self);

    my $symbols    = scalar keys %symbols;
    my $documented = scalar grep { $_ } values %symbols;
    unless ($symbols) {
        $self->{why_unrated} = "no public symbols defined";
        return;
    }
    return $documented / $symbols;
}

=head1 METHODS

=head2 coverage_arguments

Looks for arguments to your functions described.  In general, valid barewords or variable names inside of parens following a function name is expected.
Uses L<Pod::Coverage::More::Analyzer> to check that the names are parameters of your subroutine:
variables assigned from @_ or a shift of it, signature parameters, or the keys read from a hash or hashref parameter of named arguments.
Names are not case sensitive, and will attempt to obey declared sigils (see 1. in coverage_argument_types).

TODO add compatibility for Function::Parameters and other CPAN signature modules.

=cut

sub coverage_arguments {
    my $self = shift;

    my $pod_info = $self->_get_more_pods;
    $self->_extract_function_information;
    my $fail_msg;

    foreach my $subrow ( @{ $pod_info->{'function_maps'} || [] } ) {
        $self->_fill_sub_vars( $subrow, 1 );

        #Loop over declared functions/args and check against the analysis
        foreach my $fun_with_args ( keys( %{ $subrow->{'args'} } ) ) {
            my @funargs    = map { _bare_name($_) } @{ $subrow->{'args'}->{$fun_with_args} };
            my @peekedargs = map { _bare_name($_) } @{ $subrow->{'sub_vars'}->{$fun_with_args} };

            foreach my $funarg (@funargs) {
                if ( none { $_ eq $funarg } @peekedargs ) {
                    $fail_msg .= "Var Mismatch for function $fun_with_args: $funarg not in @peekedargs\n";
                }
            }
        }

    }
    return { 'status' => $fail_msg ? 0 : 1, 'message' => $fail_msg };

}

=head2 coverage_argument_types

Looks for a type to be declared for your arguments described for a particular function.

This can be done one of two ways:

1. Use standard variable notation in your arglist known by coverage_arguments (e.g. do ($foo,@bar,%baz,\$fred,\@wilma,\%barney,\&bam_bam,\*betty) or some variation thereof)

2. Specify the types by name in an =item block somewhere between it and the next detected subroutine(s).  Example:

    =head2 some_sub(ARG1,ARG2)

    does stuff

    ARGUMENTS:

    =over4

    =item B<ARG1> - INTEGER - does something weird

    =item B<ARG2> - HASHREF - does something not so weird
    ...

As usual, the type and variable name search is case insensitive.

Recognized types:

SCALAR,SCALARREF,ARRAY,ARRAYREF,HASH,HASHREF,CODEREF,TYPEGLOBREF and OBJECT,STRING,INTEGER,FLOAT,BOOLEAN (the latter five and the REFs are aliases to SCALAR when comparing versus the sigil of the parameter)

You can also cheat and say MIXED to skip type checks.  Not the way I'd write a sub, but to each their own.

These two strategies are mutually exclusive; having sigils declared for your argument (strategy 1) will obviate it's search in a following block (strategy 2).

=head3 TODO:

recognize types from Type::Tiny or other MOPs

=head3 Maybe TODO:

Recognize imported namespaces when named as being explicit statements of what type of OBJECT we want an arg to be under vanilla perl

use the usage that L<Pod::Coverage::More::Analyzer> reports (using scalar as if HASHREF, etc...) to infer the data type in vanilla perl?

=head3 Probably Shouldn't TODO:

Infer vanilla types from standard guard clauses (if they exist???) for OBJECT,STRING,INTEGER,FLOAT,BOOLEAN (isa,!looks_like_number,Regexp::Common trickery)
Make the hammer of shame fall when said guard clauses are not detected

=cut

sub coverage_argument_types {
    my $self = shift;

    my $pod_info = $self->_get_more_pods;
    $self->_extract_function_information;
    my @failures;

    foreach my $subrow ( @{ $pod_info->{'function_maps'} || [] } ) {
        $self->_fill_sub_vars( $subrow, 0 );

        #Loop over declared functions/args and check against the analysis
        foreach my $fun_with_args ( keys( %{ $subrow->{'args'} } ) ) {
            my @funargs          = @{ $subrow->{'args'}->{$fun_with_args} };
            my @args_with_sigils = grep { m/\A[\$*\\@%&|]/ } @funargs;

            #Replace REF looking args with $ sigils
            @funargs = map { ( my $subj = $_ ) =~ s/\A\\[\$*@%&|]/\$/; $subj } @funargs;
            my @peekedargs = @{ clone( $subrow->{'sub_vars'}->{$fun_with_args} ) };

            push @failures,
              @args_with_sigils
              ? _sigil_mismatches( $fun_with_args, \@funargs, \@peekedargs )
              : _item_type_mismatches( $subrow, $fun_with_args, \@funargs, \@peekedargs );
        }

    }
    return { 'status' => @failures ? 0 : 1, 'message' => @failures ? join( '', @failures ) : undef };

}

# Strategy 1: the POD wrote each argument with its sigil, so it must match the parameter exactly.
sub _sigil_mismatches {
    my ( $fun_with_args, $funargs, $peekedargs ) = @_;
    my @failures;

    #Should I make a different message if the sigil was omitted for lone args?
    foreach my $funarg (@$funargs) {
        if ( none { $_ eq $funarg } @$peekedargs ) {
            push @failures, "Var Type Mismatch for function $fun_with_args: $funarg not in @$peekedargs\n";
        }
    }
    return @failures;
}

our %SIGIL_TYPES    = ( '$' => 'scalar', '@' => 'array', '%' => 'hash' );
our %SCALAR_ALIASES = map { $_ => 1 } qw{scalarref arrayref hashref coderef typeglobref object integer float boolean string};

# Strategy 2: the type of each argument is in an =item of the text blocks that were parsed for this function group.
sub _item_type_mismatches {
    my ( $subrow, $fun_with_args, $funargs, $peekedargs ) = @_;
    my $arglist = $subrow->{'arglist'} || {};
    my @podargs = keys(%$arglist);
    my @failures;

    foreach my $funarg (@$funargs) {
        if ( none { lc($_) eq lc($funarg) } @podargs ) {
            push @failures, "Var $funarg not documented whatsoever for $fun_with_args!\n";
        }
    }

    #Check each parameter's sigil against the type documented for that arg
    foreach my $peeked_arg (@$peekedargs) {
        my ( $sigil, $arg_name ) = $peeked_arg =~ m/\A(.)(.+)\z/;
        next if !defined $sigil;
        my $peeked_type = $SIGIL_TYPES{$sigil};
        my $pod_type    = $arglist->{ lc($arg_name) };

        #An arg with no =item has no documented type to compare
        next if !defined $peeked_type || !defined $pod_type;
        next if $pod_type eq 'mixed'  || $pod_type eq $peeked_type;
        next if $peeked_type eq 'scalar' && $SCALAR_ALIASES{$pod_type};
        push @failures,
          $pod_type eq ''
          ? "No type declared for arg $arg_name of $fun_with_args\n"
          : "Type mismatch for arg $arg_name of $fun_with_args: got $pod_type, expected $peeked_type\n";
    }
    return @failures;
}

=head2 coverage_return_types

Uses L<Pod::Coverage::More::Analyzer> to find out the sort of data your function returns, and then looks for an adequate description in a text block following function definition.
Acceptable return types are same as accepted for coverage_argument_types.

TODO: the comparison against the POD is not implemented yet.
For now this returns the analysis of every sub in the package, a HASHREF of the records that C<analyze_sub> of L<Pod::Coverage::More::Analyzer> returns,
or 0 when the POD names no functions.

=cut

sub coverage_return_types {
    my $self = shift;

    my $pod_info = $self->_get_more_pods;
    return 0 if ( reftype( $pod_info->{'function_maps'} ) || 'undef' ) ne "ARRAY";
    return $self->_extract_function_information;
}

=head2 coverage_termination

Not implemented yet: returns the string C<stub>.

It is meant to find the spots where your code explicitly croaks/dies/confesses or otherwise goes down in flames,
from the C<dies> that L<Pod::Coverage::More::Analyzer> reports,
and return failure when you do not provide adequate warnings to the user foolish enough to attempt usage of said code.

In general, say the code dies/exits/croaks/confesses on some condition in a text block following function definition and you should be good to go.

=cut

sub coverage_termination {
    return 'stub';
}

=head2 coverage_examples

Not implemented yet: returns the string C<stub>.

It is meant to look through the verbatim blocks following function definition(s) for examples of said functions' (correct) usage.
Basically runs the signature,type, return type and termination coverage algorithms on said verbatim block.

=cut

sub coverage_examples {
    return 'stub';
}

sub _trace_dump {
    my ($data) = @_;
    return if !$TRACE_ALL;
    require Data::Dumper;
    print Data::Dumper::Dumper($data);
    return;
}

# An argument name without its sigils, in lower case, as the POD and the parameters are compared.
sub _bare_name {
    my ($name) = @_;
    $name =~ tr/$*\\@%&|//d;
    return lc($name);
}

# Records, for each function of the heading SUBROW, the names of its parameters,
# and also the keys of its named arguments when WITH_NAMED_KEYS is true.
sub _fill_sub_vars {
    my ( $self, $subrow, $with_named_keys ) = @_;
    $subrow->{'sub_vars'} = {} if !exists( $subrow->{'sub_vars'} );
    foreach my $function ( @{ $subrow->{'all'} } ) {
        my @vars = @{ $self->_sub_args($function) };
        push @vars, @{ $self->_sub_named_keys($function) } if $with_named_keys;
        $subrow->{'sub_vars'}->{$function} = \@vars;
    }
    return;
}

sub _get_more_pods {
    my $self = shift;

    my $package = $self->{package};
    $self->{'last_package'} = $package;    #Track this so we can optimize by not calling the extractor twice for the same file
    return $self->{'last_pod'} if ( $self->{'last_package'} eq $self->{'package'} ) && $self->{'last_pod'};

    print "getting pod location for '$package'\n" if $TRACE_ALL;
    $self->{pod_from} ||= pod_where( { -inc => 1 }, $package );

    my $pod_from = $self->{pod_from};
    unless ($pod_from) {
        $self->{why_unrated} = "couldn't find pod";
        return;
    }

    print "parsing '$pod_from'\n" if $TRACE_ALL;
    my $pod = Pod::Coverage::Extractor::More->new;
    $pod->{nonwhitespace} = $self->{nonwhitespace};
    $pod->parse_from_file( $pod_from, '/dev/null' );

    $self->{'last_pod'} = $pod;
    return $pod || {};
}

# Analyze every sub of the package once, from its compiled op tree.
sub _extract_function_information {
    my $self = shift;
    return $self->{'sub_parse'} //= Pod::Coverage::More::Analyzer->new->analyze_package( $self->{'package'} );
}

#Convenience methods to grab bits from the analysis of one sub.
#A function the POD names but the package does not define has no record, and so no parameters.
sub _sub_args {
    my ( $self, $sub ) = @_;
    my $rec = $self->{'sub_parse'}->{$sub} or return [];
    return [ grep { defined } map { $_->{'name'} } @{ $rec->{'params'} } ];
}

#Keys read from a parameter of named arguments, such as %opts in my %opts = @_.
sub _sub_named_keys {
    my ( $self, $sub ) = @_;
    my $rec = $self->{'sub_parse'}->{$sub} or return [];
    return [ map { @{ $_->{'keys'} || [] } } @{ $rec->{'params'} } ];
}

1;
__END__

=head1 SEE ALSO

L<Pod::Coverage>

L<Pod::Coverage::Extractor::More>

L<Pod::Coverage::More::Analyzer>
