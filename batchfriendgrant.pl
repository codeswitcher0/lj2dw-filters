#!/usr/bin/perl
use strict; 

# called ./batchfriendgrant.pl -batch namemapfile -config configfile
# returns the statements to run against the console to grant the same filter access
# (calls friendgrant iteratively over namemapfile)
# must be in same directory as friendgrant.pl

my $configfile;
my $namemapfile;
my %friendslist;

sub arguer {
	my $nextarg = "";
	for my $arg (@ARGV) {
		if ($nextarg eq "namemapfile") {
			$namemapfile = $arg;	
		} elsif ($nextarg eq "configfile") {
			$configfile = $arg;	
		}
		$nextarg = "";
		
		if ($arg =~ /b(|atch)/ ) {
			$nextarg = "namemapfile";
		} elsif ($arg =~ /^\-c(|onfig(|file))$/ ) {
			$nextarg = "configfile";
		}
	}
	
	($configfile) or die "No config file specifed.\n";
	
	open(NAMEMAP, "<", "$namemapfile") or die "Couldn't find batch file \'$namemapfile\'.\n";
	while (my $line = <NAMEMAP>){
		(my $flj, my $fdw) = split /\|/, $line;
		chomp $fdw;
		$friendslist{$flj} = $fdw;
	}
	close NAMEMAP;
}

arguer;
for my $flj (sort (keys %friendslist)) {
#	print $flj.":\n";
	system ( "./friendgrant.pl -flj $flj -fdw $friendslist{$flj} -config $configfile" );
}