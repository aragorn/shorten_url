#!/usr/bin/perl
package Daum::FederatedSearch;
use strict;
use warnings;
use utf8;
use charnames ":full";
use LWP::UserAgent;
use LWP::Simple qw(!head);
use Unicode::String qw(utf8);
use CGI qw(:standard escape escapeHTML -oldstyle_urls);

use vars qw(%CONFIG %CONFIG_ALL @DEBUG);
our $VERSION = '0.1';
our $BASE_SEARCH_URL = "http://search.daum.net/search";
our %collection_handler = (
  name => undef,
  realTimeColl => \&realTimeColl,
  defaultColl  => \&defaultColl,
  #realtimeColl => undef,
);

BEGIN {
  ;
}

sub new {
  my ($class, %arg) = @_;
  @DEBUG = ();
  bless {
    none => 0,
    search_url => self_url,
  }, $class;
}

sub debug {
  return @DEBUG;
}

sub status_line {
  my $self = shift;
  my $status_line = shift;
  $self->{status_line} = $status_line if $status_line;
  return $self->{status_line};
}

sub search_url {
  my $self = shift;
  my $search_url = shift;
  $self->{search_url} = $search_url if $search_url;
  return $self->{search_url};
}

################################################################################
sub defaultColl {
  my $self = shift;
  my $search_url = $self->search_url;
  $_ = shift;
  s#http://search.daum.net/search#$search_url#go;
  s#\("autocomplete","off"\);</script></span>#\("autocomplete","off"\);</script>#go; # fixed html error
  return $_ . '-' x 80 ."\n" if self_url =~ m/debug/;
  return $_;
}

sub realTimeColl {
  my $self = shift;
  my $html = shift;

  return "hello, world!";
}

################################################################################

sub handler {
  my $self    = shift;
  my $id      = shift;
  my $handler = shift;

  return unless $id;
  $collection_handler{$id} = $handler if $handler;
  return $collection_handler{$id};
}

sub html_head {
  my $self = shift;
  my $html_head = shift;
  return $self->{html_head} unless $html_head;

  my @html_head = split(/\r?\n/, $html_head);
  foreach ( @html_head ) {
    # charset을 euc-kr에서 utf-8로 변경한다. 실제 문자열의 charset은 $res->decoded_content
    # 를 사용하므로, 이미 utf-8로 변경된 상태이다.
    if ( $_ eq q(<meta http-equiv="Content-Type" content="text/html; charset=euc-kr">) ) {
      push @DEBUG, p("source charset=euc-kr");
      $_ = q(<meta http-equiv="Content-Type" content="text/html; charset=utf-8">);
    }
    # width,height=0 크기의 iframe 추가하는 javascript code를 삭제한다. 포함되어 있어도
    # 큰 문제는 없으나, 상이한 domain의 javascript code를 호출하여 실행에 오류가 발생한다.
    # 해당 javascript code는 query log 기록을 위한 페이지를 호출하는 것으로 보인다.
    if ( $_ =~ m/document.writeln/ ) { $_ = ""; }
  }
  # Shorten URL 관련 코드를 추가한다.
  push @html_head, q(<link rel="stylesheet" type="text/css" href="/cluetip/jquery.cluetip.css" />);
  push @html_head,
   q(<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>);
  push @html_head, q(<script type="text/javascript" src="/js/jquery.hoverIntent.js"></script>);
  push @html_head, q(<script type="text/javascript" src="/js/jquery.cluetip.js"></script>);
  push @html_head, <<END;
<script type="text/javascript"><!--//
\$(document).ready(function() {
  \$('p.base.desc a.stit').cluetip({
/*
     width:380,
     sticky:false,
     showTitle:false,
     clickThrough:true,
     cluetipClass:'default',
*/
     width:380,
     sticky:true,
     showTitle:false,
     clickThrough:true,
     cluetipClass:'default',
     closePosition:'bottom',
     closeText: '<img src="/cluetip/images/cross.png" alt="Close" />',

     xxend:0
  });

  \$('#houdini').cluetip({
    splitTitle: '|', // use the invoking element's title attribute to populate the clueTip...
                     // ...and split the contents into separate divs where there is a "|"
    showTitle: false // hide the clueTip's heading
  });
});
//--></script>
END

  # 실시간,소셜웹 컬렉션에서 트위터 본문 중 링크의 Style에 적용된다.
  push @html_head, <<END;
<style type="text/css">
a.g_tit.twitter:link,
a.g_tit.twitter:visited { color: #2276BB; color: #09c; }
a.stit.twitter:link,
a.stit.twitter:visited { color: #2276BB; color: #09c; }
</style>
END

  $self->{html_head} = join("\n", @html_head);
  return wantarray ? @html_head : $self->{html_head};
}

sub html_body {
  my $self = shift;
  my $html_body = shift;
  return $self->{html_body} unless $html_body;

  my $collection_separator = "<!-- 통합검색결과 -->|<!-- end 구분라인 -->|<!-- end 상세검색 -->";
  my @collections = map { s/^\s*|\s*$//g; $_; } split(/$collection_separator/, $html_body);

  $self->{collections} = [];

  foreach ( @collections ) {
    my $name = "unknown";
    my $div_id = "unknown";
    m/<!--\s*([\w\s]{1,50})\s*-->/io and $name = $1;
    m/<div id="(\w+Coll|netizen_choose)"/io and $div_id = $1;
    my $html;
    
    if (exists $collection_handler{$div_id}
        and ref $collection_handler{$div_id} eq 'CODE')
         { $html = $collection_handler{$div_id}->($self,$_); }
    else { $html = $_; }

    $html = $collection_handler{defaultColl}->($self,$html);
    push @{$self->{collections}}, {id=>$div_id, name=>$name, html=>$html};
    my $handler = ref $collection_handler{$div_id};
    push @DEBUG, p("coll name=$name, div_id=$div_id, handler=$handler");
    $_ = $html;
  }

  $self->{html_body} = join("\n<!-- end 구분라인 -->\n\n", @collections);
  return wantarray ? @collections : $self->{html_body};
}

sub html_body_close {
  my $self = shift;
  my $html_body_close = shift;
  $self->{html_body_close} = $html_body_close if $html_body_close;
  return $self->{html_body_close};
}

sub fetch_search_result {
  my $self = shift;
  my $q = shift;

  my $res = request_search_result($q);
  unless ($res->is_success)
  {
    $self->status_line($res->status_line);
    return;
  }

  my ($html_head, $html_head_close, $html_body, $html_body_close, $html_close)
    = split(/(<\/head>|<\/body>)/, $res->decoded_content);

  $self->html_head($html_head.$html_head_close);
  $self->html_body($html_body);

  push @DEBUG, p("base=", $res->base);
  foreach ($res->headers->header_field_names) {
    push @DEBUG, p("http $_=", $res->header($_));
  }
  $self->html_body_close($html_body_close.$html_close);
  return 1;
}

my $ua;
sub request_search_result {
  my $q = shift;
  my $url = $BASE_SEARCH_URL."?".$q->query_string;
  $url =~ s/;/&/go;

  if ( not defined $ua ) {
    $ua = LWP::UserAgent->new;
    $ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) "
              ."AppleWebKit/533.4 (KHTML, like Gecko) Chrome/5.0.375.125 Safari/533.4");
  }

  my $req = HTTP::Request->new(GET => $url);
  my $res = $ua->request($req);
  return $res;
}

our $url_pattern = qr{
   (?xi)
     #\b
     (?: \s | (?<!url)\( | \< | ^) \K # look-behind assertion. optional.
   (                       # Capture 1: entire matched URL
     (?:
       https?://               # http or https protocol
       |                       #   or
       www\d{0,3}[.]           # "www.", "www1.", "www2." … "www999."
       |                           #   or
       [a-z0-9.\-]+[.][a-z]{2,4}/  # looks like domain name followed by a slash
     )
     (?:                       # One or more:
       [^\s()<>]+                  # Run of non-space, non-()<>
       |                           #   or
       \(([^\s()<>]+|(\([^\s()<>]+\)))*\)  # balanced parens, up to 2 levels
     )+
     (?:                       # End with:
       \(([^\s()<>]+|(\([^\s()<>]+\)))*\)  # balanced parens, up to 2 levels
       |                               #   or
       [^\s`!()\[\]\{\};:'".,<>?«»“”‘’\p{Hangul}]        # not a space or one of these punct chars
     )
   )
}iox;

sub replace_url {
  my ($self, $string, $replace_ref) = @_;

  $string =~ s{$url_pattern} !&$replace_ref($1)!ioxge;
  return $string;
}

sub match_url {
  my ($self, $string) = @_;

  my @matched;
  eval {
     local $SIG{'__WARN__'} = sub { die $_[0]; };
     #no warnings 'all';
     while ( $string =~ m{$url_pattern}g ) { push @matched, $1; }
  };
  #if ( $@ =~ m/^Malformed UTF-8 character/ ) { print "ERROR: $_"; }
  if ( $@ ) { print "ERROR: $@\n-->$_"; find_error_token($_); }
  #foreach my $m ( @matched ) { print "m: $m\n"; }
  return @matched;
}

sub find_error_token {
  my $string = shift;
  chomp $string;
  #print "find_error_token: $string\n";
  #print "utf8::decode: ". utf8::decode($string) ."\n";
  my @tokens = split(/(\s)/, $string);

  foreach ( @tokens )
  {
    #print "token: $_\n";
    eval {
      local $SIG{'__WARN__'} = sub { die $_[0]; };
      m/$url_pattern/g;
    };
    next unless $@;
    print "not utf8::valid: $_\n" unless utf8::valid($_);
    #next if utf8::valid($_);
    print "$@: $_\n";
  }
}


##########################################################################################
sub utf8_string {
  my $str = shift;
  my $charset = shift;
  return $str if utf8::is_utf8($str);
  if ($charset =~ m/utf-8/ig)
  {
    push @DEBUG, "regard string as utf8";
    #my $utf8 = Encode::decode("utf-8", $str);
    my $utf8 = $str;
    push @DEBUG, "utf8::decode=" . utf8::decode($utf8);
    return $utf8;
  }

  push @DEBUG, "decoded euc-kr string to utf8";
  my $utf8 = Encode::decode("cp949", $str);
  push @DEBUG, "utf8::is_utf8=" . utf8::is_utf8($utf8);
  return $utf8;
}

1;

