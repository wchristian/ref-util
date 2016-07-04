use 5.006002;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME           => 'Hello::World',
    VERSION_FROM   => 'lib/Hello/World.pm',
    PREREQ_PM      => { 'Test::More' => 0, 'Exporter' => '5.57' },
    ABSTRACT_FROM  => 'lib/Hello/World.pm',
    AUTHOR         => 'Sawyer X <xsawyerx@cpan.org>',
    LICENSE        => 'mit',
    LIBS           => [''],
    DEFINE         => '',
    INC            => '-I.',
    OBJECT         => '$(O_FILES)',
    MIN_PERL_VERSION => '5.6.2',
);

