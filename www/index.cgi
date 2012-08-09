#!/usr/bin/perl -w

use strict;
use CGI qw(:standard);

my $q     = new CGI; $q->charset('utf-8'); # for proper escapeHTML
#my $server_name = join(":", $q->server_name, $q->virtual_port || $q->server_port);
my $server_name = join(":", $q->server_name, $q->virtual_port);
print $q->header(-charset=>'utf-8', -type=>'text/html');

print $q->start_html(-lang=>'ko_KR', -encoding=>'utf-8', -title=>$server_name),
  h1($server_name),
  address('Last updated on: 2012-08-09, aragorn@daumcorp.com'),
  end_html;

