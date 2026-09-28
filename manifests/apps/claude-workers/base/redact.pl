#!/usr/bin/perl
# Secret scrubber shared by worker.sh and the helpers.
#
#   redact.pl            read all of stdin, print it with secrets replaced by [REDACTED]
#   redact.pl --stream   same, line by line and unbuffered (for live logs)
#   redact.pl --detect   read a `git log -p` of new commits; print "<file>: <kind>" for each added line
#                        (or commit message) that looks like a secret, and exit 1 if any were found
#
# Exact values of the worker's own secrets (the variables named in REDACT_VARS) are always caught.
# Common token formats are caught by pattern.
use strict;
use warnings;

my $mode = $ARGV[0] // '';

my @literals = grep { defined && length >= 8 }
               map { $ENV{$_} } split /[\s,]+/, ($ENV{REDACT_VARS} // 'GH_TOKEN CLAUDE_CODE_OAUTH_TOKEN');

my @patterns = (
  [ 'GitHub token',       qr/\bgh[pousr]_[A-Za-z0-9]{30,}/ ],
  [ 'GitHub token',       qr/\bgithub_pat_[A-Za-z0-9_]{40,}/ ],
  [ 'Anthropic key',      qr/\bsk-ant-[A-Za-z0-9_-]{20,}/ ],
  [ 'AWS access key',     qr/\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/ ],
  [ 'Slack token',        qr/\bxox[abposr]-[A-Za-z0-9-]{10,}/ ],
  [ 'Google API key',     qr/\bAIza[0-9A-Za-z_-]{35}\b/ ],
  [ 'private key',        qr/-----BEGIN [A-Z ]*PRIVATE KEY-----/ ],
  [ 'credential in URL',  qr{://[^\s:/@]+:[^\s:/@]{6,}@} ],
);

sub redact {
  my ($t) = @_;
  $t =~ s/\Q$_\E/[REDACTED]/g for @literals;
  # Whole private-key blocks when the END line is present, otherwise just the BEGIN line
  $t =~ s/-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----/[REDACTED PRIVATE KEY]/gs;
  $t =~ s{(://[^\s:/@]+:)[^\s:/@]{6,}@}{$1\[REDACTED\]@}g;
  for my $p (@patterns) { next if $p->[0] eq 'credential in URL'; $t =~ s/$p->[1]/[REDACTED]/g }
  return $t;
}

if ($mode eq '--detect') {
  my ($file, %found) = ('(commit message)');
  while (my $line = <STDIN>) {
    if ($line =~ /^commit /)            { $file = '(commit message)'; next }
    if ($line =~ m{^\+\+\+ (?:b/)?(.*)}) { $file = $1; next }
    next if $line =~ /^(?:---|\+\+\+|index |diff |@@)/;
    # Only added lines of the diff, plus commit messages (indented by git log)
    next unless $line =~ /^\+/ || $file eq '(commit message)';
    for my $v (@literals) { $found{"$file: worker secret"} = 1 if index($line, $v) >= 0 }
    for my $p (@patterns) { $found{"$file: $p->[0]"} = 1 if $line =~ $p->[1] }
  }
  print "$_\n" for sort keys %found;
  exit(%found ? 1 : 0);
}

if ($mode eq '--stream') {
  $| = 1;
  print redact($_) while <STDIN>;
  exit 0;
}

local $/;
my $in = <STDIN> // '';
print redact($in);
