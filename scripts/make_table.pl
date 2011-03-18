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

sub usage {
  print <<"EOF";
Usage: $0 CSV column-headers ...
  where CSV is a comma-separated data file as built by make_csv.pl and
  column-headers is a list of one or more column names the data of which should
  be used for the resulting LaTeX table

EOF
}

if (scalar(@ARGV) < 2) {
  usage;
  exit 1;
}

my $file = $ARGV[0];
shift @ARGV;
open my $CSV, "<$file" or die "File $file not found\n";

print <<'EOF';
% requires booktabs package
\begin{table}
  \centering
EOF
print '  \begin{tabular}{' . "l" x scalar(@ARGV) . "}\n";
print "  \\toprule\n";
print "   \\multicolumn{1}{c}{" . join("} & \n   \\multicolumn{1}{c}{",
  @ARGV) . "}\\\\ \\midrule\n";

my %globals = ();

use Text::CSV;
my $csv = Text::CSV->new();
my $arref = $csv->getline($CSV);
defined($arref) or die "Failed to parse headers\n";
$csv->column_names(@$arref);

my %columns = ();
$columns{$_} = { width => 0, data => [] } foreach (@ARGV);

while (my $row = $csv->getline_hr($CSV)) {
  foreach (qw(command timeout uname cpuinfo meminfo memlimit)) {
    defined($row->{$_}) or die "No $_ data in table\n";
    defined($globals{$_}) or $globals{$_} = ();
    $globals{$_}{$row->{$_}} = 1;
  }
  
  foreach my $c (@ARGV) {
    my $val = defined($row->{$c}) ? $row->{$c} : "n/a";
    $val =~ s/_/\\_/g;
    $val = sprintf("%.3f", $val) if ($val =~ /^\d+\.\d+$/);
    $columns{$c}{width} = length($val) + 1
      if ($columns{$c}{width} < (length($val) + 1));
    push @{ $columns{$c}{data} }, $val;
  }
}

while (scalar(@{ $columns{$ARGV[0]}{data} })) {
  my @data = ();
  foreach my $c (@ARGV) {
    my $val = shift @{ $columns{$c}{data} };
    my $minus = ($val =~ /^\d/) ? "" : "-";
    push @data, sprintf("%$minus$columns{$c}{width}s ", $val);
  }
  print join(" & ", @data) . "\\\\\n";
}

close $CSV;

print <<"EOF";
  \\bottomrule
  \\end{tabular}
EOF
print '\\caption{Benchmarks obtained using ' .
  join(';', keys %{ $globals{command} }) . ' with a timeout of ' .
  join(';', keys %{ $globals{timeout} }) . ' and a memory limit of ' .
  join(';', keys %{ $globals{memlimit} }) . "}\n";
print <<"EOF";
  \\label{tab:some-results}
\\end{table}
EOF

print 'The benchmarks were run on a ' .
  join(';', keys %{ $globals{uname} }) . ' ' .
  join(';', keys %{ $globals{cpuinfo} }) . ' system equipped with ' .
  join(';', keys %{ $globals{meminfo} }) . " RAM.\n";

