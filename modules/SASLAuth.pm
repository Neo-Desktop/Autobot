# Module: SASLAuth. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::SASLAuth;
use strict;
use warnings;
use feature qw(switch);
use MIME::Base64;
use API::Std qw(hook_add hook_del rchook_add rchook_del conf_get err awarn timer_add timer_del);
use API::IRC qw(privmsg);


# Initialization subroutine.
sub _init
{
    # Check if this Auto was built with SASL support.
    if ($Auto::ENFEAT !~ m/sasl/xsm) { err(2, 'Auto was not built with SASL support. Aborting SASLAuth.', 0) and return; }
    # Add sasl to supported CAP for servers configured with SASL.
    my %servers = conf_get('server');
    foreach my $svr (keys %servers) {
        if (conf_get("server:$svr:sasl_username")) { $Proto::IRC::cap{$svr} .= ' sasl'; }
    }
    # Hook for when CAP ACK sasl is received.
    hook_add('on_capack', 'sasl.cap', \&M::SASLAuth::handle_capack) or return;
    # Hook for parsing 903.
    rchook_add('903', \&M::SASLAuth::handle_903) or return;
    # Hook for parsing 904.
    rchook_add('904', \&M::SASLAuth::handle_904) or return;
    # Hook for parsing 906.
    rchook_add('906', \&M::SASLAuth::handle_906) or return;
    return 1;
}

# Void subroutine.
sub _void
{
    # Delete the hooks.
    hook_del('on_capack') or return;
    rchook_del('903') or return;
    rchook_del('904') or return;
    rchook_del('906') or return;
    return 1;
}

sub handle_capack {
    my (($svr, $sacap)) = @_;
 
    if ($sacap eq 'sasl') {
        Auto::socksnd($svr, 'AUTHENTICATE PLAIN');
        timer_add('auth_timeout_'.$svr, 1, (conf_get("server:$svr:sasl_timeout"))[0][0], sub { Auto::socksnd($svr, 'CAP END'); });
    }
    
    return 1;
}

# Parse: AUTHENTICATE
sub handle_authenticate 
{
    my ($srv, @parv) = @_;
    my $u = (conf_get("server:$srv:sasl_username"))[0][0];
    my $p = (conf_get("server:$srv:sasl_password"))[0][0];
    my $out = join( "\0", $u, $u, $p );
    $out = encode_base64( $out, "" );

    if ( length $out == 0 ) {
        Auto::socksnd($srv, "AUTHENTICATE +");
        return;
    }
    else {
        while ( length $out >= 400 ) {
            my $subout = substr( $out, 0, 400, '' );
            Auto::socksnd($srv, "AUTHENTICATE $subout");
        }
        if ( length $out ) {
            Auto::socksnd($srv, "AUTHENTICATE $out");
        }
        else {
            Auto::socksnd($srv, "AUTHENTICATE +");
        }
    }
    return 1;
}

# Parse: Numeric:903
# SASL authentication successful.
sub handle_903 
{ 
    my ($srv, undef) = @_; 
    timer_add('cap_end_'.$srv, 1, 2, sub { Auto::socksnd($srv, 'CAP END') });
    timer_del('auth_timeout_'.$srv);
}

# Parse: Numeric:904
# SASL authentication failed.
sub handle_904 
{ 
    my ($srv, undef) = @_; 
    timer_add('cap_end_'.$srv, 1, 2, sub { Auto::socksnd($srv, 'CAP END') });
    timer_del('auth_timeout_'.$srv);
    awarn(2, "SASL authentication failed!");
}

# Parse: Numeric:906
# SASL authentication aborted.
sub handle_906 
{
    my ($svr, undef) = @_;
    timer_add('cap_end_'.$svr, 1, 2, sub { Auto::socksnd($svr, 'CAP END') });
    timer_del('auth_timeout_'.$svr);
    awarn(2, "SASL authentication aborted!");
}

# Start initialization.
API::Std::mod_init('SASLAuth', 'Xelhua', '1.00', '3.0.0a7', __PACKAGE__);
# vim: set ai et sw=4 ts=4:
# build: perl=5.010000

__END__

=head1 SASLAuth

=head2 Description

=over

This module adds support for IRCv3 SASL authentication, a nicer way of authenticating
to services and/or the IRCd.

SASL is available in Charybdis IRCd's and InspIRCd 1.2+ with m_cap and m_sasl. Atheme
IRC Services also allows you to identify to NickServ/UserServ with SASL.

=back

=head2 How To Use

=over

To use SASLAuth, first add it to module auto-load then add the following to the server
block(s) you wish to use SASL with:

  sasl_username "services accountname";
  sasl_password "services password";
  sasl_timeout <timeout in seconds>;

=back

=head2 Examples

=over

  sasl_username "JohnBot";
  sasl_password "foobar12345";
  sasl_timeout 20;

=back

=head2 To Do

=over

* Add support for SASL mechanism DH-BLOWFISH.

=back

=head2 Technical

=over

This adds an extra dependency: You must build Auto with the 
--enable-sasl option.

This module is compatible with Auto v3.0.0a7+.

=back
