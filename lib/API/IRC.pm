# lib/API/IRC.pm - IRC API subroutines.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package API::IRC;
use strict;
use warnings;
use feature qw(switch);
use Exporter;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(ban cjoin cpart cmode umode kick privmsg notice quit nick names
                    topic who usrc match_mask);

# Create the on_disconnect event.
API::Std::event_add('on_disconnect');

# Set a ban, based on config bantype value.
sub ban
{
    my ($svr, $chan, $type, $user) = @_;
    my $cbt = (API::Std::conf_get('bantype'))[0][0];

    # Prepare the mask we're going to ban.
    my $mask;
    given ($cbt) {
        when (1) { $mask = '*!*@'.$user->{host}; }
        when (2) { $mask = $user->{nick}.'!*@*'; }
        when (3) { $mask = '*!'.$user->{user}.'@'.$user->{host}; }
        when (4) { $mask = $user->{nick}.'!*'.$user->{user}.'@'.$user->{host}; }
        when (5) {
            my @hd = split m/[\.]/, $user->{host};
            shift @hd;
            $mask = '*!*@*.'.join ' ', @hd;
        }
    }

    # Now set the ban.
    if (lc $type eq 'b') {
        # We were requested to set a regular ban.
        cmode($svr, $chan, "+b $mask");
    }
    elsif (lc $type eq 'q') {
        # We were requested to set a ratbox-style quiet.
        cmode($svr, $chan, "+q $mask");
    }

    return 1;
}

# Join a channel.
sub cjoin 
{
    my ($svr, $chan, $key) = @_;
    
    Auto::socksnd($svr, "JOIN ".((defined $key) ? "$chan $key" : "$chan"));
    
    return 1;
}

# Part a channel.
sub cpart 
{
    my ($svr, $chan, $reason) = @_;
    
    if (defined $reason) {
    	Auto::socksnd($svr, "PART $chan :$reason");
    }
    else {
    	Auto::socksnd($svr, "PART $chan :Leaving");
    }

    return 1;
}

# Set mode(s) on a channel.
sub cmode 
{
    my ($svr, $chan, $modes) = @_;

    Auto::socksnd($svr, "MODE $chan $modes");
    
    return 1;
}

# Set mode(s) on us.
sub umode 
{
    my ($svr, $modes) = @_;
    
    Auto::socksnd($svr, "MODE ".$Proto::IRC::botinfo{$svr}{nick}." $modes");
    
    return 1;
} 

# Send a PRIVMSG.
sub privmsg 
{
    my ($svr, $target, $message) = @_;
    
    # Get maximum length.
    my $maxlen = 510 - length q{:}.$Proto::IRC::botinfo{$svr}{nick}.q{!}.$Proto::IRC::botinfo{$svr}{user}.q{@}.$Proto::IRC::botinfo{$svr}{mask}." PRIVMSG $target :";

    # Divide message if it surpasses the maximum length.
    while (length $message >= $maxlen) {
        my $submsg = substr $message, 0, $maxlen, q{};
        Auto::socksnd($svr, "PRIVMSG $target :$submsg");
    }
    if (length $message) { Auto::socksnd($svr, "PRIVMSG $target :$message") }
    
    return 1;
}

# Send a NOTICE.
sub notice 
{
    my ($svr, $target, $message) = @_;
    
    # Get maximum length.
    my $maxlen = 510 - length q{:}.$Proto::IRC::botinfo{$svr}{nick}.q{!}.$Proto::IRC::botinfo{$svr}{user}.q{@}.$Proto::IRC::botinfo{$svr}{mask}." NOTICE $target :";

    # Divide message if it surpasses the maximum length.
    while (length $message >= $maxlen) {
        my $submsg = substr $message, 0, $maxlen, q{};
        Auto::socksnd($svr, "NOTICE $target :$submsg");
    }
    if (length $message) { Auto::socksnd($svr, "NOTICE $target :$message") }
    
    return 1;
}

# Send an ACTION PRIVMSG.
sub act
{
    my ($svr, $target, $message) = @_;

    Auto::socksnd($svr, "PRIVMSG $target :\001ACTION $message\001");

    return 1;
}

# Change bot nickname.
sub nick 
{
    my ($svr, $newnick) = @_;
    
    Auto::socksnd($svr, "NICK $newnick");
    
    $Proto::IRC::botinfo{$svr}{newnick} = $newnick;

    return 1;
}

# Request the users of a channel.
sub names
{
    my ($svr, $chan) = @_;
    
    Auto::socksnd($svr, "NAMES $chan");
    
    return 1;
}

# Send a topic to the channel.
sub topic
{
    my ($svr, $chan, $topic) = @_;
    
    Auto::socksnd($svr, "TOPIC $chan :$topic");
    
    return 1;
}

# Kick a user.
sub kick
{
    my ($svr, $chan, $nick, $msg) = @_;

    Auto::socksnd($svr, "KICK $chan $nick :".((defined $msg) ? $msg : 'No reason'));

    return 1;
}

# Quit IRC.
sub quit {
    my ($svr, $reason) = @_;
    
    if (defined $reason) {
    	Auto::socksnd($svr, "QUIT :$reason");
    }
    else {
    	Auto::socksnd($svr, 'QUIT :Leaving');
    }

    # Trigger on_disconnect.
    API::Std::event_run('on_disconnect', $svr);

    return 1;
}

# Send a WHO.
sub who {
    my ($svr, $nick) = @_;

    Auto::socksnd($svr, "WHO $nick");

    return 1;
}

# Get nick, ident and host from a <nick>!<ident>@<host>
sub usrc
{
    my ($ex) = @_;
    
    my @si = split('!', $ex);
    my @sii = split('@', $si[1]);
    
    return (
    	nick  => $si[0],
    	user => $sii[0],
    	host  => $sii[1]
    );
}

# Match two IRC masks.
sub match_mask
{
    my ($mu, $mh) = @_;
    
    # Prepare the regex.
    $mh =~ s/\./\\\./g;
    $mh =~ s/\?/\./g;
    $mh =~ s/\*/\.\*/g;
    $mh = '^'.$mh.'$';
    
    # Let's grep the user's mask.
    if (grep(/$mh/, $mu)) {
    	return 1;
    }
    
    return 0;
}


1;
# vim: set ai et sw=4 ts=4:
