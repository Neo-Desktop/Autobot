# lib/State/IRC.pm - IRC state data.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package State::IRC;
use strict;
use warnings;
use API::Std qw(hook_add);
our (%chanusers, %botinfo);

# Create on_namesreply hook.
hook_add('on_namesreply', 'state.irc.names', sub {
    my ($svr, $chan, @data) = @_;
    $chan = lc $chan;

    # Delete the old chanusers hash if it exists.
    if (defined $chanusers{$svr}{$chan}) { delete $chanusers{$svr}{$chan} }
    # Iterate through each user.
    for (1..$#data) {
        my $fi = 0;
        PFITER: foreach my $spfx (keys %{ $Proto::IRC::csprefix{$svr} }) {
            # Check if the user has status in the channel.
            if (substr($data[$_], 0, 1) eq $Proto::IRC::csprefix{$svr}{$spfx}) {
                # He/she does. Lets set that.
                if (defined $chanusers{$svr}{$chan}{lc $data[$_]}) {
                    # If the user has multiple statuses.
                    $chanusers{$svr}{$chan}{lc substr $data[$_], 1} = $chanusers{$svr}{$chan}{lc $data[$_]}.$spfx;
                    delete $chanusers{$svr}{$chan}{lc $data[$_]};
                }
                else {
                    # Or not.
                    $chanusers{$svr}{$chan}{lc substr $data[$_], 1} = $spfx;
                }
                $fi = 1;
                $data[$_] = substr $data[$_], 1;
            }
        }
        # Check if there's still a prefix.
        foreach my $spfx (keys %{$Proto::IRC::csprefix{$svr}}) {
            if (substr($data[$_], 0, 1) eq $Proto::IRC::csprefix{$svr}{$spfx}) { goto 'PFITER' }
        }
        # They had status, so go to the next user.
        next if $fi;
        # They didn't, set them as a normal user.
        if (!defined $chanusers{$svr}{$chan}{lc $data[$_]}) {
            $chanusers{$svr}{$chan}{lc $data[$_]} = 1;
        }
    }

    return 1;
});
