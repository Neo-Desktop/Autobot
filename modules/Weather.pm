# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_Weather;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use LWP::UserAgent;
use XML::Simple;

# Initialization subroutine.
sub _init 
{
	# Create the Weather command.
	cmd_add("WEATHER", 0, 0, \%m_Weather::HELP_WEATHER, \&m_Weather::weather) or return 0;

	# Success.
	return 1;
}

# Void subroutine.
sub _void 
{
	# Delete the Weather command.
	cmd_del("WEATHER") or return 0;

	# Success.
	return 1;
}

# Help hashes.
our %HELP_WEATHER = (
		'en' => "This command will retrieve the weather via Wunderground for the specified location. Syntax: WEATHER <location>",
		);

# Callback for Weather command.
sub weather
{
	my (%data) = @_;

	# Create an instance of LWP::UserAgent.
	my $ua = LWP::UserAgent->new();
	$ua->agent('Auto IRC Bot');
	$ua->timeout(2);
	# Put together the call to the Wunderground API. 
	my @args = @{ $data{args} };
	if (!defined $args[0]) {
		notice($data{svr}, $data{nick}, trans("Not enough parameters").".");
		return 0;
	}
	my $loc = join(' ', @args);
	$loc =~ s/ /%20/g;
	my $url = "http://api.wunderground.com/auto/wui/geo/WXCurrentObXML/index.xml?query=".$loc;
	# Get the response via HTTP.
	my $response = $ua->get($url);

	if ($response->is_success) {
	# If successful, decode the content.
		my $d = XMLin($response->decoded_content);
	# And send to channel
		if (!ref($d->{observation_location}->{country})) {
			my $windc = $d->{wind_string};
			if (substr($windc, length($windc) - 1, 1) eq " ") { $windc = substr($windc, 0, length($windc) - 1); }
			privmsg($data{svr}, $data{chan}, "Results for \2".$d->{observation_location}->{full}."\2 - \2Temperature:\2 ".$d->{temperature_string}." \2Wind Conditions:\2 ".$windc." \2Conditions:\2 ".$d->{weather});
			privmsg($data{svr}, $data{chan}, "\2Heat index:\2 ".$d->{heat_index_string}." \2Humidity:\2 ".$d->{relative_humidity}." \2Pressure:\2 ".$d->{pressure_string}." - ".$d->{observation_time});
		}
		else {
		# Otherwise, send an error message.
			privmsg($data{svr}, $data{chan}, "Location not found.");
		}
	}
	else {
	# Otherwise, send an error message.
		privmsg($data{svr}, $data{chan}, "An error occurred while retrieving your weather.");
	}

	return 1;
}

# Start initialization.
API::Std::mod_init("Weather", "Xelhua", "1.00", "3.0.0d", __PACKAGE__);

__END__

=head1 Weather

=head2 Description

=over

This module adds the WEATHER command for retrieving
the current weather.

=back

=head2 How To Use

=over

Add Weather to the module autoload.

=back

=head2 Examples

=over

<JohnSmith> !weather 10111
<Auto> Results for Central Park, New York - Temperature: 27 F (-3 C) Wind Conditions: From the NE at 9 MPH Gusting to 22 MPH Conditions: Overcast
<Auto> Heat index: NA Humidity: 89% Pressure: 30.22 in (1023 mb) - Last Updated on February 1, 9:51 PM EST

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hashes.

=back

=head2 Technical

=over

This module requires LWP::UserAgent and XML::Simple. Both obtainable 
from CPAN <http://www.cpan.org>.

This module is compatible with Auto version 3.0a2+.

=back
