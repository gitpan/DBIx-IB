use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'DBIx::IB',
    'VERSION_FROM' => 'IB.pm', # finds $VERSION
	'NORECURS' => 1,
);
