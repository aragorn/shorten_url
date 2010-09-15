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
use Benchmark;
use Time::HiRes qw(gettimeofday tv_interval);

use vars qw(%CONFIG %CONFIG_ALL @DEBUG);
our $VERSION = '0.1';
our $BASE_SEARCH_URL = "http://search.daum.net/search";
our %collection_handler = (
  name => undef,
  realTimeColl => \&realTimeColl,
  uccBarBotN   => \&searchTab,
  daumGnb      => \&searchTab,
  defaultColl  => \&defaultColl,
  daumHead     => \&daumHead,
  #realtimeColl => undef,
);
our @added_tab_list = ();

BEGIN {
  ;
}

sub new {
  my ($class, %arg) = @_;
  @DEBUG = ();
  @added_tab_list = ();
  bless {
    none => 0,
    search_url => url(-full=>1),
    benchmark => $arg{benchmark},
    gettimeofday => $arg{gettimeofday},
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

sub add_tab {
  my $self = shift;
  my ($id, $name, $href) = @_;
  my $html = join("",
    qq(<li id="sb_dir">),
    qq(<a href="$href"),
    qq( id="sbar_$id" class="sbTab tabTxt">),
    qq(<span class="sp_$id">$name</span></a></li>)
  );
  push @added_tab_list, { id=>$id, name=>$name, href=>$href, html=>$html };
}

################################################################################
sub defaultColl {
  my $self = shift;
  my $search_url = $self->search_url;
  $_ = shift;
  s#http://search.daum.net/search#$search_url#go;
  s#\("autocomplete","off"\);</script></span>#\("autocomplete","off"\);</script>#go; # fixed html error
  return $_ . '-' x 80 ."\n" if self_url =~ m/debug/o;
  return $_;
}

sub realTimeColl {
  my $self = shift;
  my $html = shift;

  return "hello, world!";
}

sub searchTab {
  my $self = shift;
  my $html = shift;
  my @tab_html;
  my $query = param('q') || "";
  my $utf8_query = utf8_string($query);
  foreach my $tab ( @added_tab_list )
  {
    my ($id, $name, $href) = map { $tab->{$_} } qw(id name href);
    my $url = url(-full=>1) . "?" . sprintf($href, escape($utf8_query));
    push @tab_html, join("",
      qq(<li id="sb_$id">),
      qq(<a href="$url"),
      qq( id="sbar_$id" class="sbTab tabTxt">),
      qq(<span class="sp_$id">$name</span></a></li>\n)
    );
  }
  #map { push @DEBUG, p("tab_html=".$_); } @tab_html;
  my $where = param('w') || "";
  my @selected_tab = grep { $_ eq $where } map { $_->{id} } @added_tab_list;
  my $selected_tab = shift @selected_tab || "";
  push @DEBUG, p("selected_tab=$selected_tab");
=rem
  my @tab_list;
  my $tab_pattern1 = qr{
<a \s+ href="[^\?]+\?([^"]+)"
   \s+ id="sbar_(\w+)"
   \s+ onClick='[^']*'
   \s+ class="([\w\s]+)">
   <span \s class="[\w\s]+">(\w+)</span>
  }iox;
  while ( $html =~ m{$tab_pattern1}og ) { push @tab_list, { href=> $1, id=>$2, class=>$3, name=>$4 }; }
=cut

=rem
  my $tab_pattern2 = qr{
class="oLink">
<a \s+ href="[^\?]+\?([^"]+)"
   \s+ class="([\w\s]+)"
   \s+ onClick='[^']*'
   \s+ target="\w+"
   \s+ onmouseover="[^"]*"
   \s+ onmouseout="[^"]*"
> <span>(\w+)</span>
  }iox;
  while ( $html =~ m{$tab_pattern1}og ) { push @tab_list, { href=> $1, id=>$2, class=>$3, name=>$4 }; }
=cut
=rem
  my ($prev,$ul,$next) = #map { s/</&lt;/go; s/>/&gt;/go; $_; }
    split(/<ul id="srchTab">|<script type="text\/javascript">uccTabChg/o, $html, 3);
    #split(/<ul|<script/o, $html, 3);
push @DEBUG, p("prev=".($prev)), "-"x80;
push @DEBUG, p("ul="  .($ul)),   "-"x80;
push @DEBUG, p("next=".($next)), "-"x80;

  my $separator = qr{<\/li>\s*<li(?:\s+id="\w+")?>|<li(?:\s+id="\w+")?>|<\/li>}iox;
  my @items = split(/($separator)/o, $ul);
map { push @DEBUG, hr, div("li=".($_)); }
map { s/</&lt;/go; s/>/&gt;/go; $_; } @items;
=cut
  #map { push @DEBUG, p("id=".$_->{id}); } @tab_list;

  $html =~ s!(<div class="btab"><span class="btab"></span></div>)!join("\n",@tab_html).$1!ioe;

  # change the selected tab
  $html =~ s!(type="text/javascript">uccTabChg\("sbar_)\w+(")!$1.$selected_tab.$2!ioe
    if $selected_tab;

  return $html;
}

sub daumHead {
  my $self = shift;
  my $html = shift;
  my $where = param('w');
  $html =~ s!(<input type="hidden" name="w" value=")(\w+)(">)!$1$where$3!io;
  return $html;
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

  my @html_head = split(/\r?\n/o, $html_head);
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
    if ( $_ =~ m/document.writeln/o ) { $_ = ""; }
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
     width:500,
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
p.url.highlighted span.dimmed { font-size: 9pt; font-weight: normal; }
p.url { font-family: arial, sans-serif; color: #09c; /*#0E774A;*/ }
p.url.hidden { color: transparent; }
</style>
END

  $self->{html_head} = join("\n", @html_head);
  return wantarray ? @html_head : $self->{html_head};
}

sub html_body {
  my $self = shift;
  my $html_body = shift;
  return $self->{html_body} unless $html_body;

  my $where = param('w') || "";
  my @selected_tab = grep { $_ eq $where } map { $_->{id} } @added_tab_list;
  my $selected_tab = shift @selected_tab || "";
  my $selected_coll = $selected_tab . "Coll";
  push @DEBUG, p("selected_tab in body=$selected_tab");

  my $collection_separator = "<!-- // daumHead -->|<!-- // daumGnb -->|"
                            .qq(<div class="netizen_choose_line"></div>|)
                            .qq(<div id="line"></div>|)
                            .qq(<div class="wrap_folding.{200,500}</a> </div><div class="clr"></div>|)
                            ."\s{50,100}";
=rem
  my $collection_separator = "<!-- 통합검색결과 -->|<!-- end 구분라인 -->|"
                            ."<!-- end 상세검색 -->|<!-- 가상 키보드 DIV START -->";
=cut
  if ($self->{benchmark} and $self->{gettimeofday})
  {
    my($t2, $t02) = (new Benchmark, [gettimeofday]);
    push @DEBUG, p("before html split in html_body:",
                   tv_interval($self->{gettimeofday}, $t02),
                   timestr(timediff($t2, $self->{benchmark})));
  }
  my @splitted = map { s/^\s*|\s*$//og; $_; } split(m{($collection_separator)}os, $html_body);
  my @htmls;
  foreach ( @splitted )
  {
    if ( m{$collection_separator}os ) { $htmls[$#htmls] .= $_; }
    else                              { push @htmls, $_; }
  }
  my @collections;

  my $first_search_coll = 0;
  if ($self->{benchmark} and $self->{gettimeofday})
  {
    my($t2, $t02) = (new Benchmark, [gettimeofday]);
    push @DEBUG, p("before loop in html_body:",
                   tv_interval($self->{gettimeofday}, $t02),
                   timestr(timediff($t2, $self->{benchmark})));
  }
  foreach ( @htmls ) {
    my $name = "unknown";
    my $div_id = "unknown";
    m/<!--\s*([\w\s]{1,50})\s*-->/io and $name = $1;
    m/<div (?:id|class)="(\w+Coll|netizen_choose|detailSearchN|daumHead|daumGnb|daumFoot|content_top|searchCutOff)"/io and $div_id = $1;

    $first_search_coll ++ if $div_id =~ m/Coll$/o;

    if ($div_id =~ m/Coll$/o
        and $first_search_coll > 1
        and $selected_tab)
    { # we have an user-defined tab and it is selected now.
      # skip other ...Coll htmls.
      ;
    }
    elsif ($div_id =~ m/Coll$/o
        and $first_search_coll == 1
        and $selected_tab
        and exists $collection_handler{$selected_coll}
        and ref $collection_handler{$selected_coll} eq 'CODE')
    { # we have both user-defined tab and corresponding collection handler.
      # this div is "search tab" and we add the collection result after this div.
      $_ = $collection_handler{$selected_coll}->($self);
      $_ = $collection_handler{defaultColl}->($self,$_);
      push @collections, {id=>$selected_coll, name=>$selected_tab, html=>$_};
    }
    elsif (exists $collection_handler{$div_id}
           and ref $collection_handler{$div_id} eq 'CODE')
    {
      $_ = $collection_handler{$div_id}->($self,$_);
      $_ = $collection_handler{defaultColl}->($self,$_);
      push @collections, {id=>$div_id, name=>$name, html=>$_};
    }
    else 
    {
      $_ = $collection_handler{defaultColl}->($self,$_);
      push @collections, {id=>$div_id, name=>$name, html=>$_};
=rem
      push @DEBUG, p("default name=$name, div_id=$div_id");
      my $escaped_html = $_;
      $escaped_html =~ s/</&lt;/og;
      $escaped_html =~ s/>/&gt;/og;
      push @DEBUG, div("html=".$escaped_html) if $div_id eq 'netizen_choose';
=cut
    }

    my $handler = ref $collection_handler{$div_id};
    push @DEBUG, p("coll name=$name, div_id=$div_id, handler=$handler");
  }

  $self->{html_body} = join("\n<!-- end 구분라인 -->\n\n", map(+($_->{html}), @collections));
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

  if ($self->{benchmark} and $self->{gettimeofday})
  {
    my($t2, $t02) = (new Benchmark, [gettimeofday]);
    push @DEBUG, p("before request_search_result:",
                   tv_interval($self->{gettimeofday}, $t02),
                   timestr(timediff($t2, $self->{benchmark})));
  }

  my $res = request_search_result($q);

  if ($self->{benchmark} and $self->{gettimeofday})
  {
    my($t2, $t02) = (new Benchmark, [gettimeofday]);
    push @DEBUG, p("after request_search_result:",
                   tv_interval($self->{gettimeofday}, $t02),
                   timestr(timediff($t2, $self->{benchmark})));
  }

  unless ($res->is_success)
  {
    $self->status_line($res->status_line);
    return;
  }

  my ($html_head, $html_head_close, $html_body, $html_body_close, $html_close)
    = split(/(<\/head>|<\/body>)/o, $res->decoded_content);

  if ($self->{benchmark} and $self->{gettimeofday})
  {
    my($t2, $t02) = (new Benchmark, [gettimeofday]);
    push @DEBUG, p("before setting html_head:",
                   tv_interval($self->{gettimeofday}, $t02),
                   timestr(timediff($t2, $self->{benchmark})));
  }
  $self->html_head($html_head.$html_head_close);

  if ($self->{benchmark} and $self->{gettimeofday})
  {
    my($t2, $t02) = (new Benchmark, [gettimeofday]);
    push @DEBUG, p("after setting html_head:",
                   tv_interval($self->{gettimeofday}, $t02),
                   timestr(timediff($t2, $self->{benchmark})));
  }
  $self->html_body($html_body);

  if ($self->{benchmark} and $self->{gettimeofday})
  {
    my($t2, $t02) = (new Benchmark, [gettimeofday]);
    push @DEBUG, p("after setting html_body:",
                   tv_interval($self->{gettimeofday}, $t02),
                   timestr(timediff($t2, $self->{benchmark})));
  }

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
     (?: \s | (?<!url)\( | \< | ^) # \K # look-behind assertion. optional. # FIXME: \K requires perl 5.9.5
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
     while ( $string =~ m{$url_pattern}og ) { push @matched, $1; }
  };
  #if ( $@ =~ m/^Malformed UTF-8 character/o ) { print "ERROR: $_"; }
  if ( $@ ) { print "ERROR: $@\n-->$_"; find_error_token($_); }
  #foreach my $m ( @matched ) { print "m: $m\n"; }
  return @matched;
}

sub find_error_token {
  my $string = shift;
  chomp $string;
  #print "find_error_token: $string\n";
  #print "utf8::decode: ". utf8::decode($string) ."\n";
  my @tokens = split(/(\s)/o, $string);

  foreach ( @tokens )
  {
    #print "token: $_\n";
    eval {
      local $SIG{'__WARN__'} = sub { die $_[0]; };
      m/$url_pattern/og;
    };
    next unless $@;
    print "not utf8::valid: $_\n" unless utf8::valid($_);
    #next if utf8::valid($_);
    print "$@: $_\n";
  }
}


##########################################################################################
sub is_real_search_collection
{
  my $id = shift;
  return 1 if $id =~ m/Coll$/o;
  return 1 if $id eq 1;
}

sub utf8_string {
  my $str = shift;
  #my $charset = shift;
  utf8::decode($str);
  return $str if utf8::is_utf8($str);
=rem
  if ($charset =~ m/utf-8/iog)
  {
    push @DEBUG, "regard string as utf8";
    #my $utf8 = Encode::decode("utf-8", $str);
    my $utf8 = $str;
    push @DEBUG, "utf8::decode=" . utf8::decode($utf8);
    return $utf8;
  }
=cut
  push @DEBUG, "decode euc-kr string to utf8";
  my $utf8 = Encode::decode("cp949", $str);
  push @DEBUG, "utf8::is_utf8=" . utf8::is_utf8($utf8);
  return $utf8;
}

1;

