# Module: UNO. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::UNO;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del hook_add hook_del trans conf_get err has_priv match_user);
use API::IRC qw(notice privmsg);

# Set various variables we'll need throughout runtime.
my $UNO = 0;
my $UNOW = 0;
my ($UNOCHAN, $EDITION, $ORDER, $DEALER, $CURRTURN, $TOPCARD, %PLAYERS, %NICKS);
my $DRAWN = 0;
my $ANYEDITION = 0;

# Initialization subroutine.
sub _init {
    # Check for required configuration values.
    if (!conf_get('uno:edition')) {
        err(3, 'Unable to load UNO: Missing required configuration values.', 0);
        return;
    }
    $EDITION = (conf_get('uno:edition'))[0][0];
    $EDITION = uc(substr $EDITION, 0, 1).substr $EDITION, 1;

    # Check if the edition is valid.
    if ($EDITION !~ m/^(Original|Super|Advanced|Any)$/xsm) {
        err(3, "Unable to load UNO: Invalid edition: $EDITION", 0);
        return;
    }

    # If it's Any, set ANYEDITION.
    if ($EDITION eq 'Any') { $ANYEDITION = 1; }

    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load UNO: PostgreSQL is not supported.', 0); return; }

    # Create `unoscores` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS unoscores (player TEXT, score INTEGER)') or return;

    # Create UNO command.
    cmd_add('UNO', 0, 0, \%M::UNO::HELP_UNO, \&M::UNO::cmd_uno) or return;

    # Create on_nick hook.
    hook_add('on_nick', 'uno.updatedata.nick', \&M::UNO::on_nick) or return;
    # Create on_quit hook.
    hook_add('on_quit', 'uno.updatedata.quit', \&M::UNO::on_quit) or return;
    # Create on_part hook.
    hook_add('on_part', 'uno.updatedata.part', \&M::UNO::on_part) or return;
    # Create on_kick hook.
    hook_add('on_kick', 'uno.updatedata.kick', \&M::UNO::on_kick) or return;
    # Create on_rehash hook.
    hook_add('on_rehash', 'uno.updatedata.rehash', \&M::UNO::on_rehash) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the UNO command.
    cmd_del('UNO') or return;

    # Delete on_nick hook.
    hook_del('on_nick', 'uno.updatedata.nick') or return;
    # Delete on_quit hook.
    hook_del('on_quit', 'uno.updatedata.quit') or return;
    # Delete on_part hook.
    hook_del('on_part', 'uno.updatedata.part') or return;
    # Delete on_kick hook.
    hook_del('on_kick', 'uno.updatedata.kick') or return;
    # Delete on_rehash hook.
    hook_del('on_rehash', 'uno.updatedata.rehash') or return;

    # Success.
    return 1;
}

# Help hash for UNO command. Spanish, German and French translations needed.
our %HELP_UNO = (
    'en' => "This command allows you to take various actions in a game of UNO. \2Syntax:\2 UNO (START|JOIN|DEAL|PLAY|DRAW|PASS|CARDS|TOPCARD|STATS|KICK|QUIT|STOP|TOPTEN|SCORE) [parameters]",
);

# Callback for UNO command.
sub cmd_uno {
    my ($src, @argv) = @_;

    # Check for action parameter.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Iterate through available actions.
    given (uc $argv[0]) {
        when (/^(START|S)$/) {
            # UNO START
            
            # Ensure there is not a game already running.
            if ($UNO or $UNOW) {
                notice($src->{svr}, $src->{nick}, "There is already a game of UNO running in \2$UNOCHAN\2.");
                return;
            }

            # Check if the channel is allowed.
            if (conf_get('uno:reschan')) {
                my ($net, $chan) = split '/', (conf_get('uno:reschan'))[0][0];
                if (lc $src->{svr} ne lc $net or lc $src->{chan} ne lc $chan) {
                    return;
                }
            }

            # If it's ANYEDITION, do some extra stuff.
            if ($ANYEDITION) {
                # Require the second parameter.
                if (!defined $argv[1]) {
                    notice($src->{svr}, $src->{nick}, "This Auto is configured with Any Edition. You must specify the edition to play with as a second parameter. \2Syntax:\2 UNO START <edition>");
                    return;
                }
                if ($argv[1] !~ m/^(original|super|advanced)$/ixsm) {
                    notice($src->{svr}, $src->{nick}, "Invalid edition \2$argv[1]\2. Must be original, super or advanced.");
                    return;
                }
                # Set the edition.
                $argv[1] = lc $argv[1];
                $EDITION = $argv[1];
                $EDITION = uc(substr $EDITION, 0, 1).substr $EDITION, 1;
            }

            # Set variables.
            $UNOW = 1;
            $UNOCHAN = $src->{svr}.'/'.lc $src->{chan};
            $PLAYERS{lc $src->{nick}} = [];
            $NICKS{lc $src->{nick}} = $src->{nick};
            $DEALER = lc $src->{nick};

            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 has started \2\00303U\003\00304N\003\00312O\003 for Auto ($EDITION Edition)\2. UNO JOIN to join the game.");
        }
        when (/^(JOIN|J)$/) {
            # UNO JOIN

            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Update variables.
            $PLAYERS{lc $src->{nick}} = []; 
            $NICKS{lc $src->{nick}} = $src->{nick};
            if ($UNO) {
                $ORDER .= ' '.lc $src->{nick};
                for (my $i = 1; $i <= 7; $i++) { _givecard(lc $src->{nick}); }
            }

            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 has joined the game.");
            if ($UNO) {
                my $cards;
                foreach (@{$PLAYERS{lc $src->{nick}}}) {
                    $cards .= ' '._fmtcard($_);
                }
                $cards = substr $cards, 1;
                notice($src->{svr}, $src->{nick}, "Your cards are: $cards");
            }
        }
        when ('DEAL') {
            # UNO DEAL
            
            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if cards have already been dealt.
            if ($UNO) {
                notice($src->{svr}, $src->{nick}, 'Cards have already been dealt. Game is in progress.');
                return;
            }
            
            # Ensure this is the dealer.
            if (lc $src->{nick} ne $DEALER) {
                notice($src->{svr}, $src->{nick}, 'Only the dealer may deal the cards.');
                return;
            }

            # Check for at least two players.
            if (keys %PLAYERS < 2) {
                notice($src->{svr}, $src->{nick}, 'Two players are required to play.');
                return;
            }

            # Deal the cards.
            foreach (keys %PLAYERS) {
                for (my $i = 1; $i <= 7; $i++) { _givecard($_); }
                my $cards;
                foreach my $card (@{$PLAYERS{$_}}) {
                    $cards .= ' '._fmtcard($card);
                }
                $cards = substr $cards, 1;
                notice($src->{svr}, $_, "Your cards are: $cards");
                $ORDER .= " $_";
            }
            $ORDER = substr $ORDER, 1;

            $UNO = 1;
            $UNOW = 0;
            $TOPCARD = _givecard();
            my ($tccol, $tcval) = split m/[:]/, $TOPCARD;
            while ($tcval eq 'T' || $tccol =~ m/^W/xsm) {
                $TOPCARD = _givecard();
                ($tccol, $tcval) = split m/[:]/, $TOPCARD;
            }
            $CURRTURN = lc $src->{nick};
            my $left = _nextturn(2);
            $CURRTURN = $left;
            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 has dealt the cards. Game begin.");
            privmsg($src->{svr}, $src->{chan}, "\2".$NICKS{$left}."'s\2 turn. Top Card: "._fmtcard($TOPCARD));
            _runcard($TOPCARD, 1);
        }
        when (/^(PLAY|P)$/) {
            # UNO PLAY
            
            # Check for required parameters.
            if (!defined $argv[2]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').". \2Syntax:\2 UNO PLAY <color> <card>");
                return;
            }
            
            # Ensure a game is running.
            if (!$UNO) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Check if it's his/her turn.
            if (lc $src->{nick} ne $CURRTURN) {
                notice($src->{svr}, $src->{nick}, 'It is not your turn.');
                return;
            }

            # Fix color.
            $argv[1] =~ s/blue/B/ixsm;
            $argv[1] =~ s/red/R/ixsm;
            $argv[1] =~ s/green/G/ixsm;
            $argv[1] =~ s/yellow/Y/ixsm;
            $argv[2] =~ s/blue/B/ixsm;
            $argv[2] =~ s/red/R/ixsm;
            $argv[2] =~ s/green/G/ixsm;
            $argv[2] =~ s/yellow/Y/ixsm;

            # Check if they have this card.
            if (!_hascard(lc $src->{nick}, uc $argv[1].':'.uc $argv[2])) {
                notice($src->{svr}, $src->{nick}, 'You don\'t have that card.');
                return;
            }

            # Check if this card is valid.
            my ($tcc, $tcv) = split m/[:]/, $TOPCARD;
            if (uc $argv[1] eq 'R' || uc $argv[1] eq 'B' || uc $argv[1] eq 'G' || uc $argv[1] eq 'Y') {
                if (uc $argv[1] ne $tcc and uc $argv[2] ne $tcv) {
                    notice($src->{svr}, $src->{nick}, 'That card cannot be played.');
                    return;
                }
            }

            # If this is a Trade Hands card...
            if (uc $argv[2] eq 'T') {
                # Ensure it has the extra argument.
                if (!defined $argv[3]) {
                    notice($src->{svr}, $src->{nick}, "The Trade Hands card requires the <player> argument. \2Syntax:\2 UNO PLAY <color> T <player>");
                    return;
                }
                # Ensure they're not trading hands with themselves.
                if (lc $argv[3] eq $CURRTURN) {
                    notice($src->{svr}, $src->{nick}, 'You may not trade with yourself.');
                    return;
                }
                # Ensure the player they're trading with is playing.
                if (!defined $PLAYERS{lc $argv[3]}) {
                    notice($src->{svr}, $src->{nick}, "No such user \2$argv[3]\2 is playing.");
                    return;
                }
            }

            # If it's a wildcard...
            if ($argv[1] =~ m/^W/ixsm) {
                # Ensure the third argument is a valid color.
                if ($argv[2] !~ m/^(R|B|G|Y)$/ixsm) {
                    notice($src->{svr}, $src->{nick}, "Invalid color \2$argv[2]\2.");
                    return;
                }
            }

            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 plays "._fmtcard(uc $argv[1].':'.uc $argv[2]));
            
            # Delete the card from the player's hand.
            my $delres = _delcard(lc $src->{nick}, uc $argv[1].':'.uc $argv[2]);
            if ($delres == -1) { return 1; }

            # Play the card.
            if (defined $argv[3]) {
                _runcard(uc $argv[1].':'.uc $argv[2], 0, @argv[3..$#argv]);
            }
            else {
                _runcard(uc $argv[1].':'.uc $argv[2], 0, undef);
            }
            $DRAWN = 0;
        }
        when (/^(DRAW|D)$/) {
            # UNO DRAW
            
            # Ensure a game is running.
            if (!$UNO) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Check if it's his/her turn.
            if (lc $src->{nick} ne $CURRTURN) {
                notice($src->{svr}, $src->{nick}, 'It is not your turn.');
                return;
            }

            # Don't allow them to draw more than one card.
            if ($DRAWN eq lc $src->{nick}) {
                notice($src->{svr}, $src->{nick}, 'You may only draw once per turn. Use UNO PASS to pass.');
                return;
            }

            # Now draw card(s) depending on the edition.
            if ($EDITION eq 'Original') {
                notice($src->{svr}, $src->{nick}, 'You drew: '._fmtcard(_givecard(lc $src->{nick})));
                my ($net, $chan) = split '/', $UNOCHAN;
                privmsg($net, $chan, "\2$src->{nick}\2 drew a card.");
            }
            else {
                my $amnt = int rand 11;
                if ($amnt > 0) {
                    my @dcards;
                    for (my $i = $amnt; $i > 0; $i--) { push @dcards, _fmtcard(_givecard(lc $src->{nick})); }
                    notice($src->{svr}, $src->{nick}, 'You drew: '.join(' ', @dcards));
                }
                my ($net, $chan) = split '/', $UNOCHAN;
                privmsg($net, $chan, "\2$src->{nick}\2 drew \2$amnt\2 cards.");
            }
            $DRAWN = lc $src->{nick};
        }
        when ('PASS') {
            # UNO PASS
            
            # Ensure a game is running.
            if (!$UNO) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Check if it's his/her turn.
            if (lc $src->{nick} ne $CURRTURN) {
                notice($src->{svr}, $src->{nick}, 'It is not your turn.');
                return;
            }

            # Make sure they've drawn at least once.
            if ($DRAWN ne lc $src->{nick}) {
                notice($src->{svr}, $src->{nick}, 'You must draw once before passing.');
                return;
            }

            # Pass this user.
            $DRAWN = 0;
            my ($net, $chan) = split '/', $UNOCHAN;
            privmsg($net, $chan, "\2$src->{nick}\2 passes.");
            _nextturn(0);
        }
        when (/^(CARDS|C)$/) {
            # UNO CARDS
            
            # Ensure a game is running.
            if (!$UNO) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }
         
            # Tell them their cards.
            my $cards;
            foreach (@{$PLAYERS{lc $src->{nick}}}) { $cards .= ' '._fmtcard($_); }
            $cards = substr $cards, 1;
            notice($src->{svr}, $src->{nick}, "Your cards are: $cards");
        }
        when (/^(TOPCARD|TC)$/) {
            # UNO TOPCARD
            
            # Ensure a game is running.
            if (!$UNO) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Return the top card.
            notice($src->{svr}, $src->{nick}, 'Top card: '._fmtcard($TOPCARD));
        }
        when (/^(KICK|K)$/) {
            # UNO KICK

            # Second parameter required.
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').". \2Syntax:\2 UNO KICK <player>");
                return;
            }

            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Ensure they have permission to perform this action.
            if (lc $src->{nick} ne $DEALER && !has_priv(match_user(%$src), 'uno.override')) {
                notice($src->{svr}, $src->{nick}, trans('Permission denied').q{.});
                return;
            }
            
            # Check if the player is in the game.
            if (!defined $PLAYERS{lc $argv[1]}) {
                notice($src->{svr}, $src->{nick}, "No such user \2$argv[1]\ is playing.");
                return;
            }

            # Delete the player.
            my ($net, $chan) = split '/', $UNOCHAN;
            privmsg($net, $chan, "\2$src->{nick}\2 has kicked \2$argv[1]\2 from the game.");
            _delplyr(lc $argv[1]);
        }
        when (/^(QUIT|Q)$/) {
            # UNO QUIT

            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Check if it's his/her turn.
            if (lc $src->{nick} ne $CURRTURN) {
                notice($src->{svr}, $src->{nick}, 'It is not your turn.');
                return;
            }

            # Delete them.
            my ($net, $chan) = split '/', $UNOCHAN;
            privmsg($net, $chan, "\2$src->{nick}\2 has left the game.");
            _delplyr(lc $src->{nick});
        }
        when ('STOP') {
            # UNO STOP

            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Ensure they have permission to perform this action.
            if (lc $src->{nick} ne $DEALER && !has_priv(match_user(%$src), 'uno.override')) {
                notice($src->{svr}, $src->{nick}, trans('Permission denied').q{.});
                return;
            }

            # Stop the game.
            my ($net, $chan) = split '/', $UNOCHAN;
            $UNO = $UNOW = $UNOCHAN = $ORDER = $DEALER = $CURRTURN = $TOPCARD = $DRAWN = 0;
            %PLAYERS = ();
            %NICKS = ();
            privmsg($net, $chan, "\2$src->{nick}\2 has stopped the game.");
        }
        when (/^(CARDCOUNT|STATS|CC)$/) {
            # UNO CARDCOUNT

            # Ensure a game is running.
            if (!$UNO) {
                notice($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    notice($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }
        
            # Iterate through all players, getting their card count.
            my $str;
            foreach my $plyr (keys %PLAYERS) {
                $str .= " \2".$NICKS{$plyr}.":".scalar @{$PLAYERS{$plyr}}."\2";
            }
            $str = substr $str, 1;
            
            # Return count.
            notice($src->{svr}, $src->{nick}, "Card count: $str");
        }
        when (/^(TOPTEN|T10|TOP10)$/) {
            # UNO TOPTEN

            # Get data.
            my $dbq = $Auto::DB->prepare('SELECT * FROM unoscores') or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            $dbq->execute or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            my $data = $dbq->fetchall_hashref('score') or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            # Check if there's any scores.
            if (keys %$data) {
                my $str;
                my $i = 0;
                foreach (sort {$b <=> $a} keys %$data) {
                    if ($i > 10) { last; }
                    $str .= ", \2".$data->{$_}->{player}.":$_\2";
                    $i++;
                }
                $str = substr $str, 2;
                notice($src->{svr}, $src->{nick}, "Top Ten: $str");
            }
            else {
                notice($src->{svr}, $src->{nick}, trans('No data available').q{.});
            }
        }
        when ('SCORE') {
            # UNO SCORE

            # Second parameter needed.
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            my $target = lc $argv[1];

            if ($Auto::DB->selectrow_array('SELECT score FROM unoscores WHERE player = "'.$target.'"')) {
                # Get score.
                my $score = $Auto::DB->selectrow_array('SELECT score FROM unoscores WHERE player = "'.$target.'"') or
                    notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
                # Return it.
                notice($src->{svr}, $src->{nick}, "Score for \2$argv[1]\2: $score");
            }
            else {
                notice($src->{svr}, $src->{nick}, trans('No data available').q{.});
            }
        }
        default { notice($src->{svr}, $src->{nick}, trans('Unknown action', uc $argv[0]).q{.}); }
    }

    return 1;
}

# Subroutine for giving a player a card.
sub _givecard {
    my ($player) = @_;

    # Make sure the player exists.
    if (defined $player) {
        if (!defined $PLAYERS{$player}) { return; }
    }
    
    # Get a random number for the appropriate edition.
    my $rci;
    given ($EDITION) {
        when ('Original') { $rci = int rand 53; }
        when ('Super') { $rci = int rand 64; }
        when ('Advanced') { $rci = int rand 72; }
    }

    # Now figure out what card we have here.
    my $card;
    given ($rci) {
        when (0) { $card = 'R:1'; }
        when (1) { $card = 'R:2'; }
        when (2) { $card = 'R:3'; }
        when (3) { $card = 'R:4'; }
        when (4) { $card = 'R:5'; }
        when (5) { $card = 'R:6'; }
        when (6) { $card = 'R:7'; }
        when (7) { $card = 'R:8'; }
        when (8) { $card = 'R:9'; }
        when (9) { $card = 'B:1'; }
        when (10) { $card = 'B:2'; }
        when (11) { $card = 'B:3'; }
        when (12) { $card = 'B:4'; }
        when (13) { $card = 'B:5'; }
        when (14) { $card = 'B:6'; }
        when (15) { $card = 'B:7'; }
        when (16) { $card = 'B:8'; }
        when (17) { $card = 'B:9'; }
        when (18) { $card = 'Y:1'; }
        when (19) { $card = 'Y:2'; }
        when (20) { $card = 'Y:3'; }
        when (21) { $card = 'Y:4'; }
        when (22) { $card = 'Y:5'; }
        when (23) { $card = 'Y:6'; }
        when (24) { $card = 'Y:7'; }
        when (25) { $card = 'Y:8'; }
        when (26) { $card = 'Y:9'; }
        when (27) { $card = 'G:1'; }
        when (28) { $card = 'G:2'; }
        when (29) { $card = 'G:3'; }
        when (30) { $card = 'G:4'; }
        when (31) { $card = 'G:5'; }
        when (32) { $card = 'G:6'; }
        when (33) { $card = 'G:7'; }
        when (34) { $card = 'G:8'; }
        when (35) { $card = 'G:9'; }
        when (36) { $card = 'W:0'; }
        when (37) { $card = 'W:0'; }
        when (38) { $card = 'W:0'; }
        when (39) {
            if ($EDITION eq 'Original') { $card = 'WD4:0'; }
            else { $card = 'WHF:0'; }
        }
        when (40) {
            if ($EDITION eq 'Original') { $card = 'WD4:0'; }
            else { $card = 'WHF:0'; }
        }
        when (41) { $card = 'R:R'; }
        when (42) { $card = 'B:R'; }
        when (43) { $card = 'Y:R'; }
        when (44) { $card = 'G:R'; }
        when (45) { $card = 'R:S'; }
        when (46) { $card = 'B:S'; }
        when (47) { $card = 'Y:S'; }
        when (48) { $card = 'G:S'; }
        when (49) { $card = 'R:D2'; }
        when (50) { $card = 'B:D2'; }
        when (51) { $card = 'Y:D2'; }
        when (52) { $card = 'G:D2'; }
        when (53) { $card = 'WAH:0'; }
        when (54) { $card = 'WAH:0'; }
        when (55) { $card = 'WAH:0'; }
        when (56) { $card = 'R:T'; }
        when (57) { $card = 'B:T'; }
        when (58) { $card = 'G:T'; }
        when (59) { $card = 'Y:T'; }
        when (60) { $card = 'R:X'; }
        when (61) { $card = 'B:X'; }
        when (62) { $card = 'G:X'; }
        when (63) { $card = 'Y:X'; }
        when (64) { $card = 'R:W'; }
        when (65) { $card = 'B:W'; }
        when (66) { $card = 'G:W'; }
        when (67) { $card = 'Y:W'; }
        when (68) { $card = 'R:B'; }
        when (69) { $card = 'B:B'; }
        when (70) { $card = 'G:B'; }
        when (71) { $card = 'Y:B'; }
        default { $card = 'W:0'; }
    }

    # Add the card to the player's arrayref.
    if (defined $player) { push @{$PLAYERS{$player}}, $card; }

    # Return the card.
    return $card;
}

# Return an IRC formatted version of a card name.
sub _fmtcard {
    my ($card) = @_;

    my $fmt;
    my ($color, $val) = split m/[:]/, $card;
    if ($color eq 'W' or $color eq 'WD4' or $color eq 'WAH' or $color eq 'WHF') { $val = $color; }

    given ($color) {
        when ('R') { $fmt = "\00304[$val]\003"; }
        when ('B') { $fmt = "\00312[$val]\003"; }
        when ('G') { $fmt = "\00303[$val]\003"; }
        when ('Y') { $fmt = "\00308[$val]\003"; }
        default { $fmt = "\002\00301[$val]\003\002"; }
    }

    return $fmt;
}

# Next turn.
sub _nextturn {
    my ($skip) = @_;
    my @order = split ' ', $ORDER.' '.$ORDER;
    my $br = 0;
    my $nplayer;
    # Iterate through the players.
    foreach (@order) {
        if ($br) {
            if ($skip eq 1) {
                $skip = $_;
                next;
            }
            $nplayer = $_;
            last;
        }
        if ($_ eq $CURRTURN) {
            $br = 1;
            next;
        }
    }
    # Check if there was a result.
    if (!defined $nplayer) {
        # Mind, this should never happen, but must be the next person in order.
        $nplayer = $order[0];
    }
    if ($skip eq 2) { return $nplayer; }

    my ($net, $chan) = split '/', $UNOCHAN;
    $CURRTURN = $nplayer;
    privmsg($net, $chan, "\2".$NICKS{$nplayer}."'s\2 turn. Top Card: "._fmtcard($TOPCARD));
    my $cards;
    foreach (@{$PLAYERS{$nplayer}}) { $cards .= ' '._fmtcard($_); }
    $cards = substr $cards, 1;
    notice($net, $NICKS{$nplayer}, "Your cards are: $cards");

    if ($skip) { return $skip; }
    return 1;
}

# Subroutine for performing actions depending on the card.
sub _runcard {
    my ($card, $spec, @vals) = @_;
    my ($ccol, $cval) = split m/[:]/, $card;
    if (!defined $spec) { $spec = 0; }
    my ($net, $chan) = split '/', $UNOCHAN;
    if ($ccol ne 'R' && $ccol ne 'B' && $ccol ne 'G' && $ccol ne 'Y') {
        $TOPCARD = $cval.':0';
    }
    else {
        $TOPCARD = uc $card;
    }

    given ($ccol) {
        when (/(R|B|G|Y)/) {
            given ($cval) {
                when (/^[1-9]$/) {
                    if ($spec) { return; }
                    _nextturn(0);
                }
                when ('R') {
                    if (keys %PLAYERS > 2) {
                        # Extract current full order.
                        my $ns = 0;
                        my @nop;
                        my @order = split ' ', $ORDER.' '.$ORDER;
                        foreach (@order) {
                            if ($ns) {
                                if ($_ eq $CURRTURN) {
                                    last;
                                }
                                else {
                                    push @nop, $_;
                                }
                            }
                            else {
                                if ($_ eq $CURRTURN) {
                                    push @nop, $_;
                                    $ns = 1;
                                }
                            }
                        }
                        # Set new order.
                        $ORDER = 0;
                        for (my $i = $#nop; $i >= 0; $i--) { $ORDER .= ' '.$nop[$i]; }
                        $ORDER = substr $ORDER, 1;
                    }
                    privmsg($net, $chan, 'Game play has been reversed!');
                    if (keys %PLAYERS > 2) { _nextturn(0); }
                    else { _nextturn(1); }
                }
                when ('S') {
                    if ($spec) {
                        privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 is skipped!");
                        _nextturn(0);
                    }
                    else {
                        privmsg($net, $chan, "\2".$NICKS{_nextturn(2)}."\2 is skipped!");
                        _nextturn(1);
                    }
                }
                when ('D2') {
                    if ($spec) {
                        if ($EDITION eq 'Original') {
                            _givecard($CURRTURN);
                            _givecard($CURRTURN);
                            privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 draws 2 cards and is skipped!");
                        }
                        else {
                            my $amnt = int rand 11;
                            if ($amnt > 0) {
                                for (my $i = $amnt; $i > 0; $i--) { _fmtcard(_givecard($CURRTURN)); }
                            }
                            privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 draws \2$amnt\2 cards and is skipped!");
                        }
                        _nextturn(0);
                    }
                    else {
                        my $victim = _nextturn(2);
                        if ($EDITION eq 'Original') {
                            _givecard($victim);
                            _givecard($victim);
                            privmsg($net, $chan, "\2".$NICKS{$victim}."\2 draws 2 cards and is skipped!");
                        }
                        else {
                            my $amnt = int rand 11;
                            if ($amnt > 0) {
                                for (my $i = $amnt; $i > 0; $i--) { _fmtcard(_givecard($victim)); }
                            }
                            privmsg($net, $chan, "\2".$NICKS{$victim}."\2 draws \2$amnt\2 cards and is skipped!");
                        }
                        _nextturn(1);
                    }
                }
                when ('X') {
                    # Get all cards of this color.
                    my @xcards;
                    foreach my $ucard (@{$PLAYERS{$CURRTURN}}) {
                        my ($xhcol, undef) = split m/[:]/, $ucard;
                        if ($xhcol eq $ccol) { push @xcards, $ucard; }
                    }
                    # Get a more human-readable version of the color.
                    my $tcol;
                    given ($ccol) {
                        when ('R') { $tcol = "\00304red\003"; }
                        when ('B') { $tcol = "\00312blue\003"; }
                        when ('G') { $tcol = "\00303green\003"; }
                        when ('Y') { $tcol = "\00308yellow\003"; }
                    }
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 is discarding all his/her cards of color \2$tcol\2.");
                    # Delete all the cards.
                    my $delres;
                    foreach (@xcards) { $delres = _delcard($CURRTURN, $_); }
                    my $str;
                    for (my $i = $#xcards; $i >= 0; $i--) { $str .= ' '._fmtcard($xcards[$i]); }
                    $str = substr $str, 1;
                    if ($delres != -1) { 
                        notice($net, $NICKS{$CURRTURN}, "You discarded: $str");
                        _nextturn(0); 
                    }
                }
                when ('T') {
                    # Get cards.
                    my @ucards = @{$PLAYERS{$CURRTURN}};
                    my @rcards = @{$PLAYERS{lc $vals[0]}};
                    # Reset cards.
                    $PLAYERS{$CURRTURN} = [];
                    $PLAYERS{lc $vals[0]} = [];
                    # Set new cards.
                    foreach (@ucards) { push @{$PLAYERS{lc $vals[0]}}, $_; }
                    foreach (@rcards) { push @{$PLAYERS{$CURRTURN}}, $_; }
                    # The deed, is done.
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 has traded hands with \2".$NICKS{lc $vals[0]}."\2!");
                    _nextturn(0);
                }
                when ('B') {
                    # Iterate through all players.
                    foreach my $vplyr (keys %PLAYERS) {
                        # Make sure it isn't the player.
                        if ($vplyr ne $CURRTURN) {
                            for (my $i = 1; $i <= 7; $i++) { _givecard($vplyr); }
                        }
                    }
                    # Finished.
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 drops a card bomb on the game! All other players gain 7 cards!");
                    _nextturn(0);
                }
                when ('W') {
                    # Get a list of players.
                    my @plyrs = keys %PLAYERS;
                    # Select a random player.
                    my $rand = int rand scalar @plyrs;
                    # Make sure the player isn't the victim.
                    while ($plyrs[$rand] eq $CURRTURN) { $rand = int rand scalar @plyrs; }
                    # Set victim.
                    my $victim = $plyrs[$rand];
                    # Get the cards of the victim.
                    my $cards;
                    foreach (@{$PLAYERS{$victim}}) { $cards .= ' '._fmtcard($_); }
                    $cards = substr $cards, 1;
                    # Give the victim two cards.
                    _givecard($victim); _givecard($victim);
                    # Reveal the cards to the player.
                    notice($net, $NICKS{$CURRTURN}, "\2".$NICKS{$victim}."'s\2 cards are: $cards");
                    # Finished.
                    privmsg($net, $chan, "The magical UNO wizard has revealed \2".$NICKS{$victim}."'s\2 hand to \2".$NICKS{$CURRTURN}."\2! \2".$NICKS{$victim}."\2 gains two cards!");
                    _nextturn(0);
                }
            }
        }
        default {
            given ($ccol) {
                when ('W') {
                    my $tcol;
                    given ($cval) {
                        when ('R') { $tcol = "\00304red\003"; }
                        when ('B') { $tcol = "\00312blue\003"; }
                        when ('G') { $tcol = "\00303green\003"; }
                        when ('Y') { $tcol = "\00308yellow\003"; }
                    }
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 changes color to \2$tcol\2.");
                    _nextturn(0);
                }
                when ('WD4') {
                    my $tcol;
                    given ($cval) {
                        when ('R') { $tcol = "\00304red\003"; }
                        when ('B') { $tcol = "\00312blue\003"; }
                        when ('G') { $tcol = "\00303green\003"; }
                        when ('Y') { $tcol = "\00308yellow\003"; }
                    }
                    my $victim = _nextturn(2);
                    for (my $i = 1; $i <= 4; $i++) { _givecard($victim); }
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 changes color to \2$tcol\2. \2".$NICKS{$victim}."\2 draws 4 cards and is skipped!");
                    _nextturn(1);
                }
                when ('WHF') {
                    # Get more human-readable version of the color.
                    my $tcol;
                    given ($cval) {
                        when ('R') { $tcol = "\00304red\003"; }
                        when ('B') { $tcol = "\00312blue\003"; }
                        when ('G') { $tcol = "\00303green\003"; }
                        when ('Y') { $tcol = "\00308yellow\003"; }
                    }
                    # Give the next player a random amount of cards.
                    my $victim = _nextturn(2);
                    my $amnt = int rand 11;
                    while ($amnt == 0) { $amnt = int rand 11; }
                    for (my $i = 1; $i <= $amnt; $i++) { _givecard($victim); }
                    # All done.
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 changes color to \2$tcol\2. \2".$NICKS{$victim}."\2 draws \2$amnt\2 cards and is skipped!");
                    _nextturn(1);
                }
                when ('WAH') {
                    # Get more human-readable version of the color.
                    my $tcol;
                    given ($cval) {
                        when ('R') { $tcol = "\00304red\003"; }
                        when ('B') { $tcol = "\00312blue\003"; }
                        when ('G') { $tcol = "\00303green\003"; }
                        when ('Y') { $tcol = "\00308yellow\003"; }
                    }
                    # Iterate through all players.
                    foreach my $vplyr (keys %PLAYERS) {
                        # Make sure it isn't the player.
                        if ($vplyr ne $CURRTURN) {
                            my $amnt = int rand 11;
                            for (my $i = 1; $i <= $amnt; $i++) { _givecard($vplyr); }
                        }
                    }
                    # Finished.
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 changes color to \2$tcol\2. All other players draw 0-10 cards!");
                    _nextturn(0);
                }
            }
        }
    }

    return 1;
}

# Subroutine for checking if a player has a card.
sub _hascard {
    my ($player, $card) = @_;

    # Check for the player arrayref.
    if (!defined $PLAYERS{$player}) { return; }

    # Iterate through his/her cards.
    foreach my $pc (@{$PLAYERS{$player}}) {
        if ($pc eq $card) { return 1; }
        my ($pcol, undef) = split m/[:]/, $card;
        if ($pcol ne 'R' && $pcol ne 'B' && $pcol ne 'G' && $pcol ne 'Y') {
            my ($hcol, undef) = split m/[:]/, $pc;
            if ($pcol eq $hcol) { return 1; }
        }
    }

    return;
}

# Subroutine for deleting a card from a player's hand.
sub _delcard {
    my ($player, $card) = @_;

    # Check for the player arrayref.
    if (!defined $PLAYERS{$player}) { return; }

    # Iterate through his/her cards and delete the correct card.
    for (my $i = 0; $i < scalar @{$PLAYERS{$player}}; $i++) {
        if ($PLAYERS{$player}[$i] eq $card) {
            undef $PLAYERS{$player}[$i];
            last;
        }
        else {
            my ($pcol, undef) = split m/[:]/, $card;
            if ($pcol !~ m/^(R|B|G|Y)$/xsm) {
                my ($hcol, undef) = split m/[:]/, $PLAYERS{$player}[$i];
                if ($pcol eq $hcol) { undef $PLAYERS{$player}[$i]; last; }
            }
        }
    }

    # Rebuild his/her hand.
    my @cards = [];
    foreach my $hc (@{$PLAYERS{$player}}) {
        if (defined $hc) { push @cards, $hc; } 
    }
    delete $PLAYERS{$player};
    $PLAYERS{$player} = [];
    if (ref $cards[0] eq 'ARRAY') { shift @cards; }
    if (!scalar @cards) {
        _gameover($player);
        return -1;
    }
    elsif (scalar(@cards) == 1) {
        my ($net, $chan) = split '/', $UNOCHAN;
        privmsg($net, $chan, "\2".$NICKS{$player}."\2 has \2\00303U\003\00304N\003\00312O\003\2!");
    }
    foreach (@cards) { push @{$PLAYERS{$player}}, $_; }

    return 1;
}

# Subroutine for deleting a player.
sub _delplyr {
    my ($player) = @_;

    # Check if the player exists.
    if (!defined $PLAYERS{$player}) { return; }
    my ($net, $chan) = split '/', $UNOCHAN;
    
    # Delete their player data.
    delete $PLAYERS{$player};
    delete $NICKS{$player};

    # If there is only one player left, end the game.
    if (keys %PLAYERS < 2) {
        $UNO = $UNOW = $UNOCHAN = $ORDER = $DEALER = $CURRTURN = $TOPCARD = $DRAWN = 0;
        %PLAYERS = ();
        %NICKS = ();
        privmsg($net, $chan, 'There is only one player left. Game over.');
        return 1;
    }

    # Update state data.
    if ($UNO) {
        if ($DEALER eq $player) {
            if ($CURRTURN eq $player) { $DEALER = _nextturn(2); }
            else { $DEALER = $CURRTURN; }
        }
        if ($CURRTURN eq $player) { _nextturn(0); }
    }
    
    # Update order.
    if ($UNO) {
        my @order;
        foreach (split ' ', $ORDER) {
            if ($_ ne $player) { push @order, $_; }
        }
        $ORDER = join ' ', @order;
    }

    return 1;
}

# For when a player has won.
sub _gameover {
    my ($player) = @_;

    # Update database.
    my $score;
    if (!$Auto::DB->selectrow_array('SELECT * FROM unoscores WHERE player = "'.$player.'"')) {
        $Auto::DB->do('INSERT INTO unoscores (player, score) VALUES ("'.$player.'", "0")') or err(3, "Unable to update UNO score for $player!", 0);
        $score = 0;
    }
    else {
        $score = $Auto::DB->selectrow_array('SELECT score FROM unoscores WHERE player = "'.$player.'"') or err(3, "Unable to update UNO score for $player!", 0);
    }
    $score++;
    $Auto::DB->do('UPDATE unoscores SET score = "'.$score.'" WHERE player = "'.$player.'"') or err(3, "Unable to update UNO score for $player!", 0);

    # Declare their victory.
    my ($net, $chan) = split '/', $UNOCHAN;
    privmsg($net, $chan, "Game over. \2".$NICKS{$player}."\2 is victorious! Bringing his/her score to \2$score\2! Congratulations!");

    # Reset variables.
    $UNO = $UNOW = $UNOCHAN = $ORDER = $DEALER = $CURRTURN = $TOPCARD = $DRAWN = 0;
    %PLAYERS = ();
    %NICKS = ();

    return 1;
}

# Subroutine for when someone changes their nick.
sub on_nick {
    my (($svr, $src, $newnick)) = @_;

    # Check if a game is currently running.
    if ($UNO or $UNOW) {
        # There is.
        
        # Check if the user is playing.
        if (defined $PLAYERS{lc $src->{nick}}) {
            # Update data.
            $PLAYERS{lc $newnick} = $PLAYERS{lc $src->{nick}};
            $NICKS{lc $newnick} = $newnick;
            if ($UNO) {
                my @order = split ' ', $ORDER;
                for (my $i = 0; $i < scalar @order; $i++) {
                    if ($order[$i] eq lc $src->{nick}) {
                        $order[$i] = lc $newnick;
                    }
                }
                $ORDER = join ' ', @order;
            }
            if ($UNO) { if ($CURRTURN eq lc $src->{nick}) { $CURRTURN = lc $newnick; } }
            if ($DEALER eq lc $src->{nick}) { $DEALER = lc $newnick; }
            # Delete garbage.
            delete $PLAYERS{lc $src->{nick}};
            delete $NICKS{lc $src->{nick}};
        }
    }

    return 1;
}

# Subroutine for when someone disconnects.
sub on_quit {
    my (($svr, $src, undef)) = @_;

    # Check if a game is currently running.
    if ($UNO or $UNOW) {
        # There is.
        
        # Check if the user is playing.
        if (defined $PLAYERS{lc $src->{nick}}) {
            my ($net, $chan) = split '/', $UNOCHAN;
            privmsg($net, $chan, "\2$src->{nick}\2 left the game.");
            _delplyr(lc $src->{nick});
        }
    }

    return 1;
}

# Subroutine for when someone parts.
sub on_part {
    my (($svr, $src, $chan, undef)) = @_;

    # Check if a game is currently running.
    if ($UNO or $UNOW) {
        # There is.
        
        # Check if this is the channel UNO is in.
        my ($net, $uchan) = split '/', $UNOCHAN;
        if ($svr eq $net and lc $chan eq $uchan) {
            # Check if the user is playing.
            if (defined $PLAYERS{lc $src->{nick}}) {
                privmsg($net, $uchan, "\2$src->{nick}\2 left the game.");
                _delplyr(lc $src->{nick});
            }
        }
    }

    return 1;
}

# Subroutine for when someone is kicked.
sub on_kick {
    my (($svr, undef, $chan, $user, undef)) = @_;

    # Check if a game is currently running.
    if ($UNO or $UNOW) {
        # There is.
        
        # Check if this is the channel UNO is in.
        my ($net, $uchan) = split '/', $UNOCHAN;
        if ($svr eq $net and lc $chan eq $uchan) {
            # Check if the user is playing.
            if (defined $PLAYERS{lc $user}) {
                privmsg($net, $uchan, "\2$user\2 left the game.");
                _delplyr(lc $user);
            }
        }
    }
}

# Subroutine for when a rehash occurs.
sub on_rehash {
    # Ensure a game isn't running right now.
    if ($UNO or $UNOW) { awarn(3, 'on_rehash: Unable to update UNO edition: A game is currently running.'); return; }

    # Check if the edition is specified.
    if (conf_get('uno:edition')) {
        # Check if the edition is valid.
        my $ce = (conf_get('uno:edition'))[0][0];
        $ce = lc $ce;
        if ($ce !~ m/^(original|super|advanced|any)$/xsm) {
            awarn(3, 'on_rehash: Unable to update UNO edition: Invalid edition \''.$ce.'\'');
            return;
        }
        
        # Set new edition.
        $ce = uc(substr $ce, 0, 1).substr $ce, 1;
        if ($ce eq 'Any') { $ANYEDITION = 1 }
        else { $ANYEDITION = 0 }
        $EDITION = $ce;
    }

    return 1;
}


# Start initialization.
API::Std::mod_init('UNO', 'Xelhua', '1.02', '3.0.0a5', __PACKAGE__);
# vim: set ai sw=4 ts=4:
# build: perl=5.010000

__END__

=head1 NAME

UNO - Three editions of the UNO card game

=head1 VERSION

 1.02

=head1 SYNOPSIS

 # config block
 uno {
     edition "original";
 }

 <starcoder> !uno start
 <blue> starcoder has started UNO for Auto (Original Edition). UNO JOIN to join the game.
 <Crystal> !uno join
 <blue> Crystal has joined the game.
 <starcoder> !uno deal
 -blue- Your cards are: [2] [1] [9] [8] [S] [2] [D2]
 <blue> starcoder has dealt the cards. Game begin.
 <blue> Crystal's turn. Top Card: [4]
 <Crystal> !uno play g d2
 <blue> Crystal plays [D2]
 <blue> starcoder draws 2 cards and is skipped!
 <blue> Crystal's turn. Top Card: [D2]

=head1 DESCRIPTION

This module adds the complete functionality of the classic card game, UNO, to
Auto, with three editions (Original, Super, Advanced) for endless hours of fun.

See DIFFERENCES BETWEEN EDITIONS for the differences between the editions.

The commands this adds are:

 UNO START|S [edition]
 UNO JOIN|J
 UNO DEAL
 UNO PLAY|P <color (or wildcard)> <card (or color if wildcard)> [player if Trade Hands card]
 UNO DRAW|D
 UNO PASS
 UNO CARDS|C
 UNO TOPCARD|TC
 UNO STATS|CARDCOUNT|CC
 UNO KICK|K <player>
 UNO QUIT|Q
 UNO STOP
 UNO TOPTEN|TOP10|T10
 UNO SCORE <user>

All of which describe themselves quite well with just the name.

=head1 INSTALL

You must add the following to your configuration file:

 uno {
     edition "edition here";
 }

Edition can be "original", "super", "advanced" or "any".

If any, edition must be specified per-game in START.

You may also add the reschan option to the block, like so:

 reschan "<server>/<channel>";

This will restrict use of UNO to the specified channel. Often useful since only
one channel at a time may use UNO.

=head1 DIFFERENCES BETWEEN EDITIONS

This is a list of differences between the three editions.

=over

=item Original

This is the original UNO card game, unmodified except that the 0 card is
disabled as it is reserved for after a wildcard is used.

=item Super

This edition is based on the UNO Attack game, if you're already familiar with
UNO Attack, then no need to read this as it is unmodified other than instead of
0-12 cards, you get 0-10 cards when drawing.

Differences from Original:

* When drawing cards, instead of a set number, a random amount between 0 (0 not
always used) and 10.

* The Trade Hands (T) card, which allows trading your hand with another player.

* The Discard All (X) card, which discards all the cards of the same color from
the player's hand.

* The Wild Hit Fire (WHF) card (replaces WD4), which changes the color and
gives the next player 1-10 cards (0 is disabled here), as well as skips them.

* The Wild All Hit card, which changes the color and gives all other players 0-
10 cards. Play continues as normal.


=item Advanced

This is Xelhua's own edition, based on Super with two new cards.

Differences from Super:

* The Bomb (B) card, which gives all other players a static amount of 7 cards.

* The Wizard (W) card, which selects a random player and reveals their hand to
the user, as well as gives them two new cards that were not shown to the user.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut
