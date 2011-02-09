# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Core::IRC - Core IRC hooks.
package Core::IRC;
use strict;
use warnings;
use English qw(-no_match_vars);
use API::Std qw(hook_add hook_del);
use API::IRC qw(notice usrc);
our $VERSION = 3.000000;

# CTCP VERSION reply.
hook_add("on_uprivmsg", "ctcp_version_reply", sub {
    my (($svr, @ex)) = @_;
    my %src = usrc(substr($ex[0], 1));

    if ($ex[3] eq ":\001VERSION\001") {
        if (Auto::RSTAGE ne 'd') {
            notice($svr, $src{nick}, "\001VERSION ".Auto::NAME." ".Auto::VER.".".Auto::SVER.".".Auto::REV.Auto::RSTAGE." ".$OSNAME."\001");
        }
        else {
            notice($svr, $src{nick}, "\001VERSION ".Auto::NAME." ".Auto::VER.".".Auto::SVER.".".Auto::REV.Auto::RSTAGE."-".Auto::GR." ".$OSNAME."\001");
        }
    }

    return 1;
});
