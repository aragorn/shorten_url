#!/usr/bin/perl

use DBI;
use LWP::Simple qw(!head);
use LWP::UserAgent;
use HTTP::Request::Common;
use Time::HiRes qw(gettimeofday tv_interval);
use Benchmark;
use Data::Dumper;
use JSON;

my $which = shift || "orig";

#my $api = q(http://110.45.208.13/channel/report/drp/cafe/folder/);
my $api = q(http://10.10.215.48:8080/channel/report/drp/cafe/folder/);
$api = q(http://110.45.208.13/drp/cafe/channel/)  if $which eq "cache";
$api = q(http://110.45.208.13/drp/mcafe)          if $which eq "merge";
$api = q(http://110.45.208.13/drp/cafe/channel/)  if $which eq "thread";

my $from = 0;
foreach ( 0..100 ) {
  print "loop $_ - from=$from\n";
  my ($t1, $t01) = (new Benchmark, [gettimeofday]);

  my $list = fetch_doc($from);
  my ($t2, $t02) = (new Benchmark, [gettimeofday]);
  print "elapsed=", tv_interval($t01, $t02), "\n";

  #print Dumper($list);
  #my $last = test_channel_api($list);
  my $last;
  if ( $which eq "merge" ) {
    $last = test_merged_api($list);
  } elsif ( $which eq "cache" ) {
    $last = test_cached_api($list);
  } elsif ( $which eq "thread" ) {
    $last = test_thread_api($list);
  } else {
    $last = test_channel_api($list);
  }

  my ($t3, $t03) = (new Benchmark, [gettimeofday]);
  print "\n";
  print "elapsed=", tv_interval($t02, $t03), "\n";
  print "benchmark=", timestr(timediff($t3, $t2)), "\n\n\n";

  $from = $last + 1;
}

exit;

1;

sub test_merged_api {
  my $list = shift;

  my @id        = map { $_->{id} } @{$list};
  my @channelid = map { $_->{channelid} } @{$list};
  my $ua = new LWP::UserAgent;
  my $list = $ua->request(POST $api, { id => \@channelid } );
  my $size = length $list;

  if ( $size > 400 ) { print STDERR "."; }
  else { print STDERR "!$size\n"; }

  return $id[$#id];
}

sub test_cached_api {
  my $list = shift;

  my $last_id = 0;
  foreach ( @{$list} ) {
    $last_id = $_->{id};
    my $folder_id = $_->{channelid};
    next if $folder_id < 1;
  
    my $url = $api . $folder_id ;
    my $json = LWP::Simple::get($url);
    my $size = length $json;
    #my $data = decode_json($json);
    #my $id = $data->{channel}->{folder}->{id};

    #print Dumper($data->{channel}->{folder});
    #sleep 1;
    #print "url=$url\n";
    #print "xml = ", substr($xml, 300, 100), "\n";
 
    if ( $size > 400 ) { print STDERR "."; }
    else { print STDERR "!"; }
  }

  return $last_id;
}

sub test_thread_api {
  my $list = shift;

  my $last_id = 0;
  foreach ( @{$list} ) {
    $last_id = $_->{id};
    my $folder_id = $_->{channelid};
    next if $folder_id < 1;
  
    my $url = $api . $folder_id ;
    my $json = LWP::Simple::get($url);
    my $size = length $json;
    #my $data = decode_json($json);
    #my $id = $data->{channel}->{folder}->{id};

    #print Dumper($data->{channel}->{folder});
    #sleep 1;
    #print "url=$url\n";
    #print "xml = ", substr($xml, 300, 100), "\n";
 
    if ( $size > 400 ) { print STDERR "."; }
    else { print STDERR "!"; }
  }

  return $last_id;
}

sub test_channel_api {
  my $list = shift;

  my $last_id = 0;
  foreach ( @{$list} ) {
    $last_id = $_->{id};
    my $folder_id = $_->{channelid};
    next if $folder_id < 1;
  
    my $url = $api . $folder_id ;
    my $xml = LWP::Simple::get($url);
  
    #print "url=$url\n";
    #print "xml = ", substr($xml, 300, 100), "\n";
  
    if ( $xml =~ m#<folder>\s*<id>(\d+)</id>#og ) {
      my $id = $1;
      if ( $id > 0 ) { print STDERR "."; }
      else { print STDERR "!"; }
      #else { print STDERR "\n!$folder_id -", substr($xml, 300, 100), "\n"; }
    } else {
      print "invalid xml at iteration $folder_id\n";
    }
  }

  return $last_id;
}

exit;

sub fetch_doc {
  my $from_id = shift || 0;

  my $sql = <<SQL;
SELECT id, docid, docurl, channelid
FROM srchdoc_1
WHERE id >= ?
ORDER BY id ASC
LIMIT 1000
SQL
  my $dbh = DBI->connect(
    qq(dbi:mysql:database=cafe;host=10.10.109.95),
    qq(cdwuser),
    qq(cdwuserdb),
  );
  my $list = $dbh->selectall_arrayref($sql, { Slice => {} }, $from_id);
  return $list;
}


