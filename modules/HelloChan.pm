# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_HelloChan;
use strict;
use warnings;
use API::Std qw(hook_add hook_del);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init
{
	# Add a hook for when we join a channel.
	hook_add("on_rcjoin", "HelloChan", \&m_HelloChan::hello) or return 0;
	return 1;
}

# Void subroutine.
sub _void
{
	# Delete the hook.
	hook_del("on_rcjoin", "HelloChan") or return 0;
	return 1;
}

# Main subroutine.
sub hello
{
	my (($svr, %src, $chan)) = @_;
	
	# Send a PRIVMSG.
	privmsg($svr, $chan, "Hello ".$src{nick});
	
	return 1;
}


# Start initialization.
API::Std::mod_init("HelloChan", "Xelhua", "1.00", "3.0.0d", __PACKAGE__);
# vim: set ai sw=4 ts=4:
# build: perl=5.010000
