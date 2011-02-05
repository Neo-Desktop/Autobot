# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Standard API subroutines.
package API::Std;
use strict;
use warnings;
use Exporter;

our (%LANGE, %MODULE, %EVENTS, %HOOKS, %CMDS);
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(conf_get trans err awarn timer_add timer_del cmd_add 
					cmd_del hook_add hook_del rchook_add rchook_del match_user
					has_priv mod_exists);


# Initialize a module.
sub mod_init
{
	my ($name, $author, $version, $autover, $pkg) = @_;
	
	# Log/debug.
	API::Log::dbug("MODULES: Attempting to load ".$name." (version ".$version.") by ".$author."...");
	API::Log::alog("MODULES: Attempting to load ".$name." (version ".$version.") by ".$author."...");
	
	# Check if this module is compatible with this version of Auto.
	if ($autover ne "3.0.0d") {
		API::Log::dbug("MODULES: Failed to load ".$name.": Incompatible with your version of Auto.");
		API::Log::alog("MODULES: Failed to load ".$name.": Incompatible with your version of Auto.");
		return 0;
	}
	
	# Run the module's _init sub.
	my $mi = eval($pkg."::_init();");
	
	if ($mi) {
		# If successful, add to hash.
		$MODULE{$name}{name}    = $name;
		$MODULE{$name}{version} = $version;
		$MODULE{$name}{author}  = $author;
		$MODULE{$name}{pkg}     = $pkg;
		
		API::Log::dbug("MODULES: ".$name." successfully loaded.");
		API::Log::alog("MODULES: ".$name." successfully loaded.");
		
		return 1;
	}
	else {
		# Otherwise, return a failed to load message.
		API::Log::dbug("MODULES: Failed to load ".$name.".");
		API::Log::alog("MODULES: Failed to load ".$name.".");
		
		return 0;
	}
}

# Check if a module exists.
sub mod_exists
{
	my ($name) = @_;
	
	return 1 if defined $API::Std::MODULE{$name};
	return 0;
}

# Void a module.
sub mod_void
{
	my ($module) = @_;
	
	# Log/debug.
	API::Log::dbug("MODULES: Attempting to unload module: ".$module."...");
	API::Log::alog("MODULES: Attempting to unload module: ".$module."...");
	
	# Check if this module exists.
	unless (defined $MODULE{$module}) {
		API::Log::dbug("MODULES: Failed to unload ".$module.". No such module?");
		API::Log::alog("MODULES: Failed to unload ".$module.". No such module?");
		return 0;
	}
	
	# Run the module's _void sub.
	my $mi = eval($MODULE{$module}{pkg}."::_void();");
	
	if ($mi) {
		# If successful, delete class from program and delete module from hash.
		Class::Unload->unload($MODULE{$module}{pkg});
		delete $MODULE{$module};
		API::Log::dbug("MODULES: Successfully unloaded ".$module.".");
		API::Log::alog("MODULES: Successfully unloaded ".$module.".");
		return 1;
	}
	else {
		# Otherwise, return a failed to unload message.
		API::Log::dbug("MODULES: Failed to unload ".$module.".");
		API::Log::alog("MODULES: Failed to unload ".$module.".");
		return 0;
	}
}

# Add a command to Auto.
sub cmd_add
{
	my ($cmd, $lvl, $priv, $help, $sub) = @_;
	$cmd = uc($cmd);
	
	return 0 if (defined $API::Std::CMDS{$cmd});
	return 0 if ($lvl =~ m/[^0-2]/);
	
	$API::Std::CMDS{$cmd}{lvl}   = $lvl;
	$API::Std::CMDS{$cmd}{help}  = $help;
	$API::Std::CMDS{$cmd}{priv}  = $priv;
	$API::Std::CMDS{$cmd}{sub}   = $sub;
	
	return 1;
}


# Delete a command from Auto.
sub cmd_del
{
	my ($cmd) = @_;
	$cmd = uc($cmd);
	
	if (defined $API::Std::CMDS{$cmd}) {
		delete $API::Std::CMDS{$cmd};
	}
	else {
		return 0;
	}
	
	return 1;
}

# Add an event to Auto.
sub event_add
{
	my ($name) = @_;
	
	unless (defined $EVENTS{lc($name)}) {
		$EVENTS{lc($name)} = 1;
		return 1;
	}
	else {
		API::Log::dbug("DEBUG: Attempt to add a pre-existing event[".lc($name)."]! Ignoring...");
		return 0;
	}
}

# Delete an event from Auto.
sub event_del
{
	my ($name) = @_;
	
	if (defined $EVENTS{lc($name)}) {
		delete $EVENTS{lc($name)};
		delete $HOOKS{lc($name)};
		return 1;
	}
	else {
		API::Log::dbug("DEBUG: Attempt to delete a non-existing event[".lc($name)."! Ignoring...");
		return 0;
	}
}

# Trigger an event.
sub event_run
{
	my ($event, @args) = @_;
	
	if (defined $EVENTS{lc($event)} and defined $HOOKS{lc($event)}) {
		foreach my $hk (keys %{ $HOOKS{lc($event)} }) {
			&{ $HOOKS{lc($event)}{$hk} }(@args);
		}
	}
	
	return 1;
}

# Add a hook to Auto.
sub hook_add
{
	my ($event, $name, $sub) = @_;
	
	if (!defined $API::Std::HOOKS{lc($name)}) {
		if (defined $API::Std::EVENTS{lc($event)}) {
			$API::Std::HOOKS{lc($event)}{lc($name)} = $sub;
			return 1;
		}
		else {
			return 0;
		}
	}
	else {
		return 0;
	}
}

# Delete a hook from Auto.
sub hook_del
{
	my ($event, $name) = @_;
	
	if (defined $API::Std::HOOKS{lc($event)}{lc($name)}) {
		delete $API::Std::HOOKS{lc($event)}{lc($name)};
		return 1;
	}
	else {
		return 0;
	}
}

# Add a timer to Auto.
sub timer_add
{
	my ($name, $type, $time, $sub) = @_;
	$name = lc($name);
	
	# Check for invalid type/time.
	if ($type =~ m/[^1-2]/) {
		return 0;
	}
	if ($time =~ m/[^0-9]/) {
		return 0;
	}
	
	unless (defined $Auto::TIMERS{$name}) {
		$Auto::TIMERS{$name}{type} = $type;
		$Auto::TIMERS{$name}{time} = time + $time;
		$Auto::TIMERS{$name}{secs} = $time if ($type == 2);
		$Auto::TIMERS{$name}{sub}  = $sub;
		return 1;
	}
	else {
		return 0;
	}
}

# Delete a timer from Auto.
sub timer_del
{
	my ($name) = @_;
	$name = lc($name);
	
	if (defined $Auto::TIMERS{$name}) {
		delete $Auto::TIMERS{$name};
		return 1;
	}
	
	return 0;
}

# Hook onto a raw command.
sub rchook_add
{
	my ($cmd, $sub) = @_;
	$cmd = uc($cmd);
	
	return 0 if defined $Parser::IRC::RAWC{$cmd};
	
	$Parser::IRC::RAWC{$cmd} = $sub;
	
	return 1;
}

# Delete a raw command hook.
sub rchook_del
{
	my ($cmd) = @_;
	$cmd = uc($cmd);
	
	return 0 if !defined $Parser::IRC::RAWC{$cmd};
	
	delete $Parser::IRC::RAWC{$cmd};
	
	return 1;
}

# Configuration value getter.
sub conf_get
{
	my ($value) = @_;
	
	# Create an array out of the value.
	my @val;
	if ($value =~ m/:/) {
		@val = split(':', $value);
	}
	else {
		@val = ($value);
	}
	# Undefine this as it's unnecessary now.
	undef $value;
	
	# Get the count of elements in the array.
	my $count = scalar(@val);
	
	# Return the requested configuration value(s).
	if ($count == 1) {
		if (ref($Auto::SETTINGS{$val[0]}) eq 'HASH') {
			return %{ $Auto::SETTINGS{$val[0]} };
		}
		else {
			return $Auto::SETTINGS{$val[0]};
		}
	}
	elsif ($count == 2) {
		if (ref($Auto::SETTINGS{$val[0]}{$val[1]}) eq 'HASH') {
			return %{ $Auto::SETTINGS{$val[0]}{$val[1]} };
		}
		else {
			return $Auto::SETTINGS{$val[0]}{$val[1]};
		}
	}
	elsif ($count == 3) {
		if (ref($Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]}) eq 'HASH') {
			return %{ $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]} };
		}
		else {
			return $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]};
		}
	}
	else {
		return 0;
	}	
}

# Translation subroutine.
sub trans
{
	my ($id) = @_;
	$id =~ s/ /_/g;
	
	if (defined $API::Std::LANGE{$id}) {
		return $API::Std::LANGE{$id};
	}
	else {
		$id =~ s/_/ /g;
		return $id;
	}
}

# Match user subroutine.
sub match_user
{
	my (%user) = @_;

	# Get data from config.
	return 0 if (!conf_get("user"));
	my %uhp = conf_get("user");
	
	foreach my $userkey (keys %uhp) {
		# For each user block.
		my %ulhp = %{ $uhp{$userkey} };
		foreach my $uhk (keys %ulhp) {
            # For each user.

			if ($uhk eq "net") {
                if (defined $user{svr}) {
                    if (lc($user{svr}) ne lc(($ulhp{$uhk})[0][0])) {
                        # config.user:net conflicts with irc.user:svr.
                        last;
                    }
                }
            }
            elsif ($uhk eq "mask") {
				# Put together the user information.
				my $mask = $user{nick}."!".$user{user}."@".$user{host};
				if (API::IRC::match_mask($mask, ($ulhp{$uhk})[0][0])) {
					# We've got a host match.
					return $userkey;
				}
			}
            elsif ($uhk eq "chanstatus" and defined $ulhp{'net'}) {
                my ($ccst, $ccnm) = split(':', ($ulhp{$uhk})[0][0]);
                my $svr = $ulhp{net}[0];
                if (defined $Auto::SOCKET{$svr}) {
                    foreach my $bcj (@{ $Parser::IRC::botchans{$svr} }) {
                        if (API::IRC::match_mask($bcj, $ccnm)) {
                            API::IRC::names($svr, $bcj);
                            if (defined $Parser::IRC::chanusers{$svr}{$bcj}{$user{nick}}) {
                                return $userkey if $Parser::IRC::chanusers{$svr}{$bcj}{$user{nick}} =~ m/($ccst)/;
                            }
                        }
                    }
                }
            }
		}
	}
	
	return 0;
}

# Privilege subroutine.
sub has_priv
{
	my ($cuser, $cpriv) = @_;
	
	if (conf_get("user:$cuser:privs")) {
		my $cups = (conf_get("user:$cuser:privs"))[0][0];
		
		if (defined $Auto::PRIVILEGES{$cups}) {
			foreach (@{ $Auto::PRIVILEGES{$cups} }) {
				return 1 if ($_ eq $cpriv or $_ eq "ALL");
			}
		}
	}
	
	return 0;
}

# Error subroutine.
sub err
{
	my ($lvl, $msg, $fatal) = @_;
	
	# Check for an invalid level.
	if ($lvl =~ m/[^0-9]/) {
		return 0;
	}
	if ($fatal =~ m/[^0-1]/) {
		return 0;
	}
	
	# Level 1: Print to screen.
	if ($lvl >= 1) {
		API::Log::println("ERROR: $msg");
	}
	# Level 2: Log to file.
	if ($lvl >= 2) {
		API::Log::alog("ERROR: $msg");
	}
	
	# If it's a fatal error, exit the program.
	if ($fatal) {
		exit;
	}
	
	return 1;
}

# Warn subroutine.
sub awarn
{
	my ($lvl, $msg) = @_;
	
	# Check for an invalid level.
	if ($lvl =~ m/[^0-9]/) {
		return 0;
	}
	
	# Level 1: Print to screen.
	if ($lvl >= 1) {
		API::Log::println("WARNING: $msg");
	}
	# Level 2: Log to file.
	if ($lvl >= 2) {
		API::Log::alog("WARNING: $msg");
	}
	
	return 1;
}

1;
