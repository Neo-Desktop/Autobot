# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
use strict;
use warnings;
use Exporter;

# Standard API subroutines.
package API::Std;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(conf_get trans);

my %LANGE;


# Configuration value getter.
sub conf_get
{
	my ($value) = @_;
	
	# Create an array out of the value.
	my @val;
	if ($value =~ m/:/) {
		@val = split(':', $value);
	}
	else {
		@val = ($value);
	}
	# Undefine this as it's unnecessary now.
	undef $value;
	
	# Get the count of elements in the array.
	my $count = scalar(@val);
	
	# Return the requested configuration value(s).
	if ($count == 1) {
		return $Auto::SETTINGS{$val[0]};
	}
	elsif ($count == 2) {
		return $Auto::SETTINGS{$val[0]}{$val[1]};
	}
	elsif ($count == 3) {
		return $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]};
	}
	else {
		return 0;
	}	
}

# Translation subroutine.
sub trans
{
	my ($id) = @_;
	$id =~ s/ /_/g;
	
	if (defined $API::Std::LANGE{$id}) {
		return $API::Std::LANGE{$id};
	}
	else {
		$id =~ s/_/ /g;
		return $id;
	}
}

1;
