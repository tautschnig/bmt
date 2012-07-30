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
Usage: $0 [OPTIONS] CSV [COLUMN FILTER] [CSV [COLUMN FILTER]] ...
  where CSV is a CSV table as produced by make_csv.pl, COLUMN a column name in
  there, and FILTER a regular expression
  
  Options:            Purpose:
    -h                show help
    -s                build a scatter plot (requires exactly two CSV files)
    -c                build a cactus plot
    -l                use logarithmic scaling
    -r                use percentage of instances as x axis scaling in cactus plot
    -m REGEXP:REGEXP  map benchmark names from REGEXP to REGEXP   

EOF
}

our ($opt_s, $opt_h, $opt_c, $opt_l, $opt_r, $opt_m);
if (!getopts('hsclrm:') || defined($opt_h) || !scalar(@ARGV)) {
  usage;
  exit (defined($opt_h) ? 0 : 1);
}
  
use Text::CSV;

my %per_file_data = ();
my %results = ();

my %files_filters = ();
while (scalar(@ARGV)) {
  my $f = shift @ARGV;
  (-f $f) or die "File $f not found\n";
  defined($files_filters{$f}) and die "Duplicate file name $f\n";
  $files_filters{$f} = {
    column => "command",
    filter => ".*"
  };
  if(scalar(@ARGV) &&
    !(-f $ARGV[0] && $ARGV[0] =~ /\.csv$/))
  {
    (scalar(@ARGV) >= 2) or die "column AND filter required\n";
    $files_filters{$f}{column} = shift @ARGV;
    $files_filters{$f}{filter} = shift @ARGV;
  }
}

my $map_from = "";
my $map_to = "";
if($opt_m) {
  my @map = split(':', $opt_m);
  (scalar(@map) == 2) or die "Cannot split $opt_m on :\n";
  $map_from = shift @map;
  $map_to = shift @map;
}

foreach my $f (keys %files_filters) {
  open my $CSV, "<$f" or die "File $f not found\n";
  
  my %globals = ();
  my $dbg_lno = 1;

  my $csv = Text::CSV->new();
  my $arref = $csv->getline($CSV);
  defined($arref) or die "Failed to parse headers\n";
  $csv->column_names(@$arref);

  while (my $row = $csv->getline_hr($CSV)) {
    ++$dbg_lno;
    foreach (qw(command timeout uname cpuinfo meminfo memlimit)) {
      defined($row->{$_}) or die "No $_ data in $f, line $dbg_lno\n";
      if ($_ eq "command" && defined($globals{$_}) &&
          !defined($globals{$_}{$row->{$_}})) {
        my $cmd = "";
        for (keys %{ $globals{command} }) {
          ($cmd eq "") or die "Only single preceding command expected\n";
          $cmd = $_;
          delete $globals{command}{$_};
        }
        my $newcmd = $row->{command};
        $cmd =~ s/^(\S+).*$/$1/;
        $newcmd =~ s/^(\S+).*$/$1/;
        ($cmd eq $newcmd) or die "Multiple base commands not supported\n";
        $globals{command}{"$cmd (multiple options)"} = 1;
      } else {
        defined($globals{$_}) or $globals{$_} = ();
        $globals{$_}{$row->{$_}} = 1;
      }
    }
    
    (defined($row->{$_}) && ! ($row->{$_} =~ /^\s*$/))
      or die "No $_ data in $f, line $dbg_lno\n"
      foreach (qw(Benchmark Result usertime maxmem));

    my $col = $files_filters{$f}{column};
    my $flt = $files_filters{$f}{filter};
    defined($row->{$col}) or die "No column $col in $f\n";
    next unless($row->{$col} =~ /$flt/);

    my $bm = $row->{Benchmark};
    $bm =~ s/$map_from/$map_to/ if($opt_m);

    if (!defined($results{$bm})) {
      $results{$bm} = ();
      $results{$bm}{id} = scalar(keys %results);
      $results{$bm}{status} = $row->{Result};
    } elsif ($results{$bm}{status} ne $row->{Result}) {
      ($results{$bm}{status} =~ /^(ERROR|TIMEOUT)$/ ||
        $row->{Result} =~ /^(ERROR|TIMEOUT)$/) 
        or warn "Tools disagree about verification result for $bm\n";
    }
    defined($results{$bm}{$f}) 
      and die "Results for $bm and $f already known\n";
    $results{$bm}{$f} = ();
    $results{$bm}{$f}{result} = $row->{Result};

    my $cpu = $row->{usertime};
    $results{$bm}{$f}{cpu} = sprintf "%.2f", $cpu;

    my $mem = $row->{maxmem};
    ($mem =~ /^(\d+)kb$/)
      or die "Unexpected memory usage format in $mem\n";
    $mem = $1 / 1024.0;
    $results{$bm}{$f}{mem} = sprintf "%.2f", $mem;
  }
    
  close $CSV;

  $per_file_data{$f} = ();
  $per_file_data{$f}{name} = $f;
  $per_file_data{$f}{name} =~ s/\.csv//;
  $per_file_data{$f}{name} =~ s/.*\///;
  foreach (qw(command timeout memlimit)) {
    (scalar(keys %{ $globals{$_} }) == 1)
      or die "Multiple configurations per file not supported ($_)\n";
    $per_file_data{$f}{$_} = (keys %{ $globals{$_} })[0];
  }
  foreach (qw(uname cpuinfo meminfo)) {
    (scalar(keys %{ $globals{$_} }) == 1)
      or warn "Multiple configurations for $_ found in $f:\n" .
        join(" | ", keys %{ $globals{$_} }) . "\n";
  }
}

my $pgfbasedl = 0;
if(! -d "base") {
  $pgfbasedl = 1;
  system("wget http://mirror.ctan.org/graphics/pgf/base.zip");
  system("unzip base.zip");
}
my $pgfplotsdl = 0;
if(! -d "pgfplots") {
  $pgfplotsdl = 1;
  system("wget http://mirror.ctan.org/graphics/pgf/contrib/pgfplots.zip");
  system("unzip pgfplots.zip");
}
  
my $fn = "";
my $title = scalar(keys %per_file_data) > 1 ? "Comparison of " : "";
my $legend = "";
foreach (sort keys %per_file_data) {
  $fn .= $per_file_data{$_}{name} . "_";
  $title .= $per_file_data{$_}{name} . ", ";
  $legend .= $per_file_data{$_}{name} . " (TO " . $per_file_data{$_}{timeout} .  "), ";
}
$fn =~ s/_$//;
$opt_s and $fn .= "-scatter";
$opt_c and $fn .= "-cactus";
$opt_l and $fn .= "_log";
$title =~ s/, $//;
$title =~ s/, ([^,]+)$/ and $1/;
$legend =~ s/, $//;
  
my $lb = $opt_l ? 0.01 : 0.0;

my $width = 4;
my $xenlarge = 0;

if(!$opt_s && !$opt_c) {
  my $nfiles = scalar(keys %per_file_data);
  ($nfiles < 2) and $nfiles = 2;
  $width = scalar(keys %results) * $nfiles * 0.3;
} else {
  $width = scalar(keys %results) * 0.05;
}

$width = 4 if($width < 4);
$width = 75 if($width > 75);
$xenlarge = 1/$width;
$width = "\\pgfplotsset{width=${width}cm}\n";
  
open TEX, ">$fn.tex";
print TEX << "EOF";
\\documentclass{article}
\\usepackage{pgfplots}
\\usetikzlibrary{backgrounds}
\\tikzset{
    extra padding/.style={
        show background rectangle,
        inner frame sep=#1,
        background rectangle/.style={
            draw=none
        }
    },
    extra padding/.default=0.5cm
}
$width
\\pgfrealjobname{$fn-nn}
\\begin{document}
\\beginpgfgraphicnamed{$fn}
\\begin{tikzpicture}[extra padding]
EOF


if ($opt_s) {
  (scalar(keys %per_file_data) == 2) or
    die "Scatter plot requires exactly two input files\n";
  
  my ($f1, $f2) = sort keys %per_file_data;

  my $f1_to = $per_file_data{$f1}{timeout};
  $f1_to =~ s/s$//;
  my $f2_to = $per_file_data{$f2}{timeout};
  $f2_to =~ s/s$//;
 
  my $axis = $opt_l ? "loglogaxis" : "axis";
  my $coordstring = "";
  my $rlb = $f1_to;
  
  foreach my $bm (keys %results) {
    my %data = ();
    foreach my $f (($f1, $f2)) {
      if (defined($results{$bm}{$f}{cpu})) {
        $data{$f}{cpu} = $results{$bm}{$f}{cpu};
        ($opt_l && $data{$f}{cpu} < $lb) and
          $data{$f}{cpu} = $lb;
        $data{$f}{cpu} = ($f eq $f1) ? $f1_to : $f2_to
          if($results{$bm}{$f}{result} ne "SUCCESSFUL" &&
            $results{$bm}{$f}{result} ne "FAILED");
      } else {
        warn "Data for $bm/cpu not found in $f\n";
        $data{$f}{cpu} = ($f eq $f1) ? $f1_to : $f2_to;
      }
    }
    $coordstring .= "    (".$data{$f1}{cpu}.",".$data{$f2}{cpu}.")\n";
    $rlb = $data{$f1}{cpu} if($data{$f1}{cpu} < $rlb);
    $rlb = $data{$f2}{cpu} if($data{$f2}{cpu} < $rlb);
  }
  
print TEX << "EOF";
\\begin{$axis}[
  title={\\Large $title},
  xlabel={$per_file_data{$f1}{name}, TO $per_file_data{$f1}{timeout}},
  ylabel={$per_file_data{$f2}{name}, TO $per_file_data{$f2}{timeout}},
  xmin=$rlb,
  ymin=$rlb,
  xmax=$f1_to,
  ymax=$f2_to,
]
\\addplot+[only marks]
  coordinates {
$coordstring
  };
\\addplot[black,domain=$rlb:$f1_to]{x};
\\end{$axis}
EOF
} elsif ($opt_c) {
  my $axis = $opt_l ? "semilogyaxis" : "axis";
  
  my %coordstrings = ();
  foreach my $f (sort keys %per_file_data) {
    my @tlist = ();
    my $n = 0;
    foreach (keys %results) {
      defined($results{$_}{$f}{cpu}) or next;
      ++$n;
      my $val = $results{$_}{$f}{cpu};
      ($opt_l && $val < $lb) and $val = $lb;
      push @tlist, $val 
        if($results{$_}{$f}{result} eq "SUCCESSFUL" ||
          $results{$_}{$f}{result} eq "FAILED");
    }
    ($n > 0) or die "Zero results in $f\n";
    (scalar(@tlist)) or die "No usable results for $f\n";
    my $i = 1;
    my $mult = $opt_r ? (100.0/$n) : 1;
    my $max_str = scalar(@tlist);
    $max_str = sprintf("%.1f", $max_str * $mult) . "\\%" if($opt_r);
    $coordstrings{$f} .= " (" . ($i++ * $mult) .
      ", $_) [".($i>scalar(@tlist)?"($max_str)":" ")."]\n"
      foreach (sort { $a <=> $b } @tlist);
  }

  my $xbounds = "";
  my $xlabel = "Solved instances";
  if($opt_r) {
    $xbounds = "xmin=0, xmax=100,";
    $xlabel .= " [\\%]";
  }
 
  print TEX << "EOF";
\\begin{$axis}[
  title={\\Large $title},
  xlabel={$xlabel},
  ylabel={Time},
  axis x line*=none,
  axis y line=box, $xbounds
  legend style={at={(0.5,-2.2cm)}, 
  anchor=north,legend columns=-1},
  nodes near coords,
  point meta=explicit symbolic
]
EOF
  print TEX "\\addplot+ coordinates { $coordstrings{$_} };\n"
    foreach (sort keys %per_file_data);
  print TEX << "EOF";
\\legend{ $legend };
\\end{$axis}
EOF
} else {
  my $axis = $opt_l ? "semilogyaxis" : "axis";
  my $to_max = $lb;
  foreach my $f (sort keys %per_file_data) {
    my $cto = $per_file_data{$f}{timeout};
    $cto =~ s/s$//;
    $to_max = $cto if($cto > $to_max);
  }
    
  my $labels = "";
  my $labellen = 0;
  foreach (sort keys %results)
  {
    my $cl = "$_ ($results{$_}{status})";
    $labellen = length($cl) if (length($cl)>$labellen);
    $labels .= "$cl,\n";
  }
  $labels =~ s/\//:/g;
  $labels =~ s/_/-/g;
  
  my %coordstrings = ();
  foreach my $f (sort keys %per_file_data) {
    foreach (keys %results) {
      defined($results{$_}{$f}{cpu}) or
        warn "Data for $_/cpu not found in $f\n";
      my $val = defined($results{$_}{$f}{cpu}) ?
        $results{$_}{$f}{cpu} : $to_max;
      ($opt_l && $val < $lb) and $val = $lb;
      $val = $to_max 
        if($results{$_}{$f}{result} ne "SUCCESSFUL" &&
          $results{$_}{$f}{result} ne "FAILED");
      $coordstrings{$f} .= " ($_ ($results{$_}{status}), $val)\n";
    }
    $coordstrings{$f} =~ s/\//:/g;
    $coordstrings{$f} =~ s/_/-/g;
  }

  my $labelloc = ($labellen * -0.15) -1;
  my $legendloc = -2 + $labelloc;
 
  print TEX << "EOF";
\\begin{$axis}[
  title={\\Large $title},
  xlabel={Benchmark},
  ylabel={Time},
  axis x line*=none,
  axis y line=box,
  ymin=$lb,
  ymax=$to_max,
  enlarge x limits=$xenlarge,
  bar width=3pt,
  ybar,
  legend style={at={(0.5,${legendloc}cm)}, 
  anchor=north,legend columns=-1}, 
  symbolic x coords={$labels},
  xtick=data, 
  x tick label style={rotate=60,anchor=east}, 
  x label style={at={(0.5,${labelloc}cm)}}
]
EOF
  print TEX "\\addplot coordinates { $coordstrings{$_} };\n"
    foreach (sort keys %per_file_data);
  print TEX << "EOF";
\\legend{ $legend };
\\end{$axis}
EOF
}

print TEX << "EOF";
\\end{tikzpicture}
\\endpgfgraphicnamed
\\end{document}
EOF

system("TEXMFHOME=base:pgfplots pdflatex --jobname=$fn $fn");
system("convert -density 96 -units PixelsPerInch $fn.pdf $fn.png");

system("rm -r pgfplots") if($pgfplotsdl);
system("rm -r base") if($pgfbasedl);

