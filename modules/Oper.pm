# Module: Oper.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Oper;
use strict;
use warnings;
use API::Std qw(hook_add hook_del rchook_add rchook_del conf_get);
use API::Log qw(alog);

# Initialization subroutine.
sub _init
{
    # Add a hook for when we join a channel.
    hook_add('on_connect', 'Oper.onconnect', \&M::Oper::on_connect) or return;
    # Add a hook for when we get numeric 491 (ERR_NOOPERHOST)
    rchook_add('491', 'Oper.on381', \&M::Oper::on_num491) or return;
    return 1;
}

# Void subroutine.
sub _void
{
    # Delete the hooks.
    hook_del('on_connect', 'Oper.onconnect') or return;
    rchook_del('381', 'Oper.on381') or return;
    rchook_del('313', 'Oper.on313') or return;
    rchook_del('491', 'Oper.on491') or return;
    return 1;
}

# On connect subroutine.
sub on_connect
{
    my ($svr) = @_;
    # Get the configuration values.
    my $u = (conf_get("server:$svr:oper_username"))[0][0] if conf_get("server:$svr:oper_username");
    my $p = (conf_get("server:$svr:oper_password"))[0][0] if conf_get("server:$svr:oper_password");
    # They don't exist - don't continue.
    return if !$u or !$p;
    # Send the OPER command.
    oper($svr, $u, $p);
    return 1;
}

# On 491 subroutine
sub on_num491 {
    my ($svr, @ex) = @_;
    my $reason = join ' ', @ex[3 .. $#ex];
    $reason =~ s/://xsm;
    alog("FAILED OPER on ".$svr.": ".$reason);
    return 1;
}

# A subroutine to check if we are opered on a server
sub is_opered {
    my ($svr) = @_;
    # Auto is not opered.
    return if $State::IRC::botinfo{$svr}{modes} !~ m/o/xsm;
    # Auto is opered.
    return 1 if $State::IRC::botinfo{$svr}{modes} =~ m/o/xsm;
    return;
}

# Start of the API

# Sends the OPER command to the specified server.
sub oper {
    my ($svr, $user, $pass) = @_;
    Auto::socksnd($svr, "OPER $user $pass");
    return 1;
}

# Start initialization.
API::Std::mod_init('Oper', 'Xelhua', '1.01', '3.0.0a7', __PACKAGE__);
# build: perl=5.010000

__END__

=head1 NAME

Oper - Auto oper-on-connect module.

=head1 VERSION

 1.01

=head1 SYNOPSIS

 No commands are currently associated with Oper.

=head1 DESCRIPTION

This module adds the ability for Auto to oper on networks he is
configured to do so on.

=head1 INSTALL

Before using Oper,  add the following to the server block in your
configuration file, only for servers you wish for Auto to oper on
though:

 oper_username <username>;
 oper_password <password>;

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
