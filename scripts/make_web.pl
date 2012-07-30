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


# build an HTML table and a directory collecting log files

use strict;
use warnings FATAL => qw(uninitialized);
use Getopt::Std;

sub usage {
  print <<"EOF";
Usage: $0 [OPTIONS] CSV TARGETDIR
  where CSV is a comma-separated data file as built by make_csv.pl and TARGETDIR
  is the directory, which must not yet exist, to store the logs and the
  index.html file in
  
  Options:            Purpose:
    -h                show help
    -z                bzip2 log files larger than 1MB
    -n                omit date

EOF
}

our ($opt_z, $opt_h, $opt_n);
if (!getopts('hzn') || defined($opt_h) || scalar(@ARGV) != 2) {
  usage;
  exit (defined($opt_h) ? 0 : 1);
}

my $file = $ARGV[0];
open my $CSV, "<$file" or die "File $file not found\n";

my $destdir = $ARGV[1];
mkdir $destdir or die "Failed to create directory $destdir\n";
use File::Copy;

my %aliases = ();
my %globals = ();

use Text::CSV;
my $csv = Text::CSV->new();
my $arref = $csv->getline($CSV);
defined($arref) or die "Failed to parse headers\n";
$csv->column_names(@$arref);

my @skip = qw(command version timeout uname cpuinfo meminfo memlimit);
push @skip, "Log File";
push @skip, "Benchmark";
push @skip, "Result";
$opt_n and push @skip, "date";
my %rm;
@rm{@skip} = ();
my @headers = grep { not exists $rm{$_} } @$arref;

my %rows = ();

while (my $row = $csv->getline_hr($CSV)) {
  foreach (qw(command version timeout uname cpuinfo meminfo memlimit)) {
    defined($row->{$_}) or die "No $_ data in table\n";
    defined($globals{$_}) or $globals{$_} = ();
    $globals{$_}{$row->{$_}} = 1;
  }

  my $logfile = $row->{"Log File"};
  defined($logfile) or die "No Log File column in table\n";
  defined($aliases{$logfile}) and die "Duplicate log file $logfile\n";
  $aliases{$logfile} = "$logfile.txt";
  $aliases{$logfile} =~ s/^.*\/results\.//;
  $aliases{$logfile} =~ s/\//__/g;
  if($opt_n)
  {
    `cat $logfile | perl -e 'while(<>) { \
      if(/^### date:/) { \$skip=1; next; }
      if(\$skip) { \$skip=0; next; } \
      print; }' > $destdir/$aliases{$logfile}`;
  }
  else
  {
    copy($logfile, "$destdir/$aliases{$logfile}") 
      or die "Failed to copy log file from $logfile to $destdir/$aliases{$logfile}\n";
  }
  if($opt_z && -s $logfile > 1024*1024) {
    warn "$logfile has size ".(-s $logfile).", running bzip2\n";
    system("bzip2 $destdir/$aliases{$logfile}");
    $aliases{$logfile} .= ".bz2";
  }
    
  my @data = ();
  defined($row->{Benchmark}) or die "No Benchmark column in table\n";
  push @data, "<a href=\"$aliases{$logfile}\">$row->{Benchmark}</a>";

  defined($row->{Result}) or die "No Result column in table\n";
  my $res = $row->{Result};
  $res = "Property VIOLATED" if($row->{Result} eq "FAILED");
  $res = "Property HOLDS" if($row->{Result} eq "SUCCESSFUL");
  push @data, $res;

  push @data, defined($row->{$_}) ? $row->{$_} : "n/a"
    foreach (@headers);

  $rows{$logfile} = ();
  push @{ $rows{$logfile} }, @data;
}

close $CSV;

unshift @headers, "Result";
unshift @headers, "Benchmark";
my $ncols = scalar(@headers);
my $command = join(';', keys %{ $globals{command} });
my $version = join(';', keys %{ $globals{version} });
my $timeout = join(';', keys %{ $globals{timeout} });
my $memlimit = join(';', keys %{ $globals{memlimit} });
my $currtime = $opt_n ? "" : localtime();

open INDEX_HTML, ">$destdir/index.html" or die "Failed to create $destdir/index.html\n";
print INDEX_HTML <<"EOF";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <title>Experimental Results</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  </head>
  <style type="text/css">
<!--
.exptable, .exptable.TD, exptable.TH
{
 border:1px solid black;
 border-collapse:collapse;
 font-size:8pt;
 font-family:'Arial';
}
-->
  </style>

  <body>
    <table border=1 class="exptable">
      <tr bgcolor=lightgrey>
        <th colspan=$ncols><font size=+1>* $command version $version results *</font><br>
          Timeout: $timeout  Memory limit: $memlimit<br/>
          $currtime
        </th>
      </tr>
      <tr>
EOF

print INDEX_HTML "        <th align=\"middle\">$_</th>\n" foreach (@headers);
print INDEX_HTML "      </tr>\n";

foreach my $r (sort keys %rows) {
  print INDEX_HTML "      <tr>\n";
  print INDEX_HTML "        <td align=\"left\">$_</td>\n" foreach (@{ $rows{$r} });
  print INDEX_HTML "      </tr>\n";
}

my $sysdesc = "The benchmarks were run on a " .
  join(';', keys %{ $globals{uname} }) . ' ' .
  join(';', keys %{ $globals{cpuinfo} }) . " system equipped with " .
  join(';', keys %{ $globals{meminfo} }) . " RAM.\n";

print INDEX_HTML <<"EOF";
    </table>

    $sysdesc
  </body>
</html>
EOF


