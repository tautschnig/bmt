#!/usr/bin/perl

$SIG{INT} = sub { die "interrupted by user" };

use subs;
use strict;
use warnings;

# test.pl
#
# runs a test and check its output

sub run($$$$) {
  my ($input, $options, $gccopts, $output) = @_;
  my $ccmd = "goto-cc $gccopts $input -o testmain > compiler.out 2>&1";
  print LOG "Running $ccmd\n";
  system $ccmd;

  my $exit_value = $? >> 8;
  my $signal_num = $? & 127;
  my $dumped_core = $? & 128;
  my $failed = 0;

  print LOG "  Exit: $exit_value\n";
  print LOG "  Signal: $signal_num\n";
  print LOG "  Core: $dumped_core\n";

  if($signal_num != 0) {
    $failed = 1;
    print "Killed by signal $signal_num";
    if($dumped_core) {
      print " (code dumped)";
    }
  }

  system "echo EXIT=$exit_value >>$output";
  system "echo SIGNAL=$signal_num >>$output";

  return $failed;
}

sub load($) {
  my ($fname) = @_;

  open FILE, "<$fname";
  my @data = <FILE>;
  close FILE;

  chomp @data;
  return @data;
}

sub test($$) {
  my ($name, $test) = @_;
  my ($input, $options, $gccopts, @results) = load($test);

  my $output = $input;
  $output =~ s/\.c$/.out/;

  if($output eq $input) {
    print("Error in test file -- $test\n");
    return 1;
  }

  print LOG "Test '$name'\n";
  print LOG "  Input: $input\n";
  print LOG "  Output: $output\n";
  print LOG "  Options: $options\n";
  print LOG "  Results:\n";
  foreach my $result (@results) {
    print LOG "    $result\n";
  }

  my $failed = run($input, $options, $gccopts, $output);

  if(!$failed) {
    print LOG "Compilation [OK]\n";
  } else {
    print LOG "Compilation [FAILED]\n";
  }

  print LOG "\n";

  return $failed;
}

sub dirs() {
  my @list;
  my @prelist;

  opendir CWD, ".";
  @prelist = grep { !/^\./ && -d "$_" && !/CVS/ && !/stubs/} readdir CWD;
  closedir CWD;

  my $dir;
  foreach $dir (@prelist) {
   if(-f "$dir/test.desc" )
   {
     push(@list, $dir);
   }
  }
  
  @list = sort @list;

  return @list;
}

if(@ARGV != 0) {
  print "Usage:\n";
  print "  test.pl\n";
  exit 1;
}

open LOG,">tests.log";

print "Loading\n";
my @tests = dirs();
my $count = @tests;
if($count == 1) {
  print "  $count test found\n";
} else {
  print "  $count tests found\n";
}
print "\n";
my $failures = 0;
my $falsepositives = 0;
print "Compiling...\n";
foreach my $test (@tests) {
  print "  Compiling $test";

  chdir $test;
  my $failed = test($test, "test.desc");
  chdir "..";

  if($failed) {
    print "  [FAILED]\n";
  } else {
    print "  [OK]\n";
  }
}
print "\n";

if($failures == 0 && $falsepositives == 0) {
  print "All tests were successful\n";
} else {
  print "Tests failed\n";
  print "  $count tests were run: $failures failures, $falsepositives false positives.\n";
}

close LOG;

exit $failures;
