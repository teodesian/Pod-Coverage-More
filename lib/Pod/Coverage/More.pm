{

package Pod::Coverage::More;

use strict;
use warnings;

use constant TRACE_ALL => 0;

use Pod::Find qw(pod_where);
use PadWalker qw(peek_sub);
use Clone 'clone';

use base 'Pod::Coverage';

=head1 NAME

Pod::Coverage::More

=head1 SYNOPSIS

Extends Pod::Coverage to handle more things, like whether you are specifying args for your subroutines and whether that matches up with the subroutine's use of @_.
Will also optionally check that you describe your arguments (name them sometime before the next sub is mentioned), and optionally check whether you list it's expected type(s).
Also checks for a description of the return value(s) and it's expected type(s).
Also checks for descriptions of the function possibly causing termination incidents (croak/die,etc).
Also has a kwalitee checker to make sure you didn't forget things like SYNOPSIS, NAME, AUTHOR, COPYRIGHT etc.

For multiple functions described on one line, you can separate them with commas or spaces.  But for arguments, you must use commas; wouldn't want to confuse the copypasters out there.

=head1 METHODS

=head2 coverage

Should do the same thing as Pod::Coverage, but with a slightly more complex algorithm for getting arguments, et cetera.
Used mostly for unit testing purposes (make sure the module is sane).
Much like Pod::Coverage, it supports multiple functions being described per line.

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

=head2 coverage_arguments

Looks for arguments to your functions described.  In general, valid barewords or variable names inside of parens following a function name is expected.
Uses PadWalker's 'peek_sub' routine to check that the names are at least present as declared vars in your subroutine.
Names are not case sensitive, and will attempt to obey declared sigils (see 1. in coverage_argument_types).

TODO: use PPI to verify they are part of @_.
Also, add compatibility for method signatures and so forth.

=cut

sub coverage_arguments {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;
    my ($fun,$funargs,$peekedargs,$failMsg);

    #Use PadWalker to get the declared locals in the function
    foreach my $subrow (@{$podInfo->{'function_maps'}}) {
        #Process each function, be they having args or not
        foreach my $function (@{$subrow->{'all'}}) {
            eval "\$fun = \\&$package::$function";
            if ($@) {
                warn "No such function $package::$function";
                next;
            }
            @$funargs = keys(%{peek_sub($fun)});
            $subrow->{'sub_vars'} = {} if !exists($subrow->{'sub_vars'});
            $subrow->{'sub_vars'}->{$function} = clone $funargs;
        }

        #Loop over declared functions/args and check against peek_sub results
        foreach my $funWithArgs (keys(%{$subrow->{'args'}})) {
            $funargs     = clone $subrow->{'args'}->{$funWithArgs};
            @$funargs    = map { s/[\$|\*|\\|@|%|&]+//g; lc($_) } @$funargs;
            $peekedargs  = clone $subrow->{'sub_vars'}->{$funWithArgs};
            @$peekedargs = map { s/[\$|\*|\\|@|%|&]+//g; lc($_) } @$peekedargs;

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

As usual, the type and varname search is case insensitive.

Recognized types:

SCALAR,SCALARREF,ARRAY,ARRAYREF,HASH,HASHREF,FUNCREF,TYPEGLOBREF,OBJECT

These two strategies are mutually exclusive; having sigils declared for your argument (strategy 1) will obviate it's search in a following block (stragtegy 2).

TODO: recognize types from Type::Tiny or other MOPs

=cut

sub coverage_argument_types {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;
    my ($fun,$funargs,$peekedargs,$argsWithSigils,$failMsg);

    #Use PadWalker to get the declared locals in the function
    foreach my $subrow (@{$podInfo->{'function_maps'}}) {
        #Process each function, be they having args or not
        foreach my $function (@{$subrow->{'all'}}) {
            eval "\$fun = \\&$package::$function";
            if ($@) {
                warn "No such function $package::$function";
                next;
            }
            @$funargs = keys(%{peek_sub($fun)});
            $subrow->{'sub_vars'} = {} if !exists($subrow->{'sub_vars'});
            $subrow->{'sub_vars'}->{$function} = clone $funargs;
        }


        #Loop over declared functions/args and check against peek_sub results
        foreach my $funWithArgs (keys(%{$subrow->{'args'}})) {
            $funargs     = clone $subrow->{'args'}->{$funWithArgs};
            @$argsWithSigils = grep { m/^[\$|\*|\\|@|%|&]+/g } @$funargs;
            #Replace REF looking args with $ sigils
            @$funargs = map { s/^\\[\$|\*|@|%|&]/\$/g; $_ } @$funargs;
            $peekedargs  = clone $subrow->{'sub_vars'}->{$funWithArgs};

            if (!scalar(@$argsWithSigils)) {
                #Then we need to look for it in the text blocks that were parsed for this function group.
                $failMsg .= "Type resolution 1 not implemented for $funWithArgs.\n";
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

sub coverage_return_types {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;

}

sub coverage_termination {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;

}

sub coverage_kwalitee {
    my $self = shift;

    my $package = $self->{package};
    my $podInfo = $self->_get_more_pods;

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

1;

}

{
package Pod::Coverage::Extractor::More;

use strict;
use warnings;

use Pod::Parser;
use base 'Pod::Parser';

use constant debug => 0;

# extract subnames from a pod stream
sub command {
    my $self = shift;
    my ( $command, $text, $line_num ) = @_;
    if ( $command eq 'item' || $command =~ /^head(?:2|3|4)/ ) {

        # take a closer look
        my @pods = ( $text =~ /\s*([^\s\|,\/]+)/g );

        $text =~ s/;|#//g; #Strip semicolons, hashes that's stupid to use in your POD line
        my @args = ( $text =~ /\(\s*([\$|\\|@|%|&|\*|\w*,|\w*|\w*\s*]+)\s*\)/g );
        @args = map { $_ =~ s/\s//g; $_} @args;
        my @funcsWithArgs = ( $text =~ /(\w*)\s*\(\s*[\$|\\|@|%|&|\*|\w*,|\w*|\w*\s*]+\s*\)/g );
        my $textWithOnlyFunctions = $text;
        $textWithOnlyFunctions =~ s/\(\s*[\$|\\|@|%|&|\*|\w*,|\w*|\w*\s*]+\s*\)//g; #Strip args
        $textWithOnlyFunctions =~ s/\w+(?:::\w+)*:://g; #Strip full qualification
        $textWithOnlyFunctions =~ s/\$\w+->//g; # Strip method call on object
        # it's wrapped in a pod style B<>, or some other formatting, strip it
        $textWithOnlyFunctions =~ s/[A-Z]<//g;
        $textWithOnlyFunctions =~ s/>//g;

        my @allFuncs = ();
        #Handle nimrods who separate functions with whitespace
        if ($textWithOnlyFunctions =~ m/,/g) {
            $textWithOnlyFunctions =~ s/\s*//g; #Strip whitespace
            @allFuncs = split(/,/,$textWithOnlyFunctions);
        } else {
            $textWithOnlyFunctions =~ s/^\s*//; #Strip leading whitespace
            $textWithOnlyFunctions =~ s/\s*$//; #Strip trailing whitespace
            @allFuncs = split(/\s/,$textWithOnlyFunctions);
        }

        my @funcsWithoutArgs = grep {defined($_)} map { my $val = $_; (grep {$_ eq $val} @funcsWithArgs) ? undef : $_ } @allFuncs;
        print "$textWithOnlyFunctions\n" if debug;
        print "Found args: @args\n" if debug && scalar(@args);
        print "Found funcs w/args:  @funcsWithArgs\n" if debug && scalar(@funcsWithArgs);
        print "Found funcs wo/args: @funcsWithoutArgs\n" if debug && scalar(@funcsWithoutArgs);

        if (scalar(@funcsWithArgs) == scalar(@args)) {
            @args = map { my @ploot = split( /,/ ,$_); \@ploot } @args;
            my %fargs;
            @fargs{@funcsWithArgs} = @args;
            $self->{'current_function_map'} = {
                'all'    => \@allFuncs,
                'noargs' => \@funcsWithoutArgs,
                'args'   => \%fargs
            };

        } else {
            warn "Mismatch between detected arglist and functions with args list.  This is a bug.";
        }

        $self->{'function_maps'} = [] if !exists($self->{'function_maps'});
        push @{$self->{'function_maps'}}, $self->{'current_function_map'};
        push @{$self->{'identifiers'}}, @allFuncs;
        return;
    }
}

sub textblock {
    my $self = shift;
    my ( $text, $line_num ) = shift;
    if ( $text =~ /\S/) {
        #print $text;
    }
}

1;

}

__END__

=head1 AUTHOR

George S. Baugh <teodesian@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by George S. Baugh.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
