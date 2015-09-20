use Test::Mojo::IRC -ua;

my $t      = Test::Mojo::IRC->new;
my $server = $t->start_server;
my $irc    = Mojo::IRC::UA->new(server => $server, user => "test$$");

$irc->connect(sub { Mojo::IOLoop->stop });
Mojo::IOLoop->start;

{
  my $err;
  $irc->channel_users("", sub { $err = $_[1]; Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  is $err, 'Cannot get users without channel name.', 'channel name missing';
}

$t->run(
  [qr{NAMES} => ['main', 'convos-names.irc']],
  sub {
    my ($err, $users);

    #for testing with live server:
    #$irc->join_channel("#convos", sub { Mojo::IOLoop->stop });
    #Mojo::IOLoop->start;
    $irc->channel_users("#convos", sub { ($err, $users) = @_[1, 2]; Mojo::IOLoop->stop });
    Mojo::IOLoop->start;
    is $err, '', 'no error';
    is_deeply($users, {foo => {mode => '+'}, bar => {mode => '@'}, test6851 => {mode => ''}, batman => {mode => '@'},},
      'users');
  },
);

done_testing;

__DATA__
@@ convos-names.irc
:hybrid8.debian.local 353 test6851 = #convos :test6851 @batman
:hybrid8.debian.local 353 test6851 = #convos :@bar +foo
:hybrid8.debian.local 366 test6851 #convos :End of /NAMES list.
