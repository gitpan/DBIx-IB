#!/usr/bin/perl -w
require 5.004;

use blib;
use DBIx::IB;

$dbpath = '/home/edwin/proj/DBIx/perl_example.gdb';
$dbh = DBI->connect("dbi:IB:database=$dbpath",'','',{AutoCommit => 1}) 
	or die $DBI::errstr;

@params = ([1, "Tim Bunce", "Creator of DBI"],
		   [2, "Jonathan Lieffler", "Creator of DBD::Informix"],
		   [3, "Larry Wall", "Creator of Perl"],
		   [4, "Steven Haryanto", 'Bandung main mangler :-)'],

		   [6, "Randal Schwartz", 'The Transformer']);
#		   [5, "Gurusamy Sarathy", 'Main porter'],
$sql = "insert into SIMPLE values (?, ?, ?)";
$cursor = $dbh->prepare($sql) or die $dbh->errstr;

print "Inserting records...\n";
for (@params)
{
#	print ${@$_}[0], ${@$_}[1], ${@$_}[2],"\n";
	$cursor->execute(${@$_}[0], ${@$_}[1], ${@$_}[2])
		or die $dbh->errstr;
}
print "Finished.\n";
$dbh->disconnect or warn $dbh->errstr;

__END__
