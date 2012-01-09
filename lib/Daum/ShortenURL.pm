#!/usr/bin/perl
package Daum::ShortenURL;
use strict;
use warnings;
use utf8;
use charnames ":full";
use LWP::UserAgent;
use DBI;
use CGI;
use Daum;

use vars qw(%CONFIG %CONFIG_ALL @DEBUG);
our $VERSION = '0.1';
our @fields_url_trans =
  qw(url_id shorten_url original_url original_title 
     mime_type http_code
     website source
     has_no_info has_original_url has_title has_image
     is_dead is_unreachable
     created_on updated_on );
our ($DBH_SLAVE, $DBH_MASTER);
our $FORWARD_URL = "http://61.111.63.14:8000/ShortURL/request_crawl/";

BEGIN {
  %CONFIG_ALL = (
  example  => 'none',
  'search-url-web1:80' =>
    { DBNAME_MASTER => 'database=url_svc;host=10.10.208.88',
      DBNAME_SLAVE  => 'database=url_svc;host=10.10.208.21',
      DBUSER=>'url_svc', DBPASSWD=>'image1002' },
  'search-url-web1:8080' =>
    { DBNAME_MASTER => 'database=url_test;host=10.10.208.88',
      DBNAME_SLAVE  => 'database=url_test;host=10.10.208.21',
      DBUSER=>'url_test', DBPASSWD=>'image1001' },

  'search-url-web2:80' =>
    { DBNAME_MASTER => 'database=url_svc;host=10.10.208.88',
      DBNAME_SLAVE  => 'database=url_svc;host=10.10.208.31',
      DBUSER=>'url_svc', DBPASSWD=>'image1002' },
  'search-url-web2:8080' =>
    { DBNAME_MASTER => 'database=url_test;host=10.10.208.88',
      DBNAME_SLAVE  => 'database=url_test;host=10.10.208.31',
      DBUSER=>'url_test', DBPASSWD=>'image1001' },

  'search-url-web3:80' =>
    { DBNAME_MASTER => 'database=url_svc;host=10.10.208.88',
      DBNAME_SLAVE  => 'database=url_svc;host=10.10.208.77',
      DBUSER=>'url_svc', DBPASSWD=>'image1002' },
  'search-url-web3:8080' =>
    { DBNAME_MASTER => 'database=url_test;host=10.10.208.88',
      DBNAME_SLAVE  => 'database=url_test;host=10.10.208.77',
      DBUSER=>'url_test', DBPASSWD=>'image1001' },
  default =>
    { DBNAME_MASTER => 'database=preview;host=10.31.125.236',
      DBNAME_SLAVE  => 'database=preview;host=10.31.125.236',
      DBUSER=>'aragorn', DBPASSWD=>'image' },
  );

  my $server_name = CGI::server_name();
  $server_name =~ s/\..*//;
  my $server_port = CGI::server_port();

  my $http_host = join(":", $server_name, $server_port);
  if ( exists $CONFIG_ALL{$http_host} ) { %CONFIG = %{$CONFIG_ALL{$http_host}}; }
  else                                  { %CONFIG = %{$CONFIG_ALL{default}}; }
}

sub new {
  my ($class, %arg) = @_;
  $DBH_SLAVE  = connect_slave_db();
  $DBH_MASTER = connect_master_db();
  @DEBUG = ();
  bless {
    none => 0,
  }, $class;
}

=rem
sub DESTROY {
  my $self = shift;
  $DBH_SLAVE->disconnect if defined $DBH_SLAVE;
  $DBH_SLAVE = undef;
  $DBH_MASTER->disconnect if defined $DBH_MASTER;
  $DBH_MASTER = undef;
}
=cut

sub config {
  my $http_host = shift;
  if ($http_host and exists $CONFIG_ALL{$http_host})
  { %CONFIG = %{$CONFIG_ALL{$http_host}}; }

  return %CONFIG;
}

sub debug {
  return @DEBUG;
}

sub dbh_slave {
  return $DBH_SLAVE;
}

sub dbh_master {
  return $DBH_MASTER;
}

sub lookup_local {
  my ($self, $url, $referer) = @_;

  my $sql = qq(
select ).join(",", @fields_url_trans).qq(
from url_translation
where shorten_url = ?
);
  my $row = $DBH_SLAVE->selectrow_hashref($sql, {}, $url);
  push @DEBUG, "content_type=$row->{mime_type}" if defined $row;
  push @DEBUG, "no entry in local db" unless defined $row;
  map { utf8::decode($row->{$_}); } @fields_url_trans;
  return $row;
}

sub fetch_and_save {
  my ($self, $url, $referer, $source) = @_;
  my ($row, $res) = $self->fetch($url, $referer);
  my $type  = $res->content_type;

  save_webpage($url, $referer, $row, $source)
    if ($res->is_success and $type eq "text/html" );

  return ($row, $res);
}

sub fetch {
  my ($self, $url, $referer) = @_;

  my $row = {};
  my $res = fetch_webpage($url);
  my $code = $res->code;
  my $type  = $res->content_type;
  #my @types = map {"[$_]"} split(/[,;]\s*/, $res->header('content_type'));
  my ($charset,undef) =
    map { my($name,$value)=split(/=/,$_,2); $value; }
    grep {m/^charset=/i} split(/[,;]\s*/, $res->header('content_type'));

  if ($res->is_success and $type eq "text/html" )
  {
    my $title = $res->header('title');
    my $status = $res->status_line;
    $row->{http_code}      = $code;
    $row->{mime_type}      = $type;
    $row->{original_title} = Daum::utf8_string($title,$charset);
    $row->{original_url}   = sprintf("%s", $res->request->uri);
    $row->{charset}        = $charset;
    #my $content  = $res->decoded_content;
    push @DEBUG, "status=[$status]";
    push @DEBUG, "content_type=$type";
    #push @DEBUG, "content_type list=". join(" ",@types);
    push @DEBUG, "charset=$charset";
    push @DEBUG, "content_encoding=".($res->content_encoding||"");
  } elsif ($code == 200 and $type =~ m!^text/html!og )
  {
    my $title = $res->header('title');
    my $utf8  = Daum::utf8_string($title,$charset) || "제목이 없습니다";
    my $uri   = $res->request->uri;
    my $encoding = $res->content_encoding;
  } elsif ($res->request->uri =~ m#i.wik.im/\w+#oi ) {
    my $uri   = $res->request->uri;
    my $status = $res->status_line;

    push @DEBUG, "status=[$status]";
    push @DEBUG, "content_type=$type";
    push @DEBUG, "url=$uri";
  } else {
    my $uri   = $res->request->uri;
    my $status = $res->status_line;
    push @DEBUG, "status=[$status]";
    push @DEBUG, "content_type=$type";
    push @DEBUG, "url=$uri";
  }

  return ($row, $res);
}

sub put {
  my ($self, $shorten_url, $original_url, $original_title,
      $http_code, $mime_type, $referer, $source) = @_;

  my $row = {
    original_url => $original_url,
    original_title => $original_title,
    mime_type    => $mime_type,
    http_code    => $http_code,
  };
  my $r = save_webpage($shorten_url, $referer, $row, $source);

  return undef unless defined $r;
  return 1;
}

sub update {
  my ($self, $url_id, $shorten_url, $original_url, $original_title,
      $http_code, $mime_type, $referer, $source) = @_;

  my $row = {
    original_url => $original_url,
    original_title => $original_title,
    mime_type    => $mime_type,
    http_code    => $http_code,
  };
  my $r = update_webpage($url_id, $shorten_url, $referer, $row, $source);

  return undef unless defined $r;
  return 1;
}

sub forward {
  my ($self, $url) = @_;

  my $forward_url = $FORWARD_URL . $url;
  my $res = fetch_webpage($forward_url);
  my $content  = $res->content;

  if ($res->is_success)
  {
    push @DEBUG, "forward: is_success: $content";
    return 1;
  } else {
    my $status = $res->status_line;
    push @DEBUG, "status=[$status]";
    push @DEBUG, "forward: failed: $content";
    return 0;
  }

}

sub list {
  my ($self, $from, $count, $website, $original_url) = @_;
  $original_url = "";

  my $where = "where 1";
  my $where_and = "";
  my (@binded_vars, @count_vars);
  if ( not $website and not $original_url ) {
    $where = "where url_id between ? and ?";
    push @binded_vars, $from, $from+$count;
  }
  if ( $website ) {
    $where_and .= " and website like ?";
    push @binded_vars, $website;
    push @count_vars, $website;
  }
  if ( $original_url ) {
    $where_and .= " and original_url like ?";
    push @count_vars, $original_url;
  }

  map { push @binded_vars, $_ if $_; } ($website, $original_url);

  my $counting_sql = "select count(*) from url_translation where 1 $where_and";
  my $listing_sql = qq(select * 
from url_translation A inner join 
 (select url_id from url_translation
  $where
  $where_and
  order by url_id asc
  limit ?, ?
 ) B on A.url_id = B.url_id
);

  my ($urls, $list);
  push @DEBUG, "listing_sql: $listing_sql", join(",", @binded_vars);
  $urls = $DBH_SLAVE->selectrow_array($counting_sql, {}, @count_vars);
  push @DEBUG, "counting failed - $urls: ".$DBH_SLAVE->errstr unless $urls;
  $from = int( $urls / $count ) * $count if $from < 0;
  $list = $DBH_SLAVE->selectall_hashref($listing_sql, 'url_id', {}, @binded_vars, 0, $count);
  push @DEBUG, "listing failed - $list: ".$DBH_SLAVE->errstr unless $list;
  return ($urls,$list);
}

sub timeline {
  my ($self, $begin, $end, $roundup, $website, $original_url) = @_;
  my $where = " where 1";
  $where .= " and website like ?" if $website;
  $where .= " and original_url like ?" if $original_url;
  my $listing_sql = qq(select
count(*) as count,
date_format(A.created_on, '%m/%d %H:%i') as created_on,
  ( unix_timestamp(A.created_on)
    - mod(unix_timestamp(A.created_on), ?)
  ) as count_id
from url_translation A inner join 
 (select url_id from url_translation
  $where
      and created_on between ? and ?
  order by url_id asc
 ) B on A.url_id = B.url_id
group by 
  ( unix_timestamp(A.created_on)
    - mod(unix_timestamp(A.created_on), ?)
  )
);
  my @binded_vars = ($roundup);
  map { push @binded_vars, $_ if $_; } ($website, $original_url);
  push @binded_vars, $begin, $end, $roundup;

  my ($urls, $list);
  push @DEBUG, "listing_sql: $listing_sql", join(",", @binded_vars);
  $list = $DBH_SLAVE->selectall_hashref($listing_sql, 'count_id', {}, @binded_vars);
  push @DEBUG, "listing failed - $list: ".$DBH_SLAVE->errstr unless $list;
  return $list;
}

sub list_by_ourl_length {
  my ($self, $from, $count, $website, $original_url) = @_;
  my $where = " where 1";
  $where .= " and website like ?" if $website;
  $where .= " and original_url like ?" if $original_url;
  my $counting_sql = "select count(*) from url_translation $where";
  my $listing_sql = qq(select * 
from url_translation A inner join 
 (select url_id from url_translation
  $where
  order by length(original_url) desc
  limit ?, ?
 ) B on A.url_id = B.url_id
);
  my @binded_vars;
  map { push @binded_vars, $_ if $_; } ($website, $original_url);

  my ($urls, $list);
  push @DEBUG, "listing_sql: $listing_sql", join(",", @binded_vars, $from, $count);
  $urls = $DBH_SLAVE->selectrow_array($counting_sql, {}, @binded_vars);
  push @DEBUG, "counting failed - $urls: ".$DBH_SLAVE->errstr unless $urls;
  $from = int( $urls / $count ) * $count if $from < 0;
  $list = $DBH_SLAVE->selectall_hashref($listing_sql, 'url_id', {}, @binded_vars, $from, $count);
  push @DEBUG, "listing failed - $list: ".$DBH_SLAVE->errstr unless $list;
  return ($urls,$list);
}

sub list_by_surl_length {
  my ($self, $from, $count, $website, $original_url) = @_;
  my $where = " where 1";
  $where .= " and website like ?" if $website;
  $where .= " and original_url like ?" if $original_url;
  my $counting_sql = "select count(*) from url_translation $where";
  my $listing_sql = qq(select * 
from url_translation A inner join 
 (select url_id from url_translation
  $where
  order by length(shorten_url) desc
  limit ?, ?
 ) B on A.url_id = B.url_id
);
  my @binded_vars;
  map { push @binded_vars, $_ if $_; } ($website, $original_url);

  my ($urls, $list);
  push @DEBUG, "listing_sql: $listing_sql", join(",", @binded_vars, $from, $count);
  $urls = $DBH_SLAVE->selectrow_array($counting_sql, {}, @binded_vars);
  push @DEBUG, "counting failed - $urls: ".$DBH_SLAVE->errstr unless $urls;
  $from = int( $urls / $count ) * $count if $from < 0;
  $list = $DBH_SLAVE->selectall_hashref($listing_sql, 'url_id', {}, @binded_vars, $from, $count);
  push @DEBUG, "listing failed - $list: ".$DBH_SLAVE->errstr unless $list;
  return ($urls,$list);
}
##############################################################################
my $url_pattern = qr{
   (?xi)
     \b
     #(?: \s | (?<!url)\( | \< | ^) \K # look-behind assertion. optional.
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

sub shorten_url
{
  my $self = shift;
  my $url  = shift;
  $_ = $url;

  my @u = ("","","","","","");
  if ( m{^(https?://)(.+)$}o ) { $u[1] = $1; $url = $2; } # protocol
  else                         { return $url; }

#print STDERR "url1=$url\n";
  my $qm = index $url, '?';
  if ( $qm > 0 )    {
    $u[5] = substr $url, $qm;                 # query string
    $url = substr $url, 0, $qm;
  } else {
    ; # do nothing
  }
#print STDERR "url2=$url\n";
  my $slash = index $url, '/';
  if ( $slash > 0 )    {
    $u[2] = substr $url, 0, $slash;           # domain name
    $url = substr $url, $slash;
  } else {
    $u[2] = $url;
    ; # do nothing
    $url = "";
  }
#print STDERR "url3=$url\n";

  $slash = rindex $url, '/';
  if ( $slash > 0 )    {
    $u[3] = substr $url, 0, $slash+1;           # path
    $u[4] = substr $url, $slash+1;              # file name
  } elsif ( length $url > 0 ) {
    $u[3] = "/";
    $u[4] = substr $url, 1;
  } else {
    $u[3] = "/";
    $u[4] = "";
  }

  @u = map { m/%/o ? CGI::unescape($_) : $_ } @u;
  map { utf8::decode($_) } @u;
  @u = map { s/\s+/ /os; $_; } @u;
  #return join(" : ", map(+( $u[$_] || "" ),1..5));
  my @s = @u;
  my @m = @u;
#print STDERR "u=". join(" : ", map(+( $u[$_] || "" ),1..5));

  $m[2] = ".." . substr($u[2],-23, 23)  if length $u[2] > 25; # domain
  $m[3] = substr($u[3],  0, 23) . "../" if length $u[3] > 25; # path
  $m[4] = substr($u[4],  0, 33) . ".."  if length $u[4] > 35; # page
  $m[5] = substr($u[5],  0, 33) . ".."  if length $u[5] > 35; # query
                                        
  $s[2] = ".." . substr($u[2],-20, 20)  if length $u[2] > 22; # domain
  $s[3] = substr($u[3],  0, 10) . "../" if length $u[3] > 12; # path
  $s[4] = substr($u[4],  0, 20) . ".."  if length $u[4] > 22; # page
  $s[5] = substr($u[5],  0, 16) . ".."  if length $u[5] > 18; # query

  $url = join("", "", $u[2], $u[3], $u[4], $u[5]);

  $url = join("", "", $u[2], $u[3], $u[4], $m[5]) if length $url > 75;
  $url = join("", "", $u[2], $m[3], $u[4], $m[5]) if length $url > 75;

  $url = join("", "", $u[2], $m[3], $u[4], $s[5]) if length $url > 75;
  $url = join("", "", $u[2], $s[3], $u[4], $s[5]) if length $url > 75;

  $url = join("", "", $u[2], $s[3], $m[4], $s[5]) if length $url > 75;
  $url = join("", "", $m[2], $s[3], $u[4], $s[5]) if length $url > 75;
  $url = join("", "", $m[2], $s[3], $m[4], $s[5]) if length $url > 75;

  $url = join("", "", $s[2], $s[3], $m[4], $s[5]) if length $url > 75;

  $url = join("", "", $s[2], $s[3], $s[4], $s[5]) if length $url > 82;
  $url = join("", "", $s[2], $s[3], $s[4], $s[5] ? "?.." : "") if length $url > 82;
  $url = join("", "", $s[2], $s[3] ? "../" : "", $s[4], $s[5] ? "?.." : "") if length $url > 82;
  $url = join("", "", $s[2], ($s[3] || $s[4] || $s[5] ) ? "..." : "") if length $url > 82;
  push @DEBUG, "length of url: ". length $url;
=rem
    $url = join("",
      #span({class=>'dimmed'}, $1),
      $2,
      span({class=>'dimmed'}, $3),
      $4,
      span({class=>'dimmed'}, $5),
    );
  };
=cut
  return $url;
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

sub get_website {
  my $url = shift;

  $url =~ m!https?://([\w-]+(\.[\w-]+)*)/!o;
  my $host = $1;

  # XXX have to lookup website table
  return $host;
}

sub save_webpage {
  my ($url, $referer, $row, $source) = @_;
  $source = "internal" unless $source;
  my @fields =
    qw(shorten_url original_url original_title 
       mime_type http_code
       website source
       has_no_info has_original_url has_title has_image
       is_dead is_unreachable
       created_on);
  my $fields = join(",",@fields);

  my @values = map { $_ || "" }
    ($url, $row->{original_url}, $row->{original_title},
     $row->{mime_type}, $row->{http_code},
     get_website($row->{original_url}), $source,
     0, 1, 1, 0,
     0, 0
    );
  my $values = join(",",map(+("?"),1..13), "now()");

  my $sql = "insert into url_translation ($fields) values ($values)";
  push @DEBUG, $sql;
  push @DEBUG, join(",", @values);
  my $rows = $DBH_MASTER->do($sql, {}, @values);
  unless ($rows == 1)
  {
    push @DEBUG, "insert failed - rows=$rows: ".$DBH_MASTER->errstr;
    return undef;
  }
}

sub update_webpage {
  my ($url_id, $url, $referer, $row, $source) = @_;
  $source = "internal" unless $source;
  my @fields =
    qw(shorten_url original_url original_title 
       mime_type http_code
       website source
       has_no_info has_original_url has_title has_image
       is_dead is_unreachable);
  my $fields = join(",",@fields);

  my @values = map { $_ || "" }
    ($url, $row->{original_url}, $row->{original_title},
     $row->{mime_type}, $row->{http_code},
     get_website($row->{original_url}), $source,
     0, 1, 1, 0,
     0, 0,
     $url_id
    );

  my $sql = qq(update url_translation
set shorten_url = ?, original_url = ?, original_title = ?,
    mime_type = ?, http_code = ?, website = ?, source = ?,
    has_no_info = ?, has_original_url = ?,
    has_title = ?, has_image = ?,
    is_dead = ?, is_unreachable = ?
where url_id = ?);
  push @DEBUG, $sql;
  push @DEBUG, join(",", @values);
  my $rows = $DBH_MASTER->do($sql, {}, @values);
  unless ($rows == 1)
  {
    push @DEBUG, "update failed - rows=$rows: ".$DBH_MASTER->errstr;
    return undef;
  }
}

sub save_referer {
  my ($url, $referer, $row, $source) = @_;
  $source = "internal" unless $source;
  my @fields =
    qw(shorten_url original_url original_title 
       mime_type http_code
       website source
       has_no_info has_original_url has_title has_image
       is_dead is_unreachable
       created_on);
  my $fields = join(",",@fields);

  my @values = map { $_ || "" }
    ($url, $row->{original_url}, $row->{original_title},
     $row->{mime_type}, $row->{http_code},
     get_website($row->{original_url}), $source,
     0, 1, 1, 0,
     0, 0
    );
  my $values = join(",",map(+("?"),1..13), "now()");

  my $sql = "insert into url_translation ($fields) values ($values)";
  push @DEBUG, $sql;
  push @DEBUG, join(",", @values);
  my $rows = $DBH_MASTER->do($sql, {}, @values);
  unless ($rows == 1)
  {
    push @DEBUG, "insert failed - rows=$rows: ".$DBH_MASTER->errstr;
    return undef;
  }
}

my $ua;
sub fetch_webpage {
  my $url = shift;

  if ( not defined $ua ) {
    $ua = LWP::UserAgent->new;
    $ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) "
              ."AppleWebKit/533.4 (KHTML, like Gecko) Chrome/5.0.375.125 Safari/533.4");
    $ua->proxy([qw(http https)] => 'socks://127.0.0.1:1080')
      if CGI::server_name() eq 'shorten_url_dev';
  }

  my $req = HTTP::Request->new(GET => $url);
  my $res;
  eval {
    local $SIG{'__WARN__'} = sub { push @DEBUG, $_[0]; };
    $res = $ua->request($req);
  };
  if ( $@ ) { push @DEBUG, $@; }
  return $res;
}

sub connect_slave_db {
  my $dbname = $CONFIG{DBNAME_SLAVE};
  my $dbuser = $CONFIG{DBUSER};
  my $dbpasswd = $CONFIG{DBPASSWD};
  my $dbh = DBI->connect("dbi:mysql:$dbname", $dbuser, $dbpasswd);
  $dbh->do(qq(set names utf8));

  return $dbh;
}

sub connect_master_db {
  my $dbname = $CONFIG{DBNAME_MASTER};
  my $dbuser = $CONFIG{DBUSER};
  my $dbpasswd = $CONFIG{DBPASSWD};
  my $dbh = DBI->connect("dbi:mysql:$dbname", $dbuser, $dbpasswd);
  $dbh->do(qq(set names utf8));

  return $dbh;
}


1;

