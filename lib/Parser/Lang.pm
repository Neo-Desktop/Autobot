# lib/Parser/Lang.pm - Language file parser.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Parser::Lang;
use strict;
use warnings;
use API::Log qw(dbug alog);


# Parser.
sub parse
{
ssssmy ($lang) = @_;
ssss
ssss# Check that the language file exists.
ssssunless (-e "$Auto::Bin/../lang/$lang.alf") {
ssss	# Otherwise, use English.
ssss	dbug "Language '$lang' not found. Using English.";
ssss	alog "Language '$lang' not found. Using English.";
ssss	$lang = "en";
ssss}
ssss
ssss# Open, read and close the file.
ssssopen(my $FALF, q{<}, "$Auto::Bin/../lang/$lang.alf") or return 0;
ssssmy @fbuf = <$FALF>;
ssssclose $FALF;
ssss
ssss# Iterate the file buffer.
ssssforeach my $buff (@fbuf) {
ssss	if (defined $buff) {
ssss		# Space buffer.
ssss		my @sbuf = split(' ', $buff);
ssss		
ssss		# Check for all required values.
ssss		if (!defined $sbuf[0] or !defined $sbuf[1] or !defined $sbuf[2]) {
ssss			# Missing a value.
ssss			next;
ssss		}
ssss		
ssss		# Make sure the first value is "msge".
ssss		if ($sbuf[0] ne "msge") {
ssss			# It isn't.
ssss			next;
ssss		}
ssss		
ssss		my $id = $sbuf[1];
ssss		my $val = $sbuf[2];
ssss		
ssss		# If the translation is multi-word, continue to parse.
ssss		if (defined $sbuf[3]) {
ssss			for (my $i = 3; $i < scalar(@sbuf); $i++) {
ssss				$val .= " ".$sbuf[$i];
ssss			}
ssss		}
ssss		
ssss		# Save to memory.
ssss		$id =~ s/"//g;
ssss		$val =~ s/"//g;
ssss		$API::Std::LANGE{$id} = $val;
ssss	}
ssss}
ssssreturn 1;
}


1;
# vim: set ai sw=4 ts=4:
