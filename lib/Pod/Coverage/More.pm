# ABSTRACT: Make sure your POD covers more ground than just subroutines
# PODNAME: Pod::Coverage::More

package Pod::Coverage::More;

use strict;
use warnings;

use constant TRACE_ALL => 0;

use Pod::Find qw(pod_where);
use PPI;
use Clone 'clone';
use Scalar::Util qw{blessed reftype};

use base 'Pod::Coverage';

use Pod::Coverage::Extractor::More;

=head1 DESCRIPTION

Extends Pod::Coverage to handle more things, like whether you are specifying args for your subroutines and whether that matches up with the subroutine's use of @_.

Will also optionally check that you describe your arguments (name them sometime before the next sub is mentioned), and optionally check whether you list it's expected type(s).

Also checks for a description of the return value(s) and it's expected type(s).

Also checks for descriptions of the function possibly causing termination incidents (croak/die,etc).

Also can check for examples in your POD.

For multiple functions described on one line, you can separate them with commas or spaces.  But for arguments, you must use commas; wouldn't want to confuse the copypasters out there.

=head1 SYNOPSIS

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

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;

    if (TRACE_ALL) {
        require Data::Dumper;
        print Data::Dumper::Dumper($podInfo);
    }

    return unless $podInfo;

    my %symbols = map { $_ => 0 } $self->_get_syms($package);

    if (!%symbols && $self->{why_unrated}) {
        # _get_syms failed violently
        return;
    }

    print "tying shoelaces\n" if TRACE_ALL;
    my @pods = @{$podInfo->{'identifiers'}};
    for my $pod (@pods) {
        $symbols{$pod} = 1 if exists $symbols{$pod};
    }

    foreach my $sym ( keys %symbols ) {
        $symbols{$sym} = 1 if $self->_trustme_check($sym);
    }

    # stash the results for later
    $self->{symbols} = \%symbols;

    if (TRACE_ALL) {
        require Data::Dumper;
        print Data::Dumper::Dumper($self);
    }

    my $symbols = scalar keys %symbols;
    my $documented = scalar grep {$_} values %symbols;
    unless ($symbols) {
        $self->{why_unrated} = "no public symbols defined";
        return;
    }
    return $documented / $symbols;
}

=head1 METHODS

=head2 coverage_arguments

Looks for arguments to your functions described.  In general, valid barewords or variable names inside of parens following a function name is expected.
Uses PPI to check that the names are at least present as declared vars in your subroutine, and that they seem to be assignments of @_ or a bare shift.
Names are not case sensitive, and will attempt to obey declared sigils (see 1. in coverage_argument_types).

TODO add compatibility for various method signatures and so forth.

=cut

sub coverage_arguments {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;
    $self->_extract_function_information;
    my ($fun,$funargs,$peekedargs,$failMsg);

    #Use PadWalker to get the declared locals in the function
    foreach my $subrow (@{$podInfo->{'function_maps'}}) {
        #Process each function, be they having args or not
        foreach my $function (@{$subrow->{'all'}}) {
            $funargs = $self->_sub_args($function);
            $subrow->{'sub_vars'} = {} if !exists($subrow->{'sub_vars'});
            $subrow->{'sub_vars'}->{$function} = clone $funargs;
        }

        #Loop over declared functions/args and check against peek_sub results
        foreach my $funWithArgs (keys(%{$subrow->{'args'}})) {
            $funargs     = clone $subrow->{'args'}->{$funWithArgs};
            @$funargs    = map {my $subj = $_; $subj =~ s/[\$|\*|\\|@|%|&]+//g; lc($subj) } @$funargs;
            $peekedargs  = clone $subrow->{'sub_vars'}->{$funWithArgs};
            @$peekedargs = map {my $subj = $_; $subj =~ s/[\$|\*|\\|@|%|&]+//g; lc($subj) } @$peekedargs;

            foreach my $funarg (@$funargs) {
                if (! grep { $_ eq $funarg } @$peekedargs) {
                    $failMsg .= "Var Mismatch for function $funWithArgs: $funarg not in @$peekedargs\n";
                }
            }
        }

    }
    return {'status' => $failMsg ? 0 : 1, 'message' => $failMsg};

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

SCALAR,SCALARREF,ARRAY,ARRAYREF,HASH,HASHREF,CODEREF,TYPEGLOBREF and OBJECT,STRING,INTEGER,FLOAT,BOOLEAN (the latter five and the REFs are aliases to SCALAR when comparing versus the type detected by PadWalker)

You can also cheat and say MIXED to skip type checks.  Not the way I'd write a sub, but to each their own.

These two strategies are mutually exclusive; having sigils declared for your argument (strategy 1) will obviate it's search in a following block (strategy 2).

=head3 TODO:

recognize types from Type::Tiny or other MOPs
use PPI to enhance detection of args in vanilla perl (make sure they're really from @_).  This way order matters in the args.

=head3 Maybe TODO:

Recognize imported namespaces when named as being explicit statements of what type of OBJECT we want an arg to be under vanilla perl

use PPI to do better inference on data type (using scalar as if HASHREF, etc...) for vanilla perl?
Look into using Perl::Critic::Utils for some of this.

Consider mainline prototypes and signatures, despite their general inferiority to CPAN alternatives?

=head3 Probably Shouldn't TODO:

Infer vanilla types from standard guard clauses (if they exist???) for OBJECT,STRING,INTEGER,FLOAT,BOOLEAN (isa,!looks_like_number,Regexp::Common trickery)
Make the hammer of shame fall when said guard clauses are not detected

=cut

sub coverage_argument_types {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;
    $self->_extract_function_information;
    my ($fun,$funargs,$peekedargs,$argsWithSigils,$failMsg);

    #Use PadWalker to get the declared locals in the function
    foreach my $subrow (@{$podInfo->{'function_maps'}}) {
        #Process each function, be they having args or not
        foreach my $function (@{$subrow->{'all'}}) {
            $funargs = $self->_sub_args($function);
            $subrow->{'sub_vars'} = {} if !exists($subrow->{'sub_vars'});
            $subrow->{'sub_vars'}->{$function} = clone $funargs;
        }


        #Loop over declared functions/args and check against peek_sub results
        foreach my $funWithArgs (keys(%{$subrow->{'args'}})) {
            $funargs     = clone $subrow->{'args'}->{$funWithArgs};
            @$argsWithSigils = grep { m/^[\$|\*|\\|@|%|&]+/g } @$funargs;
            #Replace REF looking args with $ sigils
            @$funargs = map { my $subj = $_; $subj =~ s/^\\[\$|\*|@|%|&]/\$/g; $subj } @$funargs;
            $peekedargs  = clone $subrow->{'sub_vars'}->{$funWithArgs};

            if (!scalar(@$argsWithSigils)) {
                my @podargs = keys(%{$subrow->{'arglist'}});
                #Then we need to look for it in the text blocks that were parsed for this function group.
                #$failMsg .= "Type resolution 1 not implemented for $funWithArgs.\n";
                foreach my $funarg (@$funargs) {
                    if (! grep { lc($_) eq lc($funarg)} @podargs) {
                        $failMsg .= "Var $funarg not documented whatsoever for $funWithArgs!\n";
                    }
                }

                #Check types against peeked arg sigils
                my @podtypes = values(%{$subrow->{'arglist'}});
                #@podtypes = map {} @podtypes;
                my ($moreFunArg,$peekedType,$ptype);
                foreach my $moreFunArg (@$peekedargs) {
                    $peekedType = $moreFunArg;
                    $moreFunArg =~ s/^[\$|\*|@|%|&]//g; #Remove sigil
                    $peekedType =~ s/$moreFunArg$//g;
                    $peekedType =~ s/\$/scalar/g;
                    $peekedType =~ s/@/array/g;
                    $peekedType =~ s/%/hash/g;
                    foreach my $ptype (@podtypes) {
                        if ($ptype ne $peekedType) {
                            if ($peekedType eq 'scalar') {
                                last if grep {$_ eq $ptype} qw{scalarref arrayref hashref coderef typeglobref object integer float boolean string};
                            }
                            $failMsg .= "Type mismatch for arg $moreFunArg of $funWithArgs: got $ptype, expected $peekedType\n";
                        }
                    }
                }
                next;
            } else {
                #Should I make a different message if the sigil was omitted for lone args?
                foreach my $funarg (@$funargs) {
                    if (! grep { $_ eq $funarg } @$peekedargs) {
                        $failMsg .= "Var Type Mismatch for function $funWithArgs: $funarg not in @$peekedargs\n";
                    }
                }

            }
        }

    }
    return {'status' => $failMsg ? 0 : 1, 'message' => $failMsg};

}

=head2 coverage_return_types

Uses PPI to find out the sort of data your function returns, and then looks for an adequate description in a text block following function definition.
Acceptable return types are same as accepted for coverage_argument_types.

=cut

sub coverage_return_types {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;
    $self->_extract_function_information;
    use Test::More;

    return 0 if (reftype($podInfo->{'function_maps'}) || 'undef') ne "ARRAY";
    foreach my $fundef (@{$podInfo->{'function_maps'}}) {
        my $freturn = $fundef->{'returns'};
        foreach my $fun (@{$fundef->{'all'}}) {
            my $returns_ex = $self->_return_types($fun);
            note $fun." :";
            note $freturn;
            diag explain $returns_ex;
        }
    }
    return $self->{'sub_parse'}
}

=head2 coverage_termination

Uses PPI to find spots where your code explicitly croaks/dies/confesses or otherwise goes down in flames!
Returns failure when you do not provide adequate warnings to the user foolish enough to attempt usage of said code.

In general, say the code dies/exits/croaks/confesses on some condition in a text block following function definition and you should be good to go.

=cut

sub coverage_termination {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;
    return 'stub';
}

=head2 coverage_examples

Looks through the verbatim blocks following function definition(s) for examples of said functions' (correct) usage
Basically runs the signature,type, return type and termination coverage algorithms on said verbatim block.

=cut

sub coverage_examples {
    return 'stub';
}

sub _get_more_pods {
    my $self = shift;

    my $package = $self->{package};
    $self->{'last_package'} = $package; #Track this so we can optimize by not calling the extractor twice for the same file
    return $self->{'last_pod'} if ( $self->{'last_package'} eq $self->{'package'} ) && $self->{'last_pod'};

    print "getting pod location for '$package'\n" if TRACE_ALL;
    $self->{pod_from} ||= pod_where( { -inc => 1 }, $package );

    my $pod_from = $self->{pod_from};
    unless ($pod_from) {
        $self->{why_unrated} = "couldn't find pod";
        return;
    }

    print "parsing '$pod_from'\n" if TRACE_ALL;
    my $pod = Pod::Coverage::Extractor::More->new;
    $pod->{nonwhitespace} = $self->{nonwhitespace};
    $pod->parse_from_file( $pod_from, '/dev/null' );

    $self->{'last_pod'} = $pod;
    return $pod || {};
}

sub _extract_function_information {
    my $self = shift;
    my $file = $self->{'package'};
    $file =~ s/::/\//g;
    $file .= '.pm';
    $file = $INC{$file};

    my $Document = PPI::Document->new($file);

    my $subs = $Document->find('PPI::Statement::Sub');

    my ($subvars,$subwords,$subname);
    my ($input_variables,$assignment,@assignats,@kiddos);

    my $subdefs = {};

    foreach my $sub (@$subs) {
        $subwords = $sub->find('PPI::Token::Word') || [];
        for (my $j=1; $j < scalar(@$subwords); $j++ ) {
            $subname = $subwords->[$j]->content if $subwords->[$j - 1]->content eq 'sub';
        }
        $subdefs->{$subname} = {};
        $subdefs->{$subname}->{'args'} = [];
        $subdefs->{$subname}->{'returns'} = [];

        #Ok, so we need a subroutine line with either symbols -> assignment -> (magic (@_) || word (shift))
        $subvars = $sub->find('PPI::Statement::Variable') || [];
        foreach my $var (@$subvars) {
            $assignment = 0;
            $input_variables = [];
            @assignats = ();
            @kiddos = $var->children;
            #Flatten any list assignment into the child array
            for (my $i=0; $i < scalar(@kiddos); $i++) {
                #Replace element at it's index with it's children if it has any
                if ($kiddos[$i]->isa('PPI::Node') ) {
                    splice(@kiddos,$i,1,$kiddos[$i]->children);
                    $i--;
                }
            }

            foreach my $tok (@kiddos) {
                #Figure out which side of assignment we are on
                if ($tok->isa('PPI::Token::Operator') && $tok->content eq '=') {
                    $assignment = 1;
                    next;
                }

                #Figure out what we're assigning to, or from.
                if ($assignment) {
                    #TODO make sure this is a bare shift
                    push(@assignats,$tok->content) if $tok->isa('PPI::Token::Symbol') || ($tok->isa('PPI::Token::Word') && $tok->content eq 'shift') ;
                } else {
                    push(@$input_variables,$tok->content) if $tok->isa('PPI::Token::Symbol');
                }

            }
            $subdefs->{$subname}->{'args'} = $input_variables if scalar(@assignats);
        }

        #Now, to figure out what sort of things these functions are returning.
        my $breaks = $sub->find('PPI::Statement::Break'); #break it up, break it up, break it up...
        push(@{$subdefs->{$subname}->{'returns'}},map {$self->extract_returntypes($_)} @$breaks) if $breaks;

        # The task is threefold.
        # First, break the sub down into conditional blocks, so we can figure out whether the type is MIXED.
        # Next, search for PPI::Statement::Breaks containing PPI::Token::Words with content 'return'.
        # Finally, look for fall-through (PPI::Statement::Variable) returns at the end of subs.
        # Then stuff what we 'think' the return type is into $self->{'sub_parse'}->{$subname}->{'returns'} arrayref.

        #Or, get all the breaks and fall-throughs, and jump up through the parents of the breaks to see if conditional.

        #Check if this has a fall-through (dangling) return.
        my $dangler = undef;
        @kiddos = $sub->children;
        my $last_line = $kiddos[-1];
        while (scalar(@kiddos)) {
            if ($last_line->can('children')) {
                @kiddos = $last_line->children;
                @kiddos = grep {$_->significant} @kiddos;
                if (scalar(@kiddos) && $kiddos[-1]->can('children') ) {
                    $last_line = $kiddos[-1];
                    $last_line->{'is_dangling'} = 1;
                    next;
                }
            }
            @kiddos = ();
        }
        push(@{$subdefs->{$subname}->{'returns'}},$self->extract_returntypes($last_line)) if blessed($last_line) ne 'PPI::Statement::Break';
    }


    return $self->{'sub_parse'} = $subdefs;
}

#TODO Extract return types from VARIABLE or BREAK statements, and return them.
sub extract_returntypes {
    my ($self,$smt) = @_;

    #Filter out irrelevancies
    my @sigs = grep {
        my $subject = $_;
        $subject->significant &&
        !grep {$subject->content eq $_ }  (';','return','my','our','local',':',',')
    } $smt->children;

    #Strip postfix ifs
    for (my $i = 0; $i < scalar(@sigs); $i++) {
        if ( grep { $sigs[$i]->content eq $_ } ('if','unless')) {
            splice(@sigs,$i,scalar(@sigs) - $i);
            last;
        }
    }
    #Handle ternaries
    for (my $i = 0; $i < scalar(@sigs); $i++) {
        if ( grep { $sigs[$i]->content eq $_ } ('?')) {
            splice(@sigs,0,$i + 1);
            last;
        }
    }
    #Get the HASH and ARRAY refs
    for (my $i = 0; $i < scalar(@sigs); $i++) {
        my $class = blessed($sigs[$i]);
        if ($class eq 'PPI::Structure::Constructor') {
            if ($sigs[$i]->start eq '{') {
                $sigs[$i] = 'HASHREF';
            } else {
                $sigs[$i] = 'ARRAYREF';
            }
        } elsif ($sigs[$i]->isa( 'PPI::Token' ) ) {
            $sigs[$i] = $sigs[$i]->content;
            $sigs[$i] =~ s/^'|'$//g if $class eq 'PPI::Token::Quote::Single';
            $sigs[$i] =~ s/^"|"$//g if $class eq 'PPI::Token::Quote::Double';
            #TODO extra processing if blessed($sigs[$i]) eq 'PPI::Token::Symbol'

            # There is a chance this is an argument list.
            # If so grab the class SUPPOSING it's a bless().
            if ( ( ($i - 1) != -1 ) && ( $sigs[$i - 1] eq 'bless' ) ) {
                if ( ($i + 1) < scalar(@sigs) ) {
                    # Then this is a 2 arg bless.
                    $sigs[$i+1] =~ s/^'|'$//g if $class eq 'PPI::Token::Quote::Single';
                    $sigs[$i+1] =~ s/^"|"$//g if $class eq 'PPI::Token::Quote::Double';
                    splice(@sigs,$i - 1, 3, 'CLASS '.$sigs[$i+1]);
                } else {
                    # One-arg bless
                    splice(@sigs,$i - 1, 2, 'CLASS '.$self->{'package'});
                }
                $i--;
            } elsif ((($i+1) < scalar(@sigs)) && ($sigs[$i+1]->content eq '=')) {
                # Handle assignment returns
                splice(@sigs,$i,3,$sigs[$i+2]);
                $i--;
            }

        } elsif (blessed($sigs[$i]) eq 'PPI::Structure::List') {
            #Flatten all the way baybeeee
            my @koolkids = $sigs[$i]->children;
            foreach my $kid (@koolkids) {
                push(@koolkids,$kid->children) if $kid->can('children');
            }
            if (grep {$_->content eq '=>'} @koolkids) {
                $sigs[$i] = 'HASH';
            } else {
                # Ok, this is where it gets a bit interesting.
                # First, reduce 1 element array returns.
                # While this is technically correct, it is not what people normally expect.
                if (scalar($sigs[$i]->children) == 1 && $sigs[$i-1] eq 'bless') {
                    my @kids = $sigs[$i]->children;
                    if (scalar(@kids) == 1 && blessed($kids[0]) eq 'PPI::Statement::Expression') {
                        @kids = grep {
                            my $subject = $_;
                            $subject->significant &&
                            !grep {$subject->content eq $_ }  (';','return','my','our','local',':',',')
                        } $kids[0]->children;
                        splice(@sigs,$i,1,@kids);
                    } else {
                        splice(@sigs,$i,1,$sigs[$i]->children);
                    }
                    $i--;
                } else {
                    $sigs[$i] = 'ARRAY';
                }
            }
        }
    }

    #Ok, if what is left happens to be bless followed by stuffs, let's reduce to class name.

    push (@sigs,'undef') if !scalar(@sigs);

    return @sigs;
}

#Convenience methods to grab bits from the relevant hash
sub _sub_args {
    my ($self,$sub) = @_;
    return $self->{'sub_parse'}->{$sub}->{'args'};
}

sub _return_types {
    my ($self,$sub) = @_;
    return $self->{'sub_parse'}->{$sub}->{'returns'};
}

1;
__END__

=head1 SEE ALSO

L<Pod::Coverage>

L<Pod::Coverage::Extractor::More>
