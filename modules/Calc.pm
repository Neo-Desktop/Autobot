# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_Calc;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del);
use API::IRC qw(privmsg);
use LWP::UserAgent;
use URI::Escape;
use JSON -support_by_pp;

# Initialization subroutine.
sub _init 
{
	# Create the CALC command.
	cmd_add("CALC", 0, \%m_Calc::SHELP_CALC, \%m_Calc::FHELP_CALC, \&m_Calc::calc) or return 0;

	# Success.
	return 1;
}

# Void subroutine.
sub _void 
{
	# Delete the CALC command.
	cmd_del("CALC") or return 0;

	# Success.
	return 1;
}

# Help hashes.
our %SHELP_CALC = (
		'en' => "Calculate an expression.",
		);

our %FHELP_CALC = (
		'en' => "This command will calculate an expression using Google Calculator. Syntax: CALC <expression>",
		);

# Callback for CALC command.
sub calc
{
	my (%data) = @_;

	# Create an instance of LWP::UserAgent.
	my $ua = LWP::UserAgent->new();
	$ua->agent('Auto IRC Bot');
	$ua->timeout(2);
	# Create an instance of JSON.
	my $json = JSON->new();    
	# Put together the call to the Google Calculator API. 
	my @args = @{ $data{args} };
	my $expr = join(' ', @args);
	my $url = "http://www.google.com/ig/calculator?q=".uri_escape($expr);
	# Get the response via HTTP.
	my $response = $ua->get($url);

	if ($response->is_success) {
	# If successful, decode the content.
		my $d = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($response->decoded_content);
	# And send to channel
		if ($d->{error} eq "" or $d->{error} == 0) {
			privmsg($data{svr}, $data{chan}, "Result: ".$d->{lhs}." = ".$d->{rhs});
		}
		else {
	# Otherwise, send an error message.
			privmsg($data{svr}, $data{chan}, "Google calculator sent an error.");
		}
	}
	else {
	# Otherwise, send an error message.
		privmsg($data{svr}, $data{chan}, "An error occurred while sending your expression to Google Calculator.");
	}

	return 1;
}

# Start initialization.
API::Std::mod_init("Calc", "Xelhua", "1.00", "3.0d", __PACKAGE__);

__END__

=head1 Calc

=head2 Description

=over

This module adds the CALC command for evaluating an
expression using Google Calculator.

=back

=head2 How To Use

=over

Add Calc to the module autoload.

=back

=head2 Examples

=over

<JohnSmith> !calc 1+1
<Auto> Result: 1+1 = 2

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hashes.

=back

=head2 Technical

=over

This module requires LWP::UserAgent, URI::Escape and JSON both obtainable from CPAN (http://cpan.org)
This module is compatible with Auto version 3.0a2+.

=back
