use Test::Mojo::IRC -basic;

my $t      = Test::Mojo::IRC->new;
my $server = $t->start_server;
my $irc    = Mojo::IRC->new(server => $server);

# simulate server/client communication
$t->run(
  [
    # Send t/data/welcome when client sends "NICK"
    # The file contains the MOTD text
    qr{\bNICK\b} => \"t/data/welcome",
  ],
  sub {
    my $err;
    my $motd = 0;
    $t->on($irc, irc_rpl_motd      => sub { $motd++ });
    $t->on($irc, irc_rpl_endofmotd => sub { Mojo::IOLoop->stop; });    # need to manually stop the IOLoop
    $irc->connect(sub { $err = $_[1]; });
    Mojo::IOLoop->start;                                               # need to manually start the IOLoop
    is $err,  "", "connected";
    is $motd, 19, "message of the day has of 15 lines";
  },
);

# extra code to test on()
ok !$irc->has_subscribers('irc_rpl_motd'), 'irc_rpl_motd event removed';

done_testing;
