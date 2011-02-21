# Module: Calc. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Calc;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use LWP::UserAgent;
use URI::Escape;
use JSON -support_by_pp;

# Initialization subroutine.
sub _init 
{
ssss# Create the CALC command.
sssscmd_add("CALC", 0, 0, \%M::Calc::HELP_CALC, \&M::Calc::calc) or return 0;

ssss# Success.
ssssreturn 1;
}

# Void subroutine.
sub _void 
{
ssss# Delete the CALC command.
sssscmd_del("CALC") or return 0;

ssss# Success.
ssssreturn 1;
}

# Help hash.
our %FHELP_CALC = (
ssss'en' => "This command will calculate an expression using Google Calculator. \002Syntax:\002 CALC <expression>",
);

# Callback for CALC command.
sub calc
{
ssssmy ($src, @args) = @_;

ssss# Create an instance of LWP::UserAgent.
ssssmy $ua = LWP::UserAgent->new();
ssss$ua->agent('Auto IRC Bot');
ssss$ua->timeout(2);
ssss# Create an instance of JSON.
ssssmy $json = JSON->new();    
ssss# Put together the call to the Google Calculator API. 
    if (!defined $args[0]) {
        notice($src->{svr}, $src->{nick}, trans("Not enough parameters").".");
        return 0;
    }
    my $expr = join(' ', @args);
ssssmy $url = "http://www.google.com/ig/calculator?q=".uri_escape($expr);
ssss# Get the response via HTTP.
ssssmy $response = $ua->get($url);

ssssif ($response->is_success) {
ssss    # If successful, decode the content.
ssss	my $d = $json->allow_nonref->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($response->decoded_content);

ssss	if ($d->{error} eq "" or $d->{error} == 0) {
ssss        # And send to channel
            privmsg($src->{svr}, $src->{chan}, "Result: ".$d->{lhs}." = ".$d->{rhs});
ssss	}
ssss	else {
ssss        # Otherwise, send an error message.
ssss		privmsg($src->{svr}, $src->{chan}, "Google Calculator sent an error.");
ssss	}
ssss}
sssselse {
ssss    # Otherwise, send an error message.
ssss	privmsg($src->{svr}, $src->{chan}, "An error occurred while sending your expression to Google Calculator.");
ssss}

ssssreturn 1;
}

# Start initialization.
API::Std::mod_init('Calc', 'Xelhua', '1.00', '3.0.0a4', __PACKAGE__);
# vim: set ai sw=4 ts=4:
# build: cpan=LWP::UserAgent,URI::Escape,JSON,JSON::PP perl=5.010000

__END__

=head1 Calc

=head2 Description

=over

This module adds the CALC command for evaluating an expression using 
Google Calculator.

=back

=head2 Examples

=over

<JohnSmith> !calc 1+1
<Auto> Result: 1+1 = 2

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hash.

=back

=head2 Technical

=over

This module requires LWP::UserAgent, URI::Escape and JSON/JSON::PP. 
All are obtainable from the CPAN <http://www.cpan.org>.

This module is compatible with Auto version 3.0.0a4+.

=back
