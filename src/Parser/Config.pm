# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package Parser::Config;
use strict;
use warnings;

sub new 
{
    my $class = shift;
    my ($file) = @_;
    my $self = bless {}, $class;

	if (!-e "$Auto::Bin/../etc/$file") {
		return 0;
	}
	
	open CONF, "<$Auto::Bin/../etc/$file" or return 0;
	my @cosfl = <CONF> or return 0;
	close CONF or return 0;
	
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
						$param =~ s/"//g;
						my @param = ($param);
							
						unless ($blk eq 0) {
							if ($blk =~ m/@@@/) {
								my @sblk = split('@@@', $blk);
								
								if (defined $rs{c}{$sblk[0]}{$sblk[1]}{$ebuf[0]}) {
									push(@{ $rs{c}{$sblk[0]}{$sblk[1]}{$ebuf[0]} }, $param);
								}
								else {
									@{ $rs{c}{$sblk[0]}{$sblk[1]}{$ebuf[0]} } = @param;
								}
							}
							else {
								$rs{c}{$blk}{$ebuf[0]} = $ebuf[1];
								
								if (defined $rs{c}{$blk}{$ebuf[0]}) {
									push(@{ $rs{c}{$blk}{$ebuf[0]} }, $param);
								}
								else {
									@{ $rs{c}{$blk}{$ebuf[0]} } = @param;
								}
							}
						}
						else {
							if (defined $rs{c}{$ebuf[0]}) {
								push(@{ $rs{c}{$ebuf[0]} }, $param);
							}
							else {
								@{ $rs{c}{$ebuf[0]} } = @param;
							}
						}	
					}
				}
			}
			else {
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
					$blk = 0;
				}
			}
		}
	}	
	return %rs;				
}

1;
