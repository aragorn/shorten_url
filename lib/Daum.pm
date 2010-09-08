#!/usr/bin/perl
package Daum;
use strict;
use warnings;
use utf8;
use Time::Local;
use POSIX;

POSIX::setlocale( &POSIX::LC_ALL, "ko_KR.UTF-8" );

sub dttm_now {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
  return sprintf "%04d%02d%02d%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
}

sub relative_time {
  my $time1 = shift;
  my $time2 = shift;
  my $start = $time1 > $time2 ? $time2 : $time1;
  my $end   = $time1 > $time2 ? $time1 : $time2;
  if ($end - $start < 60) { return sprintf "%d초전", $end-$start; }
  else {
    my $epoch = dttm2epoch($time1);
    my $str = POSIX::strftime("%Y.%m.%d (%a) %p %l:%M", localtime($epoch));
    utf8::decode($str);
    return $str;
  }
}

sub dttm2epoch {
  my $dttm = shift;
  my ($year,$mon,$mday,$hour,$min,$sec) = unpack("a4a2a2a2a2a2", $dttm );
  return timelocal($sec,$min,$hour,$mday,$mon-1,$year);
}

1;
