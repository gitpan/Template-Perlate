#!/usr/bin/perl

use strict;
use warnings;

=pod

=head1 NAME

Template::Perlate - Template module using Perl as the langauge.

=head1 SYNOPSIS

	use Template::Perlate;

	$Template::Perlate::defaults->{...} = ...;

	print Template::Perlate::main($options);

To catch errors, wrap calls to this module in eval{} and check $@.

=head1 DESCRIPTION

This module provides a simple translation system for writing files that are
mostly text, TeX, HTML, XML, an email message, etc with some Perl code
interspersed.  The input files use [[ and ]] to mark the beginning and end of
Perl code.  Text outside of these tags is returned without modification (except
for the effects of conditional statements or loops contained in surrounding
tags of course).  PHP users will notice the similarity to the <? ?> tags used
by PHP to separate code from literal text.

A template written in this style is called a "perlate".  In contrast, "Perlate"
is the name of this module.

This approach provides the simplicity of using a language you're accustomed to
(Perl) for logic, rather than inventing a trimmed-down language.  Admittedly
that means you must exercise restraint in separating logic and text.  However,
this approach is faster (in execution) and less bug-prone since it uses a
well-developed compiler and language you already know well.  Many argue that an
unrestrained programmer will find a way to shoot themselves despite the best
efforts of the language to prevent it.  If you agree, Perlate is for you.

=head1 WRITING PERLATES

As HTML is a common use for Perlate, the following examples show HTML code
outside the tags.  The Perl code is surrounded in [[ ]] tags.  There is no
preamble or postscript; the file is otherwise indistinguishable from its
output.  For example, the following is a valid perlate:

	<html><body>
	[[ if($_params->{enabled}) { ]]
		Enabled = [[ _get "enabled"; ]]
	[[ } ]]
	</body></html>

Note that statements that normally end in a semicolon must include the
semicolon as shown.

Perlate declares some variables and functions for you in the setup code.  All
symbol names prefixed with an underline are reserved.  So far, the following
are available for your use:

=over

=item * _echo() emits the expressions passed to it.

=item * _get() emits the parameters named by the arguments.  _get("foo") is the
same as _echo($params->{foo}) and _echo($_options->{params}{foo}).

=item * _echoifdef() and _getifdef() are the same as _echo() and _get() except
they prevent warnings about undefined values.

=item * $_options is a copy of the same hash passed by the caller, with any
default settings (from the global variable $defaults) added to it.  Options
tell Perlate.pm what to do (what source file to load, what to do with the
output, etc).

=item * $_params is a convenient alias of $_options->{params}.  This contains
input parameters to your perlate.

=back

A more interesting example of using Perlate follows.  The following is an
example Perl program that calls a perlate:

	#!/usr/bin/perl
	use strict;
	use warnings;
	use Template::Perlate;
	eval {
		print Template::Perlate::main({
			input_file => "my.html.perlate",
			params => {
				enabled => 1,
				times => 6,
				message => "Display this 6 times.",
			},
		});
	};
	if($@) {
		print STDERR "An error occurred:  $@\n";
	}

The file my.html.perlate may contain:

	<html><body>
	[[- if($_params->{enabled}) { ]]
		Enabled.<br />
		[[- for(my $count = 0; $count < $_params->{times}; $count++) { ]]
		[[ _get "message"; ]]<br />
		[[- } ]]
	[[- } ]]
		[[ _echo "This was repeated $_params->{times} times."; ]]<br />
	</body></html>

Some of the tags in the example have a leading hyphen.  This signals Perlate to
remove one line of whitespace in the source before the tag.  One trailing
hyphen means to remove one line of whitespace after the tag.  N hyphens removes
up to N lines, and a plus removes all blank lines.  Removal always stops at the
first nonblank line.  Next, there may be an octothorpe (#), which indicates
that the entire tag is a comment.  A tag cannot contain both code and comments
(see caveat below).  To summarize, the tags have the following syntax (note the
position of the required whitespace):

	\[\[(\-*|\+)#?\s.*\s(\-*|\+)\]\]

The strange indentation in the example above is designed to maintain the
indentation levels of the output.  Flow control statements strip one line of
leading whitespace and are indented independently of the HTML code and output
statements.  This is simply a suggested style.  Feel free to invent your own.

While you don't need to know the internals to use Perlate, it may be useful to
understand the basic approach.  It translates the perlate into a single string
containing Perl code, surrounds it with a bit of setup and tear-down code, then
eval's the string to create a new package, then calls the package's _main()
function.  The setup code includes a "package" statement and
"sub _main {".  The text between the tags is quoted and rewritten as a call to
the _echo function.  This way the user can open a lexical scope in one tag and
close it in a later one, for example, to conditionally emit certain text or to
repeat a block of text in a loop.  A perlate is only eval'd once.  Subsequent
calls to it simply call _main() again.  (This is the reason it is wrapped in a
function declaration.)  Perl allows function declarations inside of functions,
so it's valid to define a function in a perlate that's called by other parts of
the same perlate.  This can be useful on a web page, for example, if there is a
bit of HTML code that needs to be repeated in several places.  (If this doesn't
quite make sense, try executing the code above with the I<preprocess_only>
flag.)

=head2 A NON-COMMENT TAG MAY NOT CONTAIN ANY COMMENTS.

A comment in the perlate code will screw up later tags on the same line.  The
only correct way to insert a comment is to use [[# comment ]] with no
whitespace between [[ and #.  This tells Perlate that the whole tag should be
ignored even if it contains newlines.

Consider:  [[ # foo ]] some HTML [[ _echo('bar'); ]]

These two tags have no newline between them, so the whole line will be a
comment, rather than just the first tag.  Obviously, a coder would expect the
comment to end where the tag ends.  At best, this causes a syntax error when
Perlate tries to eval the code.  (If this doesn't quite make sense, try adding
a comment to a simple perlate and run it with the I<preprocess_only> flag.)  We
can't just insert a newline after every tag, because that would screw up the
line numbers reported by Perl errors and warnings in the final eval.  Sadly,
Perl's grammar is so complex that parsing out comments would entail parsing
most of Perl.  So we arrive at this caveat:

A NON-COMMENT TAG MAY NOT CONTAIN ANY COMMENTS.

=head1 OPTIONS

There are some options available in $options.  Defaults for these options can
be specified as a hash in the global variable $defaults.  For options where it
makes sense, the default is combined with the passed options.  For example, a
default perlate input file can be specified instead of passing an explicit
filename with every call.  When used with Apache and mod_perl, for example,
setting defaults can be useful in a PerlRequire script.

Several options are available:

=over

=item * $options->{input_file} specifies a filename to read the perlate from.
Overrides both the input_file and input_string defaults.  If the filename is
absolute (begins with a slash), the path and correct directory are not
searched.  See also $options->{path}.

=item * $options->{input_string} specifies the source for a perlate as a
literal string.  Overrides both the input_file and input_string defaults.

=item * $options->{params} contains the input parameters to the perlate itself.
These can be emitted into the perlate's output by calling _get("param name") or
they can be accessed through the $_params hash.  Default parameters are added
to this hash, but do not override values set in $options->{params}.

=item * $options->{path} may be set to an array of directory names to search.
$defaults->{path} is always searched after that.  When you add paths to
$defaults->{path}, your code may work better with future code of yours if you
unshift them onto the array rather than using direct assignment.  The search
order is always:  current directory, $options->{path}, $defaults->{path}, @INC.
The path option as seen from inside the perlate (called $_options->{path})
includes all of these directories.

=item * $options->{rawperl} may be set to true to indicate that the whole file
is Perl code without [[ ]] tags.  This is useful for using parameter passing
and searching $options->{path}.  This is probably not going to be useful very
often, except perhaps for debugging.

=item * $options->{preprocess_only} may be set to true to return the
preprocessed file without executing (or caching) anything.  This is probably
only useful for debugging, unless you want to rely on the existence of _main(),
which is subject to change.  At times, this can explain why Perl is reporting a
syntax error.

=back

=head1 OTHER FEATURES & NOTES

The @INC list of directories is automatically appended to the search path.
This means you can put perlates in your lib directory beside any modules that
call them.  After all, a perlate represents a module (in a loose sense).  A
common approach in large web applications uses a small index.pl file to call a
module containing all the real logic (so that mod_perl caches the bulk of the
compilation and to avoid warnings about redefined functions).  Searching @INC
fits in nicely with that design.

Assign a true value to $Template::Perlate::debug to see some debugging
information.

=head1 CAVEATS

As described above, perlates may be specified by name, or the contents of an
unnamed perlate may be passed directly.  Naming a file is preferable because
Perlate will compile it only once unless it is modified.  The device number,
inode number, and modification time are used to uniquely identify the specified
file.  Without caching, the memory usage will grow slightly with each
execution, since there is no way to unload a module from memory, and each
perlate is loaded more or less like any regular Perl module.  Please email the
author if you know of a reasonable way to free that memory.

Of course, general programming wisdom holds that global variables are usually a
bad approach.  In a perlate, they are worse than usual for several reasons.
First, their contents is never freed, since Perl doesn't provide an easy way
for the package and its contents to be removed from memory.  Second, a
perlate's package is reused when possible, but that is not guaranteed.  A
global variable will maintain its value if and only if the package is reused.
A perlate will be recompiled under a new package name, for example, if the
file's modification time changes.  This can easily lead to a perlate acting
inconsistently on subsequent executions.  If you really need a global variable,
the best way to get around these problems is to give it an explicit package
name that you control, such as the package name of the caller.

Errors and warnings usually report the line number they occurred on.  However,
Perl seems easily confused over line numbers in an eval.  Often line 1 or the
last line will be erroneously reported as the error point.  Perlate is careful
to keep the position of newlines correct (even when stripping blank lines), but
as Perl sometimes gets confused this isn't always helpful.

The "use strict;" and "use warnings;" pragmas are applied to all perlates.
This is not optional.  If you insist on writing bad code, you can write "no
strict; no warnings;" to explicitly turn those off.

This has NOT been tested with threading, which probably means it might not work
with Apache 2.  However, I'd be happy to fix any problems with threading, if
you send me a bug report.

Again, be careful not to put comments in tags unless the whole tag is marked as
a comment, as described above.

Recursive templates are supported.

=head1 INSTALLATION

Simply copy this file to .../lib/perl5/site_perl/5.x.x/Template/Perlate.pm .

This module has no dependencies besides Perl itself.

=head1 VERSION & HISTORY

=over

=item * Version 0.90, released 2007-03-02.  This is likely to be identical to
version 1.0.  Version 1.0 may contain incompatible changes, but this is
unlikely unless anyone suggests a really good reason.

=back

=head1 AUTHOR

Leif Pedersen <bilbo@hobbiton.org>

Please send suggestions and bugfixes to this address.  Even if you have nothing
to contribute, please send a quick message.  I'd like to get an idea of how
many people use this software.  Thanks!

=head1 LICENSE

This may be distributed under the terms below (BSD'ish), or the same terms as
Perl, or under the GPL.

Copyright (C) 2006-2007 Leif Pedersen. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.

=cut


package Template::Perlate;

our $debug;

sub main {
	my ($options) = @_;

	# Copy input data for modification
	$options = {%$options};
	$options->{params} = {%{$options->{params} or {}}};
	$options->{path} = ['.', @{$options->{path} or []}];

	our $defaults;
	foreach my $default (keys %$defaults) {
		if($default eq 'params') {
			# Override default params with specified params.
			%{$options->{$default}} = (
				%{$defaults->{$default}},
				%{$options->{$default}},
			);
		} elsif($default eq 'path') {
			# Search specified path before default path.
			push @{$options->{$default}}, @{$defaults->{$default}};
		} elsif($default eq 'input_file' or $default eq 'input_string') {
			# input_file and input_string are both overridden by specifying either in $options.
			$options->{$default} = $defaults->{$default} unless exists $options->{input_file} or exists $options->{input_string};
		} else {
			$options->{$default} = $defaults->{$default} unless exists $options->{$default};
		}
	}

	# Add @INC to search path.
	push @{$options->{path}}, @INC;

	# $package_name is unique for each execution.  This allows perlates to recurse
	# (otherwise, recursion would clobber $_params, for example!) simply by calling
	# this module again.  Also, this prevents sub names from conflicting; since all
	# subs are public and named at the root of the current package (not in the
	# current lexical scope), if the code declares a sub named main() in a simple
	# eval with no package statement, it will replace this module's main() on the
	# next execution!  Also, this allows us to cache compilations of a module;
	# after eval'ing to compile the perlate, it can be executed multiple times by
	# calling ${package_name}::_main() multiple times.
	#
	# The unfortunate side-effect is that these packages are never destroyed, so
	# they are a memory leak because global variables in the namespace and Perl's
	# infrastructure for the namespace itself are never freed, even if they are not
	# used again.  (I think all modules that do this have that problem though.)
	# The silver lining is that it would be terrible style to declare globals
	# inside perlates anyway, and reused compilations don't leak.
	#
	# Caching is done by simply reusing the package created during the first run.
	# Each package is uniquely identified, if possible.  (If not, it can't be
	# reused.)

	my $input;
	my $package_name;
	my $compiled;  # True if cached package found
	if(defined $options->{input_string}) {
		# input from a string
		$input = $options->{input_string};
	} elsif(defined $options->{input_file}) {
		# input from a filename
		my $filename = $options->{input_file};

		my $fh;
		if($filename =~ qr~^/~s) {
			# Use absolute path.
			print STDERR "Using absolute path:  ${filename}.\n" if $debug;
			open($fh, "<", $filename) or die "${filename}:  $!";
		} else {
			# Search path for relative name.
			print STDERR "Search path is:\n\t", join("\n\t", @{$options->{path}}), "\n" if $debug;
			foreach my $path (@{$options->{path}}) {
				print STDERR "Searching path:  ${path}/${filename}..." if $debug;
				if(-e "${path}/${filename}") {
					print STDERR "found\n" if $debug;
					open($fh, "<", "${path}/${filename}") or die "${path}/${filename}:  $!";
					last;
				}
				print STDERR "not found\n" if $debug;
			}
			unless($fh) {
				die "$filename:  not found in search path";
			}
		}

		# Use the device number, inode number, and mod time to uniquely identify this file in our cache.
		my @stat = stat($fh);
		if(@stat) {
			$package_name = __PACKAGE__ . "::CachedFile::" . $stat[0] . '_' . $stat[1] . '_' . $stat[9];
			print STDERR "Using package name ${package_name}.\n" if $debug;
			$compiled = eval "\$${package_name}::_compiled";
		}

		if(not $compiled or $options->{preprocess_only}) {
			local $/ = undef;
			$input = <$fh>;
		}
	} else {
		die "No input specified";
	}

	# Use a temp package name unless one was assigned above.
	unless(defined $package_name) {
		our $run_count;
		if(defined $run_count) { $run_count++; } else { $run_count = 0; }
		$package_name = __PACKAGE__ . "::Uncached::${run_count}";
	}

	# Untaint input.  If it was read from a file, it'll be tainted.  It seems
	# reasonable to simply trust that the caller won't pass untrusted input as a
	# perlate.
	if(defined $input) {
		$input =~ qr/^(.*)$/s or die "Can't happen!";
		$input = $1;
	}

	# XXX: This should add the name of the perlate to warnings, as the logic above
	# adds it to dies.  Is there a reasonable way to do this?
	my $out = eval {
		if($options->{preprocess_only}) {
			return preprocess($input);
		}
		unless($compiled) {
			$input = preprocess($input) unless $options->{rawperl};
			compile($package_name, $input);
		}
		return run($package_name, $options);
	};
	if($@) {
		if(defined $options->{input_file}) {
			die $options->{input_file} . ':  ' . $@;
		}
		die $@;
	}
	return $out;
}

# Figure out what line we're on -- only used for reporting errors
sub get_linenum {
	my ($code_chunks) = @_;

	my $linenum = "@$code_chunks";
	$linenum =~ s/[^\n]//sg;
	$linenum = length $linenum;
	return $linenum;
}

# This translates $input into eval'able code, but does not add any supporting
# code.
sub preprocess {
	my ($input) = @_;

	# Push all the chunks of code onto an array, then join it at the end.  This is
	# more efficient that concatenating as we go.

	my @code_chunks = ();

	until($input eq '') {
		unless($input =~ s/^(.*?)\[\[(\-*|\+)(#?)(\s.*?\s)(\-*|\+)\]\]//s or $input =~ s/^(.*)$//s) {
			die "Can't happen:  didn't match a regex";
		}
		my $text = $1;
		my $strip_pre = $2;
		my $comment_flag = $3;
		my $code = $4;
		my $strip_post = $5;

		# Some checking to help find typos

		if($text =~ qr/(\[\[.*)/s) {
			# $text contains [[
			my $tag = $1;
			my $linenum = get_linenum(\@code_chunks);
			if(not $tag =~ qr/^\[\[(\-*|\+)#?\s/s) {
				# [[ would've matched the RE at the top of this loop if it were in this format.
				die "Invalid tag after line ${linenum}, missing space after [[ near $tag";
			} elsif($tag =~ qr/\]\]/s) {
				# ]] would've matched the RE at the top of this loop if there were a space
				# before it.
				die "Invalid tag after line ${linenum}, missing space before ]] near $tag";
			} elsif(not $tag =~ qr/\]\]/s) {
				die "Invalid tag after line ${linenum}, missing ending ]] near $tag";
			}
			die "Invalid tag near after ${linenum}, near $tag (but I don't know why it's invalid)";  # shouldn't happen
		}

		if($text =~ qr/(.*?\]\])/s) {
			# $text contains ]].
			my $linenum = get_linenum(\@code_chunks);
			die "Invalid tag after line ${linenum}, extraneous ]] near $1";
		}

		if(defined $code and $code =~ qr/^(.*?\]\])/s) {
			# $code contains ]].  This wouldn't slip through unless it didn't match the RE
			# at the top of this loop.
			my $tag = '[[' . $strip_pre . $1;
			my $linenum = get_linenum(\@code_chunks);
			die "Invalid tag after line ${linenum}, missing space before ]] near $tag";
		}

		if(defined $code and $code =~ qr/\[\[/s) {
			# $code contains [[.  There would only be another [[ if there's a missing ]].
			my $tag = '[[' . $strip_pre . $code;
			my $linenum = get_linenum(\@code_chunks);
			die "Invalid tag after line ${linenum}, missing ending ]] near $tag";
		}

		# Strip space as specified by the tag modifiers
		my $stripped;

		$stripped = '';
		if(defined $strip_pre) {
			# $strip_pre contains indications from the beginning of the tag about whether
			# to strip newlines from the text before the tag.  Text generated by the tag is
			# never stripped.
			if($strip_pre eq '+') {
				# A plus behaves just like an infinite number of minuses
				$text =~ s/((\r?\n[ \t]*)*)$//s;
				$stripped = $1;
			} else {
				# A minus means strip one newline and the whitespace after it.  Multiple
				# minuses strip multiple newlines.  More minuses than newlines is not an error.
				my $num = length($strip_pre);
				$text =~ s/((\r?\n[ \t]*){0,$num})$//s;
				$stripped = $1;
			}
		}

		# Change $text into eval'able code and append to eval string
		if(defined $text and $text ne '') {
			$text =~ s/'/'."'".'/sg;
			$text =~ s/\\/'."\\\\".'/sg;
			$text = "_echo('$text');";
			push @code_chunks, $text;
		}

		# Hide stripped newlines between statements to keep line numbers consistent
		push @code_chunks, $stripped;

		$stripped = '';
		if(defined $strip_post) {
			# $strip_post contains indications from the end of the tag about whether to
			# strip newlines from the text after the tag.  Text generated by the tag is
			# never stripped.
			if($strip_post eq '+') {
				# A plus behaves just like an infinite number of minuses
				$input =~ s/^(([ \t]*\r?\n)*)//s;
				$stripped = $1;
			} else {
				my $num = length($strip_post);
				$input =~ s/^(([ \t]*\r?\n){0,$num})//s;
				$stripped = $1;
			}
		}

		# Interpret $code
		if(defined $code and $code ne '') {
			if($comment_flag) {
				# It's a comment, so don't append $code.  However, insert newlines anyway to
				# keep line numbers consistent.
				$code =~ s/[^\n]//sg;
			}
			push @code_chunks, $code;
		}

		# Hide stripped newlines between statements to keep line numbers consistent
		push @code_chunks, $stripped;
	}

	# Add the setup and tear-down cruft.
	@code_chunks = (
		'use strict; use warnings;',

		# These variables interface with external code.
		'our (@_out, $_options, $_params, $_compiled);',

		# Calling _echo() is the only way code emits output.
		'sub _echo { push @_out, @_; }',

		# Extra convenience functions.
		'sub _echoifdef { foreach (@_) { _echo $_ if defined $_; } }',
		'sub _get { foreach (@_) { _echo $_params->{$_}; } }',
		'sub _getifdef { foreach (@_) { _echo $_params->{$_} if defined $_ and defined $_params->{$_}; } }',

		# Encapsulate the execution in a function so we can call it multiple times (to
		# support caching).
		'sub _main {',

		# Localize @_out to ensure it frees the memory before returning.  This is also
		# important to ensure reentrancy for recursion.
		'local @_out = ();',

		@code_chunks,

		'return join("", @_out); } $_compiled = 1;',
	);

	# Join with spaces between statements.
	return "@code_chunks";
}

sub compile {
	my ($package_name, $input) = @_;

	# Compile the code, but don't run it.  Run it later by calling
	# ${package_name}::_main().

	clean_eval("package ${package_name}; $input");

	return ();
}

sub run {
	my ($package_name, $options) = @_;

	my $out;

	# Insert shared variables.  Localize them to ensure it frees the memory before
	# returning.  This is also important to ensure reentrancy for recursion.
	eval "
		local \$${package_name}::_options = \$options;
		local \$${package_name}::_params = \$options->{params};

		# RUN THE CODE
		(\$out) = clean_eval(\"\${package_name}::_main();\");
	";
	die $@ if $@;

	# XXX:  We should mitigate the memory leak problem by undef'ing globals at the
	# end by looping through %{$package_name::} rather than just these.  Can we use
	# a trick like that to also delete the namespace itself?  Of course, this
	# should only be done on uncached perlates.

	return $out;
}

# This is a separate sub because all its local variables become shared with the
# eval'd code.
sub clean_eval {
#print STDERR "--------------------------------\n@_\n--------------------------------\n";
	@_ = eval "@_";
	die $@ if $@;
	return @_;
}

1;
