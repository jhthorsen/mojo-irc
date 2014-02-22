BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
use Mojo::Base -strict;
use Mojo::IRC;
use Test::More;

my $irc = Mojo::IRC->new(nick => 'batman', server => 'test.com');

$irc->parser(Parse::IRC->new(ctcp => 1));

$irc->on(
  ctcp_avatar => sub {
    my($irc, $message) = @_;
    $irc->write(
      NOTICE => $message->{params}[0],
      $irc->ctcp(AVATAR => 'https://graph.facebook.com/jhthorsen/picture'),
    );
  }
);

$irc->connect(sub {});
$irc->from_irc_server(":abc-123 PRIVMSG batman :\x{1}AVATAR\x{1}\r\n");
like $irc->{to_irc_server}, qr{NOTICE batman :\x{1}AVATAR https://graph.facebook.com/jhthorsen/picture\x{1}\r\n}, 'sent AVATAR';

done_testing;
