# Module: BotStats. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::BotStats;
use strict;
use warnings;
use English qw(-no_match_vars);
use API::Std qw(cmd_add cmd_del);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
    # Create the STATS command.
    cmd_add('STATS', 2, 0, \%M::BotStats::HELP_STATS, \&M::BotStats::stats) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the STATS command.
    cmd_del('STATS') or return;

    # Success.
    return 1;
}

# Help hash for STATS. Spanish, German and French translations needed.
our %HELP_STATS = (
    'en' => "This command will return information about the bot (uptime, version, etc.). \2Syntax:\2 STATS",
);

# Callback for STATS command.
sub stats {
    my ($src, undef) = @_;

    # Check if this was private or public.
    my $target;
    if ($src->{chan}) {
        $target = $src->{chan};
    }
    else {
        $target = $src->{nick};
    }

    # Get uptime data.
    my $uptime = time - $Auto::STARTTIME;
    my $days = my $hours = my $mins = my $secs = 0;
    while ($uptime >= 86_400) { $days++; $uptime -= 86_400; }
    while ($uptime >= 3_600) { $hours++; $uptime -= 3_600; }
    while ($uptime >= 60) { $mins++; $uptime -= 60; }
    while ($uptime >= 1) { $secs++; $uptime--; }

    # Return it.
    privmsg($src->{svr}, $target, "I have been running for \2$days\2 days, \2$hours\2 hours, \2$mins\2 minutes, and \2$secs\2 seconds.");

    # Return version data.
    privmsg($src->{svr}, $target, 'I am running '.Auto::NAME.' (version '.Auto::VER.q{.}.Auto::SVER.q{.}.Auto::REV.Auto::RSTAGE.") for Perl $PERL_VERSION on $OSNAME.");

    # Get network and channel data.
    my $nets = keys %Auto::SOCKET;
    my $chans;
    foreach my $net (keys %Auto::SOCKET) {
        foreach (keys %{$Proto::IRC::botchans{$net}}) { $chans++; }
    }

    # Return network/channel data.
    privmsg($src->{svr}, $target, "I am on \2$chans\2 channels, across \2$nets\2 networks.");

    return 1;
}


API::Std::mod_init('BotStats', 'Xelhua', '1.00', '3.0.0a6', __PACKAGE__);
# vim: set ai et sw=4 ts=4:
# build: perl=5.010000

__END__

=head1 NAME

BotStats - General information about the bot

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <starcoder> !stats
 <blue> I have been running for 0 days, 0 hours, 1 minutes, and 5 seconds.
 <blue> I am running Auto IRC Bot (version 3.0.0a6) for Perl v5.12.3 on linux.
 <blue> I am on 2 channels, across 1 networks.

=head1 DESCRIPTION

This module creates the STATS command, for returning general information about
the bot such as uptime, version, etc.

This module is compatible with Auto v3.0.0a6+.

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

This module is released under the same licensing terms as Auto itself.

=cut
