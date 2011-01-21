# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Subroutines for parsing incoming data from IRC.
package Parser::IRC;
use strict;
use warnings;
use API::Std qw(conf_get err awarn);
use API::IRC;

# Raw parsing hash.
our %RAWC = (
	'001'      => \&num001,
	'432'      => \&num432,
	'433'      => \&num433,
	'NICK'     => \&nick,
);

# Variables for various functions.
our (%got_001, %botnick);

# Parse raw data.
sub _parse
{
	my ($svr, $data) = @_;
	
	# Split spaces into @ex.
	my @ex = split(' ', $data);
	
	# Make sure there is enough data.
	if (defined $ex[0] and defined $ex[1]) {
		# If it's a ping...
		if ($ex[0] eq 'PING') {
			# send a PONG.
			Auto::socksnd($svr, "PONG ".$ex[1]);
		}
		else {
			# otherwise, check %RAWC for ex[1].
			if (defined $RAWC{$ex[1]}) {
				&{ $RAWC{$ex[1]} }($svr, @ex);
			}
		}
	}
}

###########################
# Raw parsing subroutines #
###########################

# Parse: Numeric:001
# Successful connection.
sub num001
{
	my ($svr, @ex) = @_;
	
	$got_001{$svr} = 1;
	
	# Identify string.
	unless (!conf_get("server:$svr:idstr")) {
		my $idstr = (conf_get("server:$svr:idstr"))[0][0];
		Auto::socksnd($svr, $idstr);
	}
	
	# Get the auto-join from the config.
	my @cajoin = @{ (conf_get("server:$svr:ajoin"))[0] };
	
	# Join the channels.
	unless (defined $cajoin[1]) {
		# For single-line ajoins.
		my @sajoin = split(',', $cajoin[0]);
		
		API::IRC::cjoin($svr, $_) foreach (@sajoin);
	}
	else {
		# For multi-line ajoins.
		API::IRC::cjoin($svr, $_) foreach (@cajoin);
	}
}

# Parse: Numeric:432
# Erroneous nickname.
sub num432
{
	my ($svr, undef) = @_;
	
	if ($got_001{$svr}) {
		err(3, "Got error from server[".$svr."]: Erroneous nickname.", 0);
	}
	else {
		err(2, "Got error from server[".$svr."] before 001: Erroneous nickname. Closing connection.", 0);
		API::IRC::quit($svr, "An error occurred.");
	}
}

# Parse: Numeric:433
# Nickname is already in use.
sub num433
{
	my ($svr, undef) = @_;
	
	if (defined $botnick{$svr}) {
		API::IRC::nick($svr, $botnick{$svr}."_");
	}
}

# Parse: NICK
sub nick
{
	my ($svr, @ex) = @_;
	
	my %src = API::IRC::usrc(substr($ex[0], 1));
	
	# Check if this is coming from ourselves, meaning a forced nick change.
	if ($src{nick} eq $botnick{$svr}) {
		# It is a forced nick change.
		awarn(3, "Incoming NICK from myself?");
		$botnick{$svr} = $ex[2];
	}	
}

1;
