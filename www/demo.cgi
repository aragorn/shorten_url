#!/usr/bin/perl -w

use strict;
use CGI qw(:standard);

my $q     = new CGI; $q->charset('utf-8'); # for proper escapeHTML
#my $server_name = join(":", $q->server_name, $q->virtual_port || $q->server_port);
my $server_name = join(":", $q->server_name, $q->virtual_port);
print $q->header(-charset=>'utf-8', -type=>'text/html');

print $q->start_html(-lang=>'ko_KR', -encoding=>'utf-8', -title=>$server_name),
  h1($server_name),
  h2('통합검색 데모'),
    h3('<a href="preview/search?w=tot&q=%BE%C6%C0%CC%C6%F94&nil_search=btn">', '소셜웹 데모 - 2010/08/31', '</a>'),
  h2('단축 URL'),
    h3('<a href="preview/search?nil_suggest=btn&nil_ch=&rtupcoll=&w=dir&m=sch_realtime&f=&lpp=11&q=%EC%95%84%EC%9D%B4%ED%8F%B04">',
       '실시간검색', '</a>'),
    h3('<a href="preview/get?u=http://bit.ly/ah0YlQ">', 'AJAX 호출 예시', '</a>'),
    h3('<a href="preview/list">', '데이터', '</a>', ' - ', '<a href="preview/env">', '환경변수', '</a>',),
    h3('weblog reports'),
      h4('<a href="http://110.45.208.13/awstats/awstats.pl?config=search-url-web1">', 'search-url-web1', '</a>'),
      h4('<a href="http://110.45.208.14/awstats/awstats.pl?config=search-url-web2">', 'search-url-web2', '</a>'),
      h4('<a href="http://110.45.208.69/awstats/awstats.pl?config=search-url-web3">', 'search-url-web3', '</a>'),
  h2('디버깅'),
    h3('<a href="debug/sns?q=아이폰4">', 'SNS컬렉션', '</a>'),
    h3('<a href="debug/search?nil_suggest=btn&nil_ch=&rtupcoll=&w=dir&m=sch_realtime&f=&lpp=11&q=%BE%C6%C0%CC%C6%F9">',
       '단축URL 시험(실시간검색)', '</a>'),
    h3('<a href="debug/get?u=http://bit.ly/ah0YlQ">', 'AJAX 호출 예시', '</a>'),
    h3('<a href="debug/list">', '데이터', '</a>', ' - ', '<a href="debug/env">', '환경변수', '</a>',),
    h3('단축URL 소스코드'),
      p('<a href="src/trunk/">', 'Source Files', '</a>'),
      p('<a href="src/trunk/lib/Daum/">', 'Perl Modules', '</a>'),
      p('소스코드 위치: ',
        '<a href="http://source.daumcorp.com/private/shorten_url">',
        'http://source.daumcorp.com/private/shorten_url','</a>'),
      p('<a href="http://plugins.learningjquery.com/cluetip/">', 'cluetip - a jquery tooltip using ajax', '</a>'),
  address('Last updated on: 2010-07-08, aragorn@daumcorp.com'),
  end_html;

