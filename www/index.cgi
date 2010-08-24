#!/usr/bin/perl -w

use strict;
use CGI qw(:standard);

my $q     = new CGI; $q->charset('utf-8'); # for proper escapeHTML
print $q->header(-charset=>'utf-8', -type=>'text/html');

print $q->start_html(-lang=>'ko_KR', -encoding=>'utf-8', -title=>'hello, world!'),
  h1('Test Website'),
  h2('SNS 컬렉션 데모'),
    h3('<a href="debug/search?q=아이폰4">', '통합검색 테스트', '</a>'),
    h3('<a href="debug/sns?q=아이폰4">', 'SNS컬렉션 테스트', '</a>'),
  h2('단축 URL 데모'),
    h3('<a href="preview/search">', '통검 테스트 UI', '</a>'),
    h3('<a href="preview/search?nil_suggest=btn&nil_ch=&rtupcoll=&w=dir&m=sch_realtime&f=&lpp=11&q=%BE%C6%C0%CC%C6%F9">',
       '단축URL 데모 - 실시간검색', '</a>'),
    h3('<a href="preview/preview?u=http://bit.ly/ah0YlQ">', 'AJAX 호출 예시', '</a>'),
  h2('단축 URL 개발버전 - 수정중'),
    h3('<a href="debug/search?nil_suggest=btn&nil_ch=&rtupcoll=&w=dir&m=sch_realtime&f=&lpp=11&q=%BE%C6%C0%CC%C6%F9">',
       '단축URL 개발', '</a>'),
    h3('<a href="debug/preview?u=http://bit.ly/ah0YlQ">', 'AJAX 호출 예시', '</a>'),
    h3('<a href="debug/list">', '저장 데이터', '</a>'),
    h3('<a href="src/preview/">', '단축URL 소스코드', '</a>'),
      p('<a href="src/lib/">', 'Perl Module', '</a>'),
      p('소스코드 위치: search-breeze2-dev5:/home/aragorn/preview/'),
    h3('<a href="http://plugins.learningjquery.com/cluetip/">', 'cluetip - a jquery tooltip using ajax', '</a>'),
  address('Last updated on: 2010-07-08, aragorn@daumcorp.com'),
  end_html;

