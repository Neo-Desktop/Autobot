# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Lib::Auto;
use strict;
use warnings;
use English qw(-no_match_vars);
use Sys::Hostname;
use feature qw(switch);
use API::Std qw(conf_get err);
use API::Log qw(println dbug alog);
our $VERSION = 3.000000;

# Update checker.
sub checkver
{
    if (!$Auto::NUC and Auto::RSTAGE ne 'd') {
        println '* Connecting to update server...';
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
                    println('!!! NOTICE !!! Your copy of Auto is outdated. Current version: '.Auto::VER.q{.}.Auto::SVER.q{.}.Auto::REV.Auto::RSTAGE.' - Latest version: '.$c);
                    println('!!! NOTICE !!! You can get the latest Auto by downloading '.$dll);
                }
                else {
                    println('* Auto is up-to-date.');
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
    my @REQCVALS = qw(locale expire_logs server fantasy_pf);
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
            # Prepare socket data.
            my %conndata = (
                Proto => 'tcp',
                LocalAddr => $cservers{$cskey}{'bind'}[0],
                PeerAddr  => $cservers{$cskey}{'host'}[0],
                PeerPort  => $cservers{$cskey}{'port'}[0],
                Timeout   => 20,
            );
            # Set IPv6/SSL data.
            my $use6 = 0;
            my $usessl = 0;
            if (defined $cservers{$cskey}{'ipv6'}[0]) { $use6 = $cservers{$cskey}{'ipv6'}[0]; }
            if (defined $cservers{$cskey}{'ssl'}[0]) { $usessl = $cservers{$cskey}{'ssl'}[0]; }

            # CertFP.
            if ($usessl) {
                if (defined $cservers{$cskey}{'certfp'}[0]) {
                    if ($cservers{$cskey}{'certfp'}[0] eq 1) {
                        $conndata{'SSL_use_cert'} = 1;
                        if (defined $cservers{$cskey}{'certfp_cert'}[0]) {
                            $conndata{'SSL_cert_file'} = "$Auto::Bin/../etc/certs/".$cservers{$cskey}{'certfp_cert'}[0];
                        }
                        if (defined $cservers{$cskey}{'certfp_key'}[0]) {
                            $conndata{'SSL_key_file'} = "$Auto::Bin/../etc/certs/".$cservers{$cskey}{'certfp_key'}[0];
                        }
                        if (defined $cservers{$cskey}{'certfp_pass'}[0]) {
                            $conndata{'SSL_passwd_cb'} = sub { return $cservers{$cskey}{'certfp_pass'}[0]; };
                        }
                    }
                }
            }

            # Create the socket.
            if ($use6) {
                $Auto::SOCKET{$cskey} = IO::Socket::INET6->new(%conndata) or # Or error.
                err(2, 'Failed to connect to server ('.$ERRNO.'): '.$cskey.' ['.$cservers{$cskey}{'host'}[0].q{:}.$cservers{$cskey}{'port'}[0].']', 0)
                    and delete $Auto::SOCKET{$cskey} and next;
            }
            else {
                if ($usessl) {
                    $Auto::SOCKET{$cskey} = IO::Socket::SSL->new(%conndata) or # Or error.
                    err(2, 'Failed to connect to server ('.$ERRNO.'): '.$cskey.' ['.$cservers{$cskey}{'host'}[0].q{:}.$cservers{$cskey}{'port'}[0].']', 0)
                        and delete $Auto::SOCKET{$cskey} and next;
                }
                else {
                    $Auto::SOCKET{$cskey} = IO::Socket::INET->new(%conndata) or # Or error.
                    err(2, 'Failed to connect to server ('.$ERRNO.'): '.$cskey.' ['.$cservers{$cskey}{'host'}[0].q{:}.$cservers{$cskey}{'port'}[0].']', 0)
                        and delete $Auto::SOCKET{$cskey} and next;
                }
            }

            # Send PASS if we have one.
            if (defined $cservers{$cskey}{'pass'}[0]) {
                Auto::socksnd($cskey, 'PASS :'.$cservers{$cskey}{'pass'}[0]) or
                err(2, 'Failed to connect to server: '.$cskey.' ['.$cservers{$cskey}{'host'}[0].q{:}.$cservers{$cskey}{'port'}[0].']', 0)
                    and next;
            }
            API::Std::event_run('on_preconnect', $cskey);
            # Send NICK/USER.
            API::IRC::nick($cskey, $cservers{$cskey}{'nick'}[0]);
            Auto::socksnd($cskey, 'USER '.$cservers{$cskey}{'ident'}[0].q{ }.hostname.q{ }.$cservers{$cskey}{'host'}[0].' :'.$cservers{$cskey}{'realname'}[0]) or
            err(2, 'Failed to connect to server: '.$cskey.' ['.$cservers{$cskey}{'host'}[0].q{:}.$cservers{$cskey}{'port'}[0].']', 0)
                and next;
            # Add to select.
            $Auto::SELECT->add($Auto::SOCKET{$cskey});
            # Success!
            alog '** Successfully connected to server: '.$cskey;
            dbug '** Successfully connected to server: '.$cskey;
        }
    }

    return 1;
}

###################
# Signal handlers #
###################

# SIGTERM
sub signal_term
{
    API::Std::event_run('on_sigterm');
    foreach (keys %Auto::SOCKET) { API::IRC::quit($_, 'Caught SIGTERM'); }
    $Auto::DB->disconnect;
    dbug '!!! Caught SIGTERM; terminating...';
    alog '!!! Caught SIGTERM; terminating...';
    if (-e "$Auto::Bin/auto.pid") {
        unlink "$Auto::Bin/auto.pid";
    }
    sleep 1;
    exit;
}

# SIGINT
sub signal_int
{
    API::Std::event_run('on_sigint');
    foreach (keys %Auto::SOCKET) { API::IRC::quit($_, 'Caught SIGINT'); }
    $Auto::DB->disconnect;
    dbug '!!! Caught SIGINT; terminating...';
    alog '!!! Caught SIGINT; terminating...';
    if (-e "$Auto::Bin/auto.pid") {
        unlink "$Auto::Bin/auto.pid";
    }
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
    if ($Auto::DEBUG) { println 'Perl Warning: '.$warnmsg; }
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
    $Auto::DB->disconnect;
    if (-e "$Auto::Bin/auto.pid") {
        unlink "$Auto::Bin/auto.pid";
    }
    sleep 1;
    println 'FATAL: '.$diemsg;
    exit;
}


1;
# vim: set ai sw=4 ts=4:
