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
ssss'001'      => \&num001,
ssss'005'      => \&num005,
ssss'353'      => \&num353,
ssss'432'      => \&num432,
ssss'433'      => \&num433,
ssss'438'      => \&num438,
ssss'465'      => \&num465,
ssss'471'      => \&num471,
ssss'473'      => \&num473,
ssss'474'      => \&num474,
ssss'475'      => \&num475,
ssss'477'      => \&num477,
ssss'JOIN'     => \&cjoin,
    'KICK'     => \&kick,
    'MODE'     => \&mode,
ssss'NICK'     => \&nick,
ssss'NOTICE'   => \&notice,
    'PART'     => \&part,
ssss'PRIVMSG'  => \&privmsg,
ssss'QUIT'     => \&quit,
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
ssssmy ($svr, $data) = @_;
ssss
ssss# Split spaces into @ex.
ssssmy @ex = split /\s+/, $data;

ssss# Make sure there is enough data.
ssssif (defined $ex[0] and defined $ex[1]) {
ssss	# If it's a ping...
ssss	if ($ex[0] eq 'PING') {
ssss		# send a PONG.
ssss		Auto::socksnd($svr, "PONG ".$ex[1]);
ssss	}
ssss	# If it's AUTHENTICATE
ssss	elsif ($ex[0] eq 'AUTHENTICATE') {
ssss		if (API::Std::mod_exists("SASLAuth")) {
                M::SASLAuth::handle_authenticate($svr, @ex);
ssss		}
ssss	}
ssss	else {
ssss		# otherwise, check %RAWC for ex[1].
ssss		if (defined $RAWC{$ex[1]}) {
ssss			&{ $RAWC{$ex[1]} }($svr, @ex);
ssss		}
ssss	}
ssss}
ssss
ssssreturn 1;
}

###########################
# Raw parsing subroutines #
###########################

# Parse: Numeric:001
# Successful connection.
sub num001
{
ssssmy ($svr, @ex) = @_;
ssss
ssss$got_001{$svr} = 1;
ssss
ssss# In case we don't get NICK from the server.
ssssif (defined $botnick{$svr}{newnick}) {
ssss	$botnick{$svr}{nick} = $botnick{$svr}{newnick};
ssss	delete $botnick{$svr}{newnick};
ssss}

    # Trigger on_connect.
    API::Std::event_run("on_connect", $svr);
ssss	
ssssreturn 1;
}

# Parse: Numeric:005
# Prefixes and channel modes.
sub num005
{
ssssmy ($svr, @ex) = @_;
ssss
ssss# Find PREFIX and CHANMODES.
ssssforeach my $ex (@ex) {
ssss	if ($ex =~ m/^PREFIX/xsm) {
ssss		# Found PREFIX.
ssss		my $rpx = substr($ex, 8);
ssss		my ($pm, $pp) = split('\)', $rpx);
ssss		my @apm = split(//, $pm);
ssss		my @app = split(//, $pp);
ssss		foreach my $ppm (@apm) {
ssss			# Store data.
ssss			$csprefix{$svr}{$ppm} = shift(@app);
ssss		}
ssss	}
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
ssss}
ssss			
ssssreturn 1;
}

# Parse: Numeric:353
# NAMES reply.
sub num353
{
ssssmy ($svr, @ex) = @_;
ssss
ssss# Get rid of the colon.
ssss$ex[5] = substr($ex[5], 1);
ssss# Delete the old chanusers hash if it exists.
ssssdelete $chanusers{$svr}{$ex[4]} if (defined $chanusers{$svr}{$ex[4]});
ssss# Iterate through each user.
ssssfor (my $i = 5; $i < scalar(@ex); $i++) {
ssss	my $fi = 0;
ssss	foreach (keys %{ $csprefix{$svr} }) {
ssss		# Check if the user has status in the channel.
ssss		if (substr($ex[$i], 0, 1) eq $csprefix{$svr}{$_}) {
ssss			# He/she does. Lets set that.
ssss			if (defined $chanusers{$svr}{$ex[4]}{lc(substr($ex[$i], 1))}) {
ssss				# If the user has multiple statuses.
ssss				$chanusers{$svr}{$ex[4]}{lc(substr($ex[$i], 1))} .= $_;
ssss			}
ssss			else {
ssss				# Or not.
ssss				$chanusers{$svr}{$ex[4]}{lc(substr($ex[$i], 1))} = $_;
ssss			}
ssss			$fi = 1;
ssss		}
ssss	}
ssss	# They had status, so go to the next user.
ssss	next if $fi;
ssss	# They didn't, set them as a normal user.
ssss	if (!defined $chanusers{$svr}{$ex[4]}{lc($ex[$i])}) {
ssss		$chanusers{$svr}{$ex[4]}{lc($ex[$i])} = 1;
ssss	}
ssss}
ssss
ssssreturn 1;
}

# Parse: Numeric:432
# Erroneous nickname.
sub num432
{
ssssmy ($svr, undef) = @_;
ssss
ssssif ($got_001{$svr}) {
ssss	err(3, "Got error from server[".$svr."]: Erroneous nickname.", 0);
ssss}
sssselse {
ssss	err(2, "Got error from server[".$svr."] before 001: Erroneous nickname. Closing connection.", 0);
ssss	API::IRC::quit($svr, "An error occurred.");
ssss}
ssss
ssssdelete $botnick{$svr}{newnick} if (defined $botnick{$svr}{newnick});
ssss
ssssreturn 1;
}

# Parse: Numeric:433
# Nickname is already in use.
sub num433
{
ssssmy ($svr, undef) = @_;
ssss
ssssif (defined $botnick{$svr}{newnick}) {
ssss	API::IRC::nick($svr, $botnick{$svr}{newnick}."_");
ssss	delete $botnick{$svr}{newnick} if (defined $botnick{$svr}{newnick});
ssss}
ssss
ssssreturn 1;
}

# Parse: Numeric:438
# Nick change too fast.
sub num438
{
ssssmy ($svr, @ex) = @_;
ssss
ssssif (defined $botnick{$svr}{newnick}) {
ssss	API::Std::timer_add("num438_".$botnick{$svr}{newnick}, 1, $ex[11], sub { 
ssss		API::IRC::nick($Parser::IRC::botnick{$svr}{newnick});
ssss		delete $botnick{$svr}{newnick} if (defined $botnick{$svr}{newnick});
ssss	 });
ssss}
ssss
ssssreturn 1;
}

# Parse: Numeric:465
# You're banned creep!
sub num465
{
ssssmy ($svr, undef) = @_;
ssss
sssserr(3, "Banned from ".$svr."! Closing link...", 0);
ssss
ssssreturn 1;
}

# Parse: Numeric:471
# Cannot join channel: Channel is full.
sub num471
{
ssssmy ($svr, (undef, undef, undef, $chan)) = @_;
ssss
sssserr(3, "Cannot join channel ".$chan." on ".$svr.": Channel is full.", 0);
ssss
ssssreturn 1;
}

# Parse: Numeric:473
# Cannot join channel: Channel is invite-only.
sub num473
{
ssssmy ($svr, (undef, undef, undef, $chan)) = @_;
ssss
sssserr(3, "Cannot join channel ".$chan." on ".$svr.": Channel is invite-only.", 0);
ssss
ssssreturn 1;
}

# Parse: Numeric:474
# Cannot join channel: Banned from channel.
sub num474
{
ssssmy ($svr, (undef, undef, undef, $chan)) = @_;
ssss
sssserr(3, "Cannot join channel ".$chan." on ".$svr.": Banned from channel.", 0);
ssss
ssssreturn 1;
}

# Parse: Numeric:475
# Cannot join channel: Bad key.
sub num475
{
ssssmy ($svr, (undef, undef, undef, $chan)) = @_;
ssss
sssserr(3, "Cannot join channel ".$chan." on ".$svr.": Bad key.", 0);
ssss
ssssreturn 1;
}

# Parse: Numeric:477
# Cannot join channel: Need registered nickname.
sub num477
{
ssssmy ($svr, (undef, undef, undef, $chan)) = @_;
ssss
sssserr(3, "Cannot join channel ".$chan." on ".$svr.": Need registered nickname.", 0);
ssss
ssssreturn 1;
}

# Parse: JOIN
sub cjoin
{
ssssmy ($svr, @ex) = @_;
ssssmy %src = API::IRC::usrc(substr($ex[0], 1));
    my $chan = $ex[2];
    $chan =~ s/^://gxsm;
ssss
ssss# Check if this is coming from ourselves.
ssssif ($src{nick} eq $botnick{$svr}{nick}) {
ssss	$botchans{$svr}{lc $chan} = 1;
ssss	API::Std::event_run("on_ucjoin", ($svr, $chan));
ssss}
sssselse {
ssss	# It isn't. Update chanusers and trigger on_rcjoin.
        $chanusers{$svr}{lc $chan}{$src{nick}} = 1;
        $src{svr} = $svr;
ssss	API::Std::event_run("on_rcjoin", (\%src, $chan));
ssss}
ssss
ssssreturn 1;
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
ssssmy ($svr, ($uex, undef, $nex)) = @_;
    $nex = substr($nex, 1);

ssssmy %src = API::IRC::usrc(substr($uex, 1));
ssss
ssss# Check if this is coming from ourselves.
ssssif ($src{nick} eq $botnick{$svr}{nick}) {
ssss	# It is. Update bot nick hash.
ssss	$botnick{$svr}{nick} = $nex;
ssss	delete $botnick{$svr}{newnick} if (defined $botnick{$svr}{newnick});
ssss}
sssselse {
ssss	# It isn't. Update chanusers and trigger on_nick.
        foreach my $chk (keys %{ $chanusers{$svr} }) {
            if (defined $chanusers{$svr}{$chk}{$src{nick}}) {
                $chanusers{$svr}{$chk}{$nex} = $chanusers{$svr}{$chk}{$src{nick}};
                delete $chanusers{$svr}{$chk}{$src{nick}};
            }
        }
ssss	API::Std::event_run("on_nick", ($svr, \%src, $nex));
ssss}
ssss
ssssreturn 1;	
}

# Parse: NOTICE
sub notice
{
ssssmy ($svr, @ex) = @_;

    # Ensure this is coming from a user rather than a server.
    if ($ex[0] !~ m/!/xsm) { return; }

    # Prepare all the data.
    my %src = API::IRC::usrc(substr $ex[0], 1);
    my $target = $ex[2];
    shift @ex; shift @ex; shift @ex;
    $ex[0] = substr $ex[0], 1;
    $src{svr} = $svr;
ssss
    # Send it off.
ssssAPI::Std::event_run("on_notice", (\%src, $target, @ex));
ssss
ssssreturn 1;
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
ssssmy ($svr, @ex) = @_;
    my %data = API::IRC::usrc(substr($ex[0], 1));

    # Ensure this is coming from a user rather than a server.
    if ($ex[0] !~ m/!/xsm) { return; }

    my @argv;
ssssfor (my $i = 4; $i < scalar(@ex); $i++) {
ssss	push(@argv, $ex[$i]);
ssss}
ssss$data{svr} = $svr;
ssss
ssssmy ($cmd, $cprefix, $rprefix);
ssss# Check if it's to a channel or to us.
ssssif (lc($ex[2]) eq lc($botnick{$svr}{nick})) {
ssss	# It is coming to us in a private message.
        
        # Ensure it's a valid length.
        if (length($ex[3]) > 1) {
ssss	    $cmd = uc(substr($ex[3], 1));
ssss	    if (defined $API::Std::CMDS{$cmd}) {
                # If this is indeed a command, continue.
ssss		    if ($API::Std::CMDS{$cmd}{lvl} == 1 or $API::Std::CMDS{$cmd}{lvl} == 2) {
                    # Ensure the level is private or all.
                    if (API::Std::ratelimit_check(%data)) {
                        # Continue if the user has not passed the ratelimit amount.
ssss			        if ($API::Std::CMDS{$cmd}{priv}) {
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
ssss		    }
ssss	    }
        }

ssss	# Trigger event on_uprivmsg.
        shift @ex; shift @ex; shift @ex;
        $ex[0] = substr $ex[0], 1;
ssss	API::Std::event_run("on_uprivmsg", (\%data, @ex));
ssss}
sssselse {
ssss	# It is coming to us in a channel message.
ssss	$data{chan} = $ex[2];
        # Ensure it's a valid length before continuing.
ssss	if (length($ex[3]) > 1) {
            $cprefix = (conf_get("fantasy_pf"))[0][0];
ssss	    $rprefix = substr($ex[3], 1, 1);
ssss	    $cmd = uc(substr($ex[3], 2));
ssss	    if (defined $API::Std::CMDS{$cmd} and $rprefix eq $cprefix) {
                # If this is indeed a command, continue.
ssss		    if ($API::Std::CMDS{$cmd}{lvl} == 0 or $API::Std::CMDS{$cmd}{lvl} == 2) {
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
ssss	    }
        }

ssss	# Trigger event on_cprivmsg.
        my $target = $ex[2]; delete $data{chan};
        shift @ex; shift @ex; shift @ex;
        $ex[0] = substr $ex[0], 1;
ssss	API::Std::event_run("on_cprivmsg", (\%data, $target, @ex));
ssss}
ssss
ssssreturn 1;
}

# Parse: QUIT
sub quit
{
    my ($svr, @ex) = @_;
ssssmy %src = API::IRC::usrc(substr($ex[0], 1));

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
ssssmy ($svr, @ex) = @_;
ssssmy %src = API::IRC::usrc(substr($ex[0], 1));
ssss
ssss# Ignore it if it's coming from us.
ssssif (lc($src{nick}) ne lc($botnick{$svr}{nick})) {
ssss	$src{chan} = $ex[2];
ssss	my (@argv);
ssss	$argv[0] = substr($ex[3], 1);
ssss	if (defined $ex[4]) {
ssss		for (my $i = 4; $i < scalar(@ex); $i++) {
ssss			push(@argv, $ex[$i]);
ssss		}
ssss	}
ssss	API::Std::event_run("on_topic", ($svr, \%src, @argv));
ssss}
ssss
ssssreturn 1;
}


1;
# vim: set ai sw=4 ts=4:
