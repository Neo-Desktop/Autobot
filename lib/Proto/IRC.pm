# lib/Proto/IRC.pm - Subroutines for parsing incoming data from IRC.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Proto::IRC;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(conf_get err awarn trans);
use API::IRC;

# Raw parsing hash.
our %RAWC = (
    '001'      => \&num001,
    '004'      => \&num004,
    '005'      => \&num005,
    '352'      => \&num352,
    '353'      => \&num353,
    '396'      => \&num396,
    '432'      => \&num432,
    '433'      => \&num433,
    '438'      => \&num438,
    '465'      => \&num465,
    '471'      => \&num471,
    '473'      => \&num473,
    '474'      => \&num474,
    '475'      => \&num475,
    '477'      => \&num477,
    'CAP'      => \&cap,
    'JOIN'     => \&cjoin,
    'KICK'     => \&kick,
    'MODE'     => \&mode,
    'NICK'     => \&nick,
    'NOTICE'   => \&notice,
    'PART'     => \&part,
    'PRIVMSG'  => \&privmsg,
    'QUIT'     => \&quit,
    'TOPIC'    => \&topic,
);

# Variables for various functions.
our (%got_001, %botinfo, %botchans, %csprefix, %chanusers, %chanmodes, %cap);

# Events.
API::Std::event_add('on_capack');
API::Std::event_add('on_cmode');
API::Std::event_add('on_umode');
API::Std::event_add('on_connect');
API::Std::event_add('on_rcjoin');
API::Std::event_add('on_ucjoin');
API::Std::event_add('on_isupport');
API::Std::event_add('on_kick');
API::Std::event_add('on_myinfo');
API::Std::event_add('on_namesreply');
API::Std::event_add('on_nick');
API::Std::event_add('on_notice');
API::Std::event_add('on_part');
API::Std::event_add('on_upart');
API::Std::event_add('on_cprivmsg');
API::Std::event_add('on_uprivmsg');
API::Std::event_add('on_quit');
API::Std::event_add('on_topic');
API::Std::event_add('on_whoreply');

# Parse raw data.
sub ircparse
{
    my ($svr, $data) = @_;

    # Split spaces into @ex.
    my @ex = split /\s+/, $data;

    # Make sure there is enough data.
    if (defined $ex[0] and defined $ex[1]) {
    	# If it's a ping...
    	if ($ex[0] eq 'PING') {
    		# send a PONG.
    		Auto::socksnd($svr, "PONG $ex[1]");
    	}
    	# If it's AUTHENTICATE
    	elsif ($ex[0] eq 'AUTHENTICATE') {
    		if (API::Std::mod_exists('SASLAuth')) {
                M::SASLAuth::handle_authenticate($svr, @ex);
    		}
    	}
        # Check if it's handled by core.
        elsif (defined $RAWC{$ex[1]}) {
            &{ $RAWC{$ex[1]} }($svr, @ex);
        }
    	else {
    		# otherwise, check for a raw hook.
    		if (defined $API::Std::RAWHOOKS{$ex[1]}) {
    			foreach (keys %{$API::Std::RAWHOOKS{$ex[1]}}) {
                    &{ $API::Std::RAWHOOKS{$ex[1]}{$_} }($svr, @ex);
                }
    		}
    	}
    }

    return 1;
}

###########################
# Raw parsing subroutines #
###########################

# Parse: Numeric:001
# Successful connection.
sub num001 {
    my ($svr, @ex) = @_;

    $got_001{$svr} = 1;

    # In case we don't get NICK from the server.
    if (!defined $botinfo{$svr}{nick}) {
    	$botinfo{$svr}{nick} = $botinfo{$svr}{newnick};
    	delete $botinfo{$svr}{newnick};
    }

    # Log.
    API::Log::alog "! Successfully connected to $svr as $botinfo{$svr}{nick}";
    API::Log::dbug "! Successfully connected to $svr as $botinfo{$svr}{nick}";

    # Trigger on_connect.
    API::Std::event_run('on_connect', $svr);

    return 1;
}

# Parse: Numeric:004
# Server information.
sub num004 {
    my ($svr, @ex) = @_;

    # Log server name and version.
    API::Log::alog "! $svr: $ex[3] running version $ex[4]";
    API::Log::dbug "! $svr: $ex[3] running version $ex[4]";

    # Trigger on_myinfo.
    API::Std::event_run('on_myinfo', ($svr, @ex[3..$#ex]));

    return 1;
}

# Parse: Numeric:005
# Server ISUPPORT.
sub num005 {
    my ($svr, @ex) = @_;

    # Trigger on_isupport.
    API::Std::event_run('on_isupport', ($svr, @ex[3..$#ex]));

    return 1;
}

# Parse: Numeric:352
# WHO reply.
sub num352 {
    my ($svr, @ex) = @_;

    # Trigger on_whoreply.
    $ex[9] =~ s/^://xsm;
    API::Std::event_run('on_whoreply', ($svr, $ex[7], $ex[3], $ex[4], $ex[5], $ex[6], $ex[8], $ex[9], @ex[10..$#ex]));

    return 1;
}

# Parse: Numeric:353
# NAMES reply.
sub num353 {
    my ($svr, @ex) = @_;

    # Get rid of the colon.
    $ex[5] =~ s/^://xsm;
    # Delete the old chanusers hash if it exists.
    if (defined $chanusers{$svr}{$ex[4]}) { delete $chanusers{$svr}{$ex[4]} }
    # Iterate through each user.
    for (5..$#ex) {
    	my $fi = 0;
        PFITER: foreach my $spfx (keys %{ $csprefix{$svr} }) {
    		# Check if the user has status in the channel.
    		if (substr($ex[$_], 0, 1) eq $csprefix{$svr}{$spfx}) {
    			# He/she does. Lets set that.
    			if (defined $chanusers{$svr}{$ex[4]}{lc $ex[$_]}) {
    				# If the user has multiple statuses.
    				$chanusers{$svr}{$ex[4]}{lc substr $ex[$_], 1} = $chanusers{$svr}{$ex[4]}{lc $ex[$_]}.$spfx;
                    delete $chanusers{$svr}{$ex[4]}{lc $ex[$_]};
    			}
    			else {
    				# Or not.
    				$chanusers{$svr}{$ex[4]}{lc substr $ex[$_], 1} = $spfx;
    			}
    			$fi = 1;
                $ex[$_] = substr $ex[$_], 1;
    		}
    	}
        # Check if there's still a prefix.
        foreach my $spfx (keys %{$csprefix{$svr}}) {
            if (substr($ex[$_], 0, 1) eq $csprefix{$svr}{$spfx}) { goto 'PFITER' }
        }
    	# They had status, so go to the next user.
    	next if $fi;
    	# They didn't, set them as a normal user.
    	if (!defined $chanusers{$svr}{$ex[4]}{lc $ex[$_]}) {
    		$chanusers{$svr}{$ex[4]}{lc $ex[$_]} = 1;
    	}
    }

    # Trigger on_namesreply.
    API::Std::event_run('on_namesreply', ($svr, $ex[4], @ex[5..$#ex]));

    return 1;
}

# Parse: Numeric:396
# Hidden host changed.
sub num396 {
    my ($svr, @ex) = @_;

    # Update our mask.
    $botinfo{$svr}{mask} = $ex[3];

    return 1;
}

# Parse: Numeric:432
# Erroneous nickname.
sub num432 {
    my ($svr, undef) = @_;

    if ($got_001{$svr}) {
    	err(3, "Got error from server[$svr]: Erroneous nickname.", 0);
    }
    else {
    	err(2, "Got error from server[$svr] before connection complete: Erroneous nickname. Closing connection.", 0);
    	API::IRC::quit($svr, 'An error occurred.');
    }

    if (defined $botinfo{$svr}{newnick}) { delete $botinfo{$svr}{newnick} }

    return 1;
}

# Parse: Numeric:433
# Nickname is already in use.
sub num433 {
    my ($svr, undef) = @_;

    if (defined $botinfo{$svr}{newnick}) {
    	API::IRC::nick($svr, $botinfo{$svr}{newnick}.'_');
    }

    return 1;
}

# Parse: Numeric:438
# Nick change too fast.
sub num438 {
    my ($svr, @ex) = @_;

    if (defined $botinfo{$svr}{newnick}) {
    	API::Std::timer_add('num438_'.$botinfo{$svr}{newnick}, 1, $ex[11], sub {
    		API::IRC::nick($Proto::IRC::botinfo{$svr}{newnick});
    		if (defined $botinfo{$svr}{newnick}) { delete $botinfo{$svr}{newnick} }
    	 });
    }

    return 1;
}

# Parse: Numeric:465
# You're banned creep!
sub num465 {
    my ($svr, undef) = @_;

    err(3, "Banned from $svr.! Closing link...", 0);

    return 1;
}

# Parse: Numeric:471
# Cannot join channel: Channel is full.
sub num471 {
    my ($svr, (undef, undef, undef, $chan)) = @_;

    err(3, "Cannot join channel $chan on $svr: Channel is full.", 0);

    return 1;
}

# Parse: Numeric:473
# Cannot join channel: Channel is invite-only.
sub num473 {
    my ($svr, (undef, undef, undef, $chan)) = @_;

    err(3, "Cannot join channel $chan on $svr: Channel is invite-only.", 0);

    return 1;
}

# Parse: Numeric:474
# Cannot join channel: Banned from channel.
sub num474 {
    my ($svr, (undef, undef, undef, $chan)) = @_;

    err(3, "Cannot join channel $chan on $svr: Banned from channel.", 0);
    
    return 1;
}

# Parse: Numeric:475
# Cannot join channel: Bad key.
sub num475 {
    my ($svr, (undef, undef, undef, $chan)) = @_;

    err(3, "Cannot join channel $chan on $svr: Bad key.", 0);
    
    return 1;
}

# Parse: Numeric:477
# Cannot join channel: Need registered nickname.
sub num477 {
    my ($svr, (undef, undef, undef, $chan)) = @_;
    
    err(3, "Cannot join channel $chan on $svr: Need registered nickname.", 0);
    
    return 1;
}

# Parse: CAP
sub cap {
    my ($svr, @ex) = @_;
    my $capout;

    # Iterate ex[3].
    given ($ex[3]) {
        when ('LS') {
            # Get our CAP REQ list.
            my @capreq = ();
            if ($cap{$svr} =~ m/\s/xsm) { @capreq = split ' ', $cap{$svr} }
            else { push @capreq, $cap{$svr} }

            # Iterate through what we received from the server.
            $ex[4] =~ s/^://xsm;
            foreach my $scap (@ex[4..$#ex]) {
                # Check if we support this.
                foreach my $icap (@capreq) {
                    if ($icap eq $scap) {
                        $capout .= " $scap";
                    }
                }
            }
            
            # Send CAP REQ/CAP END based on what both we and the server support.
            if (!$capout) { Auto::socksnd($svr, 'CAP END'); }
            else {
                $capout = substr $capout, 1;
                Auto::socksnd($svr, "CAP REQ :$capout");
            }
        }
        when ('ACK') {
            # Iterate through the ACK arguments.
            $ex[4] =~ s/^://xsm;
            my $sasl = 0;
            foreach (@ex[4..$#ex]) {
                if ($_ eq 'sasl') { $sasl++ }
                API::Std::event_run('on_capack', ($svr, $_));
            }
            Auto::socksnd($svr, 'CAP END') unless $sasl;
        }
        when ('NAK') {
            # This should never happen, but just in case...
            API::Log::awarn(2, "$svr: CAP failed: Server refused '$capout'");
            Auto::socksnd($svr, 'CAP END');
        }
    }

    return 1;
}

# Parse: JOIN
sub cjoin {
    my ($svr, @ex) = @_;
    my %src = API::IRC::usrc(substr($ex[0], 1));
    my $chan = $ex[2];
    $chan =~ s/^://gxsm;
    
    # Check if this is coming from ourselves.
    if ($src{nick} eq $botinfo{$svr}{nick}) {
    	$botchans{$svr}{lc $chan} = 1;
    	API::Std::event_run("on_ucjoin", ($svr, $chan));
    }
    else {
    	# It isn't. Update chanusers and trigger on_rcjoin.
        $chanusers{$svr}{lc $chan}{$src{nick}} = 1;
        $src{svr} = $svr;
    	API::Std::event_run("on_rcjoin", (\%src, $chan));
    }
    
    return 1;
}

# Parse: KICK
sub kick {
    my ($svr, @ex) = @_;

    my %src = API::IRC::usrc(substr($ex[0], 1));
    $src{svr} = $svr;

    # Update chanusers.
    delete $chanusers{$svr}{$ex[2]}{$ex[3]} if defined $chanusers{$svr}{$ex[2]}{$ex[3]};

    # Set $msg to the kick message.
    my $msg = 0;
    if (defined $ex[4]) {
        $msg = substr($ex[4], 1);
        if (defined $ex[5]) {
            for (my $i = 5; $i < scalar(@ex); $i++) {
                $msg .= " ".$ex[$i];
            }
        }
    }

    # Check if we were the ones kicked.
    if (lc($ex[3]) eq lc($botinfo{$svr}{nick})) {
        # We were kicked!

        # Delete channel from botchans.
        delete $botchans{$svr}{$ex[2]};

        # Log this horrible act.
        API::Log::alog("I was kicked from ".$svr."/".$ex[2]." by ".$src{nick}."! Reason: ".$msg);

        # Rejoin if we're told to in config.
        if (conf_get("server:$svr:autorejoin")) {
            if ((conf_get("server:$svr:autorejoin"))[0][0] eq 1) {
                API::IRC::cjoin($svr, $ex[2]);
            }
        }
    }
    else {
        # We weren't. Update chanusers and trigger on_kick.
        if (defined $chanusers{$svr}{$ex[2]}{$ex[3]}) { delete $chanusers{$svr}{$ex[2]}{$ex[3]}; }
        API::Std::event_run("on_kick", (\%src, $ex[2], $ex[3], $msg));
    }

    return 1;
}

# Parse: MODE
sub mode {
    my ($svr, @ex) = @_;

    if ($ex[2] ne $botinfo{$svr}{nick}) {
        # Set data we'll need later.
        my $chan = $ex[2];
        $ex[3] =~ s/^://xsm;
        my $modes = $ex[3];
        my $fmodes = join ' ', @ex[3..$#ex];
        $modes =~ s/^://xsm;
        # Get rid of the useless data, so the mode parser will work smoothly.
        shift @ex; shift @ex; shift @ex; shift @ex;

        # Check if the modes contain any status modes.
        my $nt = 0;
        foreach (keys %{ $csprefix{$svr} }) {
            if ($modes =~ /($_)/) {
                $nt = 1;
                last;
            }
        }

        if ($nt) {
            # It did. Lets parse the changes.
            
            my @ma = split(//, $modes);

            my $op = 1;
            foreach my $maf (@ma) {
                if ($maf eq '+') {
                    # If it's a +, change the operator to 1.
                    $op = 1;
                }
                elsif ($maf eq '-') {
                    # If it's a -, change the operator to 2.
                    $op = 2;
                }
                else {
                    # It's a mode, lets check if it's a status mode.
                    my $nnt = 0;
                    foreach (keys %{ $csprefix{$svr} }) {
                        if ($maf eq $_) {
                            $nnt = 1;
                            last;
                        }
                    }

                    if ($nnt) {
                        # It is a status mode, lets parse changes.
                        my $user = shift(@ex);

                        if (defined $chanusers{$svr}{$chan}{$user}) {
                            if ($op == 1) {
                                if ($chanusers{$svr}{$chan}{$user} eq 1) {
                                    $chanusers{$svr}{$chan}{$user} = $maf;
                                }
                                else {
                                    $chanusers{$svr}{$chan}{$user} .= $maf;
                                }
                            }
                            elsif ($op == 2) {
                                if (length($chanusers{$svr}{$chan}{$user}) == 1) {
                                    $chanusers{$svr}{$chan}{$user} = 1;
                                }
                                else {
                                    $chanusers{$svr}{$chan}{$user} =~ s/($maf)//gxsm;
                                }
                            }
                        }
                        else {
                            $chanusers{$svr}{$chan}{$user} = $maf;
                        }
                    }
                    else {
                        # It is not. Lets adjust arguments accordingly.
                        if (defined $chanmodes{$svr}{$maf}) {
                            if ($chanmodes{$svr}{$maf} == 1 || $chanmodes{$svr}{$maf} == 2) { shift @ex; }
                            if ($chanmodes{$svr}{$maf} == 3) { 
                                if ($op == 1) { shift @ex; }
                            }
                        }
                    }
                }
            }   
        }
        # Trigger on_cmode.
        API::Std::event_run('on_cmode', ($svr, $chan, $fmodes));
    }
    else {
        # User mode change; trigger on_umode.
        $ex[3] =~ s/^://xsm;
        API::Std::event_run('on_umode', ($svr, @ex[3..$#ex]));
    }
    return 1;
}

# Parse: NICK
sub nick {
    my ($svr, ($uex, undef, $nex)) = @_;
    $nex =~ s/^://gxsm;

    my %src = API::IRC::usrc(substr($uex, 1));
    $src{svr} = $svr;
 
    # Check if this is coming from ourselves.
    if ($src{nick} eq $botinfo{$svr}{nick}) {
    	# It is. Update bot nick hash.
    	$botinfo{$svr}{nick} = $nex;
    	delete $botinfo{$svr}{newnick} if (defined $botinfo{$svr}{newnick});
    }
    else {
    	# It isn't. Update chanusers and trigger on_nick.
        foreach my $chk (keys %{ $chanusers{$svr} }) {
            if (defined $chanusers{$svr}{$chk}{$src{nick}}) {
                $chanusers{$svr}{$chk}{$nex} = $chanusers{$svr}{$chk}{$src{nick}};
                delete $chanusers{$svr}{$chk}{$src{nick}};
            }
        }
    	API::Std::event_run("on_nick", (\%src, $nex));
    }
    
    return 1;	
}

# Parse: NOTICE
sub notice {
    my ($svr, @ex) = @_;

    # Ensure this is coming from a user rather than a server.
    if ($ex[0] !~ m/!/xsm) { return; }

    # Prepare all the data.
    my %src = API::IRC::usrc(substr $ex[0], 1);
    my $target = $ex[2];
    shift @ex; shift @ex; shift @ex;
    $ex[0] = substr $ex[0], 1;
    $src{svr} = $svr;
    
    # Send it off.
    API::Std::event_run("on_notice", (\%src, $target, @ex));
    
    return 1;
}

# Parse: PART
sub part {
    my ($svr, @ex) = @_;

    my %src = API::IRC::usrc(substr($ex[0], 1));
    $src{svr} = $svr;
    
    # Check if it's from us or someone else.
    if ($src{nick} eq $botinfo{$svr}{nick}) {
        # Delete this channel from botchans.
        if ($botchans{$svr}{$ex[2]}) { delete $botchans{$svr}{$ex[2]}; }
        # Trigger on_upart.
        API::Std::event_run('on_upart', ($svr, $ex[2]));
    }
    else {
        # Delete them from chanusers.
        delete $chanusers{$svr}{$ex[2]}{$src{nick}} if defined $chanusers{$svr}{$ex[2]}{$src{nick}};
    
        # Set $msg to the part message.
        my $msg = 0;
        if (defined $ex[3]) {
            $msg = substr($ex[3], 1);
            if (defined $ex[4]) {
                for (my $i = 4; $i < scalar(@ex); $i++) {
                    $msg .= " ".$ex[$i];
                }
            }
        }

        # Trigger on_part.
        API::Std::event_run("on_part", (\%src, $ex[2], $msg));
    }

    return 1;
}

# Parse: PRIVMSG
sub privmsg {
    my ($svr, @ex) = @_;
    my %data;

    # Ensure this is coming from a user rather than a server.
    if ($ex[0] !~ m/!/xsm) { 
        %data = (
                'nick' => substr($ex[0], 1),
                'user' => '*',
                'host' => '*'
                );
    }
    else { %data = API::IRC::usrc(substr($ex[0], 1)) }

    my @argv;
    for (my $i = 4; $i < scalar(@ex); $i++) {
    	push(@argv, $ex[$i]);
    }
    $data{svr} = $svr;
    
    my ($cmd, $cprefix, $rprefix);
    # Check if it's to a channel or to us.
    if (lc($ex[2]) eq lc($botinfo{$svr}{nick})) {
    	# It is coming to us in a private message.
        
        # Ensure it's a valid length.
        if (length($ex[3]) > 1) {
    	    $cmd = uc(substr($ex[3], 1));
    	    if (defined $API::Std::CMDS{$cmd}) {
                # If this is indeed a command, continue.
    		    if ($API::Std::CMDS{$cmd}{lvl} == 1 or $API::Std::CMDS{$cmd}{lvl} == 2) {
                    # Ensure the level is private or all.
                    if (API::Std::ratelimit_check(%data)) {
                        # Continue if the user has not passed the ratelimit amount.
    			        if ($API::Std::CMDS{$cmd}{priv}) {
                            # If this command requires a privilege...
                            if (API::Std::has_priv(API::Std::match_user(%data), $API::Std::CMDS{$cmd}{priv})) {
                                # Make sure they have it.
                                &{ $API::Std::CMDS{$cmd}{'sub'} }(\%data, @argv);
                            }
                            else {
                                # Else give them the boot.
                                API::IRC::notice($data{svr}, $data{nick}, API::Std::trans("Permission denied").".");
                            }
                        }
                        else {
                            # Else execute the command without any extra checks.
                            &{ $API::Std::CMDS{$cmd}{'sub'} }(\%data, @argv);
                        }
                    }
                    else {
                        # Send them a notice about their bad deed.
                        API::IRC::notice($data{svr}, $data{nick}, trans('Rate limit exceeded').q{.});
                    }
    		    }
    	    }
        }

    	# Trigger event on_uprivmsg.
        shift @ex; shift @ex; shift @ex;
        $ex[0] = substr $ex[0], 1;
    	API::Std::event_run("on_uprivmsg", (\%data, @ex));
    }
    else {
    	# It is coming to us in a channel message.
    	$data{chan} = $ex[2];
        # Ensure it's a valid length before continuing.
    	if (length($ex[3]) > 1) {
            $cprefix = (conf_get("fantasy_pf"))[0][0];
    	    $rprefix = substr($ex[3], 1, 1);
    	    $cmd = uc(substr($ex[3], 2));
    	    if (defined $API::Std::CMDS{$cmd} and $rprefix eq $cprefix) {
                # If this is indeed a command, continue.
    		    if ($API::Std::CMDS{$cmd}{lvl} == 0 or $API::Std::CMDS{$cmd}{lvl} == 2) {
                    # Ensure the level is public or all.
                    if (API::Std::ratelimit_check(%data)) {
                        # Continue if the user has not passed the ratelimit amount.
                        if ($API::Std::CMDS{$cmd}{priv}) {
                            # If this command takes a privilege...
                            if (API::Std::has_priv(API::Std::match_user(%data), $API::Std::CMDS{$cmd}{priv})) {
                                # Make sure they have it.
                                &{ $API::Std::CMDS{$cmd}{'sub'} }(\%data, @argv);
                            }
                            else {
                                # Else give them the boot.
                                API::IRC::notice($data{svr}, $data{nick}, API::Std::trans('Permission denied').q{.});
                            }
                        }
                        else {
                            # Else continue executing without any extra checks.
                            &{ $API::Std::CMDS{$cmd}{'sub'} }(\%data, @argv);
                        }
                    }
                    else {
                        # Send them a notice about their bad deed.
                        API::IRC::notice($data{svr}, $data{nick}, trans('Rate limit exceeded').q{.});
                    }
                }
                elsif ($API::Std::CMDS{$cmd}{lvl} == 3) {
                    # Or if it's a logchan command...
                    my ($lcn, $lcc) = split '/', (conf_get('logchan'))[0][0];
                    if ($lcn eq $data{svr} and lc $lcc eq lc $data{chan}) {
                        # Check if it's being sent from the logchan.
                        if ($API::Std::CMDS{$cmd}{priv}) {
                            # If this command takes a privilege...
                            if (API::Std::has_priv(API::Std::match_user(%data), $API::Std::CMDS{$cmd}{priv})) {
                                # Make sure they have it.
                                &{ $API::Std::CMDS{$cmd}{'sub'} }(\%data, @argv);
                            }
                            else {
                                # Else give them the boot.
                                API::IRC::notice($data{svr}, $data{nick}, API::Std::trans('Permission denied').q{.});
                            }
                        }
                        else {
                            # Else continue executing without any extra checks.
                            &{ $API::Std::CMDS{$cmd}{'sub'} }(\%data, @argv);
                        }
                    }
                }
    	    }
        }

    	# Trigger event on_cprivmsg.
        my $target = $ex[2]; delete $data{chan};
        shift @ex; shift @ex; shift @ex;
        $ex[0] = substr $ex[0], 1;
    	API::Std::event_run("on_cprivmsg", (\%data, $target, @ex));
    }
    
    return 1;
}

# Parse: QUIT
sub quit {
    my ($svr, @ex) = @_;

    my %src = API::IRC::usrc(substr($ex[0], 1));
    $src{svr} = $svr;

    # Set $msg to the quit message.
    my $msg = 0;
    if (defined $ex[2]) {
        $msg = substr($ex[2], 1);
        if (defined $ex[3]) {
            for (my $i = 3; $i < scalar(@ex); $i++) {
                $msg .= " ".$ex[$i];
            }
        }
    }

    # Trigger on_quit.
    API::Std::event_run("on_quit", (\%src, $msg));
    
    return 1;
}

# Parse: TOPIC
sub topic {
    my ($svr, @ex) = @_;
    my %src = API::IRC::usrc(substr($ex[0], 1));
    $src{svr} = $svr;
    $src{chan} = $ex[2];
    $ex[3] = substr $ex[3], 1;
    
    # Trigger on_topic.
    API::Std::event_run('on_topic', (\%src, @ex[3..$#ex]));
    
    return 1;
}


1;
# vim: set ai et sw=4 ts=4:
