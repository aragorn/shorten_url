#!/usr/bin/perl
package Daum;
use strict;
use warnings;
use utf8;
use Time::Local;
use POSIX;
use Encode qw/encode decode/;

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
  $mday = 1 unless $mday;
  $mon = 1 unless $mon;
  return timelocal($sec,$min,$hour,$mday,$mon-1,$year);
}

sub strhncpy {
  my $str = shift;
  utf8::decode($str);
  my $n = shift;
  my @w = unpack("U0U*", $str);
  my $copied = 0;
  my @to;
  foreach ( @w )
  {
    $_ = pack("U0U", $_); push @to, $_;
    if    ( m/\p{Hangul}/o )     { $copied += 2; }
    elsif ( m/\p{WhiteSpace}/o ) { $copied += 1; }
    else                         { $copied += 1; }
    last if $copied > $n;
  }
  push @to, ".." if length $str > $copied;
  return join("", @to);
}

sub hlength {
  my $str = shift;
  utf8::decode($str);
#unless (utf8::is_utf8($str)) { print STDERR "no utf8 [$str]\n"; }
  my @w = unpack("U0U*", $str);
  my $count = 0;
  foreach ( @w )
  {
    $_ = pack("U0U", $_);
    if    ( m/\p{Hangul}/o )     { $count += 2; }
    elsif ( m/\p{WhiteSpace}/o ) { $count += 1; }
    else                         { $count += 1; }
  }
  return $count;
}

sub utf8_string {
  my $str = shift;
  my $charset = shift || "";
  return $str if utf8::is_utf8($str);
  if ($charset =~ m/utf-8/ig)
  {
    #push @DEBUG, "regard string as utf8";
    #my $utf8 = Encode::decode("utf-8", $str);
    my $utf8 = $str; utf8::decode($utf8);
    #push @DEBUG, "utf8::decode=" . utf8::decode($utf8);
    return $utf8;
  }

  #push @DEBUG, "decoded euc-kr string to utf8";
  my $utf8 = Encode::decode("cp949", $str);
  #push @DEBUG, "utf8::is_utf8=" . utf8::is_utf8($utf8);
  return $utf8;
}

1;
