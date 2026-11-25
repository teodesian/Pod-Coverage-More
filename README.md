# NAME

Pod::Coverage::More - Make sure your POD covers more ground than just subroutines

# VERSION

version 0.003

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

It counts a sub as documented when a `=for Pod::Coverage` line or a `=begin Pod::Coverage` block names it,
as [Pod::Coverage::TrustPod](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3ATrustPod), its parent class, counts it, and then does not check it.

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
The code of a stub, a sub with no signature that reads nothing of `@_`, such as a default that subclasses override,
shows nothing of its arguments, and neither does an XS sub; so the argument checks take their POD on the author's word.
A sub with a signature, even an empty one, declares its arguments, and they are checked.
A sub that a parent class documents counts as documented, as [Pod::Coverage::CountParents](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3ACountParents) counts it,
and the checks compare its own code with the section of the parent.

- **arguments** - each argument that the POD names is a parameter of the sub: a variable assigned from `@_`,
a parameter of a signature, a key of a hash of named arguments, or a parameter that a class builder or a signature module declares.
A parameter with no name, such as the placeholder `$` in `sub check ($self, $)`, takes whatever name the POD gives the argument at its position.
An argument beyond the parameters of the sub still fails.
- **argument\_types** - each argument has a documented type that agrees with the code.  A documented type must be the type that
the code declares or a narrower one, so that the POD never promises that the sub takes what it refuses.
A type that the code only implies by its use of the argument fails only when it contradicts the documented one,
as a hash reference where the code uses an array reference.
The type of a list parameter, such as `@paths`, is `ARRAY` or `HASH`, or else an item that keeps the sigil,
as `=item @paths - Str`, gives the type of each element.
- **returns** - a sub that returns a value says so with a `Returns` paragraph or an `=item Returns`,
and the documented types cover every type that the code returns or declares.
A sub whose POD says that it returns nothing may return the value of a call, such as `$self->SUPER::update(@_)`,
because what the call returns is not in its code; any other value that it returns fails.
A documented parameterization of a type that the code returns, such as `ArrayRef[HashRef]` for `[ map { {...} } @list ]`,
covers it, because the code shows the kind of the value and not what is inside it.
The type of the result of an operator, such as `$x * 2`, is only probable, because an operand of a class that overloads the operator
makes the result an object of that class, as [Math::GMP](https://metacpan.org/pod/Math%3A%3AGMP) does; so such a type fails only when it is of another kind than every documented one
- **termination** - a sub that can die, croak, confess, throw or exit, outside an `eval` or `try`, says so
- **examples** - the section has a verbatim paragraph that calls the sub, by `name(` or `->name`

# METHODS

The other methods of [Pod::Coverage](https://metacpan.org/pod/Pod%3A%3ACoverage), such as `naked`, `covered` and `why_unrated`, work as they do there.

## analysis

The analysis of every sub of the package, as `analyze_package` of [Pod::Coverage::More::Analyzer](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3AAnalyzer) returns it. The package is analyzed once.

Returns HashRef, from the name of each sub to the record of its analysis.

```perl
my $records = $pc->analysis;
```

## coverage

The fraction of the public subs that the POD documents, as [Pod::Coverage](https://metacpan.org/pod/Pod%3A%3ACoverage) rates it, from the headings that [Pod::Coverage::More::Documentation](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3ADocumentation) reads. Nothing when the package has no POD or no public subs, and `why_unrated` says why.

Returns Num, from 0 to 1.

```perl
my $rating = $pc->coverage;
```

## coverage\_argument\_types

The result of the **argument\_types** check, as `coverage_arguments` returns it for its check.

Returns HashRef, with status and message.

```perl
my $result = $pc->coverage_argument_types;
```

## coverage\_arguments

The result of the **arguments** check over every sub: a HASHREF with `status`, true when it passes, and `message`, the messages of its failures, one per line, or undef.

Returns HashRef, with status and message.

```perl
my $result = $pc->coverage_arguments;
print $result->{message} if !$result->{status};
```

## coverage\_examples

The result of the **examples** check, as `coverage_arguments` returns it for its check.

Returns HashRef, with status and message.

```perl
my $result = $pc->coverage_examples;
```

## coverage\_report

The failures of each check, for each public sub that has a section in the POD: a HASHREF from the name of the sub to a HASHREF with `section`, the section that `section_for` returns, and `failures`, a HASHREF from the name of each check in THE CHECKS to an ARRAYREF of the messages of its failures, empty when it passes. The report is made once.  Nothing when there is no POD to rate, and `why_unrated` says why.

Returns HashRef, the report.

```perl
my $failures = $pc->coverage_report->{resize}{failures}{examples};
```

## coverage\_return\_types

The result of the **returns** check, as `coverage_arguments` returns it for its check.

Returns HashRef, with status and message.

```perl
my $result = $pc->coverage_return_types;
```

## coverage\_termination

The result of the **termination** check, as `coverage_arguments` returns it for its check.

Returns HashRef, with status and message.

```perl
my $result = $pc->coverage_termination;
```

## public\_subs

The public subs of the package, as [Pod::Coverage](https://metacpan.org/pod/Pod%3A%3ACoverage) counts them: not private, not imported, and not trusted.

Returns the names of the subs, as a list.

```perl
my @names = $pc->public_subs;
```

## section\_for(name)

The section that documents the sub `name`, as `section_for` of [Pod::Coverage::More::Documentation](https://metacpan.org/pod/Pod%3A%3ACoverage%3A%3AMore%3A%3ADocumentation) returns it: the section in the POD of the package, or else in that of the nearest parent class that documents it. Nothing when no POD documents it.

- name - Str - the name of the sub

Returns HashRef, the section.

```perl
my $section = $pc->section_for('coverage');
```

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

# CONTRIBUTOR

troglodyne-robot <trogbot@troglodyne.net>

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
