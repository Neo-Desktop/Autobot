# Module: LOLCAT. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::LOLCAT;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use Acme::LOLCAT;

# Initialization subroutine.
sub _init {
    # Create LOLCAT command.
    cmd_add('LOLCAT', 0, 0, \%M::LOLCAT::HELP_LOLCAT, \&M::LOLCAT::cmd_lolcat) or return;
    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete LOLCAT command.
    cmd_del('LOLCAT') or return;
    # Success.
    return 1;
}

# Help for LOLCAT.
our %HELP_LOLCAT = (
    en => "This command will translate English to LOLCAT speak. \2Syntax:\2 LOLCAT <text>",
);

# Callback for LOLCAT command.
sub cmd_lolcat {
    my ($src, @argv) = @_;

    # At least one parameter is required.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Return LOLCAT translation.
    privmsg($src->{svr}, $src->{chan}, 'Result: '.translate(join q{ }, @argv));
    
    return 1;
}

# Start initialization.
API::Std::mod_init('LOLCAT', 'Xelhua', '1.00', '3.0.0a8', __PACKAGE__);
# build: perl=5.010000 cpan=Acme::LOLCAT

__END__

=head1 NAME

LOLCAT - Translates English into LOLCAT.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <starcoder> !lolcat You too can speak like a lolcat!
 <Auto> Result: YU T CAN SPEKK LIEK LOLCAT!  KTHXBYE!

=head1 DESCRIPTION

This will create the LOLCAT command which allows you to translate English text
into LOLCAT speak.

See also: http://en.wikipedia.org/wiki/Lolcat

=head1 DEPENDENCIES

This module is dependent on the following modules from CPAN:

=over

=item L<Acme::LOLCAT>

This is what the module uses to translate English into LOLCAT.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:
