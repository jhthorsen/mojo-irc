use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mojo::IRC',
  VERSION_FROM => 'lib/Mojo/IRC.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  PREREQ_PM => {
    'IRC::Utils' => '0.12',
    'Mojolicious' => '4.00',
    'Parse::IRC' => '1.20',
    'Unicode::UTF8' => '0.59',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.98',
  },
  test => {
    TESTS => 't/*.t',
  },
);
