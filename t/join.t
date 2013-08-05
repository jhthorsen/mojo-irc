use strict;
use warnings;
use Mojo::IRC;
use Test::More;

plan skip_all => 'No test data' unless -r 't/data/irc.perl.org';
plan tests => 9;

my $port = Mojo::IOLoop->generate_port;
my $irc = Mojo::IRC->new;
my $read = '';

Mojo::IOLoop->server(
  { port => $port },
  sub {
    my($self, $stream) = @_;
    my($join, $welcome);
    $stream->on(
      read => sub {
        my($stream, $data) = @_;
        $read .= $data;
        if($read =~ /NICK/ and !$welcome) {
          $stream->write($welcome = irc_data('welcome'));
        }
        if($read =~ /JOIN/ and !$join) {
          $stream->write($join = irc_data('join.mojo'));
        }
      }
    );
    $stream->write(irc_data('irc.perl.org'));
  },
);

{
  isa_ok($irc, 'Mojo::IRC', 'Constructor returns right object');
  $irc->nick('test123');
  is $irc->nick, 'test123', 'nick setter works';
  $irc->user('my name');
  my $server = $ENV{IRC_HOST} || "localhost:$port";
  $irc->server($server);
  is $irc->server, $server, 'server setter works';
}

{
  my %got;
  $irc->on(
    irc_join => sub {
      my ($self, $message) = @_;

      is_deeply $message->{params}, ['#mojo'], 'got join #mojo event';
      is $message->{prefix}, 'test123!~my@1.2.3.4.foo.com', '...with prefix';
      is $got{rpl_motdstart}, 1,  '1 motdstart event';
      is $got{rpl_motd},      18, '18 motd events';
      is $got{rpl_endofmotd}, 1,  '1 endofmotd event';
      is $read, "NICK test123\r\nUSER my name 8 * :Mojo IRC\r\nJOIN #mojo\r\n", 'nick, user and join got sent';
      Mojo::IOLoop->stop;
    }
  );

  $irc->on(irc_rpl_motdstart => sub { $got{rpl_motdstart}++ });
  $irc->on(irc_rpl_motd      => sub { $got{rpl_motd}++ });
  $irc->on(irc_rpl_endofmotd => sub { $got{rpl_endofmotd}++ });

  $irc->connect(
    sub {
      my ($irc, $err) = @_;
      diag $err if $err;
      $irc->write(JOIN => '#mojo');
    }
  );

  Mojo::IOLoop->start;
}

sub irc_data {
  my $file = shift;
  diag "read $file";
  open my $FH, '<', "t/data/$file" or die $!;
  join '', map { s/\r?\n$/\r\n/; $_ } <$FH>;
}
