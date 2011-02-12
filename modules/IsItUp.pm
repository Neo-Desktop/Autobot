# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_IsItUp;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use LWP::UserAgent;

# Initialization subroutine.
sub _init 
{
	# Create the ISITUP command.
	cmd_add("ISITUP", 0, 0, \%m_IsItUp::HELP_ISITUP, \&m_IsItUp::check) or return 0;

	# Success.
	return 1;
}

# Void subroutine.
sub _void 
{
	# Delete the ISITUP command.
	cmd_del("ISITUP") or return 0;

	# Success.
	return 1;
}

# Help hashes.
our %HELP_ISITUP = (
	'en' => "This command will check if a website appears up or down to the bot. \002Syntax:\002 ISITUP <url>",
);

# Callback for ISITUP command.
sub check
{
	my (%data) = @_;

	# Create an instance of LWP::UserAgent.
	my $ua = LWP::UserAgent->new();
	$ua->agent('Auto IRC Bot');
	$ua->timeout(2);
	my @args = @{ $data{args} };
	my $curl = $args[0];
	# Do we have enough parameters?
	if (!defined $args[0]) {
		notice($data{svr}, $data{nick}, trans("Not enough parameters").".");
		return 0;
	}
	# Does the URL start with http(s)?
	if ($curl !~ m/^http/) {
		$curl = "http://".$curl;
	}

	# Get the response via HTTP.
	my $response = $ua->get($curl);

	if ($response->is_success) {
		# If successful, it's up.
		privmsg($data{svr}, $data{chan}, $curl." appears to be up from here.");
	}
	else {
		# Otherwise, it's down.
		privmsg($data{svr}, $data{chan}, $curl." appears to be down from here.");
	}

	return 1;
}

# Start initialization.
API::Std::mod_init("IsItUp", "Xelhua", "1.00", "3.0.0d", __PACKAGE__);
# vim: set ai sw=4 ts=4:
# build: cpan=LWP::UserAgent perl=5.010000

__END__

=head1 IsItUp

=head2 Description

=over

This module adds the ISITUP command for checking if a website 
appears up or down to Auto.

=back

=head2 Examples

=over

<JohnSmith> !isitup http://google.com
<Auto> http://google.com appears to be up from here.

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hashes.

=back

=head2 Technical

=over

This module requires LWP::UserAgent. You can get it from
the CPAN <http://www.cpan.org>.

This module is compatible with Auto version 3.0.0a2+.

=back
