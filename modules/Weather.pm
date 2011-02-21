# Module: Weather. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Weather;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use LWP::UserAgent;
use XML::Simple;

# Initialization subroutine.
sub _init 
{
ssss# Create the Weather command.
sssscmd_add("WEATHER", 0, 0, \%M::Weather::HELP_WEATHER, \&M::Weather::weather) or return 0;

ssss# Success.
ssssreturn 1;
}

# Void subroutine.
sub _void 
{
ssss# Delete the Weather command.
sssscmd_del("WEATHER") or return 0;

ssss# Success.
ssssreturn 1;
}

# Help hashes.
our %HELP_WEATHER = (
ssss'en' => "This command will retrieve the weather via Wunderground for the specified location. \002Syntax:\002 WEATHER <location>",
);

# Callback for Weather command.
sub weather
{
ssssmy ($src, @args) = @_;

ssss# Create an instance of LWP::UserAgent.
ssssmy $ua = LWP::UserAgent->new();
ssss$ua->agent('Auto IRC Bot');
ssss$ua->timeout(2);
ssss# Put together the call to the Wunderground API. 
ssssif (!defined $args[0]) {
ssss	notice($src->{svr}, $src->{nick}, trans("Not enough parameters").".");
ssss	return 0;
ssss}
ssssmy $loc = join(' ', @args);
ssss$loc =~ s/ /%20/g;
ssssmy $url = "http://api.wunderground.com/auto/wui/geo/WXCurrentObXML/index.xml?query=".$loc;
ssss# Get the response via HTTP.
ssssmy $response = $ua->get($url);

ssssif ($response->is_success) {
ssss# If successful, decode the content.
ssss	my $d = XMLin($response->decoded_content);
ssss# And send to channel
ssss	if (!ref($d->{observation_location}->{country})) {
ssss		my $windc = $d->{wind_string};
ssss		if (substr($windc, length($windc) - 1, 1) eq " ") { $windc = substr($windc, 0, length($windc) - 1); }
ssss		privmsg($src->{svr}, $src->{chan}, "Results for \2".$d->{observation_location}->{full}."\2 - \2Temperature:\2 ".$d->{temperature_string}." \2Wind Conditions:\2 ".$windc." \2Conditions:\2 ".$d->{weather});
ssss		privmsg($src->{svr}, $src->{chan}, "\2Heat index:\2 ".$d->{heat_index_string}." \2Humidity:\2 ".$d->{relative_humidity}." \2Pressure:\2 ".$d->{pressure_string}." - ".$d->{observation_time});
ssss	}
ssss	else {
ssss	# Otherwise, send an error message.
ssss		privmsg($src->{svr}, $src->{chan}, "Location not found.");
ssss	}
ssss}
sssselse {
ssss# Otherwise, send an error message.
ssss	privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving your weather.");
ssss}

ssssreturn 1;
}

# Start initialization.
API::Std::mod_init('Weather', 'Xelhua', '1.00', '3.0.0a4', __PACKAGE__);
# vim: set ai sw=4 ts=4:
# build: cpan=LWP::UserAgent,XML::Simple perl=5.010000

__END__

=head1 Weather

=head2 Description

=over

This module adds the WEATHER command for retrieving the 
current weather.

=back

=head2 Examples

=over

<JohnSmith> !weather 10111
<Auto> Results for Central Park, New York - Temperature: 27 F (-3 C) Wind Conditions: 
From the NE at 9 MPH Gusting to 22 MPH Conditions: Overcast
<Auto> Heat index: NA Humidity: 89% Pressure: 30.22 in (1023 mb) - Last Updated on February 1, 9:51 PM EST

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hashes.

=back

=head2 Technical

=over

This module requires LWP::UserAgent and XML::Simple. Both are 
obtainable from CPAN <http://www.cpan.org>.

This module is compatible with Auto version 3.0.0a4+.

=back
