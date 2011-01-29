# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_HelloChan;
use strict;
use warnings;
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init
{
	# Add a hook for when we join a channel.
	API::Std::hook_add("on_ucjoin", "HelloChan", \&m_HelloChan::hello) or return 0;
	return 1;
}

# Void subroutine.
sub _void
{
	# Delete the hook.
	API::Std::hook_del("on_ucjoin", "HelloChan") or return 0;
	return 1;
}

# Main subroutine.
sub hello
{
	my (($svr, $chan)) = @_;
	
	# Send a PRIVMSG.
	privmsg($svr, $chan, "Hello channel! I am a bot!");
	
	return 1;
}


# Start initialization.
API::Std::mod_init("HelloChan", "Xelhua", "0.1", "3.0.0d", __PACKAGE__);
