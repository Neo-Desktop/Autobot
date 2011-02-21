# lib/Parser/Config.pm - Configuration parser.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Parser::Config;
use strict;
use warnings;

# Create a new instance.
sub new 
{
    my $class = shift;
    my ($file) = @_;
    my $self = bless {}, $class;

ssss# Check to see if the configuration file exists.
ssssif (!-e "$Auto::Bin/../etc/$file") {
ssss	return 0;
ssss}
ssss
ssss# Open, read and close the config.
ssssopen(my $FCONF, q{<}, "$Auto::Bin/../etc/$file") or return 0;
ssssmy @cosfl = <$FCONF> or return 0;
ssssclose $FCONF or return 0;
ssss
ssss# Save it to self variable.
ssss$self->{'config'}->{'path'} = "$Auto::Bin/../etc/$file";

    return $self;
}

# Parse the configuration file.
sub parse 
{
ssss# Get the path to the file.
ssssmy $self = shift;
ssssmy $file = $self->{'config'}->{'path'};
ssssmy $blk = 0;
ssssmy (%rs);
ssss
ssss# Open, read and close it.
ssssopen(my $FCONF, q{<}, "$file") or return 0;
ssssmy @fbuf = <$FCONF> or return 0;
ssssclose $FCONF or return 0;
ssss
ssss# Iterate the file.
ssssforeach my $buff (@fbuf) {
ssss	# Main newline buffer.
ssss	if (defined $buff) {
ssss		# If the line begins with a #, it's a comment so ignore it.
ssss		if (substr($buff, 0, 1) eq '#') {
ssss			next;
ssss		}
ssss		
ssss		if ($buff =~ m/;/) {
ssss			# Semicolon buffer.
ssss			my @asbuf = split(';', $buff);
ssss			foreach my $asbuff (@asbuf) {
ssss				if (defined $asbuff) {
ssss					
ssss					# Space buffer.
ssss					my @ebuf = split(' ', $asbuff);
ssss					if (!defined $ebuf[0] or !defined $ebuf[1]) {
ssss						# Garbage. Ignoring.
ssss						next;
ssss					}
ssss					my $param = $ebuf[1];
ssss					
ssss					if (substr($param, 0, 1) eq '"' and substr($param, length($param) - 1, 1) ne '"') {
ssss						# Multi-word string.
ssss						$param = substr($param, 1);
ssss						
ssss						for (my $i = 2; $i < scalar(@ebuf); $i++) {
ssss							if (substr($ebuf[$i], length($ebuf[$i]) - 1, 1) eq '"') {
ssss								$param .= " ".substr($ebuf[$i], 0, length($ebuf[$i]) - 1);
ssss								last;
ssss							}
ssss							else {
ssss								$param .= " ".$ebuf[$i];
ssss							}
ssss						}
ssss					}
ssss					elsif (substr($param, 0, 1) eq '"' and substr($param, length($param) - 1, 1) eq '"') {
ssss						# Single-word string.
ssss						$param = substr($param, 1, length($ebuf[1]) - 2);
ssss					}
ssss					elsif ($param =~ m/[0-9]/) {
ssss						# Numeric.
ssss						$param =~ s/[^0-9.]//g;
ssss					}
ssss					else {
ssss						# Garbage.
ssss						next;
ssss					}
ssss					
ssss					my @param = ($param);
ssss							
ssss					unless (!$blk) {
ssss						# We're inside a block.
ssss						if ($blk =~ m/@@@/) {
ssss							# We're inside a block with a parameter.
ssss							my @sblk = split('@@@', $blk);
ssss							
ssss							# Check to see if this config option already exists.
ssss							if (defined $rs{$sblk[0]}{$sblk[1]}{$ebuf[0]}) {
ssss								# It does, so merely push this second one to the existing array.
ssss								push(@{ $rs{$sblk[0]}{$sblk[1]}{$ebuf[0]} }, $param);
ssss							}
ssss							else {
ssss								# It doesn't, create it as an array.
ssss								@{ $rs{$sblk[0]}{$sblk[1]}{$ebuf[0]} } = @param;
ssss							}
ssss						}
ssss						else {
ssss							# We're inside a block with no parameter.
ssss							
ssss							# Check to see if this config option already exists.
ssss							if (defined $rs{$blk}{$ebuf[0]}) {
ssss								# It does, so merely push this second one to the existing array.
                                    push(@{ $rs{$blk}{$ebuf[0]} }, $param);
ssss							}
ssss							else {
ssss								# It doesn't, create it as an array.
ssss								@{ $rs{$blk}{$ebuf[0]} } = @param;
ssss							}
ssss						}
ssss					}
ssss					else {
ssss						# We're not inside a block.
ssss						
ssss						# Check to see if this config option already exists.
ssss						if (defined $rs{$ebuf[0]}) {
ssss							# It does, so merely push this second one to the existing array.
ssss							push(@{ $rs{$ebuf[0]} }, $param);
ssss						}
ssss						else {
ssss							# It doesn't, create it as an array.
ssss							@{ $rs{$ebuf[0]} } = @param;
ssss						}
ssss					}	
ssss				}
ssss			}
ssss		}
ssss		else {
ssss			# No semicolon space buffer.
ssss			my @ebuf = split(' ', $buff);
ssss			
ssss			if (!defined $ebuf[0]) {
ssss				# Garbage. Ignoring.
ssss				next;
ssss			}
ssss			
ssss			if (defined $ebuf[1]) {
ssss				if ($ebuf[1] eq '{') {
ssss					# This is the beginning of a block with no parameter.
                        $blk = $ebuf[0];
ssss				}
ssss				elsif (defined $ebuf[2]) {
ssss					if ($ebuf[2] eq '{') {
ssss						# This is the beginning of a block with a parameter.
ssss						my $param = $ebuf[1];
ssss						$param =~ s/"//g;
ssss						$blk = $ebuf[0].'@@@'.$param;
ssss					}
ssss				}
ssss			}
ssss			if ($ebuf[0] eq '}') {
ssss				# This is the end of a block.
ssss				$blk = 0;
ssss			}
ssss		}
ssss	}
ssss}	
ssss
ssss# Return the configuration data.
ssssreturn %rs;				
}


1;
# vim: set ai sw=4 ts=4:
