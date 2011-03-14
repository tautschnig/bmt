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

sub parse_results {
  my ($file,$hash) = @_;
  open RESULTS, "<$file" or die "File $file not found\n";

  my $res_mode = 0;
  $hash->{tool} = undef;
  $hash->{timeout} = undef;
  while (<RESULTS>) {
    chomp;
    if (!$res_mode && /^TOOL: (.+)$/) {
      !defined($hash->{tool}) or die "TOOL: header already seen\n";
      $hash->{tool} = $1;
    } elsif (!$res_mode && /^TIMEOUT: (\d+)$/) {
      !defined($hash->{timeout}) or die "TIMEOUT: header already seen\n";
      $hash->{timeout} = $1;
    } elsif (!$res_mode && /^RESULTS:$/) {
      $res_mode = 1;
      $hash->{results} = ();
    } else {
      (1 == $res_mode) or die "Header not yet seen\n";
      (/^claim \d+ of \d+ \((.+)\) (SUCCESSFUL|FAILED|TOO_MANY_ITERATIONS|ERROR|TIMEOUT)(.*)$/) or
        die "Unexpected input $_\n";
      my $claim = $1;
      my %data = (
        status => $2,
        cpu => undef,
        mem => undef
      );
      my $rest = $3;
      if ($data{status} eq "TIMEOUT" || $data{status} eq "TOO_MANY_ITERATIONS"
        || $data{status} eq "ERROR") {
        $data{cpu} = $data{status} eq "TIMEOUT" ? "TO" : 
          ($data{status} eq "ERROR" ? "ERR" : "ITER");
        $data{status} = "--";
        $data{mem} = "--";
      } elsif ($data{status} eq "SUCCESSFUL" && ($rest =~ / 0\s*$/)) {
        $data{status} = "triv";
        $data{cpu} = 0;
        $data{mem} = 0;
      } elsif ($data{status} eq "FAILED" || $data{status} eq "SUCCESSFUL") {
        $data{status} = $data{status} eq "FAILED" ? "inv" : "ok";
        ($rest =~ /^.*#STATS: cpu=(.+) wall=(.+) maxmem=(\d+)$/) or
          die "Failed to parse statistics in $rest\n";
        $data{cpu} = $1;
        $data{mem} = $3 / 1024.0;
      } else {
        # just in case somebody extends the pattern above
        die "Unhandled status $data{status}\n";
      }
      $hash->{results}->{$claim} = \%data;
    }
  }
  close RESULTS;
}

return 1;

