use t::Helper;
use Mojo::IRC;

my $port = generate_port();
my $irc = Mojo::IRC->new;
my $written = '';
my $err;

$irc->name("the end");
$irc->nick("fooman");
$irc->pass("s4cret");
$irc->server("127.0.0.1:$port");
$irc->user("foo");

Mojo::IOLoop->server(
  { port => $port },
  sub {
    my($self, $stream) = @_;
    my($join, $welcome);
    $stream->on(read => sub {
      diag $_[1];
      $written .= $_[1];
      Mojo::IOLoop->stop if $written =~ /:the end/;
    });
  },
);

$irc->connect(sub { $err = pop; Mojo::IOLoop->stop if $err; });
Mojo::IOLoop->start;

is $err, '', 'no error';
is $written, "PASS s4cret\r\nNICK fooman\r\nUSER foo 8 * :the end\r\n", 'wrote PASS, NICK, USER';

done_testing;
