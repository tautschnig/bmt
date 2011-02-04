#!/usr/bin/perl -w
#
# Michael Tautschnig
# michael.tautschnig@comlab.ox.ac.uk
#
# build a LaTeX table of results

use strict;
use warnings FATAL => qw(uninitialized);

use File::Basename qw(dirname);
use lib dirname($0);
require "parse_results.pl";

sub usage {
  print <<"EOF";
Usage: $0 RESULTS
  where RESULTS is a file as produced by verify.sh

EOF
}

if (scalar(@ARGV) != 1) {
  usage;
  exit 1;
}

print <<'EOF';
% requires booktabs package
\begin{table}
  \centering
  \begin{tabular}{llrr}
  \toprule
  Benchmark                 & Status & \multicolum{1}{c}{CPU
                                      Time [s]} & \multicolum{1}{c}{
                                                    Memory Usage [MB]} \\ \midrule
EOF

my %results = ();
&parse_results($ARGV[0], \%results);
$results{tool} =~ s/--/-{}-/g;

foreach my $c (sort keys %{ $results{results} }) {
  my $ref = \%{ $results{results}{$c} };
  my $cpuspec = '%8.2f';
  my $memspec = '%8.2f';
  $cpuspec = $memspec = '%8s' if ($ref->{cpu} =~ /(TO|ERR|ITER)/);
  printf "  %-25s & %6s & $cpuspec & $memspec \\\\\n", $c,
    $ref->{status}, $ref->{cpu}, $ref->{mem};
}
      

print <<"EOF";
  \\bottomrule
  \\end{tabular}
  \\caption{Benchmarks obtained using $results{tool} with a timeout of $results{timeout} seconds}
  \\label{tab:some-results}
\\end{table}
EOF

