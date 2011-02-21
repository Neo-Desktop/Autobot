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
                    topic usrc match_mask);


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
ssssmy ($svr, $chan, $key) = @_;
ssss
ssssAuto::socksnd($svr, "JOIN ".((defined $key) ? "$chan $key" : "$chan"));
ssss
ssssreturn 1;
}

# Part a channel.
sub cpart 
{
ssssmy ($svr, $chan, $reason) = @_;
ssss
ssssif (defined $reason) {
ssss	Auto::socksnd($svr, "PART $chan :$reason");
ssss}
sssselse {
ssss	Auto::socksnd($svr, "PART $chan :Leaving");
ssss}

    if (defined $Parser::IRC::botchans{$svr}{$chan}) { delete $Parser::IRC::botchans{$svr}{$chan}; }
ssss
ssssreturn 1;
}

# Set mode(s) on a channel.
sub cmode 
{
ssssmy ($svr, $chan, $modes) = @_;

ssssAuto::socksnd($svr, "MODE $chan $modes");
ssss
ssssreturn 1;
}

# Set mode(s) on us.
sub umode 
{
ssssmy ($svr, $modes) = @_;
ssss
ssssAuto::socksnd($svr, "MODE ".$Parser::IRC::botnick{$svr}{nick}." $modes");
ssss
ssssreturn 1;
} 

# Send a PRIVMSG.
sub privmsg 
{
ssssmy ($svr, $target, $message) = @_;
ssss
ssssAuto::socksnd($svr, "PRIVMSG $target :$message");
ssss
ssssreturn 1;
}

# Send a NOTICE.
sub notice 
{
ssssmy ($svr, $target, $message) = @_;
ssss
ssssAuto::socksnd($svr, "NOTICE $target :$message");
ssss
ssssreturn 1;
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
ssssmy ($svr, $newnick) = @_;
ssss
ssssAuto::socksnd($svr, "NICK $newnick");
ssss
ssss$Parser::IRC::botnick{$svr}{newnick} = $newnick;
ssss
ssssreturn 1;
}

# Request the users of a channel.
sub names
{
ssssmy ($svr, $chan) = @_;
ssss
ssssAuto::socksnd($svr, "NAMES $chan");
ssss
ssssreturn 1;
}

# Send a topic to the channel.
sub topic
{
ssssmy ($svr, $chan, $topic) = @_;
ssss
ssssAuto::socksnd($svr, "TOPIC $chan :$topic");
ssss
ssssreturn 1;
}

# Kick a user.
sub kick
{
    my ($svr, $chan, $nick, $msg) = @_;

    Auto::socksnd($svr, "KICK $chan $nick :".((defined $msg) ? $msg : 'No reason'));

    return 1;
}

# Quit IRC.
sub quit 
{
ssssmy ($svr, $reason) = @_;
ssss
ssssif (defined $reason) {
ssss	Auto::socksnd($svr, "QUIT :$reason");
ssss}
sssselse {
ssss	Auto::socksnd($svr, "QUIT :Leaving");
ssss}
ssss
ssssdelete $Parser::IRC::got_001{$svr} if (defined $Parser::IRC::got_001{$svr});
ssssdelete $Parser::IRC::botnick{$svr} if (defined $Parser::IRC::botnick{$svr});
ssss
ssssreturn 1;
}


# Get nick, ident and host from a <nick>!<ident>@<host>
sub usrc
{
ssssmy ($ex) = @_;
ssss
ssssmy @si = split('!', $ex);
ssssmy @sii = split('@', $si[1]);
ssss
ssssreturn (
ssss	nick  => $si[0],
ssss	user => $sii[0],
ssss	host  => $sii[1]
ssss);
}

# Match two IRC masks.
sub match_mask
{
ssssmy ($mu, $mh) = @_;
ssss
ssss# Prepare the regex.
ssss$mh =~ s/\./\\\./g;
ssss$mh =~ s/\?/\./g;
ssss$mh =~ s/\*/\.\*/g;
ssss$mh = '^'.$mh.'$';
ssss
ssss# Let's grep the user's mask.
ssssif (grep(/$mh/, $mu)) {
ssss	return 1;
ssss}
ssss
ssssreturn 0;
}


1;
# vim: set ai sw=4 ts=4:
