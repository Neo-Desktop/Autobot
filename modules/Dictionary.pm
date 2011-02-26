# Module: Dictionary. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Dictionary;
use strict;
use warnings;
use Net::Dict;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(notice privmsg);

# Initialization subroutine.
sub _init
{
    # Create the DICT command.
    cmd_add('DICT', 0, 0, \%M::Dictionary::HELP_DICT, \&M::Dictionary::cmd_dict) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void
{
    # Delete the DICT command.
    cmd_del('DICT') or return;

    # Success.
    return 1;
}


# Help hash for DICT. Spanish, French and German translations needed.
our %HELP_DICT = (
    'en' => "This command allows you to lookup a word through Dict.org. \002Syntax:\002 DICT <word>",
);

# Callback for DICT command.
sub cmd_dict
{
    my ($src, ($word)) = @_;

    # Check for needed parameters.
    if (!defined $word) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Create an instance of Net::Dict.
    my $dictv = Net::Dict->new('dict.org');

    # Get the definition for this word.
    my $res = $dictv->define($word);

    # Check if there was a result.
    if (defined $res) {
        # Return the results.
        privmsg($src->{svr}, $src->{chan}, "Results for \2$word\2:");
        foreach (@{ $res }) {
            # Split the newlines.
            my @lines = split m/\n/, @$_[1];
            foreach (@lines) {
                if ($_ =~ m/[^\s]/) {
                    privmsg($src->{svr}, $src->{chan}, $_);
                }
            }
        }
    }
    else {
        # Else return no results.
        privmsg($src->{svr}, $src->{chan}, "No results for \2$word\2.");
    }

    return 1;
}


# Start initialization.
API::Std::mod_init('Dictionary', 'Xelhua', '1.00', '3.0.0a6', __PACKAGE__);
# vim: set ai et sw=4 ts=4:
# build: cpan=Net::Dict perl=5.010000

__END__

=head1 Dictionary

=head2 Description

=over

This module allows users to lookup definitions for words from dict.org via the
DICT command.

=back

=head2 Technical

=over

This module adds an extra dependency: Net::Dict. You can get it from the CPAN
<http://www.cpan.org>.

This module is compatible with Auto v3.0.0a6+.

=back
