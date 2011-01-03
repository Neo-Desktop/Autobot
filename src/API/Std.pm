# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
use strict;
use warnings;

# Standard API subroutines.
package API;

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
		return $Auto::SETTINGS{c}{$val[0]};
	}
	elsif ($count == 2) {
		return $Auto::SETTINGS{c}{$val[0]}{$val[1]};
	}
	elsif ($count == 3) {
		return $Auto::SETTINGS{c}{$val[0]}{$val[1]}{$val[2]};
	}
	else {
		return 0;
	}	
}

1;
