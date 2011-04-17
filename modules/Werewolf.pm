# Module: Werewolf. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Werewolf;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del trans hook_add hook_del timer_add timer_del trans conf_get has_priv match_user);
use API::IRC qw(privmsg notice cmode);
my ($GAME, $PGAME, $GAMECHAN, $GAMETIME, %PLAYERS, %NICKS, @STATIC, $PHASE, $SEEN, $VISIT, $GUARD, %KILL, %WKILL, %LYNCH, %SPOKE, %WARN, $LVOTEN, @SHOT, $BULLETS, $DETECTED);
my $FCHAR = (conf_get('fantasy_pf'))[0][0];

# Initialization subroutine.
sub _init {
    # Create the WOLF command.
    cmd_add('WOLF', 2, 0, \%M::Werewolf::HELP_WOLF, \&M::Werewolf::cmd_wolf) or return;
    
    # Create the on_cprivmsg hook.
    hook_add('on_cprivmsg', 'werewolf.updatedata.bed', \&M::Werewolf::on_cprivmsg) or return;
    # Create the on_uprivmsg hook.
    hook_add('on_uprivmsg', 'werewolf.relay', \&M::Werewolf::on_uprivmsg) or return;
    # Create the on_nick hook.
    hook_add('on_nick', 'werewolf.updatedata.nick', \&M::Werewolf::on_nick) or return;
    # Create the on_part hook.
    hook_add('on_part', 'werewolf.updatedata.part', \&M::Werewolf::on_part) or return;
    # Create the on_kick hook.
    hook_add('on_kick', 'werewolf.updatedata.kick', \&M::Werewolf::on_kick) or return;
    # Create the on_quit hook.
    hook_add('on_quit', 'werewolf.updatedata.quit', \&M::Werewolf::on_quit) or return;
    # Create the on_rehash hook.
    hook_add('on_rehash', 'werewolf.rehash', \&M::Werewolf::on_rehash) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the WOLF command.
    cmd_del('WOLF') or return;
    
    # Delete the on_cprivmsg hook.
    hook_del('on_cprivmsg', 'werewolf.updatedata.bed') or return;
    # Delete the on_uprivmsg hook.
    hook_del('on_uprivmsg', 'werewolf.relay') or return;
    # Delete the on_nick hook.
    hook_del('on_nick', 'werewolf.updatedata.nick') or return;
    # Delete the on_part hook.
    hook_del('on_part', 'werewolf.updatedata.part') or return;
    # Delete the on_kick hook.
    hook_del('on_kick', 'werewolf.updatedata.kick') or return;
    # Delete the on_quit hook.
    hook_del('on_quit', 'werewolf.updatedata.quit') or return;
    # Delete the on_rehash hook.
    hook_del('on_rehash', 'werewolf.rehash') or return;

    # If a game is running, end it!
    if ($GAME or $PGAME) { _gameover('n') }

    # Success.
    return 1;
}

# Commands hash.
my %COMMANDS = (
    'join'  => 'wolf join',
    'start' => 'wolf start',
    'see'   => 'wolf see <nick>',
    'visit' => 'wolf visit <nick>',
    'guard' => 'wolf guard <nick>',
    'kill'  => 'wolf kill <nick>',
    'lynch' => 'wolf lynch <nick>',
    'shoot' => 'wolf shoot <nick>',
    'id'    => 'wolf id <nick>',
);

# Help hash for the WOLF command.
our %HELP_WOLF = (
    en => "This command allows you to perform various actions in a game of Werewolf (A.K.A. Mafia). \2Syntax:\2 WOLF (JOIN|START|LYNCH|RETRACT|SHOOT|QUIT|KICK|VOTES|STATS / SEE|ID|VISIT|GUARD|KILL) [parameters]",
);

# Callback for the WOLF command.
sub cmd_wolf {
    my ($src, @argv) = @_;

    # We require at least one parameter.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Check if this was a private or public message.
    if (exists $src->{chan}) {
        # Iterate the parameter.
        given (uc $argv[0]) {
            when (/^(JOIN|J)$/) {
                # WOLF JOIN

                # Check if a game is running.
                if (!$PGAME and !$GAME) {
                    # Check if this is the game channel.
                    if (conf_get('werewolf:chan')) {
                        if ($src->{svr}.'/'.$src->{chan} ne (conf_get('werewolf:chan'))[0][0]) {
                            notice($src->{svr}, $src->{nick}, "This is not a valid Werewolf channel. Please join \2".(conf_get('werewolf:chan'))[0][0]."\2 instead.");
                            return;
                        }
                    }
                
                    # Set variables.
                    $PGAME = 1;
                    $GAME = 0;
                    $GAMECHAN = $src->{svr}.'/'.$src->{chan};
                    $PLAYERS{lc $src->{nick}} = 0;
                    $NICKS{lc $src->{nick}} = $src->{nick};
                    $GAMETIME = time;
                
                    # Game started.
                    cmode($src->{svr}, $src->{chan}, "+v $src->{nick}");
                    privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 has started a game of Werewolf. Type \"".$FCHAR.$COMMANDS{'join'}.'" to join. Type "'.$FCHAR.$COMMANDS{start}.'" to start the game.');
                }
                elsif ($GAME) {
                    notice($src->{svr}, $src->{nick}, 'Sorry, but the game is already running. Try again next time.');
                }
                else {
                    # Check if this is the game channel.
                    if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                        notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                        return;
                    }

                    # Make sure they're not already playing.
                    if (defined $PLAYERS{lc $src->{nick}}) {
                        notice($src->{svr}, $src->{nick}, 'You\'re already playing!');
                        return;
                    }

                    # Maximum amount of players is 30.
                    if (keys %PLAYERS >= 30) {
                        notice($src->{svr}, $src->{nick}, 'Too many players! Try again next time.');
                        return;
                    }

                    # Set variables.
                    $PLAYERS{lc $src->{nick}} = 0;
                    $NICKS{lc $src->{nick}} = $src->{nick};

                    # Send message.
                    my ($gsvr, $gchan) = split '/', $GAMECHAN;
                    cmode($gsvr, $gchan, "+v $src->{nick}");
                    privmsg($gsvr, $gchan, "\2$src->{nick}\2 joined the game.");
                }
            }
            when ('START') {
                # WOLF START

                # Check if a game is running.
                if (!$PGAME) {
                    if (!$GAME) {
                        notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                        return;
                    }
                    else {
                        notice($src->{svr}, $src->{nick}, 'Werewolf is already in play.');
                        return;
                    }
                }

                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                    return;
                }

                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Check join timeout.
                if ((time - $GAMETIME) < 60) {
                    my $time = time - $GAMETIME;
                    $time = 60 - $time;
                    privmsg($src->{svr}, $src->{chan}, "$src->{nick}: Please wait at least \2$time\2 more seconds.");
                    return;
                }

                # Need four or more players.
                if (keys %PLAYERS < 4) {
                    privmsg($src->{svr}, $src->{chan}, "$src->{nick}: Four or more players are required to play.");
                    return;
                }

                # First, determine how many players to declare a wolf.
                my $cwolves = POSIX::ceil(keys(%PLAYERS) * .14);
                # Only one seer, harlot, guardian angel, traitor and detective.
                my $cseers = 1;
                my $charlots = my $cangels = my $ctraitors = my $cdetectives = 0;
                if (keys %PLAYERS >= 6) { $charlots++ unless conf_get('werewolf:rated-g') }
                if (keys %PLAYERS >= 9) { $cangels++ unless conf_get('werewolf:no-angels') }
                if (keys %PLAYERS >= 12 and conf_get('werewolf:traitors')) { $ctraitors++ }
                if (keys %PLAYERS >= 16 and conf_get('werewolf:detectives')) { $cdetectives++ }

                # Give all players a role.
                foreach my $plyr (keys %PLAYERS) { $PLAYERS{$plyr} = 'v' }
                # Push players into a temporary array.
                my @plyrs = keys %PLAYERS;

                # Set wolves.
                while ($cwolves > 0) {
                    my $rpi = $plyrs[int rand scalar @plyrs];
                    if ($PLAYERS{$rpi} !~ m/^(w|s|g|h|d|t)$/xsm) {
                        $PLAYERS{$rpi} = 'w';
                        $cwolves--;
                        $STATIC[0] .= ", \2$NICKS{$rpi}\2";
                    }
                }
                $STATIC[0] = substr $STATIC[0], 2;
                # Set seers.
                while ($cseers > 0) {
                    my $rpi = $plyrs[int rand scalar @plyrs];
                    if ($PLAYERS{$rpi} !~ m/^(w|g|h|d|t)$/xsm) {
                        $PLAYERS{$rpi} = 's';
                        $cseers--;
                        $STATIC[1] = "\2$NICKS{$rpi}\2";
                    }
                }
                # Set harlots.
                while ($charlots > 0) {
                    my $rpi = $plyrs[int rand scalar @plyrs];
                    if ($PLAYERS{$rpi} !~ m/^(w|g|s|d|t)$/xsm) {
                        $PLAYERS{$rpi} = 'h';
                        $charlots--;
                        $STATIC[2] = "\2$NICKS{$rpi}\2";
                    }
                }
                # Set guardian angels.
                while ($cangels > 0) {
                    my $rpi = $plyrs[int rand scalar @plyrs];
                    if ($PLAYERS{$rpi} !~ m/^(w|h|s|d|t)$/xsm) {
                        $PLAYERS{$rpi} = 'g';
                        $cangels--;
                        $STATIC[3] = "\2$NICKS{$rpi}\2";
                    }
                }
                # Set traitors.
                while ($ctraitors > 0) {
                    my $rpi = $plyrs[int rand scalar @plyrs];
                    if ($PLAYERS{$rpi} !~ m/^(w|h|s|d|g)$/xsm) {
                        $PLAYERS{$rpi} = 't';
                        $ctraitors--;
                        $STATIC[4] = "\2$NICKS{$rpi}\2";
                    }
                }
                # Set detectives.
                while ($cdetectives > 0) {
                    my $rpi = $plyrs[int rand scalar @plyrs];
                    if ($PLAYERS{$rpi} !~ m/^(w|h|s|g|t)$/xsm) {
                        $PLAYERS{$rpi} = 'd';
                        $cdetectives--;
                        $STATIC[5] = "\2$NICKS{$rpi}\2";
                    }
                }

                # If there's 6 or more players, give one of them a gun.
                if (keys %PLAYERS >= 6) {
                    my $rpi = $plyrs[int rand scalar @plyrs];
                    while ($PLAYERS{$rpi} =~ m/w/xsm || $PLAYERS{$rpi} =~ m/t/xsm) { $rpi = $plyrs[int rand scalar @plyrs] }
                    $PLAYERS{$rpi} .= 'b';

                    # And give them PLAYER COUNT * .12 bullets rounded up.
                    $BULLETS = POSIX::ceil(keys(%PLAYERS) * .12);
                }

                # Set variables.
                $GAME = 1;
                $PGAME = 0;

                # Set spoke variables.
                foreach (keys %PLAYERS) { $SPOKE{$_} = time }

                # All players have their role, so lets begin the game!
                my ($gsvr, $gchan) = split '/', $GAMECHAN;
                privmsg($gsvr, $gchan, 'Game is now starting.');
                cmode($gsvr, $gchan, '+m');
                # Start timer for bed checking.
                timer_add('werewolf.chkbed', 2, 5, \&M::Werewolf::_chkbed);
                # Initialize the nighttime.
                _init_night();
            }
            when (/^(LYNCH|L)$/) {
                # WOLF LYNCH

                # Check if a game is running.
                if (!$GAME) {
                    notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                    return;
                }

                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Only allow lynching during the day.
                if ($PHASE ne 'd') {
                    notice($src->{svr}, $src->{nick}, 'Lynching is only allowed during the day. Please wait patiently for morning.');
                    return;
                }
                
                # Requires an extra parameter.
                if (!defined $argv[1]) {
                    notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                    return;
                }

                # Check if they've been shot today.
                if (lc $src->{nick} ~~ @SHOT) {
                    notice($src->{svr}, $src->{nick}, 'You\'re wounded and resting, thus you are unable to vote for the day.');
                    return;
                }

                # Check if the target is playing.
                if (!exists $PLAYERS{lc $argv[1]}) {
                    notice($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently playing.");
                    return;
                }

                # If they've already voted, delete old data.
                foreach my $plyr (keys %LYNCH) {
                    if (exists $LYNCH{$plyr}{lc $src->{nick}}) { delete $LYNCH{$plyr}{lc $src->{nick}} }
                }

                # All good, proceed.
                $LYNCH{lc $argv[1]}{lc $src->{nick}} = 1;
                privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 votes for \2$argv[1]\2.");

                # Pass this thing onto lynch management.
                _lynchmng();
            }
            when (/^(RETRACT|R)$/) {
                # WOLF RETRACT

                # Check if a game is running.
                if (!$GAME) {
                    notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                    return;
                }

                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Only allow lynching during the day.
                if ($PHASE ne 'd') {
                    notice($src->{svr}, $src->{nick}, 'Lynching is only allowed during the day. Please wait patiently for morning.');
                    return;
                }
                
                # Check if they've been shot today.
                if (lc $src->{nick} ~~ @SHOT) {
                    notice($src->{svr}, $src->{nick}, 'You\'re wounded and resting, thus you are unable to vote for the day.');
                    return;
                }

                # Delete their vote.
                my ($hvi, $target);
                foreach my $plyr (keys %LYNCH) {
                    if (exists $LYNCH{$plyr}{lc $src->{nick}}) { $hvi = 1; delete $LYNCH{$plyr}{lc $src->{nick}}; $target = $plyr }
                }

                # Done.
                if ($hvi) {
                    privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 retracted his/her vote.");
                }
                else {
                    notice($src->{svr}, $src->{nick}, 'You haven\'t voted yet.');
                }
                # Call lynch management.
                _lynchmng();
            }
            when (/^(VOTES|V)$/) {
                # WOLF VOTES

                # Check if a game is running.
                if (!$GAME) {
                    notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                    return;
                }

                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # No voting at night.
                if ($PHASE ne 'd') {
                    notice($src->{svr}, $src->{nick}, 'Voting is only during the day.');
                    return;
                }

                # Return data.
                if (keys %LYNCH) {
                    my $str;
                    foreach my $key (sort {keys %{$LYNCH{$b}} <=> keys %{$LYNCH{$a}}} keys %LYNCH) {
                        my $voters;
                        if (keys %{$LYNCH{$key}}) {
                            foreach (keys %{$LYNCH{$key}}) { $voters .= " $NICKS{$_}" }
                        }
                        if ($voters) { $voters =~ s/^\s//xsm }
                        else { $voters = 0 }
                        $str .= ", $NICKS{$key}: ".keys(%{$LYNCH{$key}})." ($voters)";
                    }
                    $str = substr $str, 2;
                    privmsg($src->{svr}, $src->{chan}, "$src->{nick}: $str");
                }
                else {
                    privmsg($src->{svr}, $src->{chan}, "$src->{nick}: No votes yet.");
                }
                my $plyru = keys %PLAYERS;
                if (scalar @SHOT) { for (0..$#SHOT) { $plyru-- } }
                privmsg($src->{svr}, $src->{chan}, "$src->{nick}: \2".keys(%PLAYERS)."\2 players, \2$LVOTEN\2 votes required to lynch, \2$plyru\2 players available to vote.");
            }
            when ('SHOOT') {
                # WOLF SHOOT
            
                # Check if a game is running.
                if (!$GAME) {
                    notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                    return;
                }

                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Only allow shooting during the day.
                if ($PHASE ne 'd') {
                    notice($src->{svr}, $src->{nick}, 'Shooting is only allowed during the day. Please wait patiently for morning.');
                    return;
                }

                # They must have the gun to do this.
                if ($PLAYERS{lc $src->{nick}} !~ m/b/xsm) {
                    privmsg($src->{svr}, $src->{chan}, "$src->{nick}: You don't have the gun.");
                    return;
                }

                # They must have at least one bullet.
                if (!$BULLETS) {
                    privmsg($src->{svr}, $src->{chan}, "$src->{nick}: You don't have any more bullets.");
                    return;
                }
                
                # Requires an extra parameter.
                if (!defined $argv[1]) {
                    notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                    return;
                }

                # Check if the target is playing.
                if (!exists $PLAYERS{lc $argv[1]}) {
                    notice($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently playing.");
                    return;
                }

                # All good, lets go!
                my $real = $NICKS{lc $argv[1]};

                # Massive randomizing here. 6 = 4-kill, 1-miss, 1-suicide
                my $myr = int rand 7;
                given ($myr) {
                    when (4) { # It's a miss.
                        privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 is a lousy shooter. He/She missed!");
                    }
                    when (5) { # Gun explodes = suicide.
                        privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 should clean his/her weapons more often. The gun exploded and killed him/her!");
                        if (_getrole(lc $src->{nick}, 2) ne 'villager') { privmsg($src->{svr}, $src->{chan}, "Appears (s)he was a \2"._getrole(lc $src->{nick}, 2)."\2."); }
                        _player_del(lc $src->{nick});
                        return 1;
                    }
                    default { # It's a hit.
                        privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 shot \2$real\2 with a silver bullet!");
                        
                        # Check if the target is a wolf or a villager.
                        if ($PLAYERS{lc $argv[1]} =~ m/w/xsm) { # Wolf.
                            privmsg($src->{svr}, $src->{chan}, "\2$real\2 is a wolf, and is dying from the silver bullet.");
                            _player_del(lc $argv[1]);
                        }
                        else { # Villager.
                            # So, there's a 1/5 chance of a villager dying.
                            my $rint = int rand 6;
                            given ($rint) {
                                when (5) { # Killed.
                                    privmsg($src->{svr}, $src->{chan}, "\2$real\2 is a villager, but \2$src->{nick}\2 accidentally shot them in the head and they are now dying.");
                                    if (_getrole(lc $real, 2) ne 'villager') { privmsg($src->{svr}, $src->{chan}, "Appears (s)he was a \2"._getrole(lc $real, 2)."\2."); }
                                    # Kill them.
                                    _player_del(lc $real);
                                }
                                default { # Only hurt.
                                    privmsg($src->{svr}, $src->{chan}, "\2$real\2 is a villager, and is hurt but will have a full recovery. He/She will be resting for the day.");
                                    push @SHOT, lc $real;
                                    # Delete any votes they might've made today.
                                    foreach my $plyr (keys %LYNCH) {
                                        if (exists $LYNCH{$plyr}{lc $real}) { delete $LYNCH{$plyr}{lc $real} }
                                    }
                                    # Set number of votes required to lynch.
                                    $LVOTEN = int(scalar(keys(%PLAYERS)) / 2 + 1);
                                }
                            }
                        }
                    }
                }

                # Decrement bullet count.
                $BULLETS--;
                # Call lynch management.
                _lynchmng();
            }
            when (/^(STATS|S)$/) {
                # WOLF STATS

                # Check if a game is running.
                if (!$GAME and !$PGAME) {
                    notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                    return;
                }

                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Return data.
                my $str;
                foreach (keys %PLAYERS) { $str .= ", $NICKS{$_}" }
                $str = substr $str, 2;
                privmsg($src->{svr}, $src->{chan}, "$src->{nick}: \2".keys(%PLAYERS)."\2 players: $str");
                # If all roles have been assigned, return the count of each.    
                if ($GAME) {
                    my $cwolves = my $cseers = my $charlots = my $cangels = my $ctraitors = my $cdetectives = 0;
                    foreach my $flags (values %PLAYERS) {
                        if ($flags =~ m/w/xsm) { $cwolves++ }
                        if ($flags =~ m/s/xsm) { $cseers++ }
                        if ($flags =~ m/h/xsm) { $charlots++ }
                        if ($flags =~ m/g/xsm) { $cangels++ }
                        if ($flags =~ m/t/xsm) { $ctraitors++ }
                        if ($flags =~ m/d/xsm) { $cdetectives++ }
                    }
                    privmsg($src->{svr}, $src->{chan}, "$src->{nick}: There are \2$cwolves\2 wolves, \2$cseers\2 seers, ".
                        "\2$charlots\2 ".((conf_get('werewolf:rated-g')) ? '<removed>' : 'harlots').", \2$ctraitors\2 traitors, \2$cdetectives\2 detectives, ".
                        "and \2$cangels\2 guardian angels.");
                }
            }
            when (/^(KICK|K)$/) {
                # WOLF KICK

                # Check if a game is running.
                if (!$GAME and !$PGAME) {
                    notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                    return;
                }

                # Check for the werewolf.admin privilege.
                if (!has_priv(match_user(%{$src}), 'werewolf.admin')) {
                    notice($src->{svr}, $src->{nick}, trans('Permission denied').q{.});
                    return;
                }
                
                # Requires an extra parameter.
                if (!defined $argv[1]) {
                    notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                    return;
                }

                # Kill the target.
                privmsg($src->{svr}, $src->{chan}, "\2$argv[1]\2 died of an unknown disease. He/She was a \2"._getrole(lc $argv[1], 2)."\2.");
                _player_del(lc $argv[1]);
            }
            when (/^(QUIT|Q)$/) {
                # WOLF QUIT

                # Check if a game is running.
                if (!$GAME and !$PGAME) {
                    notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$GAMECHAN\2.");
                    return;
                }
                
                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }
                
                # Kill the target.
                privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 died of an unknown disease. He/She was a \2"._getrole(lc $src->{nick}, 2)."\2.");
                _player_del(lc $src->{nick});
            }
            default { notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.}); }
        }
    }
    else {
        given (uc $argv[0]) {
            # Iterate the parameter.
            when ('SEE') {
                # WOLF SEE

                # Check if a game is running.
                if (!$GAME) {
                    privmsg($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Check if they are the seer.
                if ($PLAYERS{lc $src->{nick}} !~ m/s/xsm) {
                    privmsg($src->{svr}, $src->{nick}, 'Only the seer may use this command.');
                    return;
                }

                # Check if it's nighttime.
                if ($PHASE ne 'n') {
                    privmsg($src->{svr}, $src->{nick}, 'You may only have visions at night.');
                    return;
                }

                # Check if they've already had a vision.
                if ($SEEN) {
                    privmsg($src->{svr}, $src->{nick}, 'You may only have one vision per round.');
                    return;
                }

                # Requires an extra parameter.
                if (!defined $argv[1]) {
                    privmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                    return;
                }

                # Check if the requested nick is playing.
                if (!exists $PLAYERS{lc $argv[1]}) {
                    privmsg($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently playing.");
                    return;
                }

                # All good, proceed.
                privmsg($src->{svr}, $src->{nick}, "You have a vision; in this vision, you see that \2$argv[1]\2 is a... \2"._getrole(lc $argv[1], 1)."\2!");
                $SEEN = 1;
                # Run nighttime force end check.
                _chknight();
            }
            when ('ID') {
                # WOLF ID

                # Check if a game is running.
                if (!$GAME) {
                    privmsg($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Check if they are the detective.
                if ($PLAYERS{lc $src->{nick}} !~ m/d/xsm) {
                    privmsg($src->{svr}, $src->{nick}, 'Only the detective may use this command.');
                    return;
                }

                # Check if it's daytime.
                if ($PHASE ne 'd') {
                    privmsg($src->{svr}, $src->{nick}, 'You may only investigate people during the day.');
                    return;
                }

                # Check if they've already investigated someone.
                if ($DETECTED) {
                    privmsg($src->{svr}, $src->{nick}, 'You may only investigate one person per round.');
                    return;
                }

                # Requires an extra parameter.
                if (!defined $argv[1]) {
                    privmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                    return;
                }

                # Check if the requested nick is playing.
                if (!exists $PLAYERS{lc $argv[1]}) {
                    privmsg($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently playing.");
                    return;
                }

                # All good, proceed.
                privmsg($src->{svr}, $src->{nick}, "The results of your investigation have returned. \2$argv[1]\2 is a... \2"._getrole(lc $argv[1], 2)."\2!");
                $DETECTED = 1;

                # Now, take the 2/5 chance of revealing their identity to the wolves.
                my $rint = int rand 6;
                if ($rint =~ m/^(1|5)$/xsm) {
                    # Ouch. Gotta rat 'em out.
                    while (my ($ruser, $rflags) = each %PLAYERS) {
                        if ($rflags =~ m/w/xsm or $rflags =~ m/t/xsm) {
                            privmsg($src->{svr}, $NICKS{$ruser}, "\2$src->{nick}\2 accidentally drops a paper. The paper reveals that (s)he is the detective!");
                        }
                    }
                }
            }
            when ('GUARD') {
                # WOLF GUARD

                # Check if a game is running.
                if (!$GAME) {
                    privmsg($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Check if they are the guardian angel.
                if ($PLAYERS{lc $src->{nick}} !~ m/g/xsm) {
                    privmsg($src->{svr}, $src->{nick}, 'Only the guardian angel may use this command.');
                    return;
                }

                # Check if it's nighttime.
                if ($PHASE ne 'n') {
                    privmsg($src->{svr}, $src->{nick}, 'You may only protect people at night.');
                    return;
                }

                # They can only protect one person per round.
                if ($GUARD) {
                    privmsg($src->{svr}, $src->{nick}, "You are already protecting \2$NICKS{$VISIT}\2.");
                    return;
                }

                # Requires an extra parameter.
                if (!defined $argv[1]) {
                    privmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                    return;
                }

                # Check if the requested nick is playing.
                if (!exists $PLAYERS{lc $argv[1]}) {
                    privmsg($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently playing.");
                    return;
                }

                # They cannot guard themselves.
                if (lc $argv[1] eq lc $src->{nick}) {
                    privmsg($src->{svr}, $src->{nick}, 'You may not guard yourself!');
                    return;
                }

                # All good, proceed.
                $GUARD = lc $argv[1];
                privmsg($src->{svr}, $src->{nick}, "You are protecting \2$argv[1]\2 for the night. Farewell!");
                privmsg($src->{svr}, $NICKS{lc $argv[1]}, 'You can sleep well tonight, for the guardian angel is protecting you.');
                # Run nighttime force end check.
                _chknight();
            }
            when ('VISIT') {
                # WOLF VISIT

                # Check if a game is running.
                if (!$GAME) {
                    privmsg($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Check if they are the harlot.
                if ($PLAYERS{lc $src->{nick}} !~ m/h/xsm) {
                    privmsg($src->{svr}, $src->{nick}, 'Only the harlot may use this command.');
                    return;
                }

                # Check if it's nighttime.
                if ($PHASE ne 'n') {
                    privmsg($src->{svr}, $src->{nick}, 'You may only visit people at night.');
                    return;
                }

                # They can only visit one person per round.
                if ($VISIT) {
                    privmsg($src->{svr}, $src->{nick}, "You are already spending the night with \2$NICKS{$VISIT}\2!");
                    return;
                }

                # Requires an extra parameter.
                if (!defined $argv[1]) {
                    privmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                    return;
                }

                # Check if the requested nick is playing.
                if (!exists $PLAYERS{lc $argv[1]}) {
                    privmsg($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently playing.");
                    return;
                }

                # They can't sleep with themselves.
                if (lc $argv[1] eq lc $src->{nick}) {
                    privmsg($src->{svr}, $src->{nick}, 'You cannot sleep with yourself!');
                    return;
                }
                
                # All good, set variables and stuff.
                $VISIT = lc $argv[1];
                privmsg($src->{svr}, $src->{nick}, "You are spending the night with \2$argv[1]\2. Have a good time!");
                privmsg($src->{svr}, $NICKS{lc $argv[1]}, "You are spending the night with \2$src->{nick}\2, the village harlot. Have a good time!");
                # Run nighttime force end check.
                _chknight();
            }
            when ('KILL') {
                # WOLF KILL

                # Check if a game is running.
                if (!$GAME) {
                    privmsg($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                
                # Make sure they're playing.
                if (!defined $PLAYERS{lc $src->{nick}}) {
                    notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                    return;
                }

                # Check if they are a wolf.
                if ($PLAYERS{lc $src->{nick}} !~ m/w/xsm) {
                    privmsg($src->{svr}, $src->{nick}, 'Only a wolf may use this command.');
                    return;
                }

                # Check if it's nighttime.
                if ($PHASE ne 'n') {
                    privmsg($src->{svr}, $src->{nick}, 'You may only kill people at night.');
                    return;
                }

                # Requires an extra parameter.
                if (!defined $argv[1]) {
                    privmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                    return;
                }
                
                # Check if the requested nick is playing.
                if (!exists $PLAYERS{lc $argv[1]}) {
                    privmsg($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently playing.");
                    return;
                }

                # Check if they're trying to kill themselves.
                if (lc $argv[1] eq lc $src->{nick}) {
                    privmsg($src->{svr}, $src->{nick}, 'Suicide is bad, don\'t do it.');
                    return;
                }

                # Don't let them kill other wolves.
                if ($PLAYERS{lc $argv[1]} =~ m/w/xsm) {
                    privmsg($src->{svr}, $src->{nick}, 'You may only kill villagers, not other wolves.');
                    return;
                }

                # If they're changing their selection, reverse the old victim's data.
                if ($WKILL{lc $src->{nick}}) {
                    $KILL{lc $WKILL{lc $src->{nick}}}--;
                }

                # All good, proceed.
                $KILL{lc $argv[1]}++;
                $WKILL{lc $src->{nick}} = lc $argv[1];
                privmsg($src->{svr}, $src->{nick}, "You have selected \2$argv[1]\2 to be killed.");
                # Run nighttime force end check.
                _chknight();
            }
            default { notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.}); }
        }
    }

    return 1;
}

# Change time to night.
sub _init_night {
    my ($gsvr, $gchan) = split '/', $GAMECHAN;
    $PHASE = 'n';

    # Iterate through all players.
    foreach my $plyr (keys %PLAYERS) {
        my $role = $PLAYERS{$plyr};
        # Check if they have a special role.
        if ($role =~ m/(w|h|s|g|d|t)/xsm) {
            my ($erole, $msg);
            # For wolves.
            if ($role =~ m/w/xsm) {
                $erole = 'wolf';
                $msg = "It is your job to kill all the villagers. Use \"$COMMANDS{kill}\" to kill a villager. Also, if you send a PM to me, it will be relayed to all other wolves.\n&pi&";
                my $cwolves = 0;
                for (values %PLAYERS) { if (m/w/xsm) { $cwolves++ } }
                if ($cwolves > 1) { $msg .= "\nAlso, please consider using PM's or a channel to speak with your fellow wolves rather than my relay, to prevent from me lagging." }
            }
            # For harlots.
            elsif ($role =~ m/h/xsm) {
                $erole = 'harlot';
                $msg = "You may spend the night with one person per round. If you visit a victim of a wolf, or visit a wolf, you will die. Use \"$COMMANDS{visit}\" to visit a player.\n&ph&";
            }
            # For seers.
            elsif ($role =~ m/s/xsm) {
                $erole = 'seer';
                $msg = "It is your job to detect the wolves, you may have a vision once per night. Use \"$COMMANDS{see}\" to see the role of a player.\n&ph&";
            }
            # For guardian angels.
            elsif ($role =~ m/g/xsm) {
                $erole = 'guardian angel';
                $msg = "It is your job to protect the villagers. If you guard a wolf, there is a 50/50 chance of you dying, if you guard a victim, they will live. Use \"$COMMANDS{guard}\" to guard a player.\n&ph&";
            }
            # For detectives.
            elsif ($role =~ m/d/xsm) {
                $erole = 'detective';
                $msg = "It is your job to determine all the wolves and traitors. Your job is during the day, and you can see the true identity of all users, even traitors.";
                $msg .= "\nBut, each time you use your ability, you risk a 2/5 chance of having your identity revealed to the wolves. So be careful. Use \"$COMMANDS{id}\" to identify any player during the day.";
            }
            # For traitors.
            elsif ($role =~ m/t/xsm) {
                $erole = 'traitor';
                $msg = "You are a villager, but are on the side of the wolves. You're exactly like a villager and not even a seer can see your true identity. Only detectives can.\n&pi&";
                $msg .= "\nAll your messages are relayed to the wolves and vice versa, but, to contact the wolves, consider using PM's or a channel to speak with them rather than my relay, to prevent from me lagging.";
            }

            # Split message at \n.
            my @data = split "\n", $msg;

            # Set &pi& and &ph&.
            my $pi;
            while (my ($pnick, $prole) = each %PLAYERS) {
                if ($pnick eq $plyr) { next }
                $pi .= ", $NICKS{$pnick}";
                if ($prole =~ m/w/xsm) { $pi .= ' (wolf)' }
                if ($prole =~ m/t/xsm) { $pi .= ' (traitor)' }
            }
            $pi =~ s/^,\s//xsm;
            $data[1] =~ s/&pi&/Players: $pi/gxsm;
            my $ph;
            foreach my $pnick (keys %PLAYERS) { if ($pnick eq $plyr) { next }; $ph .= ", $NICKS{$pnick}" }
            $ph =~ s/^,\s//xsm;
            $data[1] =~ s/&ph&/Players: $ph/gxsm;

            # Give them their information.
            privmsg($gsvr, $NICKS{$plyr}, "You are a \2$erole\2. $data[0]"); 
            privmsg($gsvr, $NICKS{$plyr}, $data[1]);
            if ($data[2]) { privmsg($gsvr, $NICKS{$plyr}, $data[2]) }
        }
        # Check if they have the gun.
        if ($role =~ m/b/xsm and $BULLETS) {
            privmsg($gsvr, $NICKS{$plyr}, 'You hold a special gun. You may only use it during the day. If you shoot a wolf, (s)he will die instantly, if you shoot a villager, they will likely live. You get '.$BULLETS.' shot(s).');
            privmsg($gsvr, $NICKS{$plyr}, 'To shoot someone, type "'.$FCHAR.$COMMANDS{shoot}.'" in the channel during the day.');
        }
    }

    # It is now nighttime.
    %LYNCH = ();
    $DETECTED = 0;
    privmsg($gsvr, $gchan, 'It is now nighttime. All players check for PM\'s from me for instructions. If you did not receive one, simply sit back, relax, and wait patiently for morning.');
    timer_add('werewolf.goto_daytime', 1, 90, sub { M::Werewolf::_init_day() });

    return 1;
}

# Change time to day.
sub _init_day {
    my ($gsvr, $gchan) = split '/', $GAMECHAN;
    
    # We need wolf count.
    my $wolves = 0;
    for (values %PLAYERS) { if (m/w/xsm) { $wolves++ } }
    # For starters, lets determine if there's a victim to kill.
    my $victim;
    if (keys %KILL) {
        # First lets figure out if we have multiple wolves.
        if ($wolves == 1) {
            ($victim) = keys %KILL;
        }
        else {
            my $victv = 0;
            # Check which player had the most votes. If all wolves gave different votes, choose a random one.
            while (my ($plyr, $votec) = each %KILL) {
                if ($votec > $victv) { $victv = $votec; $victim = $plyr }
            }
        }
    }
    
    # Now check if the guardian angel protected the victim last night.
    if ($victim and $GUARD) {
        # If the victim was protected, set $victim to 1.
        if ($GUARD eq $victim) { $victim = 1 }
    }

    # Now check if the harlot spent the night with the victim last night.
    my $harlotd = 0;
    if (defined $victim and $VISIT) {
        if ($victim !~ m/^(0|1)$/xsm) {
            if ($VISIT eq $victim) {
                # Ouch! He/She did, gotta kill them. :(
                $harlotd = 1;
            }
        }
    }
    # Now check if the harlot spent the night with a wolf last night.
    if (!$harlotd and $VISIT) {
        if ($PLAYERS{$VISIT} =~ m/w/xsm) {
            # Ouch! He/She did, gotta kill them. :(
            $harlotd = 2;
        }
    }

    # Last check; lets find out if the guardian angel protected a wolf last night.
    my $angeld;
    if ($GUARD) {
        if ($PLAYERS{$GUARD} =~ m/w/xsm) {
            # Ouch. He/She did, so determine if they die or not. (50/50 chance)
            my $rint = int rand 11;
            given ($rint) {
                when (/^(1|3|5|7|9)$/) { $angeld = 0 }
                when (/^(2|4|6|8|10)$/) { $angeld = 1 }
                default { $angeld = 0 }
            }
        }
    }

    # Finally, check if the harlot was targeted and wasn't home.
    if (_getrole($victim, 2) eq 'harlot' and $VISIT) {
        privmsg($gsvr, $gchan, 'The wolves attempted to attack the harlot last night, but (s)he wasn\'t home...');
        $victim = 0;
    }

    # Set phase to day.
    $PHASE = 'd';
    
    # Cool, all data should be ready for shipment. Lets go!
    my $continue = 1;
    my $msg = 'It is now daytime. The villagers awake, thankful for surviving the night, and search the village...';
    if (!$victim) { privmsg($gsvr, $gchan, "$msg The body of a young penguin pet is found. All villagers however, have survived.") }
    elsif ($victim eq 1) {
        privmsg($gsvr, $gchan, "$msg \2$NICKS{$GUARD}\2 was attacked by the wolves last night, but luckily, the guardian angel protected them.");
    }
    else {
        privmsg($gsvr, $gchan, "$msg The dead body of \2$NICKS{$victim}\2, a \2"._getrole($victim, 2)."\2, is found. Those remaining mourn his/her death.");
        $continue = _player_del($victim);
        if ($harlotd == 1) {
            my $harlot;
            while (my ($cuser, $crole) = each %PLAYERS) { if ($crole =~ m/h/xsm) { $harlot = $cuser } }
            if ($harlot) { # Unusual cases call for this.
                privmsg($gsvr, $gchan, "\2$NICKS{$harlot}\2, the village harlot, made the unfortunate mistake of visiting the victim last night, and is now dead.");
                $continue = _player_del($harlot);
            }
        }
    }
    # Check if the harlot visited a wolf.
    if ($harlotd == 2) {
        my $harlot;
        while (my ($cuser, $crole) = each %PLAYERS) { if ($crole =~ m/h/xsm) { $harlot = $cuser } }
        if ($harlot) { # Unusual cases call for this.
            privmsg($gsvr, $gchan, "\2$NICKS{$harlot}\2, the village harlot, made the unfortunate mistake of visiting a wolf last night, and is now dead.");
            $continue = _player_del($harlot);
        }
    }
    # Check if the angel guarded a wolf.
    if ($angeld) {
        my $angel;
        while (my ($cuser, $crole) = each %PLAYERS) { if ($crole =~ m/g/xsm) { $angel = $cuser } }
        if ($angel) { # Unusual cases call for this.
            privmsg($gsvr, $gchan, "\2$NICKS{$angel}\2, the guardian angel, made the unfortunate mistake of guarding a wolf last night, attempted to escape, but failed and is now dead.");
            $continue = _player_del($angel);
        }
    }

    # If there was a winning condition, don't initialize daytime.
    if (!$continue) { return 1 }

    # Set number of votes required to lynch.
    $LVOTEN = int(scalar(keys(%PLAYERS)) / 2 + 1);
    privmsg($gsvr, $gchan, 'The villagers must now vote for who to lynch. Use "'.$FCHAR.$COMMANDS{lynch}.'" to cast your vote. '.$LVOTEN.' votes are required to lynch.');
    
    # Clear variables.
    $SEEN = $GUARD = $VISIT = 0;
    @SHOT = ();
    %KILL = ();
    %WKILL = ();

    return 1;
}

# Subroutine for checking if we should force the night to end.
sub _chknight {
    # Get a current count of each role.
    my $cwolves = my $cseers = my $charlots = my $cangels = 0;
    foreach my $flags (values %PLAYERS) {
        if ($flags =~ m/w/xsm) { $cwolves++ }
        if ($flags =~ m/s/xsm) { $cseers++ }
        if ($flags =~ m/h/xsm) { $charlots++ }
        if ($flags =~ m/g/xsm) { $cangels++ }
    }

    # Lets start with checking if all wolves have voted.
    if (keys %WKILL != $cwolves) {
        # They haven't, return.
        return;
    }
    # Next check if the seer has had their vision.
    if ($cseers && !$SEEN) {
        # They haven't, return.
        return;
    }
    # Now check if the harlot has chosen someone to visit.
    if ($charlots && !$VISIT) {
        # They haven't, return.
        return;
    }
    # Finally check if the angel has chosen someone to guard.
    if ($cangels && !$GUARD) {
        # They haven't, return.
        return;
    }

    # All players have fulfilled their respective roles. Thus, it is
    # pointless to wait for morning. Delete night timeout timer and force
    # daytime initialization.
    timer_del('werewolf.goto_daytime');
    _init_day();

    return 1;
}

# For performing lynches.
sub _judgment {
    my ($nick) = @_;

    # Kill him/her!
    my ($gsvr, $gchan) = split '/', $GAMECHAN;
    privmsg($gsvr, $gchan, "The villagers, after much debate, finally decide on lynching \2$NICKS{$nick}\2, who turned out to be... a \2"._getrole($nick, 2)."\2.");
    my $ri = _player_del($nick, 1);

    # Initialize nighttime.
    if ($ri) { _init_night() }

    return 1;
}

# Subroutine for checking who is in bed and who is not.
sub _chkbed {
    my ($gsvr, $gchan) = split '/', $GAMECHAN, 2;
    # Array for warnings.
    my @warn;
    # Iterate through all SPOKE players.
    while (my ($plyr, $time) = each %SPOKE) {
        my $since = time - $time;
        # Check if they should be kicked right now.
        if ($since >= 300) {
            privmsg($gsvr, $gchan, "\2$NICKS{$plyr}\2 didn't get out of bed for a very long time. He/She is declared dead. Appears (s)he was a \2"._getrole($plyr, 2)."\2.");
            my $ri = _player_del($plyr);
            if (!$ri) { last }
        }
        # Perhaps they should just get a warning.
        elsif ($since >= 180) {
            if (!exists $WARN{$plyr}) {
                push @warn, $NICKS{$plyr};
                $WARN{$plyr} = 1;
            }
        }
    }

    # Send out any warnings.
    if (scalar @warn) {
        privmsg($gsvr, $gchan, join(', ', @warn).": \2You have been idling for a while. Please remember to say something soon or you might be declared dead.\2") 
    }

    return 1;
}

# Return the role of a player.
sub _getrole {
    my ($plyr, $lev) = @_;

    if (!$plyr) { return 'person' }

    my $role;
    if (exists $PLAYERS{$plyr}) {
        if ($lev == 1) {
            if ($PLAYERS{$plyr} =~ m/w/xsm) { $role = 'wolf' }
            elsif ($PLAYERS{$plyr} =~ m/s/xsm) { $role = 'seer' }
            elsif ($PLAYERS{$plyr} =~ m/h/xsm) { $role = 'harlot' }
            elsif ($PLAYERS{$plyr} =~ m/g/xsm) { $role = 'guardian angel' }
            elsif ($PLAYERS{$plyr} =~ m/d/xsm) { $role = 'detective' }
            elsif ($PLAYERS{$plyr} =~ m/(v|t)/xsm) { $role = 'villager' }
        }
        elsif ($lev == 2) {
            if ($PLAYERS{$plyr} =~ m/w/xsm) { $role = 'wolf' }
            elsif ($PLAYERS{$plyr} =~ m/s/xsm) { $role = 'seer' }
            elsif ($PLAYERS{$plyr} =~ m/h/xsm) { $role = 'harlot' }
            elsif ($PLAYERS{$plyr} =~ m/g/xsm) { $role = 'guardian angel' }
            elsif ($PLAYERS{$plyr} =~ m/d/xsm) { $role = 'detective' }
            elsif ($PLAYERS{$plyr} =~ m/t/xsm) { $role = 'traitor' }
            elsif ($PLAYERS{$plyr} =~ m/v/xsm) { $role = 'villager' }
        }
    }
    if (!$role) { $role = 'person' }
    
    return $role;
}

# Delete a player.
sub _player_del {
    my ($player, $judgment) = @_;
    my ($gsvr, $gchan) = split '/', $GAMECHAN;

    # Devoice them.
    cmode($gsvr, $gchan, "-v $NICKS{$player}");

    # Delete variables.
    delete $PLAYERS{$player};
    delete $NICKS{$player};
    delete $SPOKE{$player};
    if (exists $WARN{$player}) { delete $WARN{$player} }
    if (exists $KILL{$player}) { delete $KILL{$player} }
    foreach my $acpl (keys %LYNCH) {
        if (exists $LYNCH{$acpl}{$player}) { delete $LYNCH{$acpl}{$player} }
    }
    foreach my $acpl (keys %LYNCH) {
        if ($acpl eq $player) { delete $LYNCH{$acpl} }
    }
    if ($VISIT) { if ($VISIT eq $player) { $VISIT = 0 } }
    if ($GUARD) { if ($GUARD eq $player) { $GUARD = 0 } }
    if (scalar @SHOT) {
        for (0..$#SHOT) {
            if ($SHOT[$_] eq lc $player) {
                splice @SHOT, $_, 1;
            }
        }
    }
    if ($SEEN) { if ($SEEN eq $player) { $SEEN = 0 } }
    
    # Update LVOTEN.
    if ($LVOTEN) { $LVOTEN = int(scalar(keys(%PLAYERS)) / 2 + 1) }
    
    # Check for winning conditions.
    if (!$PGAME) {
        my $wolves;
        for (values %PLAYERS) { if (m/w/xsm) { $wolves++ } }
        if (!$wolves) { _gameover('v'); return }
        my $villagers;
        for (values %PLAYERS) { if (m/(v|s|g|h|d)/xsm) { $villagers++ } }
        if ($villagers <= $wolves) { _gameover('w'); return }
    }
    else {
        # Check if there's any more players.
        if (!keys %PLAYERS) { _gameover('n') }
    }
    
    # Call lynch management IF judgment did not call us.
    if ($PHASE and !$judgment) {
        if ($PHASE eq 'd') { _lynchmng() }
    }

    # Check if nighttime should end, given we are night.
    if ($PHASE) { if ($PHASE eq 'n') { _chknight() } }

    return 1;
}

# Subroutine for managing/cleaning lynch votes.
sub _lynchmng {
    # Iterate through all the votes.
    foreach my $acc (keys %LYNCH) {
        if (!keys %{$LYNCH{$acc}}) {
            # Unclean vote. Delete it.
            delete $LYNCH{$acc};
        }
    }

    # Now check if we have anyone who has enough votes for judgment.
    foreach my $acc (keys %LYNCH) {
        if (keys %{$LYNCH{$acc}} >= $LVOTEN) { _judgment($acc); last }
    }

    return 1;
}

# Handling the end of the game.
sub _gameover {
    my ($winner) = @_;
    my ($gsvr, $gchan) = split '/', $GAMECHAN;

    if ($winner eq 'v') { # The villagers won!
        privmsg($gsvr, $gchan, 'Game over! All the wolves are dead! The villagers chop them up, BBQ them, and have a hearty meal.');
    }
    elsif ($winner eq 'w') { # The wolves won!
        privmsg($gsvr, $gchan, 'Game over! There is the same amount of wolves as villagers. The wolves eat everyone, and win.');
    }
    else { # No players.
        privmsg($gsvr, $gchan, 'No more players remaining. Game ended.');
    }

    if ($GAME) {
        my $smsg = "The wolves were $STATIC[0]. The seer was $STATIC[1].";
        if ($STATIC[0] !~ m/,/xsm) { $smsg =~ s/wolves\swere/wolf was/xsm }
        if ($STATIC[2]) { $smsg .= " The harlot was $STATIC[2]." }
        if ($STATIC[3]) { $smsg .= " The guardian angel was $STATIC[3]." }
        if ($STATIC[4]) { $smsg .= " The traitor was $STATIC[4]." }
        if ($STATIC[5]) { $smsg .= " The detective was $STATIC[5]." }
        privmsg($gsvr, $gchan, $smsg);
    }

    # Set -m, unless explicitly told not to in config.
    if (!conf_get('werewolf:always-m')) { cmode($gsvr, $gchan, '-m') }

    # Devoice all users.
    my ($gc, $gn, @gu);
    $gc = $gn = 0;
    foreach my $nick (values %NICKS) {
        $gu[$gc] .= " $nick";
        $gn++;
        if ($gn > 3) { $gn = 0; $gc++ }
    }
    foreach (@gu) { cmode($gsvr, $gchan, "-vvvv$_") }

    # Clear all variables.
    if ($PHASE) { if ($PHASE eq 'n') { timer_del('werewolf.goto_daytime') } }
    timer_del('werewolf.chkbed');
    $GAME = $PGAME = $GAMECHAN = $GAMETIME = $PHASE = $SEEN = $VISIT = $GUARD = $LVOTEN = $BULLETS = $DETECTED = 0;
    %PLAYERS = ();
    %NICKS = ();
    %KILL = ();
    %WKILL = ();
    %LYNCH = ();
    %SPOKE = ();
    %WARN = ();
    @STATIC = ();
    @SHOT = ();

    return 1;
}

# Handle channel messages.
sub on_cprivmsg {
    my ($src, $chan, undef) = @_;

    # First, check if a game is running.
    if ($GAME) {
        # Check if this is the game channel.
        if (lc $src->{svr}.'/'.$chan eq lc $GAMECHAN) {
            # Check if this person is playing.
            if (exists $PLAYERS{lc $src->{nick}}) {
                # Set their spoke variable to current time.
                $SPOKE{lc $src->{nick}} = time;
                if (exists $WARN{lc $src->{nick}}) { delete $WARN{lc $src->{nick}} }
            }
        }
    }

    return 1;
}

# Handle private messages.
sub on_uprivmsg {
    my ($src, @msg) = @_;

    # Check if a game is running.
    if ($GAME) {
        # Ensure no-wolfrelay is not set in config.
        if (!conf_get('werewolf:no-wolfrelay')) {
            # Check if this person is playing.
            if (exists $PLAYERS{lc $src->{nick}}) {
                # Check if they're a wolf/traitor.
                if ($PLAYERS{lc $src->{nick}} =~ m/w/xsm or $PLAYERS{lc $src->{nick}} =~ m/t/xsm) {
                    # Get wolf count.
                    my $cwolves = 0;
                    foreach my $flags (values %PLAYERS) { if ($flags =~ m/(w|t)/xsm) { $cwolves++ } }
                    # If there's more than one wolf, relay this message to the others.
                    if ($cwolves > 1) {
                        while ((my $plyr, my $flags) = each %PLAYERS) { 
                            if ($plyr ne lc $src->{nick} and $flags =~ m/w/xsm or $flags =~ m/t/xsm) {
                                # Also, lets try to ignore simulations.
                                if (uc(join(q{ }, @msg)) =~ m/^WOLF KILL/xsmi and
                                    split(q{ }, $COMMANDS{kill}, 2) ne ('wolf', 'kill')) { return 1 }
                                
                                # All good.
                                privmsg($src->{svr}, $NICKS{$plyr}, "\2$src->{nick}\2 says: ".join(q{ }, @msg));
                            }
                        }
                    }
                }
            }
        }
    }

    return 1;
}

# Handle nick changes.
sub on_nick {
    my ($src, $newnick) = @_;
    my $new = lc $newnick;

    # Check if a game is running.
    if ($GAME or $PGAME) {
        # Check if they're playing.
        if (exists $PLAYERS{lc $src->{nick}}) {
            # Time to update their data.
            # Hopefully this will work right, but if it doesn't, someone please make a bug report.
            $PLAYERS{$new} = $PLAYERS{lc $src->{nick}};
            $NICKS{$new} = $newnick;
            $SPOKE{$new} = $SPOKE{lc $src->{nick}};
            $WARN{$new} = $WARN{lc $src->{nick}};
            delete $PLAYERS{lc $src->{nick}};
            delete $NICKS{lc $src->{nick}};
            delete $SPOKE{lc $src->{nick}};
            delete $WARN{lc $src->{nick}};
            if (scalar @SHOT) {
                for (0..$#SHOT) {
                    if ($SHOT[$_] eq lc $src->{nick}) {
                        splice @SHOT, $_, 1;
                        push @SHOT, $new;
                    }
                }
            }
            if ($GUARD) { if ($GUARD eq lc $src->{nick}) { $GUARD = $new } }
            if ($VISIT) { if ($VISIT eq lc $src->{nick}) { $VISIT = $new } }
            if (exists $KILL{lc $src->{nick}}) {
                $KILL{$new} = $KILL{lc $src->{nick}};
                delete $KILL{lc $src->{nick}};
            }
            if (exists $WKILL{lc $src->{nick}}) {
                $WKILL{$new} = $WKILL{lc $src->{nick}};
                delete $WKILL{lc $src->{nick}};
            }
            if (exists $LYNCH{lc $src->{nick}}) {
                $LYNCH{$new} = $LYNCH{lc $src->{nick}};
                delete $LYNCH{lc $src->{nick}};
            }
            foreach my $accu (keys %LYNCH) {
                my %sers = %{$LYNCH{$accu}};
                foreach my $ser (keys %sers) {
                    if ($ser eq lc $src->{nick}) {
                        $LYNCH{$accu}{$new} = 1;
                        delete $LYNCH{$accu}{$ser};
                    }
                }
            }
            # That should be everything.
        }
    }

    return 1;
}

# Handle channel parts.
sub on_part {
    my ($src, $chan, undef) = @_;

    # Check if a game is running.
    if ($GAME or $PGAME) {
        # Check if this is the game channel.
        if (lc $src->{svr}.'/'.$chan eq lc $GAMECHAN) {
            # If they're playing, they're not anymore.
            if (exists $PLAYERS{lc $src->{nick}}) {
                my ($gsvr, $gchan) = split '/', $GAMECHAN;
                privmsg($gsvr, $gchan, "\2$src->{nick}\2 died due to eating poisonous berries. Appears (s)he was a \2"._getrole(lc $src->{nick}, 2)."\2.");
                _player_del(lc $src->{nick});
            }
        }
    }

    return 1;
}

# Handle channel kicks.
sub on_kick {
    my ($src, $chan, $user, undef) = @_;

    # Check if a game is running.
    if ($GAME or $PGAME) {
        # Check if this is the game channel.
        if (lc $src->{svr}.'/'.$chan eq lc $GAMECHAN) {
            # If they're playing, they're not anymore.
            if (exists $PLAYERS{lc $user}) {
                my ($gsvr, $gchan) = split '/', $GAMECHAN;
                privmsg($gsvr, $gchan, "\2$user\2 died due to falling off a cliff. Appears (s)he was a \2"._getrole(lc $user, 2)."\2.");
                _player_del(lc $user);
            }
        }
    }

    return 1;
}

# Handle network disconnects.
sub on_quit {
    my ($src, $msg) = @_;

    # Check if a game is running.
    if ($GAME or $PGAME) {
        # If they're playing, continue.
        if (exists $PLAYERS{lc $src->{nick}}) {
            # First make sure it's not chghost-quit.
            if (conf_get('werewolf:chghost-quit')) {
                if ($msg eq (conf_get('werewolf:chghost-quit'))[0][0]) { return }
            }

            # Kill them.
            my ($gsvr, $gchan) = split '/', $GAMECHAN;
            privmsg($gsvr, $gchan, "\2$src->{nick}\2 died due to a fatal attack by wild animals. Appears (s)he was a \2"._getrole(lc $src->{nick}, 2)."\2.");
            _player_del(lc $src->{nick});
        }
    }

    return 1;
}

# Handle bot rehashes.
sub on_rehash {
    # Reload fantasy prefix into memory.
    $FCHAR = (conf_get('fantasy_pf'))[0][0];

    return 1;
}

# Start initialization.
API::Std::mod_init('Werewolf', 'Xelhua', '1.03', '3.0.0a10');
# build: perl=5.010000

__END__

=head1 NAME

Werewolf - IRC version of the Werewolf detective/social party game

=head1 VERSION

 1.03

=head1 SYNOPSIS

 <starcoder> !wolf join
 * blue gives voice to starcoder
 <blue> starcoder has started a game of Werewolf. Type "!wolf join" to join. Type "!wolf start" to start the game.
 <starcoder--> !wolf j
 * blue gives voice to starcoder--
 <blue> starcoder-- joined the game.
 <starcoder---> !wolf j
 * blue gives voice to starcoder---
 <blue> starcoder--- joined the game.
 <starcoder_> !wolf j
 * blue gives voice to starcoder_
 <blue> starcoder_ joined the game.
 <starcoder_> !wolf b
 <blue> starcoder_: Please wait at least 48 more seconds.
 <starcoder_> !wolf b
 <blue> Game is now starting.
 * blue sets mode +m #bot
 <blue> It is now nighttime. All players check for PM's from me for instructions. If you did not receive one, simply sit back, relax, and wait patiently for morning.

=head1 DESCRIPTION

Well, this module is a rather advanced version of the popular Werewolf (also
known as Mafia) detective/social party game, redesigned and optimizied for
Internet Relay Chat.

It, obviously, is a complete module for Auto, and has absolutely no extra
dependencies.

It includes a whopping eight player roles, four of which are optional. See the
ROLES section for more information on them.

If you want the best out of Werewolf, please be sure to read over CONFIGURATION.

It is intended to be highly advanced, consistent, clean, well-documented,
minimal, and of course, customizable.

Emphasis on advanced. Kudos to those of you non-Xelhua developers who can
figure it out, even with the large amounts of comments. :)

While you might find this documentation to be comical, know that by all means,
we are serious when we say: RTFM (Read The Fine Manual), before asking for help.

Oh, and one more thing, for the sake of examples, we use ! as the prefix for
the commands. However, this might differ depending on your fantasy_pf config
option. Also, naturally, commands might differ if you're one of the cool kids,
and use aliases.

=head1 COMMANDS

Here is a list of channel commands:

 WOLF JOIN|J - Start/Join a game.
 WOLF START - Start the game play.
 WOLF LYNCH|L - Cast vote for who to lynch.
 WOLF RETRACT|R - Retract lynch vote.
 WOLF VOTES|V - Return current votes.
 WOLF SHOOT - Shoot someone with the gun.
 WOLF STATS|S - Return current player statistics.
 WOLF KICK|K - Kick a player from the game.
 WOLF QUIT|Q - Leave the game.

Here is a list of private commands:

 WOLF SEE - See a player.
 WOLF KILL - Vote to kill a player.
 WOLF VISIT - Visit a player.
 WOLF GUARD - Guard a player.
 WOLF ID - Investigate a player.

The WOLF KICK command requires the werewolf.admin privilege.

=head1 RULES

Since the rules for this particular version of Werewolf differ from the
original significantly. This section will go over *ALL* the game rules.

=over

=item Basics

Minimum amount of players is four. Maximum amount of players is thirty.

In all games, there will be at least one wolf, one seer, and two villagers.
Roles are again, explained more thoroughly in ROLES.

Typing "!wolf join" in a channel starts a game, and a 60 second timer. Others
can join the game with "!wolf join". "!wolf start" starts play.

START will fail if the 60 second timer has not stopped and there is less than

the maximum amount of players.

The bot moderates the channel (it voices all players).

Now the game begins, it starts at night.

=item Night

Nighttime is considered by many to be the funnest part of the game, because it
is when the special people get to do their main jobs.

During the night is when the bad guys, the werewolves, or wolves for short,
vote on what villager to kill. They can use Auto's private relay, or they can be
nice, and use PM's/channels, to prevent from lagging poor Auto.

Also during the night, is when the seers, harlots and guardian angels take care
of their assigned duties.

The night lasts a maximum of 90 seconds (that's a minute and a half, noob.),
unless all nightly jobs are fulfilled, in which case, Auto will cut down the
boredom, and forcibly initialize daytime.

=item Day

Day can also be interesting, because this is when the villagers are awake and
are deciding whose life is next to go. ...Erm, that sounded bad, allow me to
explain.

In the morning, whoever the wolves voted to kill (majority vote wins), is
removed from game play and their role is announced. They're out and are thus
devoiced as dead people can't talk. (DON'T SHARE INFO AFTER DEATH, CHEATER
ZOMBIE.)

So, out of rage, I mean, "justice", the villagers seek to avenge their fallen
mate, by lynching. Yes, lynching. No court, trial, judge, lawyer, evidence...
None of that silly stuff, just good old execution based on guesses. :D

(If you don't know what lynching is, please see http://www.google.com)

So, the villagers now hold their own vote on who to lynch. First person to get
(player count / 2 + 1 (bot will say the number for those of you who failed in
math.)) votes, gets killed, instantly, with their role being revealed
afterwards.

Also, the great, Xelhua Development Group, does not consider the lynched person,
given they're a villager, PM'ing their friends to say "I TOLD YOU SO!", to be
cheating.

Of course, lynching isn't done entirely on guessing. The seer, harlot and
detective are helpful. BUT ARE THEY WHO THEY CLAIM TO BE?! THEY COULD BE A WOLF!

=item Winning

There are two conditions that cause the game to end. Here they are:

* All wolves are killed. If this happens, regardless of the way they died, the
villagers are declared the winners. (derp)

* Equal amount of wolves as villagers. Poor villagers, wolves eat 'em all and
claim victory.

And, if you want to be technical, there is a third cause:

* Bot suffers a fatal exception, thus resulting in a crash and the game ending.
No winner, sorry.

=item In Case It's Not Totally Clear

NOTE: Some of this is borrowed from http://eblong.com/zarf/werewolf.html

The villagers are trying to figure out who's a werewolf; the werewolves are
pretending to be villagers, and trying to throw suspicion on real villagers. 

The seer is trying to throw suspicion on any werewolves he discovers, but
without revealing himself to be the seer (because if he does, the werewolves
will almost certainly kill him that night, since he's the greatest threat to
werewolf national security.) Of course the seer can reveal himself at any time,
if he thinks it's worthwhile to tell the other players what he's learned. Also
of course, a werewolf can claim to be the seer and "reveal" anything he wants.

The harlot and detective are the same, but have slightly different methods and
protections. See ROLES.

Also, to be technical, since the detective can find traitors but the seer and
harlot can't, he is technically the greatest threat to werewolves.

So... yeah... major game of trust and lying. :/ DON'T LET THE WOLVES FOOL YOU!

=back

=head1 ROLES

Now, lets get to the thorough explanation of each role.

=over

=item Villager

The villager is an innocent human, and does nothing but vote on who to lynch.

=item Werewolf

The wolves are the opposite of the villagers. They're the bad guys and their
job is to kill all the villagers, scoring them victory.

At night, the werewolves are each given a list of players, with traitors and
fellow wolves indicated by (traitor) or (wolf).

Just to be clear, the traitor is the traitor of the villagers, not the wolves.

The wolves and traitors can communicate with each other simply by sending
private messages to the bot. ALL messages (even ones with passwords) are
relayed to the other wolves and traitors. So please have a dedicated instance
of Auto for this game.

They can use the "wolf kill <nick>" command in PM to the bot. Majority wins, or
if all are equal, a random victim is selected from the votes.

During the day, the wolves at all costs (even if it means ratting out their own)
make the villagers believe they are innocent. You need to be clever in order to
survive.

This is the math formula of the werewolf count: <PLAYER COUNT> * .15 rounded
off UP, not normal mathematical rounding.

=item Villager (gun holder)

If a game has 6+ players, one villager (can also be seer/harlot/etc., but not
wolves or traitors.), will be given a gun with a certain amount special silver
bullets. To be exact, <PLAYER COUNT> * .12 rounded off UP.

During the day, (s)he can use "!wolf shoot <nick>" to shoot someone with that
gun, and the effect varies widely. Lets go over those.

* 1/6 chance - Miss. - Person misses. But at least they're confirmed safe, as
wolves and traitors don't get to have guns.

* 1/6 chance - Unclean gun. - Gun explodes, in turn killing the shooter. Bummer!

* 4/6 chance - Hit. - If it hits a wolf, they die instantly (and are revealed
  to be a wolf.). If it hits a villager, 4/5 chance it'll just wound them and
  make them unable to vote for the day. 1/5 chance it kills them. Oops!

So, obviously no matter what the case might be, the gun holder will always
reveal the innocence of at least someone.

=item Seer

The seer is like a villager, but gets a special ability, the ability of
foresight (No, not Foresight Linux).

They get to have a single vision every night, via the "wolf see <nick>" command,
in the vision, they will be told the exact role of the target.

Although, in case I wasn't clear above: The seer will never be shown the
traitor, when SEE'ing the traitor, the seer will be told they are a "villager".

During the day, the seer must share his findings with his fellow villagers
while concealing his identity as the seer because otherwise, he's as good as
dead the next night.

It is common for the seer to form a "trust chain", a channel with all confirmed
safe users. Trust chains typically can make the biggest difference in who wins.

Regardless of player count, there is always one seer.

=item Harlot

ATTENTION: Harlot is an old English word for prostitute, thus harlots might be
considered NSFW and can be disabled with werewolf:rated-g. See CONFIGURATION.

By default: enabled.

Harlots are similar to the seer. They can spend the night with one person per
round. They select their partner with "wolf visit <nick>". Their partner is
immediately notified of their visit and their identity as harlot.

But in the morning is when the real information becomes available.

If the harlot visited a wolf, the bot will announce their identity as the harlot
and declare them dead. Since they are immediately removed from the game, finding
a wolf is only useful if they used a trust chain to reveal who they were
visiting before morning came.

If the harlot visited the victim of a wolf, the same result happens, except
this time their death was worthless because they died indirectly through the
victim, not directly through a wolf.

If none of these are the case, the harlot knows their partner is innocent and
vice versa. This may lead to a trust chain.

Oh, and harlots have a trick, wolves cannot directly kill the harlot if they're
spending the night with someone else. The bot will announce the harlot was targeted
but was not home in the morning, no nicks are mentioned in this case.

This is very good protection. Combined with the seer, they can, via creating a
trust chain, almost completely guarantee a win for the villagers.

A single harlot is assigned to a game if it has six or more players.

=item Guardian Angel

NOTE: Some people think that guardian angels make the game less interesting.
Thus, by default they are enabled and can be disabled with werewolf:no-angels.
See CONFIGURATION.

Guardian angels are like a weapon for the villagers, particularly the seer and
detective.

Every night, the angel can guard one person with "wolf guard <nick>", the
effect depends on a single factor. The person they're guarding is notified
of their presence, but not of the angel's nickname.

In the morning...

If they guarded the victim of the wolves, the bot announces that the guardian
angel saved the victim from the wolves. No nicks are mentioned and the victim
survives.

If they guarded a wolf, the bot does a 50/50 on whether the angel escaped in
time or not. If they didn't, their identity is revealed and they are declared
dead. Like the harlot, this is only useful if they first revealed who they were
guarding to a trust chain before morning.

If they escaped, there are no further messages.

Of course, with a trust chain, the guardian angel can protect the seer or
detective from death. Thus, the wolves must kill the angel as soon as possible.

A single guardian angel is assigned to a game if it has nine or more players.

=item Traitor

NOTE: Traitors can sometimes make it nearly impossible for the villagers to win,
thus they are disabled by default and can be enabled with werewolf:traitors.
See CONFIGURATION.

Traitors are sneaky ones. They are EXACTLY like villagers, with only a few
minor differences.

Biggest one is they're on the side of the werewolves. They only win if the
wolves do. (TODO: Needs some perfection.)

Second biggest is every night they're given a list of players, with the wolves
indicated by (wolf). They are able to use the werewolf relay as well.

Traitors always appear to be a villager, except to wolves, upon death or to the
detective.

Not even the seer or harlot can detect they're a traitor. They might even
invite them into the trust chain!

However, no need to fear, the detective, is here. The detective is able to
detect traitors. Hooray!

But, BEWARE! TRAITORS ARE VERY DANGEROUS. VILLAGERS MUST IDENTIFY AND KILL THEM
AS SOON AS POSSIBLE.

A single traitor is assigned to a game if it has twelve or more players.

=item Detective

NOTE: Some people think that detectives make the game less interesting, or even
unfair if traitors are disabled. Thus they are disabled by default and can be
enabled with werewolf:detectives. See CONFIGURATION.

Detectives are EXACTLY like seers, with only three differences:

1) They use their ability ("wolf id <nick>") during the day, not the night.

2) They can identify traitors.

But, with such abilities, comes a great and risky price. Every time they use
the ID command, the bot does a 2/5 chance of their identity being revealed
to all the wolves and traitors.

That's right, 2/5 chance. Identity revealed. To all wolves and traitors.

The primary duty of the detective is to work together with the seer/harlot
(trust chain?) but focus on identifying the traitor as soon as possible.

This is because, luck will run out. Eventually it is only logical to assume
they will be revealed to the villains.

So indeed, detectives have a stressful job, and must be good at it, for the
sake of all that is good!

A single detective is assigned to a game if it has sixteen or more players.

=back

=head1 CONFIGURATION

One of this module's key features is how easily customizable it is.

All your configuration options will go in the werewolf {  } block in your
configuration file. Lets go over them now.

---

 chan "Server/#channel";

chan lets you "jail" Werewolf to a single IRC channel. Useful for an IRC bot
that serves multiple channels and doesn't want all channels playing it.

It should be set to "<network name>/#<channel name>". Yes, the slash is 
required. Also, it is case-sensitive.

---

 rated-g 1;

*DEFINING* this configuration option will disable harlots (A.K.A. prostitutes),
because you might consider them to be inappropriate for your target audience.

NOTE: Defining it disables harlots, regardless of the actual value. Remove it
to re-enable harlots.

---

 no-angels 1;

Same as rated-g. Although there are different reasons as to why you might wish
to disable guardian angels, so see ROLES for those.

---

 traitors 1;

Same as above. Defining this option enables traitors. See ROLES for reasons why
and why you shouldn't enable traitors.

---

 detectives 1;

Same as above. Defining this option enables detectives. See ROLES for reasons
why and why you shouldn't enable detectives.

---

 always-m 1;

Again, merely defining this option enables it. always-m is intended for channels
like #defocus on Freenode that always stay +m. This is usually undesirable, so
probably a good idea to leave it out.

---

 no-wolfrelay 1;

Same as above. This option disables the werewolf private relay feature. However,
at this time, wolves and traitors will still be told they can use the service.

TODO: Fix this.

You may desire to disable the relay feature to prevent from the bot lagging.
Although most modern networks should not give any issue. Let us know if they do.

---

 chghost-quit "Message";

This is useful as it causes the module to "ignore" disconnects by players with
reason "Message". It is intended to prevent from a plethora of issues caused by
disconnect/reconnect cycling on host mask change.

WE HIGHLY RECOMMEND USING THIS OPTION.

Usually, you'll want it set to:

 chghost-quit "Changing host";

But, check with your network's administrators to confirm.

---

Also, for your convenience, we've placed a COMMANDS hash near the top of this
source file that you /should/ modify if using aliases, to avoid user confusion.

We think it's pretty clear what you need to modify. Enjoy.

=head1 SUPPORT, SUGGESTIONS, ETC.

If you have any questions or generally need help. Best method is to join our
IRC channel. (See the README)

Feature suggestions and bug reports should be posted to the B/F Tracker at
http://rm.xelhua.org.

Due to the great complexity of this module, it would not make sense for it to
be completely bug-free. So, of course, testing and bug reports are very
appreciated.

Thanks for assisting by testing!

You can also contact Elijah directly at elijah@starcoder.info or "starcoder" on
IRC, if need be.

=head1 AUTHOR

This module was written by Elijah Perrault.

Random Fact: Took five days to make.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright (C) 2010-2011, Xelhua Development Group.

This module is released under the same terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:
