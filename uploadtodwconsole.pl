#!/usr/bin/perl

use strict;

# Transmits console commands to DW console, reports success line if any;
# does this in batches of no more than three commands, then awaits user
# prompting to continue.  For use with batchfriendgrant.pl and friendgrant.pl.
# call: uploadtodwconsole.pl -batch batchfile -config configfile

#
# wget the console page
#	Relevant fields:
# 		<input type='hidden' name="lj_form_auth" value="c0:[REDACTED]" />
#		<textarea wrap="soft" id="id-commands-0" name="commands" cols="70" class="text" rows="10"></textarea><input type='submit' value="Execute" class="submit" />

#####################
# Personal parameters

my $configfile;
my $batchfile;
my $authenticcookies;
my $cookiejar = "cookiejar.txt";
my $lj_form_auth;

my $consoleurl = "https://www.dreamwidth.org/admin/console/";

sub arguer {
	my $nextarg = "";
	for my $arg (@ARGV) {
		if ($nextarg eq "batchfile") {
			$batchfile = $arg;	
		} elsif ($nextarg eq "configfile") {
			$configfile = $arg;	
		}
		$nextarg = "";
		
		if ($arg =~ /^\-b(|atch)$/ ) {
			$nextarg = "batchfile";
		} elsif ($arg =~ /^\-c(|onfig(|file))$/ ) {
			$nextarg = "configfile";
		}
	}

	(-f $batchfile) or die "Couldn't find batch file, \'$batchfile\'.\n";
	
	open(CONFIG, "<", "$configfile") or die "Couldn't find configuration file \'$configfile\'.\n";
	while (my $line = <CONFIG>){
		(my $field, my $value) = split /\s/, $line;
		if ($field eq "authenticcookies") {
			$authenticcookies = $value;	
		} elsif ($field eq "cookiejar") {
			$cookiejar = $value;	
		} elsif ($field eq "lj_form_auth") {
			$lj_form_auth = $value;	
		}
	}
	close CONFIG;
	
	if ($authenticcookies eq '' || !(-f $authenticcookies)) { die "Authenticated cookie file \'$authenticcookies\' not found. Dying.\n"; }
	if ($cookiejar eq '') {
		warn "Cookiejar not specified, defaulting to \'cookiejar.txt\'.\n";
		$cookiejar = "cookiejar.txt";
	}
	if (!(-f $cookiejar)) { warn "Cookie file \'$cookiejar\' not found. Creating.\n"; }
}

arguer;

#####################

## These are from "S Vertigan"@code.activestate.com
## at http://code.activestate.com/recipes/577450-perl-url-encode-and-decode/
## Many thanks!

sub urlize {
	my ($rv) = @_;
	$rv =~ s/([^A-Za-z0-9])/sprintf("%%%2.2X", ord($1))/ge;
	return $rv;
}

sub un_urlize {
	my ($rv) = @_;
	$rv =~ s/\+/ /g;
	$rv =~ s/%(..)/pack("c",hex($1))/ge;
	return $rv;
}
##################

sub wget_DWconsolepage {
	#takes nothing, uses $consoleurl global
	#returns a webpage as a string
	
	my $commandstring = "wget -q --no-check-certificate --cookies=on --keep-session-cookies --save-cookies $cookiejar  --load-cookies $authenticcookies --header \"X-LJ-Auth: cookie\"  -O - $consoleurl";
	
#	print $commandstring."\n";
	return `$commandstring `;
} #takes nothing, uses global $cosoleurl, returns the webpage showing the console form as a string

sub find_DWconsoleform_in {
	# takes a whole HTML file as a string, 
	# returns just the line with the useful content
	for my $line (split /^/, $_[0]) {
		# Test for console form relevant field (DW)
		if ($line =~ /<input type='hidden' name=\"lj_form_auth\"/) { 
#			print "DW console form line found!\n";
			return $line;
		}
	}
} 	# Takes a whole HTML file as a string, returns just the line with the DW console form field specified.

sub tokenizeHTML {
	# Takes a string of HTML
	# Returns an array of strings, consisting of the input string
	# sliced into tokens on each HTML entity edge (either < or >).
	# Thus 
	# <a href="http://www.example.com">This is an example</a> 
	# becomes
	# ('a href="http://www.example.com"', 'This is an example','/a')

#	print "tokenizeHTML called!\n";
	my $arg = $_[0];
#	print $arg;
	my $token = "";
	my @tokenarray;
	for my $i (1 .. length $arg) {
#		print ".";
		my $char = substr($arg, $i-1, 1);
#		print $char;
		if ($char eq "<" || $char eq ">") {
#			print "token edge found!";
#			$tokenarray[++$#tokenarray] = $token;
			push @tokenarray, $token;
			$token = "";
		} else {
			$token .= $char;
		}
	}

#	print "Line tokenized! $#tokenarray tokens!\n";
#	print join("\n", @tokenarray), "\n";

	return @tokenarray;
} 	# Takes a string of HTML, returns an array of strings, consisting of the input string sliced into tokens on each HTML entity edge (either < or >).

sub extract_ljformauth {
	# Takes a tokenized content string from an DW console page 
	# (as returned by find_DWconsoleform_in and then tokenized by tokenizeHTML), 
	# Returns the lj_form_auth string.

#	print "extractfilterids called!\n";
	my @tokenarray = @_;
	
	#	loop over the array, looking for the start of our tokens of interest

####  TRUE=1, FALSE=0
	# Get the filter list
	for my $token (@tokenarray) {
		if ($token =~ /^input type\=\'hidden\' name\=\"lj_form_auth\" value\=\"(.*)\" \/$/) { 
			return $1;
			last;
		}
	}
} # Takes a tokenized content string from an DW console page (as returned by find_DWconsoleform_in and then tokenized by tokenizeHTML), returns the lj_form_auth string.

sub wget_post_to_console {
	my $add = $_[0];
		
	my $datastring = "lj_form_auth=".urlize($lj_form_auth)."&commands=".urlize($add);
	
	my $command = "wget -q --no-check-certificate --cookies=on --keep-session-cookies --save-cookies $cookiejar  --load-cookies $authenticcookies --header \"X-DW-Auth: cookie\" --post-data \"$datastring\" -O - $consoleurl";

#	print $command."\n";
	#system ($command ) == 0	or die "system call to wget failed: $?";
	my $result = `$command` ;

}

# Get the lj_form_auth token

my $consolepage = wget_DWconsolepage ;
$lj_form_auth = extract_ljformauth(tokenizeHTML(find_DWconsoleform_in($consolepage)));

($lj_form_auth =~ /^c0\:/ ) or die "Value of lj_form_auth doesn't look like a valid token: \n \"$lj_form_auth\".  \n Dying.\n";

# DO THE THING

open (BATCH, "<", $batchfile) or die "Couldn't open batch file, \"$batchfile\".";

my $tuvum = 0;
while (my $addsline = <BATCH>) {
	if ( $addsline =~ /^#/ ){
		print $addsline;
		if ($addsline =~ /^# LOW SCORE\:/ ) {
			last;
		}
	} else {

		$tuvum++;
		if ($tuvum == 3) {
			print "Press return to continue.\n";
			my $response = <STDIN>;
			$tuvum = 0;
		}
		
		print "Posting: $addsline";
		my $file = wget_post_to_console ( $addsline );
		
		for my $line (split /^/, $file) {
			if ($line =~ /Done\./) {
				print $line;
			}
		}


	}
}

close BATCH;
#  <form method="POST" action="http://www.dreamwidth.org/admin/console/">
