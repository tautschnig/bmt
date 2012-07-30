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


# build a CSV table of results

use strict;
use warnings FATAL => qw(uninitialized);

sub usage {
  print <<"EOF";
Usage: $0 TOOL RESULTS
  where TOOL specifies the log parser to be used an RESULTS lists log files
  produced by verify.sh

EOF
}

if (scalar(@ARGV) != 2) {
  usage;
  exit 1;
}

my $config = $ARGV[0];
my $file = $ARGV[1];

use File::Basename qw(dirname);
use lib dirname($0);
use lib "cprover/";
require "parse-$config.pl";

sub parse_description {
  my ($LOG, $hash) = @_;
  my $mode = "";

  while (<$LOG>) {
    chomp;
    return 1 if (/^###############################################################################$/);

    $mode = "uname", next if (/^### uname -a:$/);
    $mode = "cpuinfo", next if (/^### cat \/proc\/cpuinfo:$/);
    $mode = "cpuinfo_osx", next if (/^### \/usr\/sbin\/system_profiler -detailLevel full SPHardwareDataType:$/);
    $mode = "meminfo", next if (/^### cat \/proc\/meminfo:$/);
    $mode = "meminfo_osx", next if (/^### \/usr\/sbin\/system_profiler -detailLevel full SPMemoryDataType:$/);
    $mode = "date", next if (/^### date:$/);
    $mode = "user", next if (/^### user:$/);
    $mode = "ulimit", next if (/^### ulimit -a:$/);
    $mode = "timeout", next if (/^### timeout:$/);
    $mode = "version", next if (/^### tool version info:$/);
    $mode = "command", next if (/^### tool command:$/);
    $mode = "commandline", next if (/^### full command line:$/);
    $mode = "expected", next if (/^### expected verification result:$/);

    if ($mode eq "uname") {
      /^(\S+)\s+(\S+)\s+(\S+)\s+/ or die "Unexpected uname output\n";
      $hash->{$mode} = "$1 $3";
    } elsif ($mode eq "cpuinfo") {
      defined($hash->{$mode}) or $hash->{$mode} = "0x XXX \@\@YYYMHz";
      /^(processor\s*:\s*(\d+))|(model name\s*:\s*(.*))|(cpu MHz\s*:\s*(.*))$/ or next;
      if (defined($2)) {
        ($hash->{$mode} =~ /^(\d+)(x .*)$/) or die "Invalid cpu def\n";
        $hash->{$mode} = ($1 + 1) . $2;
      } elsif (defined($4)) {
        my $model = $4;
        ($hash->{$mode} =~ /^(\d+)x (.*) @@(.*)MHz$/) or die "Invalid cpu def\n";
        ($2 eq "XXX") or ($2 eq $model) or die "NUMA system with both $model and $2 not supported\n";
        $hash->{$mode} = "$1x $model \@\@$3MHz";
      } elsif (defined($6)) {
        my $freq = $6;
        ($hash->{$mode} =~ /^(\d+)x (.*) @@(.*)MHz$/) or die "Invalid cpu def\n";
        $hash->{$mode} = "$1x $2 \@\@${freq}MHz";
      }
    } elsif ($mode eq "cpuinfo_osx") {
      defined($hash->{cpuinfo}) or $hash->{cpuinfo} = "1x XXX \@\@YYYMHz";
      if (/^\s+Processor Name: (.*)$/) {
        my $model = $1;
        $hash->{cpuinfo} =~ s/XXX/$model/;
      } elsif (/^\s+Processor Speed: (.*) GHz$/) {
        my $freq = $1 * 1000;
        $hash->{cpuinfo} =~ s/YYY/$freq/;
      } elsif (/^\s+(Number Of Processors|Total Number Of Cores): (\d+)$/) {
        my $count = $2;
        ($hash->{cpuinfo} =~ /^(\d+)(x .*)$/) or die "Invalid cpu def\n";
        $hash->{cpuinfo} = ($1 * $count) . $2;
      }
    } elsif ($mode eq "meminfo") {
      /^MemTotal:\s+(\d+) kB/ or next;
      $hash->{$mode} = "$1kb";
    } elsif ($mode eq "meminfo_osx") {
      defined($hash->{meminfo}) or $hash->{meminfo} = "0kb";
      /^\s+Size:\s+(\d+)\s+GB/ or next;
      my $banksize = $1 * 1024 * 1024;
      ($hash->{meminfo} =~ /^(\d+)kb$/) or die "Invalid mem info\n";
      $hash->{meminfo} = ($1 + $banksize) . "kb";
    } elsif ($mode eq "date") {
      $hash->{$mode} = "$_";
    } elsif ($mode eq "user") {
      $hash->{$mode} = "$_";
    } elsif ($mode eq "ulimit") {
      /^virtual memory\s+\(kbytes, -v\) (unlimited|\d+)$/ or next;
      $hash->{memlimit} = "$1kb";
    } elsif ($mode eq "timeout") {
      /^(\s*|timeout -(s SIGINT|2) (\d+))$/ or die "Unexpected timeout format\n";
      $hash->{$mode} = defined($3) ? "$3s" : "-";
    } elsif ($mode eq "version") {
      $hash->{$mode} = "$_";
    } elsif ($mode eq "command") {
      $hash->{$mode} = "$_";
    } elsif ($mode eq "commandline") {
      $hash->{$mode} = "$_";
    } elsif ($mode eq "expected") {
      $hash->{$mode} = "$_";
    } else {
      die "Don't know what to do in mode $mode\n";
    }
  }
}

sub parse_exit {
  my ($LOG, $hash) = @_;
  my $mode = "";

  while (<$LOG>) {
    chomp;

    $mode = "exitcode", next if (/^### exit code:$/);
    $mode = "time", next if (/^### \/usr\/bin\/time -v:$/);
    $mode = "time_osx", next if (/^### \/usr\/bin\/time -l:$/);

    if ($mode eq "exitcode") {
      #/^(\d+)$/ or die "Unexpected exit code format\n";
      /^(\d+)$/ or next;
      $hash->{$mode} = $1;
      if ($1 == 124) {
        $hash->{Result} = "TIMEOUT";
      }
    } elsif ($mode eq "time") {
      if (/^\s+User time \(seconds\): (\d+\.\d+)$/) {
        $hash->{usertime} = $1;
      } elsif (/^\s+Elapsed \(wall clock\) time \(h:mm:ss or m:ss\): ((\d+:)?\d+:\d+\.\d+)$/) {
        $hash->{wallclock} = $1;
      } elsif (/^\s+Maximum resident set size \(kbytes\): (\d+)$/) {
        $hash->{maxmem} = "$1kb";
      } elsif (/^SC_time:\s+(\d+\.\d+)$/) {
        $hash->{sc_time} = "$1";
        defined($hash->{usertime}) and
        $hash->{overhead} = $hash->{usertime}/$1;
      }
    } elsif ($mode eq "time_osx") {
      if (/^\s+(\d+\.\d+)\s+real\s+(\d+\.\d+)\s+user\s+(\d+\.\d+)\s+sys$/) {
        $hash->{usertime} = $2;
        $hash->{wallclock} = $1;
      } elsif (/^\s+(\d+)\s+maximum resident set size$/) {
        $hash->{maxmem} = ($1/1024) . "kb";
      }
    } else {
      die "Don't know what to do in mode $mode\n";
    }
  }
}

sub parse_file {
  my ($file, $hash) = @_;
  open my $LOG, "<$file" or die "Logfile $file not found\n";

  &parse_description($LOG, $hash);
  &parse_log($LOG, $hash);
  &parse_exit($LOG, $hash);

  close $LOG;
}

my %results = ();

open RESULTS, "<$file" or die "File $file not found\n";
while (<RESULTS>) {
  chomp;
  next unless (/^LOGFILE:\s+(\S+)$/);
  print STDERR "Parsing $1\n";
  defined($results{$1}) and die "Duplicate log file $1\n";
  my $fname = $1;
  $results{$fname} = ();
  my $bm_name = $fname;
  if ($bm_name =~ /^.*\/results\.[^\/]+\/(\S+)\.[a-z]+_(\S+)_\d{4}-\d\d-\d\d_\d{6}_.{6}\.log$/)
  {
    $bm_name = ($2 eq "ALL_CLAIMS") ? $1 : "$1:$2";
  }
  elsif ($bm_name =~ /^.*\/(tests|results\.[^\/]+)\/([^\/]+).*(\/[a-z]+\/([^\/_]+\d+|iriw[^\/_]+))_([a-z]+(.oepc)?).*_(\S+)_\d{4}-\d\d-\d\d_\d{6}_.{6}\.log$/)
  {
    $bm_name = ($7 eq "CLAIMS" || $7 eq "ALL_CLAIMS" || $7 eq "main.1") ? "$2$3($5)" : "$2$3($5):$7";
    defined($6) and $bm_name =~ s/\)/) 1d/;
  }
  elsif ($bm_name =~ /^.*\/(tests|results\.[^\/]+)\/([^\/]+).*(\/[a-z]+\/([^\/_]+\d+|iriw[^\/_]+))\.goto_(\S+)_\d{4}-\d\d-\d\d_\d{6}_.{6}\.log$/)
  {
    ($config eq "cbmc") or die "Benchmark name only acceptable for cbmc\n";
    my $mm = `grep memory-model $fname | sed 's/.*memory-model //' | awk '{ print \$1 }' | head -n 1`;
    chomp $mm;
    $bm_name = ($5 eq "CLAIMS" || $5 eq "ALL_CLAIMS" || $5 eq "main.1") ? "$2$3($mm)" : "$2$3($mm):$5";
    defined($4) and $bm_name =~ s/\)/) 1d/;
    ($mm =~ /^(sc|tso|pso|rmo|power)(\.oepc)?$/) or die "Invalid memory model $mm\n";
  }
  else
  {
    die "Don't know how to extract benchmark name from log file name $fname\n";
  }
  $results{$fname}{Benchmark} = $bm_name;
  # default to ERROR
  $results{$fname}{Result} = "ERROR";
  &parse_file($fname, \%{ $results{$fname} });
}
close RESULTS;

my %all_fields = ();
foreach my $f (keys %results) {
  $all_fields{$_} = 1 foreach (keys %{ $results{$f} });
}

use Text::CSV;
my $csv = Text::CSV->new();

my @headings = sort keys %all_fields;
unshift @headings, "Log File";
$csv->combine(@headings) or die "Error: ".$csv->error_input()."\n";
print $csv->string() . "\n";

foreach my $f (sort keys %results) {
  my @row = ();
  push @row, $f;
  foreach my $field (sort keys %all_fields) {
    push @row, defined($results{$f}{$field}) ? 
      $results{$f}{$field} : "";
  }
  $csv->combine(@row) or die "Error: ".$csv->error_input()."\n";
  print $csv->string() . "\n";
}


