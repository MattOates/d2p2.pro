#!/usr/bin/env perl

use strict;

foreach my $record (<>){
   my ($id,$str) = split /\t/, $record, 2;
   my ($dis, $start, $end) = undef;
   my $pos = 1;
   foreach $dis (split //, $str) {
      if (not $dis and $start) {
         print "$id\t$start\t$end\n";
         $start = undef;
      }
      if($dis and not $start) {
         $start = $pos;
      }
      $end = $pos;
      $pos++;
   }
   if (substr($str,-1)) {
      print "$id\t$start\t$end\n";
   }
}
