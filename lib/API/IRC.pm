# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# IRC API subroutines.
package API::IRC;
use strict;
use warnings;
use Exporter;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(cjoin cpart cmode umode kick privmsg notice quit nick names topic
					usrc match_mask);


# Join a channel.
sub cjoin 
{
	my ($svr, $chan) = @_;
	
	Auto::socksnd($svr, "JOIN $chan");
	
	return 1;
}

# Part a channel.
sub cpart 
{
	my ($svr, $chan, $reason) = @_;
	
	if (defined $reason) {
		Auto::socksnd($svr, "PART $chan :$reason");
	}
	else {
		Auto::socksnd($svr, "PART $chan :Leaving");
	}

    if (defined $Parser::IRC::botchans{$svr}{$chan}) { delete $Parser::IRC::botchans{$svr}{$chan}; }
	
	return 1;
}

# Set mode(s) on a channel.
sub cmode 
{
	my ($svr, $chan, $modes) = @_;

	Auto::socksnd($svr, "MODE $chan $modes");
	
	return 1;
}

# Set mode(s) on us.
sub umode 
{
	my ($svr, $modes) = @_;
	
	Auto::socksnd($svr, "MODE ".$Parser::IRC::botnick{$svr}{nick}." $modes");
	
	return 1;
} 

# Send a PRIVMSG.
sub privmsg 
{
	my ($svr, $target, $message) = @_;
	
	Auto::socksnd($svr, "PRIVMSG $target :$message");
	
	return 1;
}

# Send a NOTICE.
sub notice 
{
	my ($svr, $target, $message) = @_;
	
	Auto::socksnd($svr, "NOTICE $target :$message");
	
	return 1;
}

# Send an ACTION PRIVMSG.
sub act
{
    my ($svr, $target, $message) = @_;

    Auto::socksnd($svr, "PRIVMSG $target :\001ACTION $message\001");

    return 1;
}

# Change bot nickname.
sub nick 
{
	my ($svr, $newnick) = @_;
	
	Auto::socksnd($svr, "NICK $newnick");
	
	$Parser::IRC::botnick{$svr}{newnick} = $newnick;
	
	return 1;
}

# Request the users of a channel.
sub names
{
	my ($svr, $chan) = @_;
	
	Auto::socksnd($svr, "NAMES $chan");
	
	return 1;
}

# Send a topic to the channel.
sub topic
{
	my ($svr, $chan, $topic) = @_;
	
	Auto::socksnd($svr, "TOPIC $chan :$topic");
	
	return 1;
}

# Kick a user.
sub kick
{
    my ($svr, $chan, $nick, $msg) = @_;

    Auto::socksnd($svr, "KICK $chan $nick :$msg");

    return 1;
}

# Quit IRC.
sub quit 
{
	my ($svr, $reason) = @_;
	
	if (defined $reason) {
		Auto::socksnd($svr, "QUIT :$reason");
	}
	else {
		Auto::socksnd($svr, "QUIT :Leaving");
	}
	
	delete $Parser::IRC::got_001{$svr} if (defined $Parser::IRC::got_001{$svr});
	delete $Parser::IRC::botnick{$svr} if (defined $Parser::IRC::botnick{$svr});
	
	return 1;
}


# Get nick, ident and host from a <nick>!<ident>@<host>
sub usrc
{
	my ($ex) = @_;
	
	my @si = split('!', $ex);
	my @sii = split('@', $si[1]);
	
	return (
		nick  => $si[0],
		user => $sii[0],
		host  => $sii[1]
	);
}

# Match two IRC masks.
sub match_mask
{
	my ($mu, $mh) = @_;
	
	# Prepare the regex.
	$mh =~ s/\./\\\./g;
	$mh =~ s/\?/\./g;
	$mh =~ s/\*/\.\*/g;
	$mh = '^'.$mh.'$';
	
	# Let's grep the user's mask.
	if (grep(/$mh/, $mu)) {
		return 1;
	}
	
	return 0;
}


1;
