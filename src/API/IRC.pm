# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# IRC API subroutines.
package API::IRC;
use strict;
use warnings;
use Exporter;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(cjoin cpart);


# Join a channel.
sub cjoin {
	my ($svr, $chan) = @_;
	
	Auto::socksnd($svr, "JOIN $chan");
}

# Part a channel.
sub cpart {
	my ($svr, $chan, $reason) = @_;
	
	if (defined $reason) {
		Auto::socksnd($svr, "PART $chan :$reason");
	}
	else {
		Auto::socksnd($svr, "PART $chan :Leaving");
	}
}
