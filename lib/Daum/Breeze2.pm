#!/usr/bin/perl
package Daum::Breeze2;
use strict;
use warnings;
use utf8;
use charnames ":full";
use LWP::UserAgent;
use LWP::Simple qw(!head);
use CGI qw(:standard escape escapeHTML -oldstyle_urls);
use Benchmark;
use Time::HiRes qw(gettimeofday tv_interval);
use POSIX qw(locale_h);
use Daum;

our @DEBUG = ();
our ($t_bench0, $t_gtod0);
POSIX::setlocale( &POSIX::LC_ALL, "ko_KR.UTF-8" );

sub new {
  my ($class, %arg) = @_;
  @DEBUG = ();
  bless {
    search_url => $arg{search_url},
  }, $class;
}

sub search {
  my $self = shift;
  my $url = shift;
  ;
}

sub parse_xml_result
{
  my $self = shift;
  my $xml  = shift;
  my $page = shift;
  my (%result, %doc, %doc_in_clusters);

  my @xml_path;
  my $xml_start = sub {
    my ($p, $elt, %atts) = @_;
    push @xml_path, $elt;
    my $path = join("/", @xml_path);
    map { print "$path atts{$_}=$atts{$_}\n"; } keys %atts if keys %atts > 0;

    if    ($path eq q{r} or $path eq q{r/m} ) { return; }
    elsif ($path =~ m{^r/m/}o )     { return; }
    elsif ($path eq q{r/g})         { return; }
    elsif ($path eq q{r/ds})        { $result{ds} = []; return; }
    elsif ($path eq q{r/ds/data})   { %doc = (); }
    elsif ($path =~ m{^r/ds/data/([\w\-]+)$}o ) { return; }
    elsif ($path eq q{r/ds/data/clusters})      { $doc{clusters} = []; return; }
    elsif ($path eq q{r/ds/data/clusters/data}) { %doc_in_clusters = (type=>$atts{rt}); }
    elsif ($path =~ m{^r/ds/data/clusters/data/([\w\-]+)$}o ) { return; }
    else {
print "$path started - unexpected\n";
      return;
    }
    print "$path started\n";
  };
  my $xml_end   = sub {
    my ($p, $elt) = @_;
    my $path = join("/", @xml_path);
    pop @xml_path;

    if    ($path eq q{r} or $path eq q{r/m} ) { return; }
    elsif ($path =~ m{^r/m/}o )     { return; }
    elsif ($path eq q{r/ds/data})   { my %copy = %doc; push @{$result{ds}}, \%copy; }
    elsif ($path eq q{r/ds/data/clusters/data}) { my %copy = %doc_in_clusters; push @{$doc{clusters}}, \%copy; }
    else { return; }
    print "$path(elt=$elt) ended\n";
  };

  my $xml_char  = sub {
    my ($p, $str) = @_;
    chomp $str;
    return unless $str;
    return if $str =~ m/^\s*$/o;
    my $path = join("/", @xml_path);
    if    ($path eq q(r/m/c)  )     { $result{total_count} = $str; }
    elsif ($path eq q(r/m/pc) )     { $result{page_count}  = $str; }
    elsif ($path eq q(r/m/is-end) ) { $result{is_end} = $str eq 'False' ? 0 : 1; }
    elsif ($path =~ m{^r/m/([\w\-]+)$}o ) { $result{$1} = $str; }
    elsif ($path eq q(r/g) )        { ; } # ignore
    elsif ($path =~ m{^r/ds/data/([\w\-]+)$}o ) { $doc{$1} = $str; }
    elsif ($path =~ m{^r/ds/data/clusters/data/([\w\-]+)$}o ) { $doc_in_clusters{$1} = $str; }
    else {
      print "$path str=[$str]   ", length $str, "\n";
    }
  };
  my $xml_default = sub {

  };

  my $parser = new XML::Parser ( Handlers => {
        Start => $xml_start,
        End   => $xml_end,
        Char  => $xml_char,
        Default => $xml_default,
                   });
  $parser->parse($xml);

  my $page_start = ($result{page_count} ||0) * ($page -1) + 1;
  my $page_end   = ($result{page_count} ||0) + $page_start - 1;
  $result{page_start} = $page_start;
  $result{page_end}   = $page_end;
  $result{serverdttm} = Daum::dttm_now();

  return \%result;
}

sub init_benchmark {
  ($t_bench0, $t_gtod0) = (new Benchmark, [gettimeofday]);
}

sub check_clock {
  my $log_message = shift;
  my ($t_bench1, $t_gtod1) = (new Benchmark, [gettimeofday]);
  return join("", $log_message, ":",
                  tv_interval($t_gtod0, $t_gtod1),
                  timestr(timediff($t_bench1, $t_bench0)), "secs");
}

sub commify {
  my $num = shift;
  $num =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;
  return $num;
}

1;
