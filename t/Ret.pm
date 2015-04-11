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
    return ret1;
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

#TODO other useless BS like switch statements, etc

1;