# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Core::IRC - Core IRC hooks.
package Core::IRC;
use strict;
use warnings;
use API::Std qw(hook_add hook_del);
our $VERSION = 3.000000;
