use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mojo::IRC',
  ABSTRACT_FROM => 'lib/Mojo/IRC.pm',
  VERSION_FROM => 'lib/Mojo/IRC.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'IRC::Utils' => '0.12',
    'Mojolicious' => '4.30',
    'Parse::IRC' => '1.20',
    'Unicode::UTF8' => '0.59',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.98',
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Mojo-IRC',
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojo-IRC',
      repository => 'https://github.com/jhthorsen/mojo-irc',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
);
