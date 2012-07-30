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
  $hash->{"bw finished first"} = "UNSET";
  $hash->{"iterations"} = "UNSET";
  $hash->{"work iterations"} = "UNSET";
  $hash->{"prune iterations"} = "UNSET";
  $hash->{"foward prune cycles"} = "UNSET";
  $hash->{"backward prune cycles"} = "UNSET";
  $hash->{"oracle dequeues"} = "UNSET";
  $hash->{"pruned"} = "UNSET";
  $hash->{"known"} = "UNSET";
  $hash->{"new predecessors"} = "UNSET";
  $hash->{"existing predecessors"} = "UNSET";
  $hash->{"locally_minimal"} = "UNSET";
  $hash->{"locally_non_minimal"} = "UNSET";
  $hash->{"globally_minimal"} = "UNSET";
  $hash->{"neq_nge_nle"} = "UNSET";
  $hash->{"globally_non_minimal"} = "UNSET";
  $hash->{"lowerset intersections"} = "UNSET";
  $hash->{"initial_intersect"} = "UNSET";
  $hash->{"root_intersect"} = "UNSET";
  $hash->{"lowerset_intersect"} = "UNSET";
  $hash->{"locally_pruned"} = "UNSET";
  $hash->{"max. backward depth checked"} = "UNSET";
  $hash->{"max. backward width checked"} = "UNSET";
  $hash->{"fw finished first"} = "UNSET";
  $hash->{"time to find projections"} = "UNSET";
  $hash->{"forward-reachable global states"} = "UNSET";
  $hash->{"projections found"} = "UNSET";
  $hash->{"accelerations"} = "UNSET";
  $hash->{"max acceleration depth checked"} = "UNSET";
  $hash->{"max acceleration depth"} = "UNSET";
  $hash->{"max. forward depth checked"} = "UNSET";
  $hash->{"max. forward width checked"} = "UNSET";
  $hash->{"osz_max"} = "UNSET";
  $hash->{"nsz_max"} = "UNSET";
  $hash->{"msz_max"} = "UNSET";
  $hash->{"dsz_max"} = "UNSET";
  $hash->{"wsz_max"} = "UNSET";

  $hash->{"local states"} = "UNSET";
  $hash->{"shared states"} = "UNSET";
  $hash->{"transitions"} = "UNSET";
  $hash->{"thread transitions"} = "UNSET";
  $hash->{"broadcast transitions"} = "UNSET";
  $hash->{"spawn transitions"} = "UNSET";
  $hash->{"dimension of target state"} = "UNSET";

  while (<$LOG>) {
    chomp;
    return 1 if (/^###############################################################################$/);

	if (/^VERIFICATION\s+(\S+)$/) {
	      $hash->{Result} = "$1";
	} elsif (/^bw finished first               : (\S+)$/) {
	      $hash->{"bw finished first"} = $1;
	} elsif (/^iterations                      : (\d+)$/) {
	      $hash->{"iterations"} = $1;
	} elsif (/^- work iterations               : (\d+)$/) {
	      $hash->{"work iterations"} = $1;
	} elsif (/^- prune iterations              : (\d+)$/) {
	      $hash->{"prune iterations"} = $1;
	} elsif (/^- foward prune cycles           : (\d+)$/) {
	      $hash->{"foward prune cycles"} = $1;
	} elsif (/^- backward prune cycles         : (\d+)$/) {
	      $hash->{"backward prune cycles"} = $1;
	} elsif (/^oracle dequeues                 : (\d+)$/) {
	      $hash->{"oracle dequeues"} = $1;
	} elsif (/^- pruned                        : (\d+)$/) {
	      $hash->{"pruned"} = $1;
	} elsif (/^- known                         : (\d+)$/) {
	      $hash->{"known"} = $1;
	} elsif (/^new predecessors                : (\d+)$/) {
	      $hash->{"new predecessors"} = $1;
	} elsif (/^existing predecessors           : (\d+)$/) {
	      $hash->{"existing predecessors"} = $1;
	} elsif (/^locally_minimal                 : (\d+)$/) {
	      $hash->{"locally_minimal"} = $1;
	} elsif (/^locally_non_minimal             : (\d+)$/) {
	      $hash->{"locally_non_minimal"} = $1;
	} elsif (/^globally_minimal                : (\d+)$/) {
	      $hash->{"globally_minimal"} = $1;
	} elsif (/^- neq_nge_nle                   : (\d+)$/) {
	      $hash->{"neq_nge_nle"} = $1;
	} elsif (/^globally_non_minimal            : (\d+)$/) {
	      $hash->{"globally_non_minimal"} = $1;
	} elsif (/^lowerset intersections          : (\d+)$/) {
	      $hash->{"lowerset intersections"} = $1;
	} elsif (/^- initial_intersect             : (\d+)$/) {
	      $hash->{"initial_intersect"} = $1;
	} elsif (/^- root_intersect                : (\d+)$/) {
	      $hash->{"root_intersect"} = $1;
	} elsif (/^- lowerset_intersect            : (\d+)$/) {
	      $hash->{"lowerset_intersect"} = $1;
	} elsif (/^locally_pruned                  : (\d+)$/) {
	      $hash->{"locally_pruned"} = $1;
	} elsif (/^max. backward depth checked     : (\d+)$/) {
	      $hash->{"max. backward depth checked"} = $1;
	} elsif (/^max. backward width checked     : (\d+)$/) {
	      $hash->{"max. backward width checked"} = $1;
	} elsif (/^fw finished first               : (\S+)$/) {
	      $hash->{"fw finished first"} = $1;
	} elsif (/^time to find projections        : (\S+)$/) {
	      $hash->{"time to find projections"} = $1;
	} elsif (/^forward-reachable global states : (\d+)$/) {
	      $hash->{"forward-reachable global states"} = $1;
	} elsif (/^projections found               : (\d+)$/) {
	      $hash->{"projections found"} = $1;
	} elsif (/^accelerations                   : (\d+)$/) {
	      $hash->{"accelerations"} = $1;
	} elsif (/^max acceleration depth checked  : (\d+)$/) {
	      $hash->{"max acceleration depth checked"} = $1;
	} elsif (/^max acceleration depth          : (\d+)$/) {
	      $hash->{"max acceleration depth"} = $1;
	} elsif (/^max. forward depth checked      : (\d+)$/) {
	      $hash->{"max. forward depth checked"} = $1;
	} elsif (/^max. forward width checked      : (\d+)$/) {
	      $hash->{"max. forward width checked"} = $1;
	} elsif (/^osz_max                         : (\d+)$/) {
	      $hash->{"osz_max"} = $1;
	} elsif (/^nsz_max                         : (\d+)$/) {
	      $hash->{"nsz_max"} = $1;
	} elsif (/^msz_max                         : (\d+)$/) {
	      $hash->{"msz_max"} = $1;
	} elsif (/^dsz_max                         : (\d+)$/) {
	      $hash->{"dsz_max"} = $1;
	} elsif (/^wsz_max                         : (\d+)$/) {
	      $hash->{"wsz_max"} = $1;
	} elsif (/^local states                    : (\d+)$/) {
	      $hash->{"local states"} = $1;
	} elsif (/^shared states                   : (\d+)$/) {
	      $hash->{"shared states"} = $1;
	} elsif (/^transitions                     : (\d+)$/) {
	      $hash->{"transitions"} = $1;
	} elsif (/^thread transitions              : (\d+)$/) {
	      $hash->{"thread transitions"} = $1;
	} elsif (/^broadcast transitions           : (\d+)$/) {
	      $hash->{"broadcast transitions"} = $1;
	} elsif (/^spawn transitions               : (\d+)$/) {
	      $hash->{"spawn transitions"} = $1;
	} elsif (/^dimension of target state       : (\d+)$/) {
	      $hash->{"dimension of target state"} = $1;
        }


  }
}


return 1;
