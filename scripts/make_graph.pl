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


# build scripts for making gnuplot figures

use strict;
use warnings FATAL => qw(uninitialized);
use Getopt::Std;

use File::Basename qw(dirname);
use lib dirname($0);
require "parse_results.pl";

sub usage {
  print <<"EOF";
Usage: $0 [OPTIONS] RESULTS ...
  where RESULTS are one or more files as produced by verify.sh
  
  Options:            Purpose:
    -h                show help
    -s                build a scatter plot (requires exactly two results files)

EOF
}

our ($opt_s, $opt_h);
if (!getopts('hs') || defined($opt_h) || !scalar(@ARGV)) {
  usage;
  exit (defined($opt_h) ? 0 : 1);
}

my %global_results = ();

my %results = ();
foreach my $f (@ARGV) {
  &parse_results($f, \%{$results{$f}});

  foreach my $c (sort keys %{ $results{$f}{results} }) {
    my $ref = \%{ $results{$f}{results}{$c} };
    if (!defined($global_results{$c})) {
      $global_results{$c} = {
        id => scalar(keys %global_results) + 1,
        status => $ref->{status}
      };
    } else {
      if ($global_results{$c}{status} eq "--") {
        $global_results{$c}{status} = $ref->{status};
      } else {
        ($ref->{status} eq "--" || $ref->{status} eq $global_results{$c}{status})
          or warn "Tools disagree about verification result for claim $c\n";
      }
    }

    my $cpu = ($ref->{cpu} =~ /(TO|ERR|ITER)/) ? $results{$f}{timeout} : $ref->{cpu};
    my $mem = ($ref->{mem} eq "--") ? 0 : $ref->{mem};
    defined($results{$f}{values}{ $global_results{$c}{id} }) and
      die "Duplicate entry\n";
    $results{$f}{values}{ $global_results{$c}{id} } = sprintf "%8.2f  %8.2f", $cpu, $mem;
  }
}

if ($opt_s) {
  (scalar(keys %results) == 2) or
    die "Scatter plot requires exactly two input files\n";
  my ($f1, $f2) = keys %results;
  
  open DAT, ">$f1.scatter.dat";
  foreach my $c (sort keys %global_results) {
    defined($results{$f1}{values}{ $global_results{$c}{id} }) or
      die "Data for claim $c not available for $results{$f1}{tool}\n";
    defined($results{$f2}{values}{ $global_results{$c}{id} }) or
      die "Data for claim $c not available for $results{$f2}{tool}\n";
    print DAT "$results{$f1}{values}{ $global_results{$c}{id} } $results{$f2}{values}{ $global_results{$c}{id} }\n";
  }
  close DAT;

  print << "EOF";
# set terminal postscript eps size 5.7cm,5cm
# set output "foo_bar.eps"
set xlabel "$results{$f1}{tool}, TO $results{$f1}{timeout}"
set ylabel "$results{$f2}{tool}, TO $results{$f2}{timeout}"
set xrange [0.0001:$results{$f1}{timeout}]
set yrange [0.0001:$results{$f2}{timeout}]
set logscale x
set logscale y
plot "$f1.scatter.dat" using 1:3 title "" with point pointsize 2, x title "" with lines lt 3
# set output
EOF
} else {
  
  my $boxwidth = 2.0/scalar(keys %results);
  print << "EOF";
# set terminal postscript eps size 8cm,4cm
# set output "foo_bar.eps"
# set style histogram clustered gap 1
# set style data histogram
set boxwidth $boxwidth*0.75
set style fill solid noborder
set xtics border in scale 0,0 nomirror rotate by -90
set xlabel "Benchmark"
set ylabel "log(t)"
set xrange [0:*]
set logscale y
# set key right bottom
EOF
  my $comma = "";
  print "set xtics (";
  foreach my $c (keys %global_results) {
    print "$comma\"$c ($global_results{$c}{status})\" $global_results{$c}{id}*4";
    $comma = ",";
  }
  print ")\n";
  
  print "plot";
  $comma = "";
  my $offset = 0;
  foreach my $f (keys %results) {
    open DAT, ">$f.dat";
    printf DAT "%-5d  %s\n", $_, $results{$f}{values}{$_} 
      foreach (sort keys %{ $results{$f}{values} });
    close DAT;
    
    print "$comma\"$f.dat\" using (\$1*4-1.0+$boxwidth*0.5+$boxwidth*$offset):2 title \"$results{$f}{tool}, TO $results{$f}{timeout}\" with boxes";
    $comma = ",";
    $offset++;
  }
  print "\n";
  print "# set output\n";
}


