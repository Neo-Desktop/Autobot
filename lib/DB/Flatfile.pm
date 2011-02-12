# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.

# Database subroutines for the Auto-Flatfile database format.
package DB;
use strict;
use warnings;

my (%MEM);


# Database initial loading.
sub load
{
	# Open, read and close the database.
	open(my $FDB, q{<}, "$Auto::Bin/../etc/auto.db") or return 0;
	my @fbuf = <$FDB> or return 0;
	close $FDB or return 0;
	
	# Make sure the database version is compatible.
	if ($fbuf[0] ne "DBV Auto-Flatfile_1.0\n") {
		# It is not. Bail.
		return 0;
	}
	
	# Iterate the buffer.
	foreach my $buff (@fbuf) {
		# Check if the buffer is defined.
		if (defined $buff) {
			# Space buffer.
			my @lbuf = split(' ', $buff);
			
			# Check if the first two values are defined.
			if (defined $lbuf[0] and defined $lbuf[1]) {
				# Make sure it isn't DBV.
				if ($lbuf[0] eq "DBV") {
					next;
				}
				# Get a count of the values in the buffer minus one.
				my $c = scalar(@lbuf) - 1;
				
				# Create an array of the values excluding the first.
				my @vs;
				for (my $i = $c; $i <= $c; $i++) {
					push(@vs, $lbuf[$i]);
				}
				
				# Insert data into memory.
				if (defined $MEM{$lbuf[0]}) {
					# There is a database entry of the same name already, add to existing array.
					push(@{ $MEM{$lbuf[0]} }, [ @vs ]);
				}
				else {
					# This is the first database entry of this name, create an array.
					@{ $MEM{$lbuf[0]} } = [ @vs ];
				}
			}
		}
	}		
	return 1;
}

# Database flush to disk.
sub flush
{
	my $wd = "DBV Auto-Flatfile_1.0\n";
	# Iterate through all the database data in memory.
	foreach my $mek (keys %MEM) {
		foreach my $mas (@{ $MEM{$mek} }) {
			$wd .= $mek;
			foreach my $masl (@{ $mas }) {
				$wd .= " ".$masl;
			}
			$wd .= "\n";
		}
	}
	
	# Write to disk.
	unless (-e "$Auto::Bin/../etc/auto.db") {
		`touch $Auto::Bin/../etc/auto.db`;
	}
	open(my $FDB, q{>}, "$Auto::Bin/../etc/auto.db") or return 0;
	print $FDB $wd or return 0;
	close $FDB or return 0;
	
	return 1;
}

# Get database value.
sub get
{
	my ($name) = @_;
	
	if (defined $MEM{$name}) {
		return $MEM{$name};
	}
	else {
		return 0;
	}
}

# Write to database.
sub mwrite
{
	my ($name, @values) = @_;
	
	if (defined $MEM{$name}) {
		# There is a database entry of the same name already, add to existing array.
		push(@{ $MEM{$name} }, [ @values ]);
	}
	else {
		# This is the first database entry of this name, create an array.
		@{ $MEM{$name} } = [ @values ];
	}
	
	return 1;
}

# Delete from database.
sub mdelete
{
	my ($name, $i) = @_;
	
	if (defined $MEM{$name}[$i]) {
		delete $MEM{$name}[$i];
	}
	
	return 1;
}


1;
