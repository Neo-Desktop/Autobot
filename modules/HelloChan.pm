# Module: HelloChan.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::HelloChan;
use strict;
use warnings;
use API::Std qw(hook_add hook_del);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init
{
    # Add a hook for when we join a channel.
    hook_add('on_ucjoin', 'HelloChan', \&M::HelloChan::hello) or return;
    return 1;
}

# Void subroutine.
sub _void
{
    # Delete the hook.
    hook_del('on_ucjoin', 'HelloChan') or return;
    return 1;
}

# Main subroutine.
sub hello
{
    my (($svr, $chan)) = @_;
    
    # Send a PRIVMSG.
    privmsg($svr, $chan, 'Hello channel! I am a bot!');
    
    return 1;
}


# Start initialization.
API::Std::mod_init('HelloChan', 'Xelhua', '1.00', '3.0.0a10');
# build: perl=5.010000

__END__

=head1 NAME

HelloChan - An example module. Also, cows go moo.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 * Auto has joined #moocows
 <Auto> Hello channel! I am a bot!

=head1 DESCRIPTION

This module sends "Hello channel! I am a bot!" whenever it 
joins a channel.

=head1 INSTALL

No additonal steps need to be taking to use this module.

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
