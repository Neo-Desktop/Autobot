# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_Bitly;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del conf_get err);
use API::IRC qw(privmsg);
use LWP::UserAgent;

sub _init {

	if (!(conf_get('bitly_user'))[0][0] or !(conf_get('bitly_key'))[0][0]) {
		err(2, "Please verify that you have bitly_user and bitly_key defined in your configuration file", 0);
		return 0;
	}
	cmd_add("SHORTEN", 0, "Shorten a URL", "This command shortens a URL using bit.ly\nSyntax: SHORTEN <url>", \&m_Shorten::shorten);
	cmd_add("REVERSE", 0, "Reverses a URL", "This command reverses a bit.ly URL\nSyntax: REVERSE <url>", \&m_Shorten::reverse);
	return 1;

}

sub _void {

	cmd_del("SHORTEN");
	cmd_del("REVERSE");
	return 1;

}

sub shorten {

	my (%data) = @_;
	my $ua = LWP::UserAgent->new();
	$ua->agent('Auto IRC Bot');
	$ua->timeout(2);
	my @args = @ { $data{args} };
	my ($surl, $user, $key) = ($args[0], (conf_get('bitly_user'))[0][0], (conf_get('bitly_key'))[0][0]);
	my $url = "http://api.bit.ly/v3/shorten?version=3.0.1&longUrl=".$surl."&apiKey=".$key."&login=".$user."&format=txt";
	my $response = $ua->get($url);

	if ($response->is_success)
	{
		my $d = $response->decoded_content;
		chomp $d;
		if ($d =~ m/bit.ly/i) {
			privmsg($data{svr}, $data{chan}, $d);
		}
		else {
			dbug($d);
			privmsg($data{svr}, $data{chan}, "An error occured while shortening your URL.");
		}
	}
        else {
                privmsg($data{svr}, $data{chan}, "An error occured while reversing your URL.");
        }


	return 1;

}

sub reverse {

        my (%data) = @_;
        my $ua = LWP::UserAgent->new();
        $ua->agent('Auto IRC Bot');
        $ua->timeout(2);
        my @args = @ { $data{args} };
        my ($surl, $user, $key) = ($args[0], (conf_get('bitly_user'))[0][0], (conf_get('bitly_key'))[0][0]);
        my $url = "http://api.bit.ly/v3/expand?version=3.0.1&shortURL=".$surl."&apiKey=".$key."&login=".$user."&format=txt";
        my $response = $ua->get($url);

        if ($response->is_success)
        {
                my $d = $response->decoded_content;
		chomp $d;
		privmsg($data{svr}, $data{chan}, $d);
	}
	else {
		privmsg($data{svr}, $data{chan}, "An error occured while reversing your URL.");
	}

	return 1;
}


API::Std::mod_init("Bitly", "Xelhua", "0.1", "3.0d", __PACKAGE__);
