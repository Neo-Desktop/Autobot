# lib/Core/IRC.pm - Core IRC hooks and timers.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Core::IRC;
use strict;
use warnings;
use English qw(-no_match_vars);
use API::Std qw(hook_add timer_add conf_get);
use API::IRC qw(notice usrc);

our (%usercmd);

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

# QUIT hook; delete user from chanusers.
hook_add("on_quit", "quit_update_chanusers", sub {
    my (($svr, $src, undef)) = @_;
    my %src = %{ $src };

    # Delete the user from all channels.
    foreach my $ccu (keys %{ $Parser::IRC::chanusers{$svr} }) {
        if (defined $Parser::IRC::chanusers{$svr}{$ccu}{$src{nick}}) { delete $Parser::IRC::chanusers{$svr}{$ccu}{$src{nick}}; }
    }

    return 1;
});

# Modes on connect.
hook_add("on_connect", "on_connect_modes", sub {
    my ($svr) = @_;

	if (conf_get("server:$svr:modes")) {
		my $connmodes = (conf_get("server:$svr:modes"))[0][0];
		API::IRC::umode($svr, $connmodes);
	}

    return 1;
});

# Plaintext auth.
hook_add("on_connect", "plaintext_auth", sub {
	my ($svr) = @_;
    
    if (conf_get("server:$svr:idstr")) {
		my $idstr = (conf_get("server:$svr:idstr"))[0][0];
		Auto::socksnd($svr, $idstr);
	}

    return 1;
});

# Auto join.
hook_add("on_connect", "autojoin", sub {
    my ($svr) = @_;

	# Get the auto-join from the config.
	my @cajoin = @{ (conf_get("server:$svr:ajoin"))[0] };
	
	# Join the channels.
	if (!defined $cajoin[1]) {
		# For single-line ajoins.
		my @sajoin = split(',', $cajoin[0]);
		
		API::IRC::cjoin($svr, $_) foreach (@sajoin);
	}
	else {
		# For multi-line ajoins.
		API::IRC::cjoin($svr, $_) foreach (@cajoin);
    }
    # And logchan, if applicable.
    if (conf_get('logchan')) {
        my ($lcn, $lcc) = split '/', (conf_get('logchan'))[0][0];
        if ($lcn eq $svr) {
            API::IRC::cjoin($svr, $lcc);
        }
    }

    return 1;
});

sub clear_usercmd_timer 
{
    # If ratelimit is set to 1 in config, add this timer.
    if ((conf_get('ratelimit'))[0][0] eq 1) {
        # Clear usercmd hash every X seconds.
        timer_add('clear_usercmd', 2, (conf_get('ratelimit_time'))[0][0], sub {
            foreach (keys %Core::IRC::usercmd) {
                $Core::IRC::usercmd{$_} = 0;
            }

            return 1;
        });
    }

    return 1;
}


1;
# vim: set ai sw=4 ts=4:
