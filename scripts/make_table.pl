#!/usr/bin/perl -w
#
# Copyright (c) 2011 Michael Tautschnig <michael.tautschnig@comlab.ox.ac.uk>
# Daniel Kroening
# Computing Laboratory, Oxford University
# 
# All rights reserved. Redistribution and use in source and binary forms, with
# or without modification, are permitted provided that the following
# conditions are met:
# 
#   1. Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
# 
#   2. Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
# 
#   3. All advertising materials mentioning features or use of this software
#      must display the following acknowledgement:
# 
#      This product includes software developed by Daniel Kroening,
#      Edmund Clarke, Computer Systems Institute, ETH Zurich
#      Computer Science Department, Carnegie Mellon University
# 
#   4. Neither the name of the University nor the names of its contributors
#      may be used to endorse or promote products derived from this software
#      without specific prior written permission.
# 
#    
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS `AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


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

