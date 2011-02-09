# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package Lib::Auto;
use strict;
use warnings;
use API::Log qw(println);
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
