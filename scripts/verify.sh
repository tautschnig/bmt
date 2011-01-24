#!/bin/bash
#
# Michael Tautschnig
# michael.tautschnig@comlab.ox.ac.uk
#
# wrapper around CPROVER verification tools to verify a claim at a time and
# generate useful benchmarking data

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
  local tmpf="`mktemp --tmpdir=. $prefix.XXX`"
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
  $SELF runs a verification tool of choice, first extracting all claims and then
  verifying each in turn. All options following -- are handed on to the back
  end.

  Options for the verify front end:     Purpose:
    -h|--help                           show help
    --no-cleanup                        don't remove generated files
    --prepare-only                      stop after preparation (implies --no-cleanup)
  Options controlling the verification back end:
    --timeout                           timeout per claim in seconds (only if supported by system)
    --satabs                            use SATABS as verification tool (default)
    --cbmc                              use CBMC as verification tool
    --wolverine                         use WOLVERINE as verification tool

EOF
}

read_output_file() {
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

prove_claims() {
  TMP_FILES="$TMP_FILES .smv_lock cegar_tmp_abstract.warn \
    cegar_tmp_abstract.smv cegar_tmp_abstract.stats \
    cegar_tmp_abstract.out cegar_tmp_abstract.update \
    cegar_tmp_smv_out1 cegar_tmp_smv_out2"
  for i in `seq 1 $NUMBER_CLAIMS` ; do
    claim_id_var="CLAIM_${i}_claim_id"
    file_var="CLAIM_${i}_file"
    line_var="CLAIM_${i}_line"
    text_var="CLAIM_${i}_text"
    claim_var="CLAIM_${i}_claim"
    echo "claim $i of $NUMBER_CLAIMS (${!claim_id_var}) " 1>&2
    echo -n "claim $i of $NUMBER_CLAIMS (${!claim_id_var}) "
    if [ "${!claim_var}" = "TRUE" ] ; then
      echo "SUCCESSFUL 0 "
    else
      exit_code=0
      mktemp_local_prefix_suffix claim_out claim .txt
      bash -i -c "$TIMEOUT $BENCHMARKING $TOOL $OPTS --claim ${!claim_id_var} $SOURCES > $claim_out 2>&1" || exit_code=$?
      case $exit_code in
        0|10)
          awk '
BEGIN {foundline = 0; linenr = 0; ORS = "";}
/VERIFICATION/ {print $2, "\t"; foundline = 1; linenr = NR}
(foundline == 1) && (NR == linenr + 1) {print $2, $4, $6, $9, $11, " "}
(foundline == 1) && (NR == linenr + 2) {print $2, " "}
(foundline == 1) && (NR == linenr + 3) {print $2, ""}
          ' $claim_out
          grep '^#STATS' $claim_out
          if [ $exit_code -eq 10 ] ; then
            mv $claim_out cex_log_${!claim_id_var}
          fi
          ;;
        124)
          echo "TIMEOUT"
          ;;
        *)
          if [ "$TOOL" = "satabs" -a $exit_code -eq 11 ] ; then
            echo -n "TOO_MANY_ITERATIONS "
            awk '
BEGIN {foundline = 0; linenr = 0; ORS = "";}
/^Too many iterations, giving up.*/ {foundline = 1; linenr = NR}
(foundline == 1) && (NR == linenr + 2) {print $2, $4, $6, $9, $11, " "}
(foundline == 1) && (NR == linenr + 3) {print $2, " "}
(foundline == 1) && (NR == linenr + 4) {print $2, "\n"}
            ' $claim_out
          else
            echo "ERROR (exit code $exit_code)"
            mv $claim_out err_log_${!claim_id_var}
          fi
          ;;
      esac
    fi
  done
}

run_tool() {
  echo -n "Running $TOOL .." 1>&2
  mktemp_local_prefix_suffix list_of_claims claims .txt
  exit_code=0
  $TOOL $OPTS --show-claims $SOURCES > $list_of_claims || exit_code=$?
  if [ $exit_code -ne 0 ] && [ "$TOOL" != "satabs" -o $exit_code -ne 1 ] ; then
    echo
    die "Could not start $TOOL"
  fi
  echo "." 1>&2
  echo -n "Parsing $TOOL output .." 1>&2
  mktemp_local_prefix_suffix list_of_claims_converted claimsconv .txt
  awk '
BEGIN {foundclaim = 0;}
/^Claim*/ {foundclaim = 1; claim = NR; n = length($2) - 1; str = substr($2, 1, n); print str}
(NR == claim + 1) && (foundclaim == 1) {print $2 "\n" $4}
(NR == claim + 2) && (foundclaim == 1) {print substr($0, 3)}		
(NR == claim + 3) && (foundclaim == 1) {print substr($0, 3) "\n"}
  ' $list_of_claims > $list_of_claims_converted
  echo "." 1>&2
  read_output_file $list_of_claims_converted
  echo "$NUMBER_CLAIMS Claims" 1>&2
  prove_claims
}

SELF=$0

opts=`getopt -n "$0" -o "h" --long "\
	    help,\
      no-cleanup,\
	    prepare-only,\
      timeout:,\
	    satabs,\
	    cbmc,\
      wolverine,\
  " -- "$@"`
eval set -- "$opts"

unset NO_CLEANUP PREPARE_ONLY TIMEOUT

TOOL=satabs

while true ; do
  case "$1" in
    -h|--help) usage ; exit 0;;
    --no-cleanup) NO_CLEANUP=1 ; shift 1;;
	  --prepare-only) PREPARE_ONLY=1 ; NO_CLEANUP=1 ; shift 1;;
    --timeout)
      if ! echo $2 | egrep -q "^[[:digit:]]+$" ; then
        die "Invalid parameter to --timeout"
      fi
      TIMEOUT="timeout -s SIGINT $2" ; shift 2;;
	  --satabs) TOOL=satabs ; shift 1;;
	  --cbmc) TOOL=cbmc ; shift 1;;
	  --wolverine) TOOL=wolverine ; shift 1;;
    --) shift ; break ;;
    *) die "Unknown option $1" ;;
  esac
done


unset SOURCES OPTS
for o in $@ ; do
  case "$o" in
    -*)
      OPTS=$@
      break
      ;;
    *)
      [ -f "$o" ] || die "Source file $o not found"
      SOURCES="$SOURCES $o"
      shift 1
      ;;
  esac
done
[ -n "$SOURCES" ] || die "No source file given"

BENCHMARKING="/usr/bin/time -f '#STATS: cpu=%U wall=%e maxmem=%M'"

run_tool

