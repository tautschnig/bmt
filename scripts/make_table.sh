#!/bin/bash
#
# Michael Tautschnig
# michael.tautschnig@comlab.ox.ac.uk
#
# build a LaTeX table of results

set -e

die() {
  echo $1
  exit 1
}
  
usage() {
  cat <<EOF
Usage: $SELF RESULTS
  where RESULTS is a file as produced by verify.sh

EOF
}

SELF=$0
RESULTS=$1

if [ $# -ne 1 ] ; then
  usage
  exit 1
fi

[ -f $RESULTS ] || die "File $RESULTS not found"

cat <<"EOF"
% requires booktabs package
\begin{table}
  \centering
  \begin{tabular}{llrr}
  \toprule
  Benchmark & Status & \multicolum{1}{c}{CPU Time [s]} & \multicolum{1}{c}{Memory Usage [MB]} \\ \midrule
EOF

ifs=$IFS
IFS='
'
results=0
while read line ; do
  case "$line" in
    TOOL:*) TOOL="`echo $line | sed 's/^TOOL: //'`" ;;
    TIMEOUT:*) TIMEOUT="`echo $line | sed 's/^TIMEOUT: //'`" ;;
    RESULTS:) results=1 ;;
    *)
      [ $results -eq 1 ] || die "Header not yet seen"
      bm="`echo $line | sed 's/^[^(]*(\([^)]*\)).*$/\1/'`"
      if echo $line | grep -q TIMEOUT ; then
        stat="--" ; cput="TO" ; mem="--"
      elif echo $line | grep -q "TOO_MANY_ITERATIONS" ; then
        stat="--" ; cput="IT" ; mem="--"
      elif echo $line | grep -q "ERROR" ; then
        stat="--" ; cput="ERR" ; mem="--"
      elif echo $line | grep -q "FAILED" ; then
        stat="inv"
        cput="`echo $line | sed 's/.*cpu=\([^ ]*\) .*/\1/'`"
        mem="`echo $line | sed 's/.*maxmem=\([^ ]*\)$/\1/'`"
      elif echo $line | grep -q "SUCCESSFUL" ; then
        if echo $line | grep -q "#STATS" ; then
          stat="ok"
          cput="`echo $line | sed 's/.*cpu=\([^ ]*\) .*/\1/'`"
          mem="`echo $line | sed 's/.*maxmem=\([^ ]*\)$/\1/'`"
        else
          stat="triv"
          cput="0"
          mem="0"
        fi
      else
        die "Unexpected line $line"
      fi
      cat <<EOF
$bm  &  $stat  &  $cput  &  $mem \\\\
EOF
      ;;
  esac
done < $RESULTS
IFS=$ifs

cat <<EOF
  \\bottomrule
  \\end{tabular}
  \\caption{Benchmarks obtained using $TOOL with a timeout of $TIMEOUT seconds}
  \\label{tab:some-results}
\\end{table}
EOF

