# AGENTS.md - CLI::Cmdline.pm Development Guide

## Build Commands

```bash
# Initial setup
perl Makefile.PL

# Build the module
make

# Run all tests
make test

# Run tests with verbose output
make test TEST_VERBOSE=1

# Run a single test file
prove -v t/01-basic.t

# Run a single test with prove
prove -v t/02-alias.t

# Run all .t files in t/ directory
prove -v t/*.t

# Install the module
make install

# Clean build artifacts
make clean
```

## Test Framework

- **Framework**: Test::More with `done_testing()`
- **Runner**: `prove` for individual tests, `make test` for distribution
- **Test files**:
  - `t/00-load.t` - Module loading test
  - `t/01-basic.t` - 162 tests for basic functionality
  - `t/02-alias.t` - 27 tests for alias features
  - `t/03-complex.t` - 28 tests for edge cases
  - `t/04-error.t` - 27 tests for error handling
  - `t/05-integration.t` - 24 tests for script integration
  - `xt/release/kwalitee.t` - CPAN kwalitee tests

## Code Style Guidelines

### General
- **Perl version**: 5.010 minimum (use 5.010)
- **Strict/warnings**: Always enabled
- **Indentation**: 4 spaces (no tabs)
- **Line endings**: Unix (LF)

### Module Structure
```perl
#!/usr/bin/perl
package CLI::Cmdline;

use strict;
use warnings;
use 5.010;
use Exporter 'import';

our @EXPORT_OK = qw(parse);
our $VERSION   = '1.23';

# Pod documentation starts after version
# Main code functions after __END__
```

### Imports
- Core: `strict`, `warnings`, `5.010`
- Optional: `Exporter 'import'` if exporting functions
- Pragmas first, then modules, then exports

### Naming Conventions
- **Packages**: `CLI::Cmdline` (Capitalized, double-colon separator)
- **Functions**: `parse` (lowercase, action-oriented)
- **Private subs**: `_process_spec`, `_check_match` (underscore prefix)
- **Variables**: `%opt`, `$switches`, `$options` (descriptive, lowercase)
- **Constants**: `@EXPORT_OK`, `$VERSION` (uppercase)

### Pod Documentation
- Use `=head1 NAME`, `=head1 VERSION`, `=head1 SYNOPSIS`, `=head1 DESCRIPTION`
- Use `=head2` for subsections
- Include `=over`/`=back` for bullet lists
- End with `=cut`

### Error Handling
- Return `1` on success, `0` on error
- Restore `@ARGV` on error
- Let caller handle `or die` for fatal errors
- No exceptions in parsing logic

### Hash Operations
- Use hash slices: `@{$ph}{@$pasw_missing} = (0) x @$pasw_missing`
- Use `exists` before accessing
- Check `ref` for array vs scalar handling

### Regex Patterns
- Capture groups: `if ($arg =~ /^--([^=]+)=(.*)$/)`
- Use `//r` for non-destructive substitutions
- Single-quote regex unless interpolation needed

### Test Patterns
```perl
sub run_test {
    my ($desc, $argv, $sw, $opt, $init, $expect_p, $expect_argv, $expect_ret) = @_;
    local @ARGV = @$argv;
    my %p = %$init;
    my $ret = CLI::Cmdline::parse(\%p, $sw // '', $opt // '');
    is($ret, $expect_ret, "$desc: return");
    is_deeply(\%p, $expect_p, "$desc: params");
    is_deeply(\@ARGV, $expect_argv, "$desc: ARGV");
}
```

### Key Patterns
- **Switches** (no argument): increment on repeat, default to 0
- **Options** (require argument): take next arg or `=` value, default to ''
- **Aliases**: use `|` syntax, first name is canonical
- **Bundling**: single letters can bundle, last can take argument
- **`--`**: terminates option processing, preserves remaining args

## Adding New Features

1. Add tests to existing `.t` files or create new test file
2. Update main module in `lib/CLI/Cmdline.pm`
3. Update `Makefile.PL` if new dependencies added
4. Update `README.md` with usage examples
5. Update `Changes` file with version notes
6. Run `make test` to verify

## Common Commands

```bash
# Run all tests
make test

# Check module loads correctly
perl -MCLI::Cmdline -e 'print $CLI::Cmdline::VERSION'

# Run specific test with verbose output
prove -v t/04-error.t

# Test with Devel::Cover (if installed)
cover -test
```
