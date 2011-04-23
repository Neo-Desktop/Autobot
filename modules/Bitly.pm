# Module: Bitly. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Bitly;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del conf_get err trans);
use API::IRC qw(privmsg notice);
use LWP::UserAgent;
use URI::Escape;

# Initialization subroutine.
sub _init 
{
    # Check for required configuration values.
    if (!conf_get('bitly:user') or !conf_get('bitly:key')) {
        err(2, 'Bitly: Please verify that you have bitly_user and bitly_key defined in your configuration file.', 0);
        return;
    }
    # Create the SHORTEN and REVERSE commands.
    cmd_add('SHORTEN', 0, 0, \%M::Bitly::HELP_SHORTEN, \&M::Bitly::shorten) or return;
    cmd_add('REVERSE', 0, 0, \%M::Bitly::HELP_REVERSE, \&M::Bitly::reverse) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void 
{
    # Delete the SHORTEN and REVERSE commands.
    cmd_del('SHORTEN') or return;
    cmd_del('REVERSE') or return;

    # Success.
    return 1;
}

# Help hashes.
our %HELP_SHORTEN = (
    en => "This command will shorten an URL using Bit.ly. \2Syntax:\2 SHORTEN <url>",
    de => "Dieser Befehl wird eine URL verkuerzen. \2Syntax:\2 SHORTEN <url>",
);
our %HELP_REVERSE = (
    en => "This command will expand a Bit.ly URL. \2Syntax:\2 REVERSE <url>",
    de => "Dieser Befehl wird eine URL erweitern. \2Syntax:\2 REVERSE <url>",
);

# Callback for SHORTEN command.
sub shorten 
{
    my ($src, @args) = @_;

    # Create an instance of LWP::UserAgent.
    my $ua = LWP::UserAgent->new();
    $ua->agent('Auto IRC Bot');
    $ua->timeout(2);
    
    # Put together the call to the Bit.ly API. 
    if (!defined $args[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').".");
        return;
    }
    my ($surl, $user, $key) = ($args[0], (conf_get('bitly:user'))[0][0], (conf_get('bitly:key'))[0][0]);
    $surl = uri_escape($surl);
    my $url = "http://api.bit.ly/v3/shorten?version=3.0.1&longUrl=".$surl."&apiKey=".$key."&login=".$user."&format=txt";
    # Get the response via HTTP.
    my $response = $ua->get($url);

    if ($response->is_success) {
        # If successful, decode the content.
        my $d = $response->decoded_content;
        chomp $d;
        # And send to channel.
        privmsg($src->{svr}, $src->{chan}, "URL: ".$d);
    }
    else {
        # Otherwise, send an error message.
        privmsg($src->{svr}, $src->{chan}, 'An error occurred while shortening your URL.');
    }

    return 1;
}

# Callback for REVERSE command.
sub reverse 
{
    my ($src, @args) = @_;

    # Create an instance of LWP::UserAgent.
    my $ua = LWP::UserAgent->new();
    $ua->agent('Auto IRC Bot');
    $ua->timeout(2);

    # Put together the call to the Bit.ly API.
    if (!defined $args[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').".");
        return;
    }
    my ($surl, $user, $key) = ($args[0], (conf_get('bitly:user'))[0][0], (conf_get('bitly:key'))[0][0]);
    $surl = uri_escape($surl);
    my $url = "http://api.bit.ly/v3/expand?version=3.0.1&shortURL=".$surl."&apiKey=".$key."&login=".$user."&format=txt";
    # Get the response via HTTP.
    my $response = $ua->get($url);

    if ($response->is_success) {
        # If successful, decode the content.
        my $d = $response->decoded_content;
        chomp $d;
        # And send it to channel.
        privmsg($src->{svr}, $src->{chan}, "URL: ".$d);
    }
    else {
        # Otherwise, send an error message.
        privmsg($src->{svr}, $src->{chan}, 'An error occurred while reversing your URL.');
    }

    return 1;
}


# Start initialization.
API::Std::mod_init('Bitly', 'Xelhua', '1.00', '3.0.0a10');
# build: cpan=LWP::UserAgent,URI::Escape perl=5.010000

__END__

=head1 Bitly

=head2 Description

=over

This module adds the SHORTEN and REVERSE commands for shortening/expanding an
URL using the bit.ly shortening service API.

=back

=head2 How To Use

=over

Add Bitly to module auto-load and the following to your configuration file:

  bitly {
    user "<bit.ly username>";
    key "<bit.ly API key>";
  }

=back

=head2 Examples

=over

  bitly {
    user "JohnSmith";
    key "A_a95929f19402a0s9301041f0f29581089";
  }

<JohnSmith> !shorten http://www.google.com
<Auto> URL: http://bit.ly/eFdSkG
<JohnSmith> !reverse http://bit.ly/eFdSkG
<Auto> URL: http://www.google.com

=back

=head2 To Do

=over

* Add Spanish and German translations for the help hashes.

=back

=head2 Technical

=over

This module adds extra dependencies: LWP::UserAgent and URI::Escape. You can
get it from the CPAN <http://www.cpan.org>.

This module is compatible with Auto version 3.0.0a10+.

=back

# vim: set ai et sw=4 ts=4:
