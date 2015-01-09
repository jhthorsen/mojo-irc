BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
use Mojo::Base -strict;
use Mojo::IRC;
use Test::More;

my $irc = Mojo::IRC->new(nick => 'batman', server => 'test.com');
my @msg;

$irc->parser(Parse::IRC->new(ctcp => 1));
$irc->on(irc_479 => sub { push @msg, $_[1] });
$irc->connect(sub { });
$irc->from_irc_server(":hostname 479 nickname 1 :Illegal channel name\r\n");

is_deeply(
  \@msg,
  [
    {
      command  => 479,
      params   => ['nickname', '1', 'Illegal channel name'],
      prefix   => 'hostname',
      raw_line => ':hostname 479 nickname 1 :Illegal channel name',
    },
  ],
  'got numeric event',
);

done_testing;
