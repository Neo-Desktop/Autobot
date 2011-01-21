# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# IRC API subroutines.
package API::IRC;
use strict;
use warnings;
use Exporter;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(cjoin cpart mode privmsg notice quit);


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

# Set mode(s) on a channel.
sub cmode {
	my ($svr, $chan, $modes) = @_;

	Auto::socksnd($svr, "MODE $chan $modes");
}

# Set mode(s) on us.
sub umode {
	my ($svr, $modes) = @_;
	
	
} 

# Send a PRIVMSG.
sub privmsg {
	my ($svr, $target, $message) = @_;
	
	Auto::socksnd($svr, "PRIVMSG $target :$message");
}

# Send a NOTICE.
sub notice {
	my ($svr, $target, $message) = @_;
	
	Auto::socksnd($svr, "NOTICE $target :$message");
}

# Quit IRC.
sub quit {
	my ($svr, $reason) = @_;
	
	if (defined $reason) {
		Auto::socksnd($svr, "QUIT :$reason");
	}
	else {
		Auto::socksnd($svr, "QUIT :Leaving");
	}
	
	delete $Parser::IRC::got_001{$svr} if (defined $Parser::IRC::got_001{$svr});
}

