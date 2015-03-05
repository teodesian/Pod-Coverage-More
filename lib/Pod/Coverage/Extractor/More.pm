package Pod::Coverage::Extractor::More;

use strict;
use warnings;

use Pod::Parser;
use Test::Deep::NoTest qw{eq_deeply};
use base 'Pod::Parser';

use constant debug => 0;

# extract subnames from a pod stream
sub command {
    my ( $self, $command, $text, $line_num ) = @_;
    if ( $command eq 'item') {
        #TODO They are args, process...
        my @types = qw{SCALAR SCALARREF ARRAY ARRAYREF HASH HASHREF CODEREF TYPEGLOBREF OBJECT STRING INTEGER FLOAT BOOLEAN MIXED};
        my $argTypeList = {};

        #TODO: Be a bit safer here...
        my @argIndices = keys(%{$self->{'current_function_map'}->{'args'}});
        return if !defined $argIndices[0];
        my @args = @{ $self->{'current_function_map'}->{'args'}->{$argIndices[0]} };
        foreach my $arg (@args) {
            $arg = lc($arg);
            if ( lc($text) =~ /$arg/g ) {
                #Check if it has a type declared
                $argTypeList->{$arg} = '';
                foreach my $type (@types) {
                    $type = lc($type);
                    if (lc($text) =~ /$type/g) {
                        $argTypeList->{$arg} = $type;
                        last;
                    }
                }
                last;
            }
        }

        #Parse text, get types
        foreach my $frow (@{$self->{'function_maps'}}) {
            #XXX Not particularly optimized, but do you really care for POD tests?
            if (eq_deeply($frow,$self->{'current_function_map'})) {
                $frow->{'arglist'} = {} if !exists($frow->{'arglist'});
                @{$frow->{'arglist'}}{keys($argTypeList)} = values($argTypeList);
                last;
            }
        }
        return;
    }
    if ( $command =~ /^head(?:2|3|4)/ ) {

        # take a closer look
        my @pods = ( $text =~ /\s*([^\s\|,\/]+)/g );

        $text =~ s/;|#//g; #Strip semicolons, hashes that's stupid to use in your POD line
        my @args = ( $text =~ /\(\s*([\$|\\|@|%|&|\*|\w*,|\w*|\w*\s*]+)\s*\)/g );
        @args = map { my $subj = $_; $subj =~ s/\s//g; $subj} @args;
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
    return 1;
}

1;

