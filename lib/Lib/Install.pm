# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Lib::Install;
use strict;
use warnings;
use Exporter;
use English qw(-no_match_vars);
use FindBin qw($Bin);
our $Bin = $Bin;

our $VERSION = 1.00;
our @ISA = qw(Exporter);
our @EXPORT = qw(println modfind build checkver checkcore installmods);

sub println
{
    my ($out) = @_;

    if (defined $out) {
        print $out.$/;
    }
    else {
        print $/;
    }

    return 1;
}

sub modfind
{
    my ($mod) = @_;

    print "    $mod: ";
    eval('require '.$mod.'; 1;') and println "Found" or println "Not Found" and $Install::ERROR = 1;

    return 1;
}

sub build
{
    my ($features) = @_;

    open(my $FTIME, q{>}, "$Bin/build/time") or println "Failed to install." and exit;
    print $FTIME time."\n" or println "Failed to install." and exit;
    close $FTIME or println "Failed to install." and exit;

    open(my $FOS, q{>}, "$Bin/build/os") or println "Failed to install." and exit;
    print $FOS $OSNAME."\n" or println "Failed to install." and exit;
    close $FOS or println "Failed to install." and exit;

    open(my $FFEAT, q{>}, "$Bin/build/feat") or println "Failed to install." and exit;
    print $FFEAT $features."\n" or println "Failed to install." and exit;
    close $FFEAT or println "Failed to install." and exit;

    open(my $FPERL, q{>}, "$Bin/build/perl") or println "Failed to install." and exit;
    print $FPERL "$]\n" or println "Failed to install." and exit;
    close $FPERL or println "Failed to install." and exit;

    open(my $FVER, q{>}, "$Bin/build/ver") or println "Failed to install." and exit;
    print $FVER "3.0.0d\n" or println "Failed to install." and exit;
    close $FVER or println "Failed to install." and exit;

    return 1;
}

sub checkver
{
    my ($ver) = @_;

    println "* Connecting to update server...";
    my $uss = IO::Socket::INET->new(
        'Proto'    => 'tcp',
        'PeerAddr' => 'dist.xelhua.org',
        'PeerPort' => 80,
        'Timeout'  => 30
    ) or println "Cannot connect to update server! Aborting update check.";
    send($uss, "GET http://dist.xelhua.org/auto/version.txt\n", 0);
    my $dll = '';
    while (my $data = readline($uss)) {
        $data =~ s/(\n|\r)//g;
        my ($v, $c) = split('=', $data);

        if ($v eq "url") {
            $dll = $c;
        }
        elsif ($v eq "version") {
            if ($ver ne $c) {
                println("!!! NOTICE !!! Your copy of Auto is outdated. Current version: ".$ver." - Latest version: ".$c);
                println("!!! NOTICE !!! You can get the latest Auto by downloading ".$dll);
                println("!!! NOTICE !!! Won't install without force.");
                exit;
            }
            else {
                println("* Auto is up-to-date.");
            }
        }
    }

    return 1;
}

sub checkcore
{
    println "\0";
    modfind('Carp');
    modfind('FindBin');
    modfind('feature');
    modfind('IO::Socket');
    modfind('Sys::Hostname');
    modfind('POSIX');
    modfind('Time::Local');
}

sub installmods
{
    print 'Would you like to install any official modules? [y/n] ';
    my $response = <STDIN>;
    chomp $response;
    if (lc $response eq 'y') {
        println 'What modules would you like to install? (separate by commas)';
        println 'Available modules: Badwords, Bitly, Calc, EightBall, FML, HelloChan, IsItUp, QDB, SASLAuth, Weather';
        print '> ';
        my $modules = <STDIN>; chomp $modules;
        $modules =~ s/ //g;
        my @modst = split ',', $modules;
        foreach (@modst) {
            system "$Bin/bin/buildmod $_";
        }
    }
}
