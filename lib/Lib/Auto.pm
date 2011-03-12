# lib/Lib/Auto.pm - Core Auto subroutines.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Lib::Auto;
use strict;
use warnings;
use feature qw(say);
use English qw(-no_match_vars);
use Sys::Hostname;
use feature qw(switch);
use API::Std qw(hook_add conf_get err);
use API::Log qw(dbug alog);
our $VERSION = 3.000000;

# Core events.
API::Std::event_add('on_shutdown');
API::Std::event_add('on_rehash');

# Update checker.
sub checkver
{
    if (!$Auto::NUC and Auto::RSTAGE ne 'd') {
        say '* Connecting to update server...';
        my $uss = IO::Socket::INET->new(
            'Proto'    => 'tcp',
            'PeerAddr' => 'dist.xelhua.org',
            'PeerPort' => 80,
            'Timeout'  => 30
        ) or err(1, 'Cannot connect to update server! Aborting update check.');
        send $uss, "GET http://dist.xelhua.org/auto/version.txt\n", 0;
        my $dll = q{};
        while (my $data = readline $uss) {
            $data =~ s/(\n|\r)//g;
            my ($v, $c) = split m/[=]/, $data;

            if ($v eq 'url') {
                $dll = $c;
            }
            elsif ($v eq 'version') {
                if (Auto::VER.q{.}.Auto::SVER.q{.}.Auto::REV.Auto::RSTAGE ne $c) {
                    say('!!! NOTICE !!! Your copy of Auto is outdated. Current version: '.Auto::VER.q{.}.Auto::SVER.q{.}.Auto::REV.Auto::RSTAGE.' - Latest version: '.$c);
                    say('!!! NOTICE !!! You can get the latest Auto by downloading '.$dll);
                }
                else {
                    say('* Auto is up-to-date.');
                }
            }
        }
    }
}

sub rehash
{
    # Parse configuration file.
    my %newsettings = $Auto::CONF->parse or err(2, 'Failed to parse configuration file!', 0) and return;

    # Check for required configuration values.
    my @REQCVALS = qw(locale expire_logs server fantasy_pf ratelimit bantype);
    foreach my $REQCVAL (@REQCVALS) {
        if (!defined $newsettings{$REQCVAL}) {
            err(2, "Missing required configuration value: $REQCVAL", 0) and return;
        }
    }
    undef @REQCVALS;

    # Set new configuration.
    %Auto::SETTINGS = %newsettings;

    # Expire old logs.
    API::Log::expire_logs();

    # Parse privileges.
    my %PRIVILEGES;
    # If there are any privsets.
    if (conf_get('privset')) {
        # Get them.
        my %tcprivs = conf_get('privset');

        foreach my $tckpriv (keys %tcprivs) {
            # For each privset, get the inner values.
            my %mcprivs = conf_get("privset:$tckpriv");

            # Iterate through them.
            foreach my $mckpriv (keys %mcprivs) {
                # Switch statement for the values.
                given ($mckpriv) {
                    # If it's 'priv', save it as a privilege.
                    when ('priv') {
                        if (defined $PRIVILEGES{$tckpriv}) {
                            # If this privset exists, push to it.
                            push @{ $PRIVILEGES{$tckpriv} }, ($mcprivs{$mckpriv})[0][0];
                        }
                        else {
                            # Otherwise, create it.
                            @{ $PRIVILEGES{$tckpriv} } = (($mcprivs{$mckpriv})[0][0]);
                        }
                    }
                    # If it's 'inherit', inherit the privileges of another privset.
                    when ('inherit') {
                        # If the privset we're inheriting exists, continue.
                        if (defined $PRIVILEGES{($mcprivs{$mckpriv})[0][0]}) {
                            # Iterate through each privilege.
                            foreach (@{ $PRIVILEGES{($mcprivs{$mckpriv})[0][0]} }) {
                                # And save them to the privset inheriting them
                                if (defined $PRIVILEGES{$tckpriv}) {
                                    # If this privset exists, push to it.
                                    push @{ $PRIVILEGES{$tckpriv} }, $_;
                                }
                                else {
                                    # Otherwise, create it.
                                    @{ $PRIVILEGES{$tckpriv} } = ($_);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    %Auto::PRIVILEGES = %PRIVILEGES;

    # Load modules.
    if (conf_get('module')) {
        alog '* Loading modules...';
        foreach (@{ (conf_get('module'))[0] }) {
            if (!API::Std::mod_exists($_)) { Auto::mod_load($_); }
        }
    }

    ## Create sockets.
    alog '* Connecting to servers...';
    # Get servers from config.
    my %cservers = conf_get('server');
    # Iterate through each configured server.
    foreach my $cskey (keys %cservers) {
        if (!defined $Auto::SOCKET{$cskey}) {
            ircsock(\%{$cservers{$cskey}}, $cskey);
        }
    }

    # Check for server connections.
    if (!keys %Auto::SOCKET) {
        err(2, 'No IRC connections -- Exiting program.', 0);
        API::Std::event_run('on_shutdown');
        exit 1;
    }

    # Now trigger on_rehash.
    API::Std::event_run('on_rehash');

    return 1;
}

# Socket creation.
sub ircsock {
    my ($cdata, $svrname) = @_;

    # Prepare socket data.
    my %conndata = (
    	Proto => 'tcp',
        LocalAddr => $cdata->{'bind'}[0],
    	PeerAddr  => $cdata->{'host'}[0],
    	PeerPort  => $cdata->{'port'}[0],
        Timeout   => 20,
    );
    # Set IPv6/SSL data.
    my $use6 = 0;
    my $usessl = 0;
    if (defined $cdata->{'ipv6'}[0]) { $use6 = $cdata->{'ipv6'}[0]; }
    if (defined $cdata->{'ssl'}[0]) { $usessl = $cdata->{'ssl'}[0]; }

    # Check for appropriate build data.
    if ($usessl) {
        if ($Auto::ENFEAT !~ m/ssl/ixsm) { err(2, '** Auto not built with SSL support: Aborting connection to '.$svrname, 0); return; }
    }
    if ($use6) {
        if ($Auto::ENFEAT !~ m/ipv6/ixsm) { err(2, '** Auto not built with IPv6 support: Aborting connection to '.$svrname, 0); return; }
    }

    # CertFP.
    if ($usessl) {
        if (defined $cdata->{'certfp'}[0]) {
            if ($cdata->{'certfp'}[0] eq 1) {
                $conndata{'SSL_use_cert'} = 1;
                if (defined $cdata->{'certfp_cert'}[0]) {
                    $conndata{'SSL_cert_file'} = "$Auto::bin{etc}/certs/".$cdata->{'certfp_cert'}[0];
                }
                if (defined $cdata->{'certfp_key'}[0]) {
                    $conndata{'SSL_key_file'} = "$Auto::bin{etc}/certs/".$cdata->{'certfp_key'}[0];
                }
                if (defined $cdata->{'certfp_pass'}[0]) {
                    $conndata{'SSL_passwd_cb'} = sub { return $cdata->{'certfp_pass'}[0]; };
                }
            }
        }
    }

    # Create the socket.
    if ($use6) {
        $Auto::SOCKET{$svrname} = IO::Socket::INET6->new(%conndata) or # Or error.
        err(2, 'Failed to connect to server ('.$ERRNO.'): '.$svrname.' ['.$cdata->{'host'}[0].q{:}.$cdata->{'port'}[0].']', 0)
            and delete $Auto::SOCKET{$svrname} and return;
    }
    else {
        if ($usessl) {
            $Auto::SOCKET{$svrname} = IO::Socket::SSL->new(%conndata) or # Or error.
            err(2, 'Failed to connect to server ('.$ERRNO.'): '.$svrname.' ['.$cdata->{'host'}[0].q{:}.$cdata->{'port'}[0].']', 0)
            and delete $Auto::SOCKET{$svrname} and next;
        }
        else {
            $Auto::SOCKET{$svrname} = IO::Socket::INET->new(%conndata) or # Or error.
            err(2, 'Failed to connect to server ('.$ERRNO.'): '.$svrname.' ['.$cdata->{'host'}[0].q{:}.$cdata->{'port'}[0].']', 0)
            and delete $Auto::SOCKET{$svrname} and next;
        }
    }

    # Create a CAP entry if it doesn't already exist.
    if (!$Proto::IRC::cap{$svrname}) { $Proto::IRC::cap{$svrname} = 'multi-prefix' }
    # Send PASS if we have one.
    if (defined $cdata->{'pass'}[0]) {
        Auto::socksnd($svrname, 'PASS :'.$cdata->{'pass'}[0]) or return;
    }
    # Send CAP LS.
    Auto::socksnd($svrname, 'CAP LS');
    # Trigger on_preconnect.
    API::Std::event_run('on_preconnect', $svrname);
    # Send NICK/USER.
    API::IRC::nick($svrname, $cdata->{'nick'}[0]);
    Auto::socksnd($svrname, 'USER '.$cdata->{'ident'}[0].q{ }.hostname.q{ }.$cdata->{'host'}[0].' :'.$cdata->{'realname'}[0]) or return;
    # Add to select.
    $Auto::SELECT->add($Auto::SOCKET{$svrname});
    # Success!
    alog '** Successfully connected to server: '.$svrname;
    dbug '** Successfully connected to server: '.$svrname;

    return 1;
}

# Shutdown.
hook_add('on_shutdown', 'shutdown.core_cleanup', sub {
    if (defined $Auto::DB) { $Auto::DB->disconnect; }
    if ($Auto::UPREFIX) { if (-e "$Auto::bin{cwd}/auto.pid") { unlink "$Auto::bin{cwd}/auto.pid"; } }
    else { if (-e "$Auto::Bin/auto.pid") { unlink "$Auto::Bin/auto.pid"; } }
    return 1;
});

###################
# Signal handlers #
###################

# SIGTERM
sub signal_term
{
    API::Std::event_run('on_sigterm');
    API::Std::event_run('on_shutdown');
    foreach (keys %Auto::SOCKET) { API::IRC::quit($_, 'Caught SIGTERM'); }
    dbug '!!! Caught SIGTERM; terminating...';
    alog '!!! Caught SIGTERM; terminating...';
    sleep 1;
    exit;
}

# SIGINT
sub signal_int
{
    API::Std::event_run('on_sigint');
    API::Std::event_run('on_shutdown');
    foreach (keys %Auto::SOCKET) { API::IRC::quit($_, 'Caught SIGINT'); }
    dbug '!!! Caught SIGINT; terminating...';
    alog '!!! Caught SIGINT; terminating...';
    sleep 1;
    exit;
}

# SIGHUP
sub signal_hup
{
    dbug '!!! Caught SIGHUP; rehashing';
    alog '!!! Caught SIGHUP; rehashing';
    rehash();
    API::Std::event_run('on_sighup');
    return 1;
}

# __WARN__
sub signal_perlwarn
{
    my ($warnmsg) = @_;
    $warnmsg =~ s/(\n|\r)//xsmg;
    alog 'Perl Warning: '.$warnmsg;
    if ($Auto::DEBUG) { say 'Perl Warning: '.$warnmsg; }
    return 1;
}

# __DIE__
sub signal_perldie
{
    my ($diemsg) = @_;
    $diemsg =~ s/(\n|\r)//xsmg;

    return if $EXCEPTIONS_BEING_CAUGHT;
    alog 'Perl Fatal: '.$diemsg.' -- Terminating program!';
    foreach (keys %Auto::SOCKET) { API::IRC::quit($_, 'A fatal error occurred!'); }
    API::Std::event_run('on_shutdown');
    sleep 1;
    say 'FATAL: '.$diemsg;
    exit;
}


1;
# vim: set ai et sw=4 ts=4:
