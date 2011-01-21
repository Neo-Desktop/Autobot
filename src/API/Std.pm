# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.

# Standard API subroutines.
package API::Std;
use strict;
use warnings;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(conf_get trans err);

my (%LANGE, %MODULE);


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
	
	# Run the module's _init sub.
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
	
}

# Delete a command from Auto.
sub cmd_del
{
	
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
}

1;
