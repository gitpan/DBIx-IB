package 
DBI;

=head1 NAME

DBIx::IB - This is a thin DBI Emulation Layer for IBPerl

=head1 SYNOPSIS

  use DBIx::IB;
  
  $dbpath = '/usr/interbase/data/perl_example.gdb';
  $dbh = DBI->connect(DBI:IB:database=$dbpath) or die "DBI::errstr";
  $sth = $dbh->prepare("select * from SIMPLE") or die $dbh->errstr;
  $sth->execute;
  while (@row = $sth->fetchrow_array))
  {
    print @row, "\n";
  }
  $dbh->commit;
  $dbh->disconnect;  

For more examples, see eg/ directory.

=head1 DESCRIPTION

The DBIx::IB module is a thin DBI emulation layer for IBPerl. Use this as 
a kludge during the advent of DBD::IB ! 

=head1 WARNING

If AutoCommit is on, there may be some warning issued when disconnecting.

=head1 DBI METHODS AVAILABLE

Class and database handle methods:

=over 4

=item * $dbh = DBI->connect($dsn, $user, $passw, \%attr);

=item * $dbh->disconnect;

=item * $dbh->do;

=item * $dbh->commit;

=item * $dbh->rollback;

=item * $sth = $dbh->prepare($sql);

=item * $dbh->errstr;

=back

Statement handle methods:

=over 4

=item * $sth->execute;

=item * $sth->fetch;

=item * $sth->fetchrow_array;

=item * $sth->fetchrow_arrayref;

=item * $sth->finish;

=back

=head1 DBI ATTRIBUTES AVAILABLE

Only $DBI::errstr available as package-global. 

=head1 AUTHOR

Copyright (c) 1999 Edwin Pratomo <ed.pratomo@computer.org>.

All rights reserved. This is a B<free code>, available as-is;
you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

DBI(3), IBPerl(1).

=cut

use strict;
use Carp;
use IBPerl;

use vars qw($VERSION @ISA $errstr);

@ISA = qw(IBPerl);

$VERSION = '0.01';
#my $Revision = substr(q$Revision$, 10);

sub DBI::IB::import { }

# $data_source = "dbi:IB:database=path_to_db;host=host_name;port=port";
# or ... (emulation after all! :-):
# $data_source = "database=path_to_db;host=host_name;port=port";
# $dbh = DBI->connect($data_source, $user, $passw, \%attr)

sub connect {
    my ($class, $dsn, $dbuser, $dbpasswd, $attr) = @_;
	my %conn;
	my ($key, $val);
	foreach my $pair (split(/;/, $dsn))
	{
		($key, $val) = $pair =~ m{(.+)=(.*)};
		$conn{Server} = $val if ($key eq 'host');
		$conn{Path} = $val if ($key =~ m{database});
		$conn{Port} = $val if ($key eq 'port');
	}

	$conn{User} = $dbuser || "SYSDBA";
	$conn{Password} = $dbpasswd || "masterkey";
		
    my $db = new IBPerl::Connection(%conn);
	if ($db->{Handle} < 0) {
		$errstr = $db->{Error};
		return undef;
	}
	
	my $h = new IBPerl::Transaction(Database=>$db);
	if ($h->{Handle} < 0) {
		$errstr = $h->{Error};
		return undef;
	}
    bless $db, $class if $h;	# rebless into our class
	$db->{__trans_handle} = $h; # save transaction handle

	# read attributes
	while (($key, $val) = each(%$attr))
	{
		$db->{$key} = $val;		#if AutoCommit is set, it is here
	}		
    $db;
}

sub disconnect
{
	my $db = shift;
	if ($db->{AutoCommit})
	{
		$db->commit or return undef;
	}
	if ($db->IBPerl::Connection::disconnect < 0)
	{
		$errstr = $db->{Error};
		return undef;
	}	
	1;
}

sub do {
    my($db, $statement, $attribs, @params) = @_;
	my $h = $db->{__trans_handle};
    Carp::carp "\$h->do() attribs unused\n" if $attribs;

	my $st = new IB::Statement(
		Transaction => $h,
	    Stmt => $statement);
	if ($st->{Handle} < 0) {
		$errstr = $st->{Error};
		return undef;
	}		
	if ($st->IB::Statement::execute(@params) < 0) { 
		$errstr = $st->{Error};
		return undef; 
	}

	if ($db->{AutoCommit})
	{
		$db->commit or return undef;
	}
	"0E0";
# no rows method, currently
#    my $rows = $h->rows;
#    ($rows == 0) ? "0E0" : $rows;
}
	
sub prepare {
    my ($db, $sql) = @_;
	my $h = $db->{__trans_handle};

# $h is a DBI dbh
#    $h->{'__prepare'} = $sql;
#	$h->{NAME} = [];
#	$h->{NUM_OF_FIELDS} = -1;

	my $st = new IB::Statement(
		Transaction => $h,
	    Stmt => $sql);

	if ($st->{Handle} < 0) {
		$errstr = $st->{Error};
		return undef;
	}

# return a DBI sth
    return $st;
}

sub commit
{
	my $h = shift->{__trans_handle};
	if ($h->IBPerl::Transaction::commit < 0) {
		$errstr = $h->{Error};
		return undef;
	}	
	1;
}

sub rollback
{
	my $h = shift->{__trans_handle};
	if ($h->IBPerl::Transaction::rollback < 0) {
		$errstr = $h->{Error};
		return undef;
	}	
	1;
}

sub errstr
{
	scalar($errstr);
}

{
# a class for statement handle $sth
package IB::Statement;
use IBPerl;
use vars qw(@ISA);
@ISA = qw(IBPerl::Statement);

sub execute {
    my ($st, @params) = @_;

	my $stmt = $st->{Stmt};
# use open() for select and execute() for non-select
	if ($stmt =~ m{^\s*?SELECT}i)
	{
		if ($st->open(@params) < 0)
		{
			$DBI::errstr = $st->{Error};
			return undef;
		}
	}
	else
	{
		if ($st->IBPerl::Statement::execute(@params) < 0)
		{
			$DBI::errstr = $st->{Error};
			return undef;
		}
# we'll take a look again at this in the near future...
#		if ($db->{AutoCommit})
#		{
#			$db->commit or return undef;
#		}
	}		

# doesn't have method for this:
#    my @fields = $h->FieldNames;
#    $h->{NAME} = \@fields;
#    $h->{NUM_OF_FIELDS} = scalar @fields;

    $st;
}

sub fetch {
    my @row = shift->fetchrow_array;
    return undef unless @row;
    return \@row;
}

sub fetchrow_array
{
	my $st = shift;
	my @record = ();
	my $retval = $st->IBPerl::Statement::fetch(\@record);
	if ($retval == 0) {return @record;}
	if ($retval < 0) {$DBI::errstr = $st->{Error}};
	return ();	
}

*fetchrow_arrayref = \&fetch;

sub finish
{
	my $st = shift;
	if ($st->close < 0) 
	{
		$DBI::errstr = $st->{Error};
		return undef;
	}
	1;
}

}
1;

__END__

