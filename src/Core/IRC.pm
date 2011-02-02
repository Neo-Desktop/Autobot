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


# Help hashes for MODLOAD. Spanish, French and German needed.
our %SHELP_MODLOAD = (
    'en' => 'Load a module.',
);
our %FHELP_MODLOAD = (
    'en' => 'Loads a module into the running Auto live.',
);
# MODLOAD callback.
sub cmd_modload
{
    my (%data) = @_;
    my @argv = @{ $data{args} };
    
    # Check for the appropriate privilege.
    if (!has_priv(match_user(%data), "cfunc.modules")) {
        notice($data{svr}, $data{nick}, trans("Permission denied").".");
        return 0;
    }
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

# Help hashes for MODUNLOAD. Spanish, French and German needed.
our %SHELP_MODUNLOAD = (
    'en' => 'Unload a module.',
);
our %FHELP_MODUNLOAD = (
    'en' => 'Unloads a module from the running Auto live.',
);
# MODUNLOAD callback.
sub cmd_modunload
{
    my (%data) = @_;
    my @argv = @{ $data{args} };
    
    # Check for the appropriate privilege.
    if (!has_priv(match_user(%data), "cfunc.modules")) {
        notice($data{svr}, $data{nick}, trans("Permission denied").".");
        return 0;
    }
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

# Help hashes for MODRELOAD. Spanish, French and German needed.
our %SHELP_MODRELOAD = (
    'en' => 'Reload a module.',
);
our %FHELP_MODRELOAD = (
    'en' => 'Unloads then loads a module into the running Auto live.',
);
# MODRELOAD callback.
sub cmd_modreload
{
    my (%data) = @_;
    my @argv = @{ $data{args} };
    
    # Check for the appropriate privilege.
    if (!has_priv(match_user(%data), "cfunc.modules")) {
        notice($data{svr}, $data{nick}, trans("Permission denied").".");
        return 0;
    }
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

# Help hashes for SHUTDOWN. Spanish, French and German needed.
our %SHELP_SHUTDOWN = (
    'en' => 'Shutdown Auto.',
);
our %FHELP_SHUTDOWN = (
    'en' => 'This will send out shutdown notifications, quit all networks, flush the database then exit the program.',
);
# SHUTDOWN callback.
sub cmd_shutdown
{
    my (%data) = @_;
    
    # Check for the appropriate privilege.
    if (!has_priv(match_user(%data), "cmd.shutdown")) {
        notice($data{svr}, $data{nick}, trans("Permission denied").".");
        return 0;
    }

    # Goodbye world!
    notice($data{svr}, $data{nick}, "Shutting down.");
    dbug "Got SHUTDOWN from ".$data{nick}."!".$data{user}."@".$data{host}."! Shutting down. . .";
    alog "Got SHUTDOWN from ".$data{nick}."!".$data{user}."@".$data{host}."! Shutting down. . .";
    quit($_, "SHUTDOWN from ".$data{nick}) foreach (keys %Auto::SOCKET);
    sleep 1;
    DB::flush();
    sleep 1;
    exit;

    # To appease PerlCritic.
    return 1;
}


1;
