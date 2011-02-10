# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package Lib::Auto;
use strict;
use warnings;
use English qw(-no_match_vars);
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
    API::Std::event_run('on_sighup');
    dbug '!!! Caught SIGHUP but rehash is unavailable; ignoring';
    alog '!!! Caught SIGHUP but rehash is unavailable; ignoring';
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
