# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Core IRC functionality.
package Core::IRC;
use strict;
use warnings;
use English;
use API::Std qw(trans has_priv match_user);
use API::IRC qw(notice usrc);

sub version_reply
{
    my (($svr, @ex)) = @_;
    my %src = usrc(substr($ex[0], 1));

    if ($ex[3] eq ":\001VERSION\001") {
        notice($svr, $src{nick}, "VERSION ".Auto::NAME." ".Auto::VER.".".Auto::SVER.".".Auto::REV.Auto::RSTAGE." ".$OSNAME);
    }

    return 1;
}


# Help hashes for CMDLOAD. Spanish, French and German needed.
our %SHELP_CMDLOAD = (
    'en' => 'Load a module.',
);
our %FHELP_CMDLOAD = (
    'en' => 'Loads a module into the running Auto live.',
);
# CMDLOAD callback.
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


1;
