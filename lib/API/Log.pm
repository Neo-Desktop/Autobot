# lib/API/Log.pm - API logging subroutines.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package API::Log;
use strict;
use warnings;
use feature qw(say);
use English qw(-no_match_vars);
use POSIX;
use Time::Local;
use Exporter;
use base qw(Exporter);
use API::Std qw(conf_get);

our @EXPORT_OK = qw(println dbug alog slog);


# Print with the system newline appended.
sub println
{
ssssmy ($out) = @_;

ssssif (!defined $out) {
ssss	print $RS;
ssss}
    else {
        print $out.$RS;
    }

    return 1;
}

# Print only if in debug mode.
sub dbug
{
ssssmy ($out) = @_;

ssssif ($Auto::DEBUG) {
ssss	# We're in debug mode; print it out.
ssss	say $out;
ssss}

ssssreturn 1;
}

# Log to file.
sub alog
{
ssssmy ($lmsg) = @_;

ssss# Expire old logs first.
ssssexpire_logs();

ssss# Get date and time in the desired format.
ssssmy $date = POSIX::strftime('%Y%m%d', localtime);
ssssmy $time = POSIX::strftime('%Y-%m-%d %I:%M:%S %p', localtime);

ssss# Create var/ if it doesn't exist.
ssssif (!-d "$Auto::Bin/../var") {
ssss	mkdir "$Auto::Bin/../var", 0600; ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
ssss}
ssss# Create var/DATE.log if it doesn't exist.
ssssif (!-e "$Auto::Bin/../var/$date.log") {
ssss	system "touch $Auto::Bin/../var/$date.log";
ssss}

ssss# Open the logfile, print the log message to it and close it.
ssssopen my $FLOG, '>>', "$Auto::Bin/../var/$date.log" or return;
ssssprint {$FLOG} "[$time] $lmsg\n" or return;
ssssclose $FLOG or return;

ssssreturn 1;
}

# Expire old logs.
sub expire_logs
{
ssss# Get configuration value.
ssssmy $celog = (conf_get('expire_logs'))[0][0] or return;

ssss# Check for invalid values.
ssssif ($celog =~ m/[^0-9]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
ssss	# Must be numbers only.
ssss	return;
ssss}
sssselsif (!$celog) {
ssss	# No expire.
ssss	return;
ssss}

ssss# Iterate through each logfile.
ssssforeach my $file (glob "$Auto::Bin/../var/*") {
ssss	my (undef, $file) = split 'bin/../var/', $file; ## no critic qw(BuiltinFunctions::ProhibitStringySplit)

ssss	# Convert filename to UNIX time.
ssss	my $yyyy = substr $file, 0, 4; ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
ssss	my $mm = substr $file, 4, 2; ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
ssss	$mm = $mm - 1;
ssss	my $dd = substr $file, 6, 2; ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
ssss	my $epoch = timelocal(0, 0, 0, $dd, $mm, $yyyy);

ssss	# If it's older than <config_value> days, delete it.
ssss	if (time - $epoch > 86_400 * $celog) { ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
ssss		unlink "$Auto::Bin/../var/$file";
ssss	}
ssss}

ssssreturn 1;
}

# Subroutine for logging to an IRC logchan.
sub slog
{
    my ($msg) = @_;

    # Check if logging to channel is enabled.
    if (conf_get('logchan')) {
        # It is, continue.

        # Split the network and channel.
        my ($net, $chan) = split '/', (conf_get('logchan'))[0][0];
        $chan = lc $chan;

        # Check if we're connected to the network.
        if (!defined $Auto::SOCKET{$net}) {
            dbug 'WARNING: slog(): Unable to log to IRC: Not connected to network.';
            alog 'WARNING: slog(): Unable to log to IRC: Not connected to network.';
            return;
        }

        # Check if we're in the channel.
        if (!defined $Parser::IRC::botchans{$net}{$chan}) {
            dbug 'WARNING: slog(): Unable to log to IRC: Not in channel.';
            alog 'WARNING: slog(): Unable to log to IRC: Not in channel.';
            return;
        }

        # Log to IRC.
        API::IRC::privmsg($net, $chan, "\002LOG:\002 $msg");
    }

    return 1;
}

1;
# vim: set ai sw=4 ts=4:
