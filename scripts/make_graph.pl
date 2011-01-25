#!/usr/bin/perl -w
#
# Michael Tautschnig
# michael.tautschnig@comlab.ox.ac.uk
#
# build scripts for making gnuplot figures

use strict;
use warnings FATAL => qw(uninitialized);
use Getopt::Std;

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
          or die "Tools disagree about verification result for claim $c\n";
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


