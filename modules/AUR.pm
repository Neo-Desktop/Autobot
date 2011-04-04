# Module: AUR. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::AUR;
use strict;
use warnings;
use WWW::AUR;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(notice privmsg);

# Initialization subroutine.
sub _init {
    # Create the AUR command.
    cmd_add('AUR', 0, 0, \%M::AUR::HELP_AUR, \&M::AUR::cmd_aur) or return;
    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the AUR command.
    cmd_del('AUR') or return;

    # Success.
    return 1;
}


# Help hash for AUR. Spanish and French translations needed.
our %HELP_AUR = (
    en => "This command allows you to lookup a module in the Arch Linux AUR. \2Syntax:\2 AUR <module>",
    de => "Dieser Befehl ermoeglicht du auf nachschlagst ein Modul in der Arch Linux AUR. \2Syntax:\2 AUR <module>",
);

# Callback for AUR command.
sub cmd_aur {
    my ($src, ($mod)) = @_;

    # Check for needed parameters.
    if (!defined $mod) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Create an instance of WWW::AUR.
    my $aur = WWW::AUR->new;
    # Create an instance of WWW::AUR::Package.
    my $pkg = $aur->find($mod);

    # Check if there was a result.
    if (defined $pkg) {
        # Return the results.
        privmsg($src->{svr}, $src->{chan}, "Results for \2$mod\2:");
        privmsg($src->{svr}, $src->{chan}, 'ID: '.$pkg->id.' | Name: '.$pkg->name.' | Version: '.$pkg->version);
        privmsg($src->{svr}, $src->{chan}, 'Maintainer: '.$pkg->maintainer->name);
        privmsg($src->{svr}, $src->{chan}, 'URL: https://aur.archlinux.org/packages.php?ID='.$pkg->id);
    }
    else {
        # Else return no results.
        privmsg($src->{svr}, $src->{chan}, "No results for \2$mod\2.");
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('AUR', 'Xelhua', '1.00', '3.0.0a10');
# build: cpan=WWW::AUR perl=5.010000

__END__

=head1 NAME

AUR - AUR package information module.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <JohnSmith> !aur autobot-git
 <Auto> Results for autobot-git:
 <Auto> ID: 47329 Name: autobot-git Version: 20110311-1
 <Auto> Maintainer: iElijah101
 <Auto> URL: https://aur.archlinux.org/packages.php?ID=47329

=head1 DESCRIPTION

This module adds a command to allow getting information on a package in the
Arch User Repository at https://aur.archlinux.org.

=head1 DEPENDENCIES

This module is dependent on the following modules from CPAN:

=over

=item L<WWW::AUR>

Interface to the Arch User Repository.

=back

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
