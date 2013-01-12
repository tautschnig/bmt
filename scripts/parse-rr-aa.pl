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


# parse Rugina/Rinard timing statistics

use strict;
use warnings FATAL => qw(uninitialized);

sub parse_log {
  my ($LOG, $hash) = @_;

  my %threads = ();
    
  $hash->{Result} = "ERROR";
  $hash->{instcount} = 0;

  while (<$LOG>) {
    chomp;
    last if (/^###############################################################################$/);

    if (/Miscellaneous Ungrouped Timers/) {
      $hash->{Result} = "SUCCESS";
    #    0.0020 ( 33.3%)   0.0020 ( 33.3%)   0.0026 ( 38.1%)  Thread 0x7fff429d0a20 Iteration 1 Timer
    } elsif (/^\s+(\d+\.\d+)\s+.*Thread 0x([a-f0-9]+) Iteration (\d+) Timer\s*$/) {
      if (!defined($threads{$2})) {
        $threads{$2} = {
          total_time => 0,
          max_iter => 0,
          per_iter => {}
        };
      }

      $threads{$2}{total_time} += $1;
      $threads{$2}{max_iter} = $threads{$2}{max_iter} < $3 ? $3 : $threads{$2}{max_iter};
      defined($threads{$2}{per_iter}{$3}) and die "Iteration timer already seen\n";
      $threads{$2}{per_iter}{$3} = $1;
    } elsif (/^\s*(\d+) instcount\s+- Number of/) {
      $hash->{instcount} += $1;
    }
  }
      
  return 1 if ($hash->{Result} eq "FAILED");

  my $max_iter = 0;
  my $avg_iter = 0;
  my $max_time = 0;
  my $avg_time = 0;
  my $avg_it1_part = 0;
  my $total_time_not_it1 = 0;
  foreach my $t (keys %threads) {
    $max_iter = $max_iter < $threads{$t}{max_iter} ? $threads{$t}{max_iter} : $max_iter;
    $avg_iter += $threads{$t}{max_iter};
    $max_time = $max_time < $threads{$t}{total_time} ? $threads{$t}{total_time} : $max_time;
    $avg_time += $threads{$t}{total_time};
    $avg_it1_part += $threads{$t}{per_iter}{1} / $threads{$t}{total_time}
      if ($threads{$t}{total_time} > 0.0);
    $total_time_not_it1 += $threads{$t}{total_time} - $threads{$t}{per_iter}{1};
  }
  
  $hash->{maxiter} = $max_iter;
  $hash->{avgiter} = $avg_iter / scalar(keys %threads);
  $hash->{maxtime} = $max_time;
  $hash->{avgtime} = $avg_time / scalar(keys %threads);
  $hash->{avgit1part} = $avg_it1_part / scalar(keys %threads);
  $hash->{nthreads} = scalar(keys %threads);
  $hash->{timenotit1} = $total_time_not_it1;
}

return 1;

