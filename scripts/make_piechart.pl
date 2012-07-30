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


# build a pie chart of correct results, grouped by pattern-defined groups

use strict;
use warnings FATAL => qw(uninitialized);
use Getopt::Std;

sub usage {
  print <<"EOF";
Usage: $0 [OPTIONS] CSV ... GROUP-NAME GROUP-PATTERN ...
  where CSV is one ore more CSV tables as produced by make_csv.pl; the sequence
  of GROUP-NAMEs and GROUP-PATTERNs are applied to the benchmark names to build
  groups
  
  Options:            Purpose:
    -h                show help
    -p                make a pie chart (otherwise do a bar chart)
    -g                produce a chart per group instead of per file
    -A                display average runtimes instead of soundness results
    -E                display average runtimes with error bars

EOF
}

our ($opt_p, $opt_g, $opt_h, $opt_A, $opt_E);
if (!getopts('hpgAE') || defined($opt_h) || !scalar(@ARGV)) {
  usage;
  exit (defined($opt_h) ? 0 : 1);
}
  
use Text::CSV;

my %by_category = ();

my @files = ();
while(scalar(@ARGV) && $ARGV[0] =~ /\.csv$/ && -f $ARGV[0]) {
  push @files, shift @ARGV;
}
(scalar(@ARGV) % 2 == 0) or die "Names/patterns must be pairs\n";

foreach my $f (@files) {
  open my $CSV, "<$f" or die "File $f not found\n";
  my $csv = Text::CSV->new();
  my $arref = $csv->getline($CSV);
  defined($arref) or die "Failed to parse headers\n";
  $csv->column_names(@$arref);
  my $dbg_lno = 1;

  while (my $row = $csv->getline_hr($CSV)) {
    $dbg_lno++;
    (defined($row->{$_}) && ! ($row->{$_} =~ /^\s*$/))
      or die "No $_ data in $f, line $dbg_lno\n"
      foreach (qw(Benchmark Result expected usertime));

    my $bm = $row->{Benchmark};
    my $group = 0;
    for (my $i=1; $i<=(scalar(@ARGV)/2); $i++) {
      my $pat = $ARGV[(($i-1)*2)+1];
      $group = $i if($bm =~ m{$pat});
    }
    my $groupname = $group==0 ? "Other" : $ARGV[($group-1)*2];

    my $tn = $opt_g ? $groupname : $f;
    $tn =~ s/\.csv$// if(!$opt_g);
    if($opt_g) {
      $groupname = $group = $f;
      $groupname =~ s/\.csv$//;
    }

    my $cpu = $row->{usertime};
    defined($by_category{$tn}{$group}) or
      $by_category{$tn}{$group} = {
        name => $groupname,
        total => 0,
        ok => 0,
        error => 0,
        unknown => 0,
        mintime => $cpu,
        maxtime => 0,
        tottime => 0
    };
    my $val = "unknown";
    #$val = "error" if($row->{Result} eq "ERROR");
    if($row->{expected} eq "valid") {
      $val = "ok" if($row->{Result} eq "SUCCESSFUL");
      $val = "error" if($row->{Result} eq "FAILED");
    } elsif($row->{expected} eq "invalid") {
      $val = "error" if($row->{Result} eq "SUCCESSFUL");
      $val = "ok" if($row->{Result} eq "FAILED");
    }
    $by_category{$tn}{$group}{total}++;
    $by_category{$tn}{$group}{$val}++;
    $by_category{$tn}{$group}{mintime} = $cpu
      if($by_category{$tn}{$group}{mintime} > $cpu);
    $by_category{$tn}{$group}{maxtime} = $cpu
      if($by_category{$tn}{$group}{maxtime} < $cpu);
    $by_category{$tn}{$group}{tottime} += $cpu;
  }

  close $CSV;
}

my $pgfbasedl = 0;
my $pgfplotsdl = 0;
if(! -f "pgf-pie.sty") {
  system("wget http://pgf-pie.googlecode.com/files/pgf-pie-0.2.zip");
  system("unzip -j pgf-pie-0.2.zip pgf-pie-0.2/pgf-pie.sty");
  if(! -d "base") {
    $pgfbasedl = 1;
    system("wget http://mirror.ctan.org/graphics/pgf/base.zip");
    system("unzip base.zip");
  }
  if(! -d "pgfplots") {
    $pgfplotsdl = 1;
    system("wget http://mirror.ctan.org/graphics/pgf/contrib/pgfplots.zip");
    system("unzip pgfplots.zip");
  }
}

for my $tn (keys %by_category) {
  my $fn = $tn;
  $fn =~ s/[:\/]/_/g if($opt_g);

  if($opt_p) {
    my $pie_str = "";
    my $N = 0;
    $N += $by_category{$tn}{$_}{total} foreach (keys %{ $by_category{$tn} });
    foreach my $cat (sort keys %{ $by_category{$tn} }) {
      $pie_str .= sprintf("%.0f", $by_category{$tn}{$cat}{ok}/$N*100)
      . "/" . $by_category{$tn}{$cat}{name} . " (ok), "
      if($by_category{$tn}{$cat}{ok} > 0);
      $pie_str .= sprintf("%.0f", $by_category{$tn}{$cat}{error}/$N*100)
      . "/" . $by_category{$tn}{$cat}{name} . " (wrong result), "
      if($by_category{$tn}{$cat}{error} > 0);
      $pie_str .= sprintf("%.0f", $by_category{$tn}{$cat}{unknown}/$N*100)
      . "/" . $by_category{$tn}{$cat}{name} . " (error/timeout), "
      if($by_category{$tn}{$cat}{unknown} > 0);
    }
    $pie_str =~ s/, $//;

    open TEX, ">$fn.tex";
    print TEX << "EOF";
\\documentclass{article}
\\usepackage{pgf-pie}
\\pgfrealjobname{$fn-nn}
\\begin{document}
\\beginpgfgraphicnamed{$fn}
\\begin{tikzpicture}
\\pie[explode=0.1, text=legend]{ $pie_str }
\\end{tikzpicture}
\\endpgfgraphicnamed
\\end{document}
EOF
  } elsif($opt_A || $opt_E) {
    my %vals = ();
    foreach my $cat (sort keys %{ $by_category{$tn} }) {
      my $N = $by_category{$tn}{$cat}{total};
      next if($N == 0);

      my $cn = $by_category{$tn}{$cat}{name};
      defined($vals{$cn}) or $vals{$cn} = "";
      my $min = $by_category{$tn}{$cat}{mintime};
      my $max = $by_category{$tn}{$cat}{maxtime};
      my $avg = sprintf("%.0f", $by_category{$tn}{$cat}{tottime}/$N);

      $vals{$cn} .= " ($cn, $avg)";
      $vals{$cn} .= " +- ($min,$max)" if($opt_E);
    }

    my @ll = ();
    push @ll, $by_category{$tn}{$_}{name} foreach (sort keys %{ $by_category{$tn} });
    my $labels = join(", ", @ll);
    my $width = scalar(@ll);
    $width = 4 if($width < 4);
    my $xenlarge = 1/$width;
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
\\pgfplotsset{width=${width}cm}
\\pgfrealjobname{$fn-nn}
\\begin{document}
\\beginpgfgraphicnamed{$fn}
\\begin{tikzpicture}[extra padding]
\\begin{axis}[
  title={\\Large Average runtimes for $tn},
  axis x line*=none,
  axis y line=box,
  ymin=0,
  enlarge x limits=$xenlarge, 
  legend style={at={(0.5,-2.2cm)}, 
  anchor=north,legend columns=-1}, 
  symbolic x coords={$labels},
  xtick=data, 
  x tick label style={rotate=60,anchor=east}, 
  xlabel={Category},
  ylabel={Time},
]
EOF
  my $style = $opt_E ? "error bars/.cd, y dir=both,y explicit" :
    "ybar,bar width=3pt";
  print TEX "\\addplot+[$style] plot coordinates { $vals{$_} };\n"
    foreach (sort keys %vals);
  my $legend = join(",", sort keys %vals);
  print TEX << "EOF";
\\legend{ $legend };
\\end{axis}
\\end{tikzpicture}
\\endpgfgraphicnamed
\\end{document}
EOF

  } else {
    my $ok = "";
    my $unknown = "";
    my $error = "";
    foreach my $cat (sort keys %{ $by_category{$tn} }) {
      my $N = $by_category{$tn}{$cat}{total};
      next if($N == 0);

      my $cn = $by_category{$tn}{$cat}{name};
      $ok .= " ($cn, " . sprintf("%.0f", $by_category{$tn}{$cat}{ok}/$N*100) . ")";
      $unknown .= " ($cn, " . sprintf("%.0f", $by_category{$tn}{$cat}{unknown}/$N*100) . ")";
      $error .= " ($cn, " . sprintf("%.0f", $by_category{$tn}{$cat}{error}/$N*100) . ")";
    }

    my @ll = ();
    push @ll, $by_category{$tn}{$_}{name} foreach (sort keys %{ $by_category{$tn} });
    my $labels = join(", ", @ll);
    my $width = scalar(@ll);
    $width = 4 if($width < 4);
    my $xenlarge = 1/$width;
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
\\pgfplotsset{width=${width}cm}
\\pgfrealjobname{$fn-nn}
\\begin{document}
\\beginpgfgraphicnamed{$fn}
\\begin{tikzpicture}[extra padding]
\\begin{axis}[
  title={\\Large Soundness results for $tn},
  axis x line*=none,
  axis y line=box,
  ybar stacked,
  ymin=-3, ymax=103,
  enlarge x limits=$xenlarge, 
  legend style={at={(0.5,-2.2cm)}, 
  anchor=north,legend columns=-1}, 
  %ylabel={Some text}, 
  symbolic x coords={$labels},
  xtick=data, 
  x tick label style={rotate=60,anchor=east}, 
]
\\addplot+[green!50!black, ybar] plot coordinates { $ok };
\\addplot+[orange!90!black, ybar] plot coordinates { $unknown };
\\addplot+[red!70!black, ybar] plot coordinates { $error };
\\legend{ ok, error/timeout, wrong result };
\\end{axis}
\\end{tikzpicture}
\\endpgfgraphicnamed
\\end{document}
EOF

  }

  system("TEXMFHOME=base:pgfplots pdflatex --jobname=$fn $fn");
  system("convert -density 96 -units PixelsPerInch $fn.pdf $fn.png");
}

system("rm -r pgfplots") if($pgfplotsdl);
system("rm -r base") if($pgfbasedl);

