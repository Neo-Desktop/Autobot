# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Configuration parser.
package Parser::Config;
use strict;
use warnings;

# Create a new instance.
# Funny how we still haven't taken advantage of Mouse/Moose yet.
sub new 
{
    my $class = shift;
    my ($file) = @_;
    my $self = bless {}, $class;

	# Check to see if the configuration file exists.
	if (!-e "$Auto::Bin/../etc/$file") {
		return 0;
	}
	
	# Open, read and close the config.
	open CONF, "<$Auto::Bin/../etc/$file" or return 0;
	my @cosfl = <CONF> or return 0;
	close CONF or return 0;
	
	# Save it to self variable.
	$self->{'config'}->{'path'} = "$Auto::Bin/../etc/$file";

    return $self;
}

# Parse the configuration file.
sub parse 
{
	# Get the path to the file.
	my $self = shift;
	my $file = $self->{'config'}->{'path'};
	my $blk = 0;
	my (%rs);
	
	# Open, read and close it.
	open CONF, "<$file" or return 0;
	my @fbuf = <CONF> or return 0;
	close CONF or return 0;
	
	# Iterate the file.
	foreach my $buff (@fbuf) {
		# Main newline buffer.
		if (defined $buff) {
			# If the line begins with a #, it's a comment so ignore it.
			if (substr($buff, 0, 1) eq '#') {
				next;
			}
			
			if ($buff =~ m/;/) {
				# Semicolon buffer.
				my @asbuf = split(';', $buff);
				foreach my $asbuff (@asbuf) {
					if (defined $asbuff) {
						
						# Space buffer.
						my @ebuf = split(' ', $asbuff);
						if (!defined $ebuf[0] or !defined $ebuf[1]) {
							# Garbage. Ignoring.
							next;
						}
						my $param = $ebuf[1];
						
						if (substr($param, 0, 1) eq '"' and substr($param, length($param) - 1, 1) ne '"') {
							# Multi-word string.
							$param = substr($param, 1);
							
							for (my $i = 2; $i < scalar(@ebuf); $i++) {
								if (substr($ebuf[$i], length($ebuf[$i]) - 1, 1) eq '"') {
									$param .= " ".substr($ebuf[$i], 0, length($ebuf[$i]) - 1);
									last;
								}
								else {
									$param .= " ".$ebuf[$i];
								}
							}
						}
						elsif (substr($param, 0, 1) eq '"' and substr($param, length($param) - 1, 1) eq '"') {
							# Single-word string.
							$param = substr($param, 1, length($ebuf[1]) - 2);
						}
						elsif ($param =~ m/[0-9]/) {
							# Numeric.
							$param =~ s/[^0-9.]//g;
						}
						else {
							# Garbage.
							next;
						}
						
						my @param = ($param);
								
						unless (!$blk) {
							# We're inside a block.
							if ($blk =~ m/@@@/) {
								# We're inside a block with a parameter.
								my @sblk = split('@@@', $blk);
								
								# Check to see if this config option already exists.
								# Whose great idea was it to tab over this far? It screws with vim. :/
								if (defined $rs{$sblk[0]}{$sblk[1]}{$ebuf[0]}) {
									# It does, so merely push this second one to the existing array.
									push(@{ $rs{$sblk[0]}{$sblk[1]}{$ebuf[0]} }, $param);
								}
								else {
									# It doesn't, create it as an array.
									@{ $rs{$sblk[0]}{$sblk[1]}{$ebuf[0]} } = @param;
								}
							}
							else {
								# We're inside a block with no parameter.
								$rs{$blk}{$ebuf[0]} = $ebuf[1];
								
								# Check to see if this config option already exists.
								if (defined $rs{$blk}{$ebuf[0]}) {
									# It does, so merely push this second one to the existing array.
									push(@{ $rs{$blk}{$ebuf[0]} }, $param);
								}
								else {
									# It doesn't, create it as an array.
									@{ $rs{$blk}{$ebuf[0]} } = @param;
								}
							}
						}
						else {
							# We're not inside a block.
							
							# Check to see if this config option already exists.
							if (defined $rs{$ebuf[0]}) {
								# It does, so merely push this second one to the existing array.
								push(@{ $rs{$ebuf[0]} }, $param);
							}
							else {
								# It doesn't, create it as an array.
								@{ $rs{$ebuf[0]} } = @param;
							}
						}	
					}
				}
			}
			else {
				# No semicolon space buffer.
				my @ebuf = split(' ', $buff);
				
				if (!defined $ebuf[0]) {
					# Garbage. Ignoring.
					next;
				}
				
				if (defined $ebuf[1]) {
					if ($ebuf[1] eq '{') {
						# This is the beginning of a block with no parameter.
						$blk = $ebuf[0];
					}
					elsif (defined $ebuf[2]) {
						if ($ebuf[2] eq '{') {
							# This is the beginning of a block with a parameter.
							my $param = $ebuf[1];
							$param =~ s/"//g;
							$blk = $ebuf[0].'@@@'.$param;
						}
					}
				}
				if ($ebuf[0] eq '}') {
					# This is the end of a block.
					$blk = 0;
				}
			}
		}
	}	
	
	# Return the configuration data.
	return %rs;				
}

1;
