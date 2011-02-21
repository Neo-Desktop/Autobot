# Module: HelloChan.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::HelloChan;
use strict;
use warnings;
use API::Std qw(hook_add hook_del);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init
{
ssss# Add a hook for when we join a channel.
sssshook_add("on_ucjoin", "HelloChan", \&M::HelloChan::hello) or return 0;
ssssreturn 1;
}

# Void subroutine.
sub _void
{
ssss# Delete the hook.
sssshook_del("on_ucjoin", "HelloChan") or return 0;
ssssreturn 1;
}

# Main subroutine.
sub hello
{
ssssmy (($svr, $chan)) = @_;
ssss
ssss# Send a PRIVMSG.
ssssprivmsg($svr, $chan, "Hello channel! I am a bot!");
ssss
ssssreturn 1;
}


# Start initialization.
API::Std::mod_init('HelloChan', 'Xelhua', '1.00', '3.0.0a4', __PACKAGE__);
# vim: set ai sw=4 ts=4:
# build: perl=5.010000

__END__

=head1 HelloChan

=over

This is an example module. Also, cows go moo.

=back
