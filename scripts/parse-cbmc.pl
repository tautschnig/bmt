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


# parse the CPROVER tool specific part of a benchmark log file

use strict;
use warnings FATAL => qw(uninitialized);

sub parse_log {
  my ($LOG, $hash) = @_;
  
  $hash->{Result} = "ERROR";

  while (<$LOG>) {
    chomp;
    return 1 if (/^###############################################################################$/);

    if (/^Timeout: aborting command/) {
      $hash->{Result} = "TIMEOUT";
    } elsif (/^VERIFICATION\s+(\S+)$/) {
      $hash->{Result} = "$1";
    } elsif (/^max-per-address:\s+(\d+)$/) {
      $hash->{mt_max_per_address} = $1;
    } elsif (/^num-unique-addresses:\s+(\d+)$/) {
      $hash->{mt_num_unique_addresses} = $1;
    } elsif (/^tot-subevent-count:\s+(\d+)$/) {
      $hash->{mt_tot_subevent_count} = $1;
    } elsif (/^(po|rf|rfi|ws|fr|ab):\s+(\d+)$/) {
      $hash->{mt_$1} = $2;
    } elsif (/^(atomic-block|rf-at-least-one|thread-spawn|uniproc|thin-air|ws-preceding):\s+(\d+)$/) {
      $hash->{mt_$1} = $2;
    }
  }

  my $max = 0;
  $hash->{mt_max_constr} = "po (0)";
  for my $r (qw/po rf ws fr ab/) {
    my $val = defined($hash->{mt_$r}) ? $hash->{mt_$r} : 0;
    $val += defined($hash->{mt_rfi}) ? $hash->{mt_rfi} : 0 if($r eq "rf");

    $hash->{mt_max_constr} = "$r ($val)" if($val > $max);
  }
}

return 1;

