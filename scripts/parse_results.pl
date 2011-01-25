#!/usr/bin/perl -w
#
# Michael Tautschnig
# michael.tautschnig@comlab.ox.ac.uk
#
# build a LaTeX table of results

use strict;
use warnings FATAL => qw(uninitialized);

sub parse_results {
  my ($file,$hash) = @_;
  open RESULTS, "<$file" or die "File $file not found\n";

  my $res_mode = 0;
  $hash->{tool} = undef;
  $hash->{timeout} = undef;
  while (<RESULTS>) {
    chomp;
    if (!$res_mode && /^TOOL: (.+)$/) {
      !defined($hash->{tool}) or die "TOOL: header already seen\n";
      $hash->{tool} = $1;
    } elsif (!$res_mode && /^TIMEOUT: (\d+)$/) {
      !defined($hash->{timeout}) or die "TIMEOUT: header already seen\n";
      $hash->{timeout} = $1;
    } elsif (!$res_mode && /^RESULTS:$/) {
      $res_mode = 1;
      $hash->{results} = ();
    } else {
      (1 == $res_mode) or die "Header not yet seen\n";
      (/^claim \d+ of \d+ \((.+)\) (SUCCESSFUL|FAILED|TOO_MANY_ITERATIONS|ERROR|TIMEOUT)(.*)$/) or
        die "Unexpected input $_\n";
      my $claim = $1;
      my %data = (
        status => $2,
        cpu => undef,
        mem => undef
      );
      my $rest = $3;
      if ($data{status} eq "TIMEOUT" || $data{status} eq "TOO_MANY_ITERATIONS"
        || $data{status} eq "ERROR") {
        $data{cpu} = $data{status} eq "TIMEOUT" ? "TO" : 
          ($data{status} eq "ERROR" ? "ERR" : "ITER");
        $data{status} = "--";
        $data{mem} = "--";
      } elsif ($data{status} eq "SUCCESSFUL" && ($rest =~ / 0\s*$/)) {
        $data{status} = "triv";
        $data{cpu} = 0;
        $data{mem} = 0;
      } elsif ($data{status} eq "FAILED" || $data{status} eq "SUCCESSFUL") {
        $data{status} = $data{status} eq "FAILED" ? "inv" : "ok";
        ($rest =~ /^.*#STATS: cpu=(.+) wall=(.+) maxmem=(\d+)$/) or
          die "Failed to parse statistics in $rest\n";
        $data{cpu} = $1;
        $data{mem} = $3 / 1024.0;
      } else {
        # just in case somebody extends the pattern above
        die "Unhandled status $data{status}\n";
      }
      $hash->{results}->{$claim} = \%data;
    }
  }
  close RESULTS;
}

return 1;

