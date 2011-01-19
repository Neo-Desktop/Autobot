# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Subroutines for parsing incoming data from IRC.
package Parser::IRC;
use strict;
use warnings;
use API::Std qw(conf_get);
use API::IRC qw(cjoin);

# Raw parsing hash.
our %RAWC = (
	'001' => \&num001,
);

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
sub num001
{
	my ($svr, @ex) = @_;
	
	# Get the auto-join from the config.
	my @cajoin = @{ (conf_get("server:$svr:ajoin"))[0] };
	
	# Join the channels.
	unless (defined $cajoin[1]) {
		# For single-line ajoins.
		my @sajoin = split(',', $cajoin[0]);
		
		foreach my $sjoin (@sajoin) {
			cjoin($svr, $sjoin);
		}
	}
	else {
		# For multi-line ajoins.
		foreach my $sjoin (@cajoin) {
			cjoin($svr, $sjoin);
		}
	}
}

1;
