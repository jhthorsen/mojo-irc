use t::Helper;

plan skip_all => 'No test data' unless -r 't/data/irc.perl.org';

my $port = generate_port();
my $irc  = Mojo::IRC->new;
my $read = '';

Mojo::IOLoop->server(
  {port => $port},
  sub {
    my ($self, $stream) = @_;
    my ($welcome, $whois);
    $stream->on(
      read => sub {
        my ($stream, $data) = @_;
        $read .= $data;
        if ($read =~ /NICK/ and !$welcome) {
          $stream->write($welcome = irc_data('welcome'));
        }
        if ($read =~ /WHOIS/ and !$whois) {
          $stream->write($whois = irc_data('whois.test123'));
        }
      }
    );
    $stream->write(irc_data('irc.perl.org'));
  },
);

$irc->nick('test123');
$irc->user('my name');
my $server = $ENV{IRC_HOST} || "127.0.0.1:$port";
$irc->server($server);

my $message = {};
my $err     = '';
my %got;

$irc->on($_ => sub { $got{rpl_whois}++ })
  for qw/irc_rpl_whoisuser irc_rpl_whoischannels irc_rpl_whoisserver irc_rpl_whoisidle/;
$irc->on($_ => sub { $got{rpl_whois_numeric}++ }) for qw/irc_275 irc_311 irc_312 irc_317 irc_319/;
$irc->on(irc_rpl_endofwhois    => sub { $got{rpl_endofwhois}++; Mojo::IOLoop->stop; });
$irc->connect(sub { (my $irc, $err) = @_; $irc->write(WHOIS => 'test123'); });

start_ioloop();
is $got{rpl_whois},         4, '4 whois events';
is $got{rpl_whois_numeric}, 5, '5 numeric whois events';
is $got{rpl_endofwhois},    1, '1 endofwhois event';
is $read, "NICK test123\r\nUSER my name 8 * :Mojo IRC\r\nWHOIS test123\r\n", 'nick, user and whois got sent';
is + ($err || ''), '', 'no error';

done_testing;

sub irc_data {
  my $file = shift;
  diag "read $file";
  open my $FH, '<', "t/data/$file" or die $!;
  join '', map { s/\r?\n$/\r\n/; $_ } <$FH>;
}

sub start_ioloop {
  $err    = 'ioloop-failed';
  $status = 'ioloop-failed';
  my $tid = Mojo::IOLoop->timer(1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($tid);
}
