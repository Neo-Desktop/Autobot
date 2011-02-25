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
    err(2, "Auto was not built with SASL support. Aborting SASLAuth.", 0) and return 0 if $Auto::ENFEAT !~ /sasl/;
    # Add a hook for before we connect.
    hook_add('on_preconnect', 'CAP', sub { my ($srv) = @_; Auto::socksnd($srv, 'CAP LS'); }
    ) or return 0;
    # Hook for parsing CAP.
    rchook_add('CAP', \&M::SASLAuth::handle_cap) or return 0;
    # Hook for parsing 903.
    rchook_add('903', \&M::SASLAuth::handle_903) or return 0;
    # Hook for parsing 904.
    rchook_add('904', \&M::SASLAuth::handle_904) or return 0;
    # Hook for parsing 906.
    rchook_add('906', \&M::SASLAuth::handle_906) or return 0;
    return 1;
}

# Void subroutine.
sub _void
{
    # Delete the hooks.
    hook_del("on_preconnect", "CAP") or return 0;
    rchook_del('CAP');
    rchook_del('903');
    rchook_del('904');
    rchook_del('906');
    return 1;
}

sub handle_cap {
    my ($srv, @parv) = @_;
    my $line = join(' ',@parv);
    my ($tosend);
    
    given ($line) {
        when (/ LS /) {
            $tosend .= 'multi-prefix ' if $line =~ /multi-prefix/i;
            $tosend .= 'sasl ' if $line =~ /sasl/ and conf_get("server:$srv:sasl_username");
            awarn(2, "SASL is unavailable on this server.") if $tosend !~ /sasl/;
            if ($tosend eq '') { Auto::socksnd($srv, 'CAP END') }
            else { Auto::socksnd($srv, "CAP REQ :$tosend"); }
        }
        when (/ ACK /) {
            if ( $line =~ /sasl/) {
                Auto::socksnd($srv, 'AUTHENTICATE PLAIN');
                timer_add('auth_timeout', 1, (conf_get("server:$srv:sasl_timeout"))[0][0], sub { Auto::socksnd($srv, 'CAP END'); });
            }
            else {
                Auto::socksnd($srv, 'CAP END');
                awarn(2, "SASL authentication failed at ACK");
            }
        }
        when (/ NAK /) {
            Auto::socksnd($srv, 'CAP END');
            awarn(2, "SASL authentication failed. Server refused ".$tosend);
        }
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
    Auto::socksnd($srv, 'CAP END');
    timer_del('auth_timeout');
}

# Parse: Numeric:904
# SASL authentication failed.
sub handle_904 
{ 
    my ($srv, undef) = @_; 
    Auto::socksnd($srv, 'CAP END');
    timer_del('auth_timeout');
    awarn(2, "SASL authentication failed!");
}

# Parse: Numeric:906
# SASL authentication aborted.
sub handle_906 
{
    my ($svr, undef) = @_;
    Auto::socksnd($svr, 'CAP END');
    timer_del('auth_timeout');
    awarn(2, "SASL authentication aborted!");
}

# Start initialization.
API::Std::mod_init('SASLAuth', 'Xelhua', '1.00', '3.0.0a4', __PACKAGE__);
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

This module is compatible with Auto v3.0.0a4+.

=back
