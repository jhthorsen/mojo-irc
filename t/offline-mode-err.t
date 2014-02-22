BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
use Mojo::Base -strict;
use Mojo::IRC;
use Test::More;

my $irc = Mojo::IRC->new(nick => 'batman', server => 'test.com');
my @err;

$irc->parser(Parse::IRC->new(ctcp => 1));

$irc->on(irc_error => sub { push @err, $_[1] });
$irc->on(irc_err_nosuchnick => sub { push @err, $_[1] }); # WILL BE DEPRECATED
$irc->on(err_nosuchnick => sub { push @err, $_[1] });

$irc->connect(sub {});
$irc->from_irc_server(":hostname 401 jhthorsen convos-gh :No such nick/channel\r\n");

is_deeply(
  \@err,
  [
    map {
      +{
        command => 401,
        params => [ 'jhthorsen', 'convos-gh', 'No such nick/channel' ],
        prefix => 'hostname',
        raw_line => ':hostname 401 jhthorsen convos-gh :No such nick/channel',
      },
    } 1..3
  ],
  'got irc_error events',
);

done_testing;
