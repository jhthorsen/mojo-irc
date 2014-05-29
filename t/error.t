use strict;
use warnings;
use Mojo::IRC;
use Test::More;
use Errno ();

my $status = 'YIKES';

my $server = Mojo::IOLoop->server(
  { address => '127.0.0.1' },
  sub {
    my($ioloop, $stream) = @_;
    Mojo::IOLoop->timer(0.01 => sub { $stream->close });
  },
);

my $port = Mojo::IOLoop->acceptor($server)->handle->sockport;

my $irc = Mojo::IRC->new(server => "localhost:$port");

plan skip_all => 'Could not find any port' unless $port;

{
  $irc->on(close => sub { $status = 'close'; Mojo::IOLoop->stop });
}

{
  my $bad_port = Mojo::IOLoop::Server->generate_port;
  $irc->server("localhost:$bad_port");
  $irc->connect(sub {
    my($irc, $error) = @_;
    is int($!), Errno::ECONNREFUSED, "could not connect ($!) ($error)";
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
}

{
  $irc->server("localhost:$port");
  $irc->connect(sub {
    my($irc, $error) = @_;
    is $error, '', 'connected';
  });
  Mojo::IOLoop->start;

  is $status, 'close', 'connection closed';
}

{
  $irc->server("localhost:$port");
  $irc->connect(sub {
    my($irc, $error) = @_;
    $status = 'connected';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  is $status, 'connected', 'could still connect';
}

done_testing;
