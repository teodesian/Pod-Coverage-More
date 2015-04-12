package Ret;

use strict;
use warnings;

#Test base returns
sub ret1 {
    return 1;
}

sub ret2 {
    return undef;
}

sub ret3 {
    return;
}

sub ret4 {
    my $sym;
    return $sym;
}

#Fall-through return
sub ret5 {
    my @otherSym;
}

#Compound data types
sub ret6 {
    return [1,2,3];
}

sub ret7 {
    return (1,2,3);
}

sub ret8 {
    return { 'a' => 'b', 'c' => 'd' };
}

sub ret9 {
    return ( 'a' => 'b', 'c' => 'd' );
}

#Check objects
sub ret10 {
    return bless('a','someClass');
}

#The big kahuna -- walk functions
sub ret11 {
    return ret1('a','b');
}

#Test conditional returns
sub ret12 {
    if (1) {
        return 1;
    } else {
        return 0;
    }
}

sub ret13 {
    unless (1) {
        return 1;
    } else {
        return 0;
    }
}

sub ret14 {
    return 'whee' if 1;
    return "zop";
}

sub ret15 {
    return 'eee' unless 1;
    return 0 ? 'nny' : 'wnnh';
}

sub ret16 {
    return bless 'whee', 'eee';
}

sub ret17 {
    return (bless 'whee', 'eee');
}

sub ret18 {
    return bless 'ehee';
}

sub ret19 {
    return bless('a','b');
}

#Test stupid things like assignment as the return (common in oo)
sub ret20 {
    return my $nugs = 'gravy';
}

#TODO other useless BS like switch statements, etc

1;
