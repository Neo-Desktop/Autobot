# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# API logging subroutines.
package API::Log;
use strict;
use warnings;
use POSIX;
use Time::Local;
use Exporter;
use API::Std qw(conf_get);

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
	my ($out) = @_;
	
	if ($Auto::DEBUG) {
		# We're in debug mode; print it out.
		println $out;
	}
}

# Log to file.
sub alog
{
	my ($lmsg) = @_;
	
	# Expire old logs first.
	expire_logs();
	
	# Get date and time in the desired format.
	my $date = POSIX::strftime("%Y%m%d", localtime);
	my $time = POSIX::strftime("%Y-%m-%d %I:%M:%S %p", localtime);
	
	# Create var/ if it doesn't exist.
	unless (-d "$Auto::Bin/../var") {
		`mkdir $Auto::Bin/../var`;
	}
	# Create var/DATE.log if it doesn't exist.
	unless (-e "$Auto::Bin/../var/$date.log") {
		`touch $Auto::Bin/../var/$date.log`;
	}
	
	# Open the logfile, print the log message to it and close it.
	open LOG, ">>$Auto::Bin/../var/$date.log" or return 0;
	print LOG "[$time] $lmsg\n" or return 0;
	close LOG or return 0;
	
	return 1;
}

# Expire old logs.
sub expire_logs
{
	# Get configuration value.
	my $celog = (conf_get("expire_logs"))[0][0] or return 0;
	
	# Check for invalid values.
	if ($celog =~ m/[^0-9]/) {
		# Must be numbers only.
		return;
	}
	elsif (!$celog) {
		# No expire.
		return;
	}
	
	# Iterate through each logfile.
	foreach my $file (<$Auto::Bin/../var/*>) {
		my (undef, $file) = split('bin/../var/', $file);
		
		# Convert filename to UNIX time.
		my $yyyy = substr($file, 0, 4);
		my $mm = substr($file, 4, 2);
		my $dd = substr($file, 6, 2);
		my $epoch = timelocal(0, 0, 0, $dd, $mm, $yyyy);
		
		# If it's older than <config_value> days, delete it.
		if (time - $epoch > 86400 * $celog) {
			`rm $Auto::Bin/../var/$file`;
		}
	}
}

1;
