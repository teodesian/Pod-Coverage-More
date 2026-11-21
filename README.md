# NAME

Pod::Coverage::More - Make sure your POD covers more ground than just subroutines

# VERSION

version 0.001

# SYNOPSIS

```perl
use Pod::Coverage::More;

my $pc    = Pod::Coverage::More->new(package => 'Quux');
my $acov  = $pc->coverage_arguments();
my $atcov = $pc->coverage_argument_types();
```

# DESCRIPTION

Extends Pod::Coverage to handle more things, like whether you are specifying args for your subroutines and whether that matches up with the subroutine's use of @\_.

Will also optionally check that you describe your arguments (name them sometime before the next sub is mentioned), and optionally check whether you list it's expected type(s).

Also checks for a description of the return value(s) and it's expected type(s).

Also checks for descriptions of the function possibly causing termination incidents (croak/die,etc).

Also can check for examples in your POD.

For multiple functions described on one line, you can separate them with commas or spaces.  But for arguments, you must use commas; wouldn't want to confuse the copypasters out there.

# OVERRIDDEN METHODS

## coverage

Should do the same thing as Pod::Coverage, but with a slightly more complex algorithm for getting arguments, et cetera.
Much like Pod::Coverage, it supports multiple functions being described per line.

You should use this if you want to have the rest of the functions here work too, as it has a significant caveat.

### CAVEAT:

item commands are parsed as arguments to subroutines, not as subroutine entries.  This makes strategy 1) in coverage\_argument\_types possible.
It makes sense to me, given arguments are _items_ in _lists_.

# METHODS

## coverage\_arguments

Looks for arguments to your functions described.  In general, valid barewords or variable names inside of parens following a function name is expected.
Uses [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer) to check that the names are parameters of your subroutine:
variables assigned from @\_ or a shift of it, signature parameters, or the keys read from a hash or hashref parameter of named arguments.
Names are not case sensitive, and will attempt to obey declared sigils (see 1. in coverage\_argument\_types).

TODO add compatibility for Function::Parameters and other CPAN signature modules.

## coverage\_argument\_types

Looks for a type to be declared for your arguments described for a particular function.

This can be done one of two ways:

1\. Use standard variable notation in your arglist known by coverage\_arguments (e.g. do ($foo,@bar,%baz,\\$fred,\\@wilma,\\%barney,\\&bam\_bam,\\\*betty) or some variation thereof)

2\. Specify the types by name in an =item block somewhere between it and the next detected subroutine(s).  Example:

```perl
=head2 some_sub(ARG1,ARG2)

does stuff

ARGUMENTS:

=over4

=item B<ARG1> - INTEGER - does something weird

=item B<ARG2> - HASHREF - does something not so weird
...
```

As usual, the type and variable name search is case insensitive.

Recognized types:

SCALAR,SCALARREF,ARRAY,ARRAYREF,HASH,HASHREF,CODEREF,TYPEGLOBREF and OBJECT,STRING,INTEGER,FLOAT,BOOLEAN (the latter five and the REFs are aliases to SCALAR when comparing versus the sigil of the parameter)

You can also cheat and say MIXED to skip type checks.  Not the way I'd write a sub, but to each their own.

These two strategies are mutually exclusive; having sigils declared for your argument (strategy 1) will obviate it's search in a following block (strategy 2).

### TODO:

recognize types from Type::Tiny or other MOPs

### Maybe TODO:

Recognize imported namespaces when named as being explicit statements of what type of OBJECT we want an arg to be under vanilla perl

use the usage that [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer) reports (using scalar as if HASHREF, etc...) to infer the data type in vanilla perl?

### Probably Shouldn't TODO:

Infer vanilla types from standard guard clauses (if they exist???) for OBJECT,STRING,INTEGER,FLOAT,BOOLEAN (isa,!looks\_like\_number,Regexp::Common trickery)
Make the hammer of shame fall when said guard clauses are not detected

## coverage\_return\_types

Uses [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer) to find out the sort of data your function returns, and then looks for an adequate description in a text block following function definition.
Acceptable return types are same as accepted for coverage\_argument\_types.

TODO: the comparison against the POD is not implemented yet.
For now this returns the analysis of every sub in the package, a HASHREF of the records that `analyze_sub` of [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer) returns,
or 0 when the POD names no functions.

## coverage\_termination

Not implemented yet: returns the string `stub`.

It is meant to find the spots where your code explicitly croaks/dies/confesses or otherwise goes down in flames,
from the `dies` that [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer) reports,
and return failure when you do not provide adequate warnings to the user foolish enough to attempt usage of said code.

In general, say the code dies/exits/croaks/confesses on some condition in a text block following function definition and you should be good to go.

## coverage\_examples

Not implemented yet: returns the string `stub`.

It is meant to look through the verbatim blocks following function definition(s) for examples of said functions' (correct) usage.
Basically runs the signature,type, return type and termination coverage algorithms on said verbatim block.

# SEE ALSO

Please see those modules/websites for more information related to this module.

- [Pod::Coverage](https://metacpan.org/pod/Pod%3A%3ACoverage)
- [Pod::Coverage::Extractor::More](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AExtractor%3A%3AMore)
- [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer)

# BUGS

Please report any bugs or feature requests on the bugtracker website
[https://github.com/teodesian/Pod-Coverage-More/issues](https://github.com/teodesian/Pod-Coverage-More/issues)

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHORS

Current Maintainers:

- George S. Baugh <teodesian@cpan.org>

# CONTRIBUTORS

- George S. Baugh <george@troglodyne.com>
- George S. Baugh <george@troglodyne.net>
- troglodyne-robot <trogbot@troglodyne.net>

# COPYRIGHT AND LICENSE

Copyright (c) 2014-2026 George S. Baugh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
