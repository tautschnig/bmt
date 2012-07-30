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
  $hash->{"Transition refinements"} = -1;
  $hash->{"Invalid states requiring more than 1 passive thread"} = 0;
  $hash->{"Spurious guard transitions requiring more than 1 passive thread"} = 0;
  $hash->{"Spurious assignment transitions requiring more than 1 passive thread"} = 0;

  while (<$LOG>) {
    chomp;
    return 1 if (/^###############################################################################$/);

    if (/^Too many iterations, giving up/) {
      $hash->{Result} = "TOO_MANY_ITERATIONS";
    } elsif (/^Timeout: aborting command/) {
      $hash->{Result} = "TIMEOUT";
    } elsif (/^VERIFICATION\s+(\S+)$/) {
      $hash->{Result} = "$1";
    } elsif (/^Time: (\d+\.\d+) total, (\d+\.\d+) abstractor, (\d+\.\d+) model checker, (\d+\.\d+) simulator, (\d+\.\d+) refiner$/) {
      $hash->{"Time abstractor"} = $2;
      $hash->{"Time model checker"} = $3;
      $hash->{"Time simulator"} = $4;
      $hash->{"Time refiner"} = $5;
    } elsif (/^Time: (\d+\.\d+) total, (\d+\.\d+) abstractor, (\d+\.\d+) model checker, (\d+) simulator, (\d+\.\d+) refiner$/) {
      $hash->{"Time abstractor"} = $2;
      $hash->{"Time model checker"} = $3;
      $hash->{"Time simulator"} = $4;
      $hash->{"Time refiner"} = $5;
    } elsif (/^Time: (\d+\.\d+) total, (\d+\.\d+) abstractor, (\d+\.\d+) model checker, (\d+) simulator, (\d+) refiner$/) {
      $hash->{"Time abstractor"} = $2;
      $hash->{"Time model checker"} = $3;
      $hash->{"Time simulator"} = $4;
      $hash->{"Time refiner"} = $5;
    } elsif (/^Time: (\d+\.\d+) total, (\d+\.\d+) abstractor, (\d+\.\d+) model checker, (\d+\.\d+) simulator, (\d+) refiner$/) {
      $hash->{"Time abstractor"} = $2;
      $hash->{"Time model checker"} = $3;
      $hash->{"Time simulator"} = $4;
      $hash->{"Time refiner"} = $5;
    } elsif (/^Iterations: (\d+)$/) {
      $hash->{Iterations} = $1;
      $hash->{"Transition refinements"} += $1;
    } elsif (/^\s+shared: (\d+)$/) {
      $hash->{"Shared predicates"} = $1;
    } elsif (/^\s+local: (\d+)$/) {
      $hash->{"Local predicates"} = $1;
    } elsif (/^\s+mixed: (\d+)$/) {
      $hash->{"Mixed predicates"} = $1;
    } elsif (/^Transitions are not spurious$/) {
      --$hash->{"Transition refinements"};
    } elsif (/^Broadcast assignment operations executed: (\d+)$/) {
      $hash->{"Broadcast assignment operations executed"} = $1;
    } elsif (/^Max number of slots used: (\d+)$/) {
      $hash->{"Max number of slots used"} = $1;
    } elsif (/^Non-broadcast assignment operations executed: (\d+)$/) {
      $hash->{"Non-broadcast assignment operations executed"} = $1;
    } elsif (/^Time spent in broadcast assignment operations: (\S+)$/) {
      $hash->{"Time spent in broadcast assignment operations"} = $1;
    } elsif (/^Time spent in non-broadcast assignment operations: (\S+)$/) {
      $hash->{"Time spent in non-broadcast assignment operations"} = $1;
    } elsif (/^Invalid states requiring more than 1 passive thread: (\d+)$/) {
      $hash->{"Invalid states requiring more than 1 passive thread"} = $1;
    } elsif (/^Spurious guard transitions requiring more than 1 passive thread: (\d+)$/) {
      $hash->{"Spurious guard transitions requiring more than 1 passive thread"} = $1;
    } elsif (/^Spurious assignment transitions requiring more than 1 passive thread: (\d+)$/) {
      $hash->{"Spurious assignment transitions requiring more than 1 passive thread"} = $1;
    } elsif (/^Total transition refinements: (\d+)$/) {
      $hash->{"Total transition refinements"} = $1;
    }
  }
}

return 1;

