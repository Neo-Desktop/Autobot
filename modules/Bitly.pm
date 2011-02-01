# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_Bitly;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del conf_get err);
use API::IRC qw(privmsg);
use LWP::UserAgent;

# Initialization subroutine.
sub _init 
{
    # Check for required configuration values.
	if (!(conf_get('bitly_user'))[0][0] or !(conf_get('bitly_key'))[0][0]) {
		err(2, "Please verify that you have bitly_user and bitly_key defined in your configuration file.", 0);
		return 0;
	}
    # Create the SHORTEN and REVERSE commands.
	cmd_add("SHORTEN", 0, \%m_Bitly::SHELP_SHORTEN, \%m_Bitly::FHELP_SHORTEN, \&m_Bitly::shorten) or return 0;
	cmd_add("REVERSE", 0, \%m_Bitly::SHELP_REVERSE, \%m_Bitly::FHELP_REVERSE, \&m_Bitly::reverse) or return 0;

    # Success.
    return 1;
}

# Void subroutine.
sub _void 
{
    # Delete the SHORTEN and REVERSE commands.
	cmd_del("SHORTEN") or return 0;
	cmd_del("REVERSE") or return 0;

    # Success.
	return 1;
}

# Help hashes.
our %SHELP_SHORTEN = (
    'en' => "Shorten an URL.",
);
our %SHELP_REVERSE = (
    'en' => "Expand a shortened URL.",
);

our %FHELP_SHORTEN = (
    'en' => "This command will shorten an URL using Bit.ly. Syntax: SHORTEN <url>",
);
our %FHELP_REVERSE = (
    'en' => "This command will expand a Bit.ly URL. Syntax: REVERSE <url>",
);

# Callback for SHORTEN command.
sub shorten 
{
	my (%data) = @_;

    # Create an instance of LWP::UserAgent.
	my $ua = LWP::UserAgent->new();
	$ua->agent('Auto IRC Bot');
	$ua->timeout(2);
    
    # Put together the call to the Bit.ly API. 
	my @args = @{ $data{args} };
	my ($surl, $user, $key) = ($args[0], (conf_get('bitly_user'))[0][0], (conf_get('bitly_key'))[0][0]);
	my $url = "http://api.bit.ly/v3/shorten?version=3.0.1&longUrl=".$surl."&apiKey=".$key."&login=".$user."&format=txt";
    # Get the response via HTTP.
    my $response = $ua->get($url);

	if ($response->is_success) {
        # If successful, decode the content.
        my $d = $response->decoded_content;
		chomp $d;
		if ($d =~ m/bit.ly/i) {
            # And send to channel.
			privmsg($data{svr}, $data{chan}, "URL: ".$d);
		}
		else {
            # Otherwise, send an error message.
			privmsg($data{svr}, $data{chan}, "An error occurred while shortening your URL.");
		}
	}
    else {
        # Otherwise, send an error message.
        privmsg($data{svr}, $data{chan}, "An error occurred while shortening your URL.");
    }

	return 1;
}

# Callback for REVERSE command.
sub reverse 
{
    my (%data) = @_;

    # Create an instance of LWP::UserAgent.
    my $ua = LWP::UserAgent->new();
    $ua->agent('Auto IRC Bot');
    $ua->timeout(2);

    # Put together the call to the Bit.ly API.
    my @args = @{ $data{args} };
    my ($surl, $user, $key) = ($args[0], (conf_get('bitly_user'))[0][0], (conf_get('bitly_key'))[0][0]);
    my $url = "http://api.bit.ly/v3/expand?version=3.0.1&shortURL=".$surl."&apiKey=".$key."&login=".$user."&format=txt";
    # Get the response via HTTP.
    my $response = $ua->get($url);

    if ($response->is_success) {
        # If successful, decode the content.
        my $d = $response->decoded_content;
		chomp $d;
        # And send it to channel.
		privmsg($data{svr}, $data{chan}, "URL: ".$d);
	}
	else {
        # Otherwise, send an error message.
		privmsg($data{svr}, $data{chan}, "An error occurred while reversing your URL.");
	}

	return 1;
}


# Start initialization.
API::Std::mod_init("Bitly", "Xelhua", "1.00", "3.0d", __PACKAGE__);

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

  bitly_user "<bit.ly username>";
  bitly_key "<bit.ly API key>";

=back

=head2 Examples

=over

  bitly_user "JohnSmith";
  bitly_key "A_a95929f19402a0s9301041f0f29581089";

<JohnSmith> !shorten http://www.google.com
<Auto> URL: http://bit.ly/eFdSkG
<JohnSmith> !reverse http://bit.ly/eFdSkG
<Auto> URL: http://www.google.com

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hashes.

=back

=head2 Technical

=over

This module adds an extra dependency: LWP::UserAgent. You can get this from
the CPAN <http://www.cpan.org>. 

This module is compatible with Auto version 3.0a2+.

=back
