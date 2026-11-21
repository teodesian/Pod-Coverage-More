# NAME

Pod::Coverage::More - Make sure your POD covers more ground than just subroutines

# VERSION

version 0.001

# SYNOPSIS

```perl
use Pod::Coverage::More;

my $pc     = Pod::Coverage::More->new( package => 'Pod::Coverage::More' );
my $report = $pc->coverage_report;
my $acov   = $pc->coverage_arguments;
print $acov->{message} if !$acov->{status};
```

# DESCRIPTION

Extends [Pod::Coverage](https://metacpan.org/pod/Pod%3A%3ACoverage), which makes sure that the POD names each public sub of a module,
to make sure that the POD also says what each sub takes, returns, and how it fails.
It compares what [Pod::Coverage::More::Documentation](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3ADocumentation) reads from the POD
with what [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer) reads from the compiled subs,
and the types that they name as [Type::Tiny](https://metacpan.org/pod/Type%3A%3ATiny) constraints.

[Test::Pod::Coverage::More](https://metacpan.org/pod/Test%3A%3APod%3A%3ACoverage%3A%3AMore) runs these checks as tests.

# WRITING THE POD

A heading names the subs that its section documents, each with an optional argument list,
and an `=item` per argument gives its type.  [Pod::Coverage::More::Documentation](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3ADocumentation) describes the forms in full.

```perl
=head2 resize($width, $height)

=over 4

=item width - Int - in pixels

=item height - Int - in pixels

=back

Returns a Image object.  Dies when either size is not positive.

    my $smaller = $image->resize( 100, 50 );
```

For several functions on one line, separate them with commas or spaces; for arguments, use commas.
An argument list can give the sigils of the arguments, as `($foo, @bar, \%baz)`.
Then the sigils are compared with those of the parameters, and no `=item` is needed.

# THE CHECKS

Each check applies to the public subs that have a section in the POD.
A sub without one is the business of `coverage`.

- **arguments** - each argument that the POD names is a parameter of the sub: a variable assigned from `@_`,
a parameter of a signature, a key of a hash of named arguments, or a parameter that a class builder or a signature module declares
- **argument\_types** - each argument has a documented type that agrees with the code.  A documented type must be the type that
the code declares or a narrower one, so that the POD never promises that the sub takes what it refuses.
A type that the code only implies by its use of the argument fails only when it contradicts the documented one,
as a hash reference where the code uses an array reference.
- **returns** - a sub that returns a value says so with a `Returns` paragraph or an `=item Returns`,
and the documented types cover every type that the code returns or declares.
The type of the result of an operator, such as `$x * 2`, is only probable, because an operand of a class that overloads the operator
makes the result an object of that class, as [Math::GMP](https://metacpan.org/pod/Math%3A%3AGMP) does; so such a type fails only when it is of another kind than every documented one
- **termination** - a sub that can die, croak, confess, throw or exit, outside an `eval` or `try`, says so
- **examples** - the section has a verbatim paragraph that calls the sub, by `name(` or `->name`

# OVERRIDDEN METHODS

## coverage

Returns the fraction of the public subs that the POD documents, as [Pod::Coverage](https://metacpan.org/pod/Pod%3A%3ACoverage) does,
from the headings that [Pod::Coverage::More::Documentation](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3ADocumentation) reads.

# METHODS

## coverage\_report

Returns a HASHREF from the name of each public sub that has a section in the POD to a HASHREF with `section`,
the section that `section_for` of [Pod::Coverage::More::Documentation](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3ADocumentation) returns, and `failures`,
a HASHREF from the name of each check in THE CHECKS to an ARRAYREF of the messages of its failures, empty when it passes.

Returns nothing when there is no POD to rate, and `why_unrated` says why.

## coverage\_arguments

Returns a HASHREF with `status`, true when the **arguments** check passes for every sub, and `message`,
the messages of its failures, one per line, or undef.  The other methods below return the same for their check.

## coverage\_argument\_types

The **argument\_types** check.

## coverage\_return\_types

The **returns** check.

## coverage\_termination

The **termination** check.

## coverage\_examples

The **examples** check.

# SEE ALSO

Please see those modules/websites for more information related to this module.

- [Pod::Coverage](https://metacpan.org/pod/Pod%3A%3ACoverage)
- [Pod::Coverage::More::Documentation](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3ADocumentation)
- [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer)
- [Test::Pod::Coverage::More](https://metacpan.org/pod/Test%3A%3APod%3A%3ACoverage%3A%3AMore)

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
