#!/usr/bin/perl
package CLI::Cmdline;

use strict;
use warnings;
use 5.010;
use Exporter 'import';
use Carp;

our @EXPORT_OK = qw(parse);
our $VERSION   = '1.19';

=encoding utf8

=head1 NAME

CLI::Cmdline - Minimal command-line parser with short and long options in pure Perl

=head1 VERSION

1.19

=head1 SYNOPSIS

    use CLI::Cmdline qw(parse);

    my $switches = '-v -q --help --dry-run';
    my $options  = '--input --output --config --include';

    # only define options which have no default value 0 or '';
    my %opt = (
        include => [],         # multiple values allowed
        config  => '/etc/myapp.conf',
    );

    CLI::Cmdline::parse(\%opt, $switches, $options)
        or die "Usage: $0 [options] <files...>\nTry '$0 --help' for more information.\n";

    # @ARGV now contains only positional arguments
    die " .... "   if $#ARGV < 0 || $ARGV[0] ne 'file.txt';

=head1 DESCRIPTION

Tiny, zero-dependency command-line parser supporting short/long options,
bundling, repeated switches, array collection, and C<--> termination.

=over 4

=item * Short options: C<-v>, C<-vh>, C<-header>

=item * Long options: C<--verbose>, C<--help>

=item * Long options with argument: C<--output file.txt> or C<--output=file.txt>

=item * Single-letter bundling: C<-vh>, C<-vvv>, C<-vd dir>

=item * Switches counted on repeat

=item * Options collect into array only if default is ARRAY ref

=item * C<--> ends processing

=item * On error: returns 0, restores @ARGV

=item * On success: returns 1

=back

=head1 EXAMPLES

=head2 Minimal example – switches without explicit defaults

You do not need to pre-define every switch with a default value.
Missing switches are automatically initialized to C<0>.

    my %opt;
    parse(\%opt, '-v -h -x')
        or die "usage: $0 [-v] [-h] [-x] files...\n";

    # After parsing ./script.pl -vvvx file.txt
    # %opt will contain: (v => 3, h => 0, x => 1)
    # @ARGV == ('file.txt')

=head2 Required Options

To make an option required, declare it with an empty string default and check afterward:

    my %opt = ( mode => 'normal');
    parse(\%opt, '', '--input --output --mode')
        or die "usage: $0 --input=FILE [--output=FILE] [--mode=TYPE] files...\n";

    die "Error: --input is required\n"   if ($opt{input} eq '');

=head2 Collecting multiple values, no default array needed

If you want multiple occurrences but don't want to pre-set an array:

    my %opt = (
        define => [],        # explicitly an array ref
    );

    parse(\%opt, '', '--define')
        or die "usage: $0 [--define NAME=VAL ...] files...\n";

    # ./script.pl --define DEBUG=1 --define TEST --define PROFILE
    # $opt{define} == ['DEBUG=1', 'TEST', 'PROFILE']

    # Alternative: omit the default entirely (parser will not auto-create array)
    # If you forget the [] default, repeated --define will overwrite the last value.

=head2 Realistic full script with clear usage message

    #!/usr/bin/perl
    use strict;
    use warnings;
    use CLI::Cmdline qw(parse);

    my $switches = '-v -q --help --dry-run -f';
    my $options  = '--input --output --mode --tag';

    my %opt = (
        mode    => 'normal',
        tag     => [],            # multiple tags allowed
    );

    parse(\%opt, $switches, $options)
        or die <<'USAGE';
Usage: process.pl [options] --input=FILE [files...]

Options:
  -v                        Increase verbosity (repeatable)
  -q                        Suppress normal output
  --dry-run                 Show what would be done
  -f                        Force operation even if risky
  --input=FILE              Input file (required)
  --output=FILE             Output file (optional)
  --mode=MODE               Processing mode (normal|fast|safe)
  --tag=TAG                 Add a tag (multiple allowed)
  --help                    Show this help message

Example:
  process.pl --input=data.csv --output=result.json --tag=2026 --tag=final -vv
USAGE

    if ($opt{h}) {
        print <<'HELP';
Full documentation goes here...
HELP
        exit 0;
    }

    if (!defined $opt{input}) {
        die "Error: --input is required. See --help for usage.\n";
    }

    my $verbosity = $opt{v} - $opt{q};
    print "Starting processing (verbosity $verbosity)...\n" if $verbosity > 0;


=head2 Using -- to pass filenames starting with dash

    my %opt;
    parse(\%opt, '-r')
        or die "usage: $0 [-r] files...\n";

    # Command line:
    ./script.pl -r -- -hidden-file.txt another-file

    # Results:
    # $opt{r} == 1
    # @ARGV == ('-hidden-file.txt', 'another-file')

=head1 AUTHOR

Hans Harder <hans@atbas.org>

=head1 LICENSE

This module is free software.

You can redistribute it and/or modify it under the same terms as Perl itself.

See the official Perl licensing terms: https://dev.perl.org/licenses/

=cut

sub parse {
    my ($ph, $sw, $opt) = @_;

    my %sw_lookup  = map { s/^--?//r => 1 } split /\s+/, $sw  // '';
    my %opt_lookup = map { s/^--?//r => 1 } split /\s+/, $opt // '';

    my @sw_missing  = grep { !exists $ph->{$_} } keys %sw_lookup;
    my @opt_missing = grep { !exists $ph->{$_} } keys %opt_lookup;

    @{$ph}{@sw_missing}  = (0)  x @sw_missing;
    @{$ph}{@opt_missing} = ('') x @opt_missing;

    while (@ARGV) {
        my $arg = $ARGV[0];

        if ($arg eq '--') {
            shift @ARGV;
            last;
        }

        # Stop at non-options or lone '-'
        last if $arg eq '-' || substr($arg, 0, 1) ne '-';
        shift @ARGV;

        # Handle --key=value form for long options
        my $name = $arg;
        my $attached_val = undef;
        if ($arg =~ /^--([^=]+)=(.*)$/) {
            $name = $1;
            $attached_val = $2;
        } else {
            $name =~ s/^--?//;
        }

        # Full match (multi-char or single after prefix strip)
        if (length($name) > 0) {
            my $rc = _check_match($ph, \%sw_lookup, \%opt_lookup, $name, 1, $attached_val);
            if ($rc == 1) {
                next;
            } elsif ($rc == -1) {
                unshift @ARGV, $arg;
                return 0;
            }
            # rc == 0 : not full match = try bundling (only if short form)
        }

        # Only try bundling if it looks like short bundle
        if ($arg =~ /^-[^-][^=]*$/) {  # -abc, no =
            my @chars = split //, substr($arg, 1);

            for my $i (0 .. $#chars) {
                my $nm   = $chars[$i];
                my $last = ($i == $#chars) ? 1 : 0;

                my $rc = _check_match($ph, \%sw_lookup, \%opt_lookup, $nm, $last);
                if ($rc == 1) {
                    last if exists $opt_lookup{$nm};
                } elsif ($rc == -1 || $rc == 0) {
                    unshift @ARGV, $arg;
                    return 0;
                }
            }
        } else {
            # Was not a valid full match and not bundleable → restore
            unshift @ARGV, $arg;
            return 0;
        }
    }

    return 1;
}

# internal sub, Returns: 1 = matched and processed, 0 = not found, -1 = error
sub _check_match {
    my ($ph, $sw_ref, $opt_ref, $name, $is_last, $attached_val) = @_;

    if (exists $sw_ref->{$name} && not $attached_val) {
        $ph->{$name} = exists $ph->{$name} ? $ph->{$name} + 1 : 1;
        return 1;
    }
    elsif (exists $opt_ref->{$name}) {
        return -1 if !$is_last && !defined $attached_val;

        my $val = defined $attached_val ? $attached_val : shift @ARGV;
        return -1 unless defined $val || defined $attached_val;

        if (ref $ph->{$name} eq 'ARRAY') {
            push @{$ph->{$name}}, $val;
        } else {
            $ph->{$name} = $val;
        }
        return 1;
    }

    return 0;
}

1;

__END__
