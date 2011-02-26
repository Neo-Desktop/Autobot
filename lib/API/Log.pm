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
    my ($out) = @_;

    if (!defined $out) {
    	print $RS;
    }
    else {
        print $out.$RS;
    }

    return 1;
}

# Print only if in debug mode.
sub dbug
{
    my ($out) = @_;

    if ($Auto::DEBUG) {
    	# We're in debug mode; print it out.
    	say $out;
    }

    return 1;
}

# Log to file.
sub alog
{
    my ($lmsg) = @_;

    # Expire old logs first.
    expire_logs();

    # Get date and time in the desired format.
    my $date = POSIX::strftime('%Y%m%d', localtime);
    my $time = POSIX::strftime('%Y-%m-%d %I:%M:%S %p', localtime);

    # Create var/ if it doesn't exist.
    if (!-d "$Auto::Bin/../var") {
    	mkdir "$Auto::Bin/../var", 0600; ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
    }
    # Create var/DATE.log if it doesn't exist.
    if (!-e "$Auto::Bin/../var/$date.log") {
    	system "touch $Auto::Bin/../var/$date.log";
    }

    # Open the logfile, print the log message to it and close it.
    open my $FLOG, '>>', "$Auto::Bin/../var/$date.log" or return;
    print {$FLOG} "[$time] $lmsg\n" or return;
    close $FLOG or return;

    return 1;
}

# Expire old logs.
sub expire_logs
{
    # Get configuration value.
    my $celog = (conf_get('expire_logs'))[0][0] or return;

    # Check for invalid values.
    if ($celog =~ m/[^0-9]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
    	# Must be numbers only.
    	return;
    }
    elsif (!$celog) {
    	# No expire.
    	return;
    }

    # Iterate through each logfile.
    foreach my $file (glob "$Auto::Bin/../var/*") {
    	my (undef, $file) = split 'bin/../var/', $file; ## no critic qw(BuiltinFunctions::ProhibitStringySplit)

    	# Convert filename to UNIX time.
    	my $yyyy = substr $file, 0, 4; ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
    	my $mm = substr $file, 4, 2; ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
    	$mm = $mm - 1;
    	my $dd = substr $file, 6, 2; ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
    	my $epoch = timelocal(0, 0, 0, $dd, $mm, $yyyy);

    	# If it's older than <config_value> days, delete it.
    	if (time - $epoch > 86_400 * $celog) { ## no critic qw(ValuesAndExpressions::ProhibitMagicNumbers)
    		unlink "$Auto::Bin/../var/$file";
    	}
    }

    return 1;
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
        if (!defined $Proto::IRC::botchans{$net}{$chan}) {
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
# vim: set ai et sw=4 ts=4:
