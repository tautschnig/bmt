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
    --scratch                           use SCRATCH as verification tool

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
    echo -n "claim $i of $NUMBER_CLAIMS (${!claim_id_var}) ... "
    
    mktemp_local_prefix_suffix time_out stats .stat
    BENCHMARKING="/usr/bin/time -v -o$time_out"
    exit_code=0
    mktemp_local_prefix_suffix claim_out log .err
    cat > $claim_out <<EOF
uname -a:
`uname -a`
cat /proc/cpuinfo:
`cat /proc/cpuinfo`
cat /proc/meminfo:
`cat /proc/meminfo`
date:
`date`
user:
$USER
ulimit -a:
`ulimit -a`
timeout:
$TIMEOUT
command:
$TOOL $OPTS --claim ${!claim_id_var} $SOURCES
###############################################################################
EOF
    if [ "${!claim_var}" = "TRUE" ] ; then
      bash -i -c "$BENCHMARKING echo -e "Trivially true.\nVERIFICATION SUCCESSFUL" >> $claim_out 2>&1" || exit_code=$?
    else
      bash -i -c "$TIMEOUT $BENCHMARKING $TOOL $OPTS --claim ${!claim_id_var} $SOURCES >> $claim_out 2>&1" || exit_code=$?
    fi
    cat >> $claim_out <<EOF
###############################################################################
exit code:
$exit_code
statistics:
`cat $time_out`
EOF
    mv $claim_out log_${!claim_id_var}

    echo "done."
    echo "LOGFILE: $PWD/log_${!claim_id_var}"
  done
}

run_tool() {
  echo -n "Running $TOOL ... "
  mktemp_local_prefix_suffix list_of_claims claims .txt
  exit_code=0
  $TOOL $OPTS --show-claims $SOURCES > $list_of_claims || exit_code=$?
  if [ $exit_code -ne 0 ] && [ "$TOOL" != "satabs" -o $exit_code -ne 1 ] ; then
    echo
    die "Could not start $TOOL"
  fi
  echo "done."
  echo -n "Parsing $TOOL output ... "
  mktemp_local_prefix_suffix list_of_claims_converted claimsconv .txt
  awk '
BEGIN {foundclaim = 0;}
/^Claim*/ {foundclaim = 1; claim = NR; n = length($2) - 1; str = substr($2, 1, n); print str}
(NR == claim + 1) && (foundclaim == 1) {print $2 "\n" $4}
(NR == claim + 2) && (foundclaim == 1) {print substr($0, 3)}		
(NR == claim + 3) && (foundclaim == 1) {print substr($0, 3) "\n"}
  ' $list_of_claims > $list_of_claims_converted
  echo "done."
  read_claims $list_of_claims_converted
  echo "$NUMBER_CLAIMS claims"
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
      scratch,\
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
	  --scratch) TOOL=scratch ; shift 1;;
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

