# lib/Parser/IRC.pm - Subroutines for parsing incoming data from IRC.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Parser::IRC;
use strict;
use warnings;
use API::Std qw(conf_get err awarn trans);
use API::IRC;

# Raw parsing hash.
our %RAWC = (
	'001'      => \&num001,
	'005'      => \&num005,
	'353'      => \&num353,
	'432'      => \&num432,
	'433'      => \&num433,
	'438'      => \&num438,
	'465'      => \&num465,
	'471'      => \&num471,
	'473'      => \&num473,
	'474'      => \&num474,
	'475'      => \&num475,
	'477'      => \&num477,
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
our (%got_001, %botnick, %botchans, %csprefix, %chanusers, %chanmodes);

# Events.
API::Std::event_add("on_connect");
API::Std::event_add("on_rcjoin");
API::Std::event_add("on_ucjoin");
API::Std::event_add("on_kick");
API::Std::event_add("on_nick");
API::Std::event_add("on_notice");
API::Std::event_add("on_cprivmsg");
API::Std::event_add("on_uprivmsg");
API::Std::event_add("on_quit");
API::Std::event_add("on_topic");

# Parse raw data.
sub ircparse
{
	my ($svr, $data) = @_;
	
	# Split spaces into @ex.
	my @ex = split(' ', $data);
	
	# Make sure there is enough data.
	if (defined $ex[0] and defined $ex[1]) {
		# If it's a ping...
		if ($ex[0] eq 'PING') {
			# send a PONG.
			Auto::socksnd($svr, "PONG ".$ex[1]);
		}
		# If it's AUTHENTICATE
		elsif ($ex[0] eq 'AUTHENTICATE') {
			if (API::Std::mod_exists("SASLAuth")) {
				m_SASLAuth::handle_authenticate($svr, @ex);
			}
		}
		else {
			# otherwise, check %RAWC for ex[1].
			if (defined $RAWC{$ex[1]}) {
				&{ $RAWC{$ex[1]} }($svr, @ex);
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
sub num001
{
	my ($svr, @ex) = @_;
	
	$got_001{$svr} = 1;
	
	# In case we don't get NICK from the server.
	if (defined $botnick{$svr}{newnick}) {
		$botnick{$svr}{nick} = $botnick{$svr}{newnick};
		delete $botnick{$svr}{newnick};
	}

    # Trigger on_connect.
    API::Std::event_run("on_connect", $svr);
		
	return 1;
}

# Parse: Numeric:005
# Prefixes and channel modes.
sub num005
{
	my ($svr, @ex) = @_;
	
	# Find PREFIX and CHANMODES.
	foreach my $ex (@ex) {
		if ($ex =~ m/^PREFIX/xsm) {
			# Found PREFIX.
			my $rpx = substr($ex, 8);
			my ($pm, $pp) = split('\)', $rpx);
			my @apm = split(//, $pm);
			my @app = split(//, $pp);
			foreach my $ppm (@apm) {
				# Store data.
				$csprefix{$svr}{$ppm} = shift(@app);
			}
		}
        elsif ($ex =~ m/^CHANMODES/xsm) {
            # Found CHANMODES.
            my ($mtl, $mtp, $mtpp, $mts) = split m/[,]/xsm, substr($ex, 10);
            # List modes.
            foreach (split(//, $mtl)) { $chanmodes{$svr}{$_} = 1; }
            # Modes with parameter.
            foreach (split(//, $mtp)) { $chanmodes{$svr}{$_} = 2; }
            # Modes with parameter when +.
            foreach (split(//, $mtpp)) { $chanmodes{$svr}{$_} = 3; }
            # Modes without parameter.
            foreach (split(//, $mts)) { $chanmodes{$svr}{$_} = 4; }
        }
	}
				
	return 1;
}

# Parse: Numeric:353
# NAMES reply.
sub num353
{
	my ($svr, @ex) = @_;
	
	# Get rid of the colon.
	$ex[5] = substr($ex[5], 1);
	# Delete the old chanusers hash if it exists.
	delete $chanusers{$svr}{$ex[4]} if (defined $chanusers{$svr}{$ex[4]});
	# Iterate through each user.
	for (my $i = 5; $i < scalar(@ex); $i++) {
		my $fi = 0;
		foreach (keys %{ $csprefix{$svr} }) {
			# Check if the user has status in the channel.
			if (substr($ex[$i], 0, 1) eq $csprefix{$svr}{$_}) {
				# He/she does. Lets set that.
				if (defined $chanusers{$svr}{$ex[4]}{lc(substr($ex[$i], 1))}) {
					# If the user has multiple statuses.
					$chanusers{$svr}{$ex[4]}{lc(substr($ex[$i], 1))} .= $_;
				}
				else {
					# Or not.
					$chanusers{$svr}{$ex[4]}{lc(substr($ex[$i], 1))} = $_;
				}
				$fi = 1;
			}
		}
		# They had status, so go to the next user.
		next if $fi;
		# They didn't, set them as a normal user.
		if (!defined $chanusers{$svr}{$ex[4]}{lc($ex[$i])}) {
			$chanusers{$svr}{$ex[4]}{lc($ex[$i])} = 1;
		}
	}
	
	return 1;
}

# Parse: Numeric:432
# Erroneous nickname.
sub num432
{
	my ($svr, undef) = @_;
	
	if ($got_001{$svr}) {
		err(3, "Got error from server[".$svr."]: Erroneous nickname.", 0);
	}
	else {
		err(2, "Got error from server[".$svr."] before 001: Erroneous nickname. Closing connection.", 0);
		API::IRC::quit($svr, "An error occurred.");
	}
	
	delete $botnick{$svr}{newnick} if (defined $botnick{$svr}{newnick});
	
	return 1;
}

# Parse: Numeric:433
# Nickname is already in use.
sub num433
{
	my ($svr, undef) = @_;
	
	if (defined $botnick{$svr}{newnick}) {
		API::IRC::nick($svr, $botnick{$svr}{newnick}."_");
		delete $botnick{$svr}{newnick} if (defined $botnick{$svr}{newnick});
	}
	
	return 1;
}

# Parse: Numeric:438
# Nick change too fast.
sub num438
{
	my ($svr, @ex) = @_;
	
	if (defined $botnick{$svr}{newnick}) {
		API::Std::timer_add("num438_".$botnick{$svr}{newnick}, 1, $ex[11], sub { 
			API::IRC::nick($Parser::IRC::botnick{$svr}{newnick});
			delete $botnick{$svr}{newnick} if (defined $botnick{$svr}{newnick});
		 });
	}
	
	return 1;
}

# Parse: Numeric:465
# You're banned creep!
sub num465
{
	my ($svr, undef) = @_;
	
	err(3, "Banned from ".$svr."! Closing link...", 0);
	
	return 1;
}

# Parse: Numeric:471
# Cannot join channel: Channel is full.
sub num471
{
	my ($svr, (undef, undef, undef, $chan)) = @_;
	
	err(3, "Cannot join channel ".$chan." on ".$svr.": Channel is full.", 0);
	
	return 1;
}

# Parse: Numeric:473
# Cannot join channel: Channel is invite-only.
sub num473
{
	my ($svr, (undef, undef, undef, $chan)) = @_;
	
	err(3, "Cannot join channel ".$chan." on ".$svr.": Channel is invite-only.", 0);
	
	return 1;
}

# Parse: Numeric:474
# Cannot join channel: Banned from channel.
sub num474
{
	my ($svr, (undef, undef, undef, $chan)) = @_;
	
	err(3, "Cannot join channel ".$chan." on ".$svr.": Banned from channel.", 0);
	
	return 1;
}

# Parse: Numeric:475
# Cannot join channel: Bad key.
sub num475
{
	my ($svr, (undef, undef, undef, $chan)) = @_;
	
	err(3, "Cannot join channel ".$chan." on ".$svr.": Bad key.", 0);
	
	return 1;
}

# Parse: Numeric:477
# Cannot join channel: Need registered nickname.
sub num477
{
	my ($svr, (undef, undef, undef, $chan)) = @_;
	
	err(3, "Cannot join channel ".$chan." on ".$svr.": Need registered nickname.", 0);
	
	return 1;
}

# Parse: JOIN
sub cjoin
{
	my ($svr, @ex) = @_;
	my %src = API::IRC::usrc(substr($ex[0], 1));
	
	# Check if this is coming from ourselves.
	if ($src{nick} eq $botnick{$svr}{nick}) {
		$botchans{$svr}{lc(substr $ex[2], 1)} = 1;
		API::Std::event_run("on_ucjoin", ($svr, substr($ex[2], 1)));
	}
	else {
		# It isn't. Update chanusers and trigger on_rcjoin.
        $chanusers{$svr}{lc(substr $ex[2], 1)}{$src{nick}} = 1;
		API::Std::event_run("on_rcjoin", ($svr, \%src, substr($ex[2], 1)));
	}
	
	return 1;
}

# Parse: KICK
sub kick
{
    my ($svr, @ex) = @_;
    my %src = API::IRC::usrc(substr($ex[0], 1));

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
    if (lc($ex[3]) eq lc($botnick{$svr}{nick})) {
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
        API::Std::event_run("on_kick", ($svr, \%src, $ex[2], $ex[3], $msg));
    }

    return 1;
}

# Parse: MODE
sub mode
{
    my ($svr, @ex) = @_;

    if ($ex[2] ne $botnick{$svr}{nick}) {
        # Set data we'll need later.
        my $chan = $ex[2];
        my $modes = $ex[3];
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
    }

    return 1;
}

# Parse: NICK
sub nick
{
	my ($svr, ($uex, undef, $nex)) = @_;
    $nex = substr($nex, 1);

	my %src = API::IRC::usrc(substr($uex, 1));
	
	# Check if this is coming from ourselves.
	if ($src{nick} eq $botnick{$svr}{nick}) {
		# It is. Update bot nick hash.
		$botnick{$svr}{nick} = $nex;
		delete $botnick{$svr}{newnick} if (defined $botnick{$svr}{newnick});
	}
	else {
		# It isn't. Update chanusers and trigger on_nick.
        foreach my $chk (keys %{ $chanusers{$svr} }) {
            if (defined $chanusers{$svr}{$chk}{$src{nick}}) {
                $chanusers{$svr}{$chk}{$nex} = $chanusers{$svr}{$chk}{$src{nick}};
                delete $chanusers{$svr}{$chk}{$src{nick}};
            }
        }
		API::Std::event_run("on_nick", ($svr, \%src, $nex));
	}
	
	return 1;	
}

# Parse: NOTICE
sub notice
{
	my ($svr, @ex) = @_;
	
	API::Std::event_run("on_notice", ($svr, @ex));
	
	return 1;
}

# Parse: PART
sub part
{
    my ($svr, @ex) = @_;
    my %src = API::IRC::usrc(substr($ex[0], 1));

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
    API::Std::event_run("on_part", ($svr, \%src, $ex[2], $msg));

    return 1;
}

# Parse: PRIVMSG
sub privmsg
{
	my ($svr, @ex) = @_;
	my %data = API::IRC::usrc(substr($ex[0], 1));

	my @argv;
	for (my $i = 4; $i < scalar(@ex); $i++) {
		push(@argv, $ex[$i]);
	}
	$data{svr} = $svr;
	@{ $data{args} } = @argv;
	
	my ($cmd, $cprefix, $rprefix);
	# Check if it's to a channel or to us.
	if (lc($ex[2]) eq lc($botnick{$svr}{nick})) {
		# It is coming to us in a private message.
		$cmd = uc(substr($ex[3], 1));
		if (defined $API::Std::CMDS{$cmd}) {
            # If this is indeed a command, continue.
			if ($API::Std::CMDS{$cmd}{lvl} == 1 or $API::Std::CMDS{$cmd}{lvl} == 2) {
                # Ensure the level is private or all.
                if (!defined $Core::IRC::usercmd{$data{nick}.'@'.$data{host}}) { $Core::IRC::usercmd{$data{nick}.'@'.$data{host}} = 0; }
                if (API::Std::ratelimit_check(%data)) {
                    # Continue if the user has not passed the ratelimit amount.
				    if ($API::Std::CMDS{$cmd}{priv}) {
                        # If this command requires a privilege...
                        if (API::Std::has_priv(API::Std::match_user(%data), $API::Std::CMDS{$cmd}{priv})) {
                            # Make sure they have it.
                            &{ $API::Std::CMDS{$cmd}{'sub'} }(%data);
                        }
                        else {
                            # Else give them the boot.
                            API::IRC::notice($data{svr}, $data{nick}, API::Std::trans("Permission denied").".");
                        }
                    }
                    else {
                        # Else execute the command without any extra checks.
                        &{ $API::Std::CMDS{$cmd}{'sub'} }(%data);
                    }
                }
                else {
                    # Send them a notice about their bad deed.
                    API::IRC::notice($data{svr}, $data{nick}, trans('Rate limit exceeded').q{.});
                }
			}
		}
		
		# Trigger event on_uprivmsg.
		API::Std::event_run("on_uprivmsg", ($svr, @ex));
	}
	else {
		# It is coming to us in a channel message.
		$data{chan} = $ex[2];
		$cprefix = (conf_get("fantasy_pf"))[0][0];
		$rprefix = substr($ex[3], 1, 1);
		$cmd = uc(substr($ex[3], 2));
		if (defined $API::Std::CMDS{$cmd}) {
            # If this is indeed a command, continue.
			if ($API::Std::CMDS{$cmd}{lvl} == 0 or $API::Std::CMDS{$cmd}{lvl} == 2) {
                # Ensure the level is public or all.
                if (!defined $Core::IRC::usercmd{$data{nick}.'@'.$data{host}}) { $Core::IRC::usercmd{$data{nick}.'@'.$data{host}} = 0; }
                if (API::Std::ratelimit_check(%data)) {
                    # Continue if the user has not passed the ratelimit amount.
                    if ($API::Std::CMDS{$cmd}{priv}) {
                        # If this command takes a privilege...
                        if (API::Std::has_priv(API::Std::match_user(%data), $API::Std::CMDS{$cmd}{priv})) {
                            # Make sure they have it.
                            &{ $API::Std::CMDS{$cmd}{'sub'} }(%data) if $rprefix eq $cprefix;
                        }
                         else {
                            # Else give them the boot.
                            API::IRC::notice($data{svr}, $data{nick}, API::Std::trans("Permission denied").".");
                        }
                    }
                    else {
                        # Else continue executing without any extra checks.
                        &{ $API::Std::CMDS{$cmd}{'sub'} }(%data) if $rprefix eq $cprefix;
                    }
                }
                else {
                    # Send them a notice about their bad deed.
                    API::IRC::notice($data{svr}, $data{nick}, trans('Rate limit exceeded').q{.});
                }
            }
		}
		
		# Trigger event on_cprivmsg.
		API::Std::event_run("on_cprivmsg", ($svr, @ex));
	}
	
	return 1;
}

# Parse: QUIT
sub quit
{
    my ($svr, @ex) = @_;
	my %src = API::IRC::usrc(substr($ex[0], 1));

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
    API::Std::event_run("on_quit", ($svr, \%src, $msg));
    
    return 1;
}

# Parse: TOPIC
sub topic
{
	my ($svr, @ex) = @_;
	my %src = API::IRC::usrc(substr($ex[0], 1));
	
	# Ignore it if it's coming from us.
	if (lc($src{nick}) ne lc($botnick{$svr}{nick})) {
		$src{chan} = $ex[2];
		my (@argv);
		$argv[0] = substr($ex[3], 1);
		if (defined $ex[4]) {
			for (my $i = 4; $i < scalar(@ex); $i++) {
				push(@argv, $ex[$i]);
			}
		}
		API::Std::event_run("on_topic", ($svr, \%src, @argv));
	}
	
	return 1;
}


1;
# vim: set ai sw=4 ts=4:
