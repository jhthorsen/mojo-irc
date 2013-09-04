use strict;
use warnings;
use Mojo::IRC;
use Test::More;

plan skip_all => 'Need TEST_TLS=1' unless $ENV{TEST_TLS};
plan tests => 3;

my $irc = Mojo::IRC->new;

is $irc->tls, undef, 'tls is disabled by default';

$irc->server('irc.freenode.net:7000');
$irc->nick('mojo-irc-' . int rand 1000);
$irc->tls({});
$irc->connect(sub {
  my($irc, $error) = @_;
  is $error, '', 'no error' or diag $error;
  Mojo::IOLoop->stop;
});

ok $irc->{stream_id}, 'stream_id is set';

Mojo::IOLoop->start;
