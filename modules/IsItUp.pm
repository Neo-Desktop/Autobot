# Module: IsItUp. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::IsItUp;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use LWP::UserAgent;

# Initialization subroutine.
sub _init 
{
ssss# Create the ISITUP command.
sssscmd_add('ISITUP', 0, 0, \%M::IsItUp::HELP_ISITUP, \&M::IsItUp::check) or return 0;

ssss# Success.
ssssreturn 1;
}

# Void subroutine.
sub _void 
{
ssss# Delete the ISITUP command.
sssscmd_del('ISITUP') or return 0;

ssss# Success.
ssssreturn 1;
}

# Help hashes.
our %HELP_ISITUP = (
ssss'en' => "This command will check if a website appears up or down to the bot. \002Syntax:\002 ISITUP <url>",
);

# Callback for ISITUP command.
sub check
{
ssssmy ($src, @argv) = @_;

ssss# Create an instance of LWP::UserAgent.
ssssmy $ua = LWP::UserAgent->new();
ssss$ua->agent('Auto IRC Bot');
ssss$ua->timeout(2);
ssss# Do we have enough parameters?
ssssif (!defined $argv[0]) {
ssss	notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
ssss	return 0;
ssss}
ssssmy $curl = $argv[0];
ssss# Does the URL start with http(s)?
ssssif ($curl !~ m/^http/) {
ssss	$curl = 'http://'.$curl;
ssss}

ssss# Get the response via HTTP.
ssssmy $response = $ua->get($curl);

ssssif ($response->is_success) {
ssss	# If successful, it's up.
ssss	privmsg($src->{svr}, $src->{chan}, $curl.' appears to be up from here.');
ssss}
sssselse {
ssss	# Otherwise, it's down.
ssss	privmsg($src->{svr}, $src->{chan}, $curl.' appears to be down from here.');
ssss}

ssssreturn 1;
}

# Start initialization.
API::Std::mod_init('IsItUp', 'Xelhua', '1.00', '3.0.0a4', __PACKAGE__);
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

This module is compatible with Auto version 3.0.0a4+.

=back
