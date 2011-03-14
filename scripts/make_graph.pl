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

sub usage {
  print <<"EOF";
Usage: $0 [OPTIONS] CSVs ...
  where CSVs are one or more CSV tables as produced by make_csv.pl
  
  Options:            Purpose:
    -h                show help
    -s                build a scatter plot (requires exactly two CSV files)

EOF
}

our ($opt_s, $opt_h);
if (!getopts('hs') || defined($opt_h) || !scalar(@ARGV)) {
  usage;
  exit (defined($opt_h) ? 0 : 1);
}
  
use Text::CSV;

my %per_file_data = ();
my %results = ();

foreach my $f (@ARGV) {
  open my $CSV, "<$f" or die "File $f not found\n";
  
  my %globals = ();

  my $csv = Text::CSV->new();
  my $arref = $csv->getline($CSV);
  defined($arref) or die "Failed to parse headers\n";
  $csv->column_names(@$arref);

  while (my $row = $csv->getline_hr($CSV)) {
    foreach (qw(command timeout uname cpuinfo meminfo memlimit)) {
      defined($row->{$_}) or die "No $_ data in table\n";
      defined($globals{$_}) or $globals{$_} = ();
      $globals{$_}{$row->{$_}} = 1;
    }
    
    (defined($row->{$_}) && ! ($row->{$_} =~ /^\s*$/))
      or die "No $_ data in table\n"
      foreach (qw(Benchmark Result usertime maxmem));

    my $bm = $row->{Benchmark};

    if (!defined($results{$bm})) {
      $results{$bm} = ();
      $results{$bm}{id} = scalar(keys %results);
      $results{$bm}{status} = $row->{Result};
    } else {
      ($results{$bm}{status} eq $row->{Result})
        or warn "Tools disagree about verification result for $bm\n";
    }
    defined($results{$bm}{$f}) 
      and die "Results for $bm and $f already known\n";
    $results{$bm}{$f} = ();

    my $cpu = $row->{usertime};
    $results{$bm}{$f}{cpu} = sprintf "%8.2f", $cpu;

    my $mem = $row->{maxmem};
    ($mem =~ /^(\d+)kb$/)
      or die "Unexpected memory usage format in $mem\n";
    $mem = $1 / 1024.0;
    $results{$bm}{$f}{mem} = sprintf "%8.2f", $mem;
  }
    
  close $CSV;

  $per_file_data{$f} = ();
  foreach (qw(command timeout uname cpuinfo meminfo memlimit)) {
    (scalar(keys %{ $globals{$_} }) == 1)
      or die "Multiple configurations per file not supported ($_)\n";
    $per_file_data{$f}{$_} = (keys %{ $globals{$_} })[0];
  }
}

if ($opt_s) {
  (scalar(keys %per_file_data) == 2) or
    die "Scatter plot requires exactly two input files\n";
  my ($f1, $f2) = keys %per_file_data;
  
  open DAT, ">$f1.scatter.dat";
  foreach my $bm (keys %results) {
    my $f1_cpu = -1.0;
    my $f1_mem = -1.0;
    my $f2_cpu = -1.0;
    my $f2_mem = -1.0;
    my %data = ();
    foreach my $t (qw(cpu mem)) {
      foreach my $f (($f1, $f2)) {
        if (defined($results{$bm}{$f}{$t})) {
          $data{$f}{$t} = $results{$bm}{$f}{$t};
        } else {
          warn "Data for $bm/$t not found in $f\n";
          $data{$f}{$t} = -1.0;
        }
      }
    }
    print DAT "$data{$f1}{cpu}  $data{$f1}{mem}  $data{$f2}{cpu} $data{$f2}{mem}\n";
  }
  close DAT;

  my $f1_to = $per_file_data{$f1}{timeout};
  $f1_to =~ s/s$//;
  my $f2_to = $per_file_data{$f2}{timeout};
  $f2_to =~ s/s$//;
  print << "EOF";
# set terminal postscript eps size 5.7cm,5cm
# set output "foo_bar.eps"
set xlabel "$per_file_data{$f1}{command}, TO $per_file_data{$f1}{timeout}"
set ylabel "$per_file_data{$f2}{command}, TO $per_file_data{$f2}{timeout}"
set xrange [0.0001:$f1_to]
set yrange [0.0001:$f2_to]
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
  foreach my $bm (keys %results) {
    print "$comma\"$bm($results{$bm}{status})\" $results{$bm}{id}*4";
    $comma = ",";
  }
  print ")\n";
  
  print "plot";
  $comma = "";
  my $offset = 0;
  foreach my $f (keys %per_file_data) {
    open DAT, ">$f.dat";
    printf DAT "%-5d  %s  %s\n", $results{$_}{id}, $results{$_}{$f}{cpu}, $results{$_}{$f}{mem}
      foreach (keys %results);
    close DAT;
    
    print "$comma\"$f.dat\" using (\$1*4-1.0+$boxwidth*0.5+$boxwidth*$offset):2 title \"$per_file_data{$f}{command}, TO $per_file_data{$f}{timeout}\" with boxes";
    $comma = ",";
    $offset++;
  }
  print "\n";
  print "# set output\n";
}


