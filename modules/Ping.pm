# Module: Ping. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Ping;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del hook_add hook_del rchook_add rchook_del);
use API::IRC qw(privmsg notice who);
my (@PING, $STATE);
my $LAST = 0;

# Initialization subroutine.
sub _init {
    # Create the PING command.
    cmd_add('PING', 0, 'cmd.ping', \%M::Ping::HELP_PING, \&M::Ping::cmd_ping) or return;
    # Create the on_whoreply hook.
    hook_add('on_whoreply', 'ping.who', \&M::Ping::on_whoreply) or return;
    # Hook onto numeric 315.
    rchook_add('315', 'ping.eow', \&M::Ping::ping) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the PING command.
    cmd_del('PING') or return;
    # Delete the on_whoreply hook.
    hook_del('on_whoreply', 'ping.who') or return;
    # Delete 315 hook.
    rchook_del('315', 'ping.eow') or return;

    # Success.
    return 1;
}

# Help for PING.
our %HELP_PING = (
    en => "This command will ping all non-/away users in the channel. \2Syntax:\2 PING",
);

# Callback for PING command.
sub cmd_ping {
    my ($src, @argv) = @_;

    # Check ratelimit (once every five minutes).
    if ((time - $LAST) < 300) {
        notice($src->{svr}, $src->{nick}, 'This command is ratelimited. Please wait a while before using it again.');
        return;
    }

    # Set last used time to current time.
    $LAST = time;
    # Set state.
    $STATE = $src->{svr}.'::'.$src->{chan};

    # Ship off a WHO.
    who($src->{svr}, $src->{chan});

    return 1;
}

# Callback for WHO reply.
sub on_whoreply {
    my ($svr, $nick, $target, undef, undef, undef, $status, undef, undef) = @_;
    
    # If it's us, just return.
    if ($nick eq $State::IRC::botinfo{$svr}{nick}) { return 1 }

    # Check if we're doing a ping right now.
    if ($STATE) {
        # Check if this is the target channel.
        if ($STATE eq $svr.'::'.$target) {
            # If their status is not away, push to ping array.
            if ($status !~ m/G/xsm) {
                push @PING, $nick;
            }
        }
    }

    return 1;
}

# Ping!
sub ping {
    if ($STATE) {
        my ($svr, $chan) = split '::', $STATE, 2;
        privmsg($svr, $chan, 'PING! '.join(' ', @PING));
        @PING = ();
        $STATE = 0;
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('Ping', 'Xelhua', '1.01', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

 Ping - A module for pinging a channel.

=head1 VERSION

 1.01

=head1 SYNOPSIS

 <Hermione> .ping   
 <howlbot> PING! `A` tdubellz Hermione Oakfeather LightToagac shadowm_goat kitten starcoder2 Suiseiseki metabill theknife Trashlord Cam HardDisk_WP nerdshark2 MJ94 JonathanD Julius2 CensoredBiscuit LordVoldemort e36freak alyx mth starcoder

=head1 DESCRIPTION

This merely creates the PING command, which will highlight everyone in the
channel, excluding the bot itself and those who are /away.

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:
