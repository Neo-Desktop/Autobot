# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Core IRC functionality.
package Core::IRC;
use strict;
use warnings;
use English;
use API::IRC qw(notice usrc);

sub version_reply
{
    my (($svr, @ex)) = @_;
    my %src = usrc(substr($ex[0], 1));

    if ($ex[3] eq ":\001VERSION\001") {
        notice($svr, $src{nick}, "VERSION ".Auto::NAME." ".Auto::VER.".".Auto::SVER.".".Auto::REV.Auto::RSTAGE." ".$OSNAME);
    }

    return 1;
}


1;
