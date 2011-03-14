#!/bin/bash
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


# wrapper around CPROVER verification tools to obtain a list of claims; for
# other (unsupported) verification tools, ALL_CLAIMS:UNKNOWN is returned

set -e

die() {
  echo $1
  exit 1
}
  
ifs_bak=$IFS

cleanup() {
  IFS=$ifs_bak
  if [ -z "$NO_CLEANUP" ] ; then
    for f in $TMP_FILES ; do
      if [ -f $f ] ; then
        rm $f
      fi
    done
    rm -f tmp.stderr*.txt
  fi
}

trap 'cleanup' ERR EXIT

mktemp_local_prefix_suffix() {
  local varname=$1
  local prefix=$2
  local suffix=$3
  local tmpf="`TMPDIR=. mktemp -t $prefix.XXXXXX`"
  TMP_FILES="$TMP_FILES $tmpf"
  local rand="`echo $tmpf | sed "s#^./$prefix\\\.##"`"
  eval $varname=\"${prefix}_$rand$suffix\"
  TMP_FILES="$TMP_FILES ${!varname}"
  [ ! -f "${!varname}" ] || die "File already exists"
  mv $tmpf ${!varname}
}

usage() {
  cat <<EOF
Usage: $SELF [OPTIONS] SOURCES ... [-- BACKENDOPTS]
  where SOURCES are C files or goto binaries
  $SELF runs a verification tool of choice to extract a list of claim names.
  All options following "--" are handed on to the tool.

  Options for the verify front end:     Purpose:
    -h|--help                           show help
    --no-cleanup                        don't remove generated files
    --cmd CMD                           target verification tool to list claims for

EOF
}

read_claims() {
  local ofile=$1
  NUMBER_CLAIMS=0
  local ifs=$IFS
  IFS='
'
  while read line1 && read line2 && read line3 && read line4 && read line5 && read line6 ; do
    NUMBER_CLAIMS=$((NUMBER_CLAIMS + 1))
    eval CLAIM_${NUMBER_CLAIMS}_claim_id=\'$line1\'
    eval CLAIM_${NUMBER_CLAIMS}_file=\'$line2\'
    eval CLAIM_${NUMBER_CLAIMS}_line=\'$line3\'
    eval CLAIM_${NUMBER_CLAIMS}_text='\"$line4\"'
    eval CLAIM_${NUMBER_CLAIMS}_claim=\'$line5\'
    [ -z "$line6" ] || die "Unexpected non-empty line $line6"
  done < $ofile
  IFS=$ifs
}

print_claims() {
  for i in `seq 1 $NUMBER_CLAIMS` ; do
    claim_id_var="CLAIM_${i}_claim_id"
    file_var="CLAIM_${i}_file"
    line_var="CLAIM_${i}_line"
    text_var="CLAIM_${i}_text"
    claim_var="CLAIM_${i}_claim"
    if [ "${!claim_var}" = "TRUE" ] ; then
      echo "${!claim_id_var}:TRUE"
    else
      echo "${!claim_id_var}:UNKNOWN"
    fi
  done
}

run_tool() {
  echo -n "Running $TOOL ... " 1>&2
  mktemp_local_prefix_suffix list_of_claims claims .txt
  exit_code=0
  $TOOL $OPTS --show-claims $SOURCES > $list_of_claims || exit_code=$?
  if [ $exit_code -ne 0 ] && [ "$TOOL" != "satabs" -o $exit_code -ne 1 ] ; then
    die "Could not start $TOOL"
  fi
  echo "done." 1>&2
  echo -n "Parsing $TOOL output ... " 1>&2
  mktemp_local_prefix_suffix list_of_claims_converted claimsconv .txt
  awk '
BEGIN {foundclaim = 0;}
/^Claim*/ {foundclaim = 1; claim = NR; n = length($2) - 1; str = substr($2, 1, n); print str}
(NR == claim + 1) && (foundclaim == 1) {print $2 "\n" $4}
(NR == claim + 2) && (foundclaim == 1) {print substr($0, 3)}		
(NR == claim + 3) && (foundclaim == 1) {print substr($0, 3) "\n"}
  ' $list_of_claims > $list_of_claims_converted
  echo "done." 1>&2
  read_claims $list_of_claims_converted
  echo "$NUMBER_CLAIMS claims" 1>&2
  print_claims
}

SELF=$0

opts=`getopt -n "$0" -o "h" --long "\
	    help,\
      no-cleanup,\
      cmd:,\
  " -- "$@"`
eval set -- "$opts"

unset NO_CLEANUP TOOL

while true ; do
  case "$1" in
    -h|--help) usage ; exit 0;;
    --no-cleanup) NO_CLEANUP=1 ; shift 1;;
	  --cmd) TOOL="$2" ; shift 2;;
    --) shift ; break ;;
    *) die "Unknown option $1" ;;
  esac
done

[ -n "$TOOL" ] || die "Please select the verification tool to be used"

case "$TOOL" in
  satabs|cbmc|wolverine|scratch|loopfrog)
    unset SOURCES OPTS
    for o in $@ ; do
      case "$o" in
        -*)
          OPTS=$@
          break
          ;;
        *)
          [ -f "$o" ] || die "Source file $o not found"
          if [ "$TOOL" = "scratch" -a "`file -b $o`" = "data" ] ; then
            SOURCES="$SOURCES --binary $o"
          else
            SOURCES="$SOURCES $o"
          fi
          shift 1
          ;;
      esac
    done
    [ -n "$SOURCES" ] || die "No source file given"

    run_tool
    ;;
  *)
    echo "No specific support for $TOOL" 1>&2
    echo "ALL_CLAIMS:UNKNOWN"
    ;;
esac

