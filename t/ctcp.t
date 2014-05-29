use strict;
use warnings;
use Test::More;

{
  *Mojo::IRC::localtime = sub { 'Fri Feb 21 19:35:24 2014' };
  *Mojo::IRC::time = sub () { 1393007663 };
  require Mojo::IRC;
}

my $read = '';

my $server = Mojo::IOLoop->server(
  { address => '127.0.0.1' },
  sub {
    my($self, $stream) = @_;

    $stream->on(
      read => sub {
        my($stream, $data) = @_;
        $read .= $data;
        Mojo::IOLoop->stop if $read =~ /VERSION/;
      }
    );

    $stream->write(":abc-123 PRIVMSG #channel :\x{1}ACTION msg1\x{1}\r\n");
    $stream->write(":abc-123 PRIVMSG ctcpman :\x{1}PING 1393007660\x{1}\r\n");
    $stream->write(":abc-123 PRIVMSG ctcpman :\x{1}TIME\x{1}\r\n");
    $stream->write(":abc-123 PRIVMSG ctcpman :\x{1}VERSION\x{1}\r\n");
  },
);

my $port = Mojo::IOLoop->acceptor($server)->handle->sockport;

my $irc = Mojo::IRC->new(nick => "ctcpman", user => "u1", server => "localhost:$port");

$irc->parser(Parse::IRC->new(ctcp => 1));

{
  my $action;
  $irc->on(ctcp_action => sub { $action = $_[1]; });
  $irc->connect(sub { diag $_[1] || 'Connected'; });
  Mojo::IOLoop->start;

  delete $action->{raw_line};
  no warnings 'qw';
  is_deeply(
    $action,
    {
      command => 'CTCP_ACTION',
      params => [qw( #channel msg1 )],
      prefix => 'abc-123',
    },
    'CTCP ACTION',
  );

  is $read, <<"  READ", "got correct response from client";
NICK ctcpman\r
USER u1 8 * :Mojo IRC\r
NOTICE ctcpman :\001Ping reply from ctcpman: 3 second(s)\001\r
NOTICE ctcpman :\001TIME Fri Feb 21 19:35:24 2014\001\r
NOTICE ctcpman :\001VERSION Mojo-IRC $Mojo::IRC::VERSION\001\r
  READ
}

done_testing;
