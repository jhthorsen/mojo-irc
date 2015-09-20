use Test::Mojo::IRC -ua;

my $t      = Test::Mojo::IRC->new;
my $server = $t->start_server;
my $irc    = Mojo::IRC::UA->new(server => $server, user => "test$$");

{
  my $err;
  $irc->join_channel("", sub { $err = $_[1]; Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  is $err, 'Cannot join without channel name.', 'channel name missing';
}

{
  my $err;
  $irc->join_channel("channel with space", sub { $err = $_[1]; Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  is $err, 'Cannot join channel with spaces.', 'channel name with whitespace';
}

$irc->connect(sub { Mojo::IOLoop->stop });
Mojo::IOLoop->start;

$t->run(
  [qr{USER} => ['main', 'join-convos.irc']],
  sub {
    my ($err, $info);
    $irc->join_channel("#convos", sub { ($err, $info) = @_[1, 2]; Mojo::IOLoop->stop });
    Mojo::IOLoop->start;
    is $err, '', 'channel joined';
    is_deeply(
      $info,
      {
        topic    => 'some cool topic',
        topic_by => 'jhthorsen!jhthorsen@i.love.debian.org',
        users    => {batman => {mode => '@'}, Test21362 => {mode => ''}},
      },
      'got channel info'
    );
  },
);

$t->run(
  [qr{USER} => ['main', 'join-convos.irc']],
  sub {
    my $err;
    $irc->op_timeout(0.3)->join_channel("#convos", sub { $err = $_[1]; Mojo::IOLoop->stop });
    Mojo::IOLoop->start;
    local $TODO = 'Maybe TOPIC can be added to see if already joined?';
    is $err, 'Response timeout after 0.3s.', 'response timeout';
  }
);

done_testing;

__DATA__
@@ join-convos.irc
:test21362!test21362@i.love.debian.org JOIN :#convos
:hybrid8.debian.local 332 test21362 #convos :some cool topic
:hybrid8.debian.local 333 test21362 #convos jhthorsen!jhthorsen@i.love.debian.org 1432932059
:hybrid8.debian.local 353 test21362 = #convos :Test21362 @batman
:hybrid8.debian.local 366 test21362 #convos :End of /NAMES list.
