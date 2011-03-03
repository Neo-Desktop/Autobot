# lib/Lib/Users.pm - Library for user tracking.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Lib::Users;
use strict;
use warnings;
use API::Std qw(hook_add);
our %users;

# Initialize the libusers_create and libusers_delete events.
API::Std::event_add('libusers_create');
API::Std::event_add('libusers_delete');

# Create the on_rcjoin hook.
hook_add('on_rcjoin', 'libusers.onjoin', sub {
    my ($src, $chan) = @_;

    # Add the user to the users hash, if not already defined.
    if (!$users{$src->{svr}}{lc $src->{nick}}) {
        $users{$src->{svr}}{lc $src->{nick}} = $src->{nick};
        API::Std::event_run('libusers_create', ($src->{svr}, $src->{nick}));
    }

    return 1;
});

# Create the on_namesreply hook.
hook_add('on_namesreply', 'libusers.names', sub {
    my ($svr, $chan, undef) = @_;

    # Iterate through the users for this channel.
    foreach (keys %{$Proto::IRC::chanusers{$svr}{$chan}}) {
        # Check if the user already exists.
        if (!$users{$svr}{$_}) {
            # They do not; WHO them.
            API::IRC::who($svr, $_);
        }
    }

    return 1;
});

# Create the on_whoreply hook.
hook_add('on_whoreply', 'libusers.who', sub {
    my ($svr, $nick, undef) = @_;

    # Ensure it is not us.
    if (lc $nick ne lc $Proto::IRC::botinfo{$svr}{nick}) {
        # It is not. Check if they're already in the users hash.
        if (!$users{$svr}{lc $nick}) {
            # They are not; add them.
            $users{$svr}{lc $nick} = $nick;
        }
    }

    return 1;
});

# Create the on_nick hook.
hook_add('on_nick', 'libusers.onnick', sub {
    my ($src, $newnick) = @_;

    # Modify the user's entry in the users hash.
    if ($users{$src->{svr}}{lc $src->{nick}}) {
        $users{$src->{svr}}{lc $newnick} = $newnick;
        delete $users{$src->{svr}}{lc $src->{nick}};
    }

    return 1;
});

# Create the on_kick hook.
hook_add('on_kick', 'libusers.onkick', sub {
    my ($src, $kchan, $user, undef) = @_;

    # Ensure there is a users hash entry for this user.
    if ($users{$src->{svr}}{lc $user}) {
        # Figure out if the user is in any other channel we're in.
        my $ri = 0;
        foreach my $chan (keys %{$Proto::IRC::chanusers{$src->{svr}}}) {
            if ($chan ne $kchan) {
                if (defined $Proto::IRC::chanusers{$src->{svr}}{$chan}{lc $user}) { $ri++; last; }
            }
        }
        if (!$ri) {
            # They are not, delete them.
            delete $users{$src->{svr}}{lc $user};
            API::Std::event_run('libusers_delete', ($src->{svr}, $user));
        }
    }

    return 1;
});

# Create the on_part hook.
hook_add('on_part', 'libusers.onpart', sub {
    my ($src, $pchan, undef) = @_;

    # Ensure there is a users hash entry for this user.
    if ($users{$src->{svr}}{lc $src->{nick}}) {
        # Figure out if the user is in any other channel we're in.
        my $ri = 0;
        foreach my $chan (keys %{$Proto::IRC::chanusers{$src->{svr}}}) {
            if ($chan ne $pchan) {
                if (defined $Proto::IRC::chanusers{$src->{svr}}{$chan}{lc $src->{nick}}) { $ri++; last; }
            }
        }
        if (!$ri) {
            # They are not, delete them.
            delete $users{$src->{svr}}{lc $src->{nick}};
            API::Std::event_run('libusers_delete', ($src->{svr}, $src->{nick}));
        }
    }

    return 1;
});

# Create the on_quit hook.
hook_add('on_quit', 'libusers.onquit', sub {
    my ($src, undef) = @_;

    # Delete the user's entry from the users hash.
    if ($users{$src->{svr}}{lc $src->{nick}}) {
        delete $users{$src->{svr}}{lc $src->{nick}};
    }

    return 1;
});


1;
# vim: set ai et sw=4 ts=4:
