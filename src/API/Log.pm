# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
use strict;
use warnings;
use POSIX qw(strftime);
use Exporter;
use API::Std qw(conf_get);

# API logging subroutines.
package API::Log;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(println dbug alog);


# Print with the system newline appended.
sub println
{
	my ($out) = @_;
	
	my ($nl);
	if ($^O =~ /dos/i or $^O =~ /win/i or $^O =~ /netware/i) {
		$nl = "\r\n";
	}
	elsif ($^O =~ /linux/i or $^O =~ /bsd/i) {
		$nl = "\n";
	}
	elsif ($^O =~ /mac/i or $^O =~ /darwin/i) {
		$nl = "\r";
	}
	else {
		$nl = "\r\n";
	}
	
	print $out.$nl;
	
	return 1;
}

# Print only if in debug mode.
sub dbug
{
	
}

# Log to file.
sub alog
{
	my ($lmsg) = @_;
	
	my @celog = conf_get("expire_logs");
	
	return 1;
}


1;
