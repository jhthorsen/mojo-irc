use t::Helper;

plan skip_all => 'No test data' unless -r 't/data/irc.perl.org';

my $port = generate_port();
my $irc  = Mojo::IRC->new;
my $read = '';

Mojo::IOLoop->server(
  {port => $port},
  sub {
    my ($self, $stream) = @_;
    my ($join, $welcome);
    $stream->on(
      read => sub {
        my ($stream, $data) = @_;
        $read .= $data;
        if ($read =~ /NICK/ and !$welcome) {
          $stream->write($welcome = irc_data('welcome'));
        }
        if ($read =~ /JOIN/ and !$join) {
          $stream->write($join = irc_data('join.mojo'));
        }
      }
    );
    $stream->write(irc_data('irc.perl.org'));
  },
);

isa_ok($irc, 'Mojo::IRC', 'Constructor returns right object');
$irc->nick('test123');
is $irc->nick, 'test123', 'nick setter works';
$irc->user('my name');
my $server = $ENV{IRC_HOST} || "127.0.0.1:$port";
$irc->server($server);
is $irc->server, $server, 'server setter works';

my $message = {};
my $err     = '';
my %got;
$irc->on(irc_join => sub { (my $self, $message) = @_; Mojo::IOLoop->stop; });

$irc->on(irc_rpl_motdstart => sub { $got{rpl_motdstart}++ });
$irc->on(irc_rpl_motd      => sub { $got{rpl_motd}++ });
$irc->on(irc_rpl_endofmotd => sub { $got{rpl_endofmotd}++ });
$irc->connect(sub { (my $irc, $err) = @_; $irc->write(JOIN => '#mojo'); });

start_ioloop();
is_deeply $message->{params}, ['#mojo'], 'got join #mojo event';
is $message->{prefix}, 'test123!~my@1.2.3.4.foo.com', '...with prefix';
is $got{rpl_motdstart}, 1,  '1 motdstart event';
is $got{rpl_motd},      23, '23 motd events';
is $got{rpl_endofmotd}, 1,  '1 endofmotd event';
is $read, "NICK test123\r\nUSER my name 8 * :Mojo IRC\r\nJOIN #mojo\r\n", 'nick, user and join got sent';
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
