# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Core IRC functionality.
package Core::IRC;
use strict;
use warnings;
use English;
use API::Std qw(trans has_priv match_user);
use API::Log qw(dbug alog);
use API::IRC qw(notice quit usrc);

sub version_reply
{
    my (($svr, @ex)) = @_;
    my %src = usrc(substr($ex[0], 1));

    if ($ex[3] eq ":\001VERSION\001") {
        notice($svr, $src{nick}, "VERSION ".Auto::NAME." ".Auto::VER.".".Auto::SVER.".".Auto::REV.Auto::RSTAGE." ".$OSNAME);
    }

    return 1;
}


# Help hash for MODLOAD. Spanish, French and German needed.
our %HELP_MODLOAD = (
    'en' => 'Loads a module into the running Auto live.',
);
# MODLOAD callback.
sub cmd_modload
{
    my (%data) = @_;
    my @argv = @{ $data{args} };
    
    # Check for the needed parameters.
    if (!defined $argv[0]) {
        notice($data{svr}, $data{nick}, trans("Not enough parameters").".");
        return 0;
    }

    # Check if the module is already loaded.
    if (API::Std::mod_exists($argv[0])) {
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 is already loaded.");
        return 0;
    }

    # Go for it!
    my $tn = Auto::mod_load($argv[0]);

    # Check if we were successful or not.
    if ($tn) {
        # We were!
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 successfully loaded.");
    }
    else {
        # We weren't.
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 failed to load.");
        return 0;
    }

    return 1;
}

# Help hash for MODUNLOAD. Spanish, French and German needed.
our %HELP_MODUNLOAD = (
    'en' => 'Unloads a module from the running Auto live.',
);
# MODUNLOAD callback.
sub cmd_modunload
{
    my (%data) = @_;
    my @argv = @{ $data{args} };
    
    # Check for the needed parameters.
    if (!defined $argv[0]) {
        notice($data{svr}, $data{nick}, trans("Not enough parameters").".");
        return 0;
    }

    # Check if the module exists.
    if (!API::Std::mod_exists($argv[0])) {
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 is not loaded.");
        return 0;
    }

    # Go for it!
    my $tn = API::Std::mod_void($argv[0]);

    # Check if we were successful or not.
    if ($tn) {
        # We were!
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 successfully unloaded.");
    }
    else {
        # We weren't.
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 failed to unload.");
        return 0;
    }

    return 1;
}

# Help hash for MODRELOAD. Spanish, French and German needed.
our %HELP_MODRELOAD = (
    'en' => 'Unloads then loads a module into the running Auto live.',
);
# MODRELOAD callback.
sub cmd_modreload
{
    my (%data) = @_;
    my @argv = @{ $data{args} };
    
    # Check for the needed parameters.
    if (!defined $argv[0]) {
        notice($data{svr}, $data{nick}, trans("Not enough parameters").".");
        return 0;
    }

    # Check if the module exists.
    if (!API::Std::mod_exists($argv[0])) {
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 is not loaded.");
        return 0;
    }

    # Go for it!
    my ($tvn, $tln) = (0, 0);
    $tvn = API::Std::mod_void($argv[0]);
    $tln = Auto::mod_load($argv[0]) if $tvn;

    # Check if we were successful or not.
    if ($tvn and $tln) {
        # We were!
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 successfully reloaded.");
    }
    else {
        # We weren't.
        notice($data{svr}, $data{nick}, "Module \002".$argv[0]."\002 failed to reload.");
        return 0;
    }

    return 1;
}

# Help hash for SHUTDOWN. Spanish, French and German needed.
our %HELP_SHUTDOWN = (
    'en' => 'This will send out shutdown notifications, quit all networks, flush the database then exit the program.',
);
# SHUTDOWN callback.
sub cmd_shutdown
{
    my (%data) = @_;
    
    # Goodbye world!
    notice($data{svr}, $data{nick}, "Shutting down.");
    dbug "Got SHUTDOWN from ".$data{nick}."!".$data{user}."@".$data{host}."/".$data{svr}."! Shutting down. . .";
    alog "Got SHUTDOWN from ".$data{nick}."!".$data{user}."@".$data{host}."/".$data{svr}."! Shutting down. . .";
    quit($_, "SHUTDOWN from ".$data{nick}."/".$data{svr}) foreach (keys %Auto::SOCKET);
    DB::flush();
    system("rm $Auto::Bin/auto.pid");
    exit;

    # To appease PerlCritic.
    return 1;
}

# Help hash for RESTART. Spanish, French and German needed.
our %HELP_RESTART = (
    'en' => 'This will send out restart notifications, quit all networks, flush the database, start a new Auto process, then exit the program.',
);
# RESTART callback.
sub cmd_restart
{
    my (%data) = @_;
    
    # Goodbye world!
    notice($data{svr}, $data{nick}, "Restarting.");
    dbug "Got RESTART from ".$data{nick}."!".$data{user}."@".$data{host}."/".$data{svr}."! Restarting. . .";
    alog "Got RESTART from ".$data{nick}."!".$data{user}."@".$data{host}."/".$data{svr}."! Restarting. . .";
    quit($_, "RESTART from ".$data{nick}."/".$data{svr}) foreach (keys %Auto::SOCKET);
    DB::flush();
    system("rm $Auto::Bin/auto.pid") if -e "$Auto::Bin/auto.pid";

    # Time to come back from the dead!
    if ($Auto::DEBUG) {
        system("$Auto::Bin/auto -d");
    }
    else {
        system("$Auto::Bin/auto");
    }
    exit;

    # To appease PerlCritic.
    return 1;
}

# Help hash for HELP. Spanish, French and German needed.
our %HELP_HELP = (
    'en' => 'Displays help for commands.',
);
# HELP callback.
sub cmd_help
{
    my (%data) = @_;
    my @argv = @{ $data{args} }; delete $data{args};

    # Check for arguments and reply accordingly.
    if (!defined $argv[0]) {
        # No command specified. List commands.
        my $cmdlist = '';
        foreach (sort keys %API::Std::CMDS) {
            if (defined $data{chan}) {
                if ($API::Std::CMDS{$_}{lvl} == 0 or $API::Std::CMDS{$_}{lvl} == 2) {
                    if ($API::Std::CMDS{$_}{priv}) {
                        if (has_priv(match_user(%data), $API::Std::CMDS{$_}{priv})) {
                            $cmdlist .= ", \002".uc($_)."\002";
                        }
                    }
                    else {
                        $cmdlist .= ", \002".uc($_)."\002";
                    }
                }
            }
            else {
                if ($API::Std::CMDS{$_}{lvl} == 1 or $API::Std::CMDS{$_}{lvl} == 2) {
                    if ($API::Std::CMDS{$_}{priv}) {
                        if (has_priv(match_user(%data), $API::Std::CMDS{$_}{priv})) {
                            $cmdlist .= ", \002".uc($_)."\002";
                        }
                    }
                    else {
                        $cmdlist .= ", \002".uc($_)."\002";
                    }
                }
            }
        }
        $cmdlist = substr($cmdlist, 2);

        notice($data{svr}, $data{nick}, "Command List: ".$cmdlist);
    }
    else {
        # Help for a specific command was requested. Lets get it.
        my $rcm = uc($argv[0]);

        if (defined $API::Std::CMDS{$rcm}{help}) {
            # If there is help for this command.
            
            # Check for necessary privileges.
            if ($API::Std::CMDS{$rcm}{priv}) {
                if (!has_priv(match_user(%data), $API::Std::CMDS{$rcm}{priv})) {
                    notice($data{svr}, $data{nick}, trans("Access denied").".");
                    return;
                }
            }

            if ($API::Std::CMDS{$rcm}{help}) {
                # If there is valid help for this command.
                
                # Get the language.
                my ($lang, undef) = split('_', $Auto::LOCALE);

                if (defined ${ $API::Std::CMDS{$rcm}{help} }{$lang}) {
                    # If help for this command is available in the configured language.
                    notice($data{svr}, $data{nick}, "Help for \002".$rcm."\002: ".${ $API::Std::CMDS{$rcm}{help} }{$lang});
                }
                else {
                    # If it isn't, default to English.
                    if (defined ${ $API::Std::CMDS{$rcm}{help} }{en}) {
                        # If help for this command is available in English.
                        notice($data{svr}, $data{nick}, "Help for \002".$rcm."\002: ".${ $API::Std::CMDS{$rcm}{help} }{en});
                    }
                    else {
                        # If it isn't, no help.
                        notice($data{svr}, $data{nick}, "No help for \002".$rcm."\002 available.");
                    }
                }
            }
            else {
                # If it isn't valid, no help.
                notice($data{svr}, $data{nick}, "No help for \002".$rcm."\002 available.");
            }
        }
        else {
            # If there is no help, don't give any.
            notice($data{svr}, $data{nick}, "No help for \002".$rcm."\002 available.");
        }
    }

    return 1;
}


1;
