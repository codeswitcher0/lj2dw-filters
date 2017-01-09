#!/usr/bin/perl
use strict; 

# called ./friendgrant.pl -flj theirusername@lj -fdw theirusername@dw -config configfile
# returns the statement to run against the console to grant the same filter access

# Assign args
# Get filter assignment off LJ
# Make filter assignment for DW

my $flj;
my $fdw;
my $configfile;

my $username;
my $authenticcookies;
my $cookiejar = "cookiejar.txt";
my $filtermap;
my %filterhash; # populated by extract_DWfilterids_in(), man we should cache this

main();

sub arguer {
	my $nextarg = "";
	for my $arg (@ARGV) {
		if ($nextarg eq "username") {
			$username = $arg;	
		} elsif ($nextarg eq "flj") {
			$flj = $arg;	
		} elsif ($nextarg eq "fdw") {
			$fdw = $arg;	
		} elsif ($nextarg eq "configfile") {
			$configfile = $arg;	
		}
		$nextarg = "";
		
		if ($arg =~ /u(|ser(|name))/ ) {
			$nextarg = "username";
		} elsif ($arg =~ /^\-flj$/ ) {
			$nextarg = "flj";
		} elsif ($arg =~ /^\-fdw$/ ) {
			$nextarg = "fdw";
		} elsif ($arg =~ /^\-c(|onfig(|file))$/ ) {
			$nextarg = "configfile";
		}
	}
	
	open(CONFIG, "<", "$configfile") or die "Couldn't find configuration file \'$configfile\'.\n";
	while (my $line = <CONFIG>){
		(my $field, my $value) = split /\s/, $line;
		if ($field eq "username") {
			$username = $value;	
		} elsif ($field eq "authenticcookies") {
			$authenticcookies = $value;	
		} elsif ($field eq "cookiejar") {
			$cookiejar = $value;	
		} elsif ($field eq "filtermap") {
			$filtermap = $value;	
		}
	}
	close CONFIG;
	
	
	if ($flj eq '') { die "For whom should we find friend filters? No username specified. Dying.\n" ; }
	if ($fdw eq '') { 
		warn "No Dreamwidth username specified, assuming user of same name as on LJ is whom you mean.\n" ; 
		$fdw = $flj;
	}
	
	if ($username eq '') { die "No username specified. Dying.\n" ; }
	if ($authenticcookies eq '' || !(-f $authenticcookies)) { die "Authenticated cookie file \'$authenticcookies\' not found. Dying.\n"; }
	if ($cookiejar eq '') {
		warn "Cookiejar not specified, defaulting to \'cookiejar.txt\'.\n";
		$cookiejar = "cookiejar.txt";
	}
	if (!(-f $cookiejar)) { warn "Cookie file \'$cookiejar\' not found. Creating.\n"; }
	if ($filtermap eq '') {
		warn "Filter map file not specified, defaulting to \'filtermap.txt\'.\n";
		$filtermap = "filtermap.txt";
	}
}

sub wget_LJfiltermembershippage_for {
	#takes an LJusername of the friend
	#returns a webpage as a string
	my $friend = $_[0];	
	my $url  = "http://www.livejournal.com/friends/add.bml?user=" . $friend  ;
	
	my $commandstring = "wget -q --cookies=on --keep-session-cookies --save-cookies $cookiejar  --load-cookies $authenticcookies --header \"X-LJ-Auth: cookie\"  -O - $url";
	
#	print $command."\n";
	return `$commandstring `;
} #takes an LJusername of the friend, returns the webpage showing filter memberships as a string

sub wget_DWfilterpage_mine {
	# Takes NOTHING, 
	# Returns the DW Manage Access Filters webpage as a string.
	my $url  = "https://www.dreamwidth.org/manage/circle/editfilters"  ;
	
	my $commandstring = "wget -q --no-check-certificate --cookies=on --keep-session-cookies --save-cookies $cookiejar  --load-cookies $authenticcookies --header \"X-DW-Auth: cookie\"  -O - $url";
	
#	print $commandstring."\n";
	return `$commandstring `;
} #takes NOTHING, returns the DW Manage Access Filters webpage as a string.

sub find_LJFilterline_in {
	# takes a whole HTML file as a string, 
	# returns just the line with the useful content
#	print "find_LJFilterline_in called.\n";
	for my $line (split /^/, $_[0]) {
		# Test for filter membership file (LJ)
		if ($line =~ /<h1 class="b-service-title"> Modify Friend <\/h1>/) { 
			return $line;
		}
	}
} 	# Takes a whole HTML file as a string, returns just the line with the LJ filters specified

sub find_DWFilterline_in {
	# takes a whole HTML file as a string, 
	# returns just the line with the useful content
	for my $line (split /^/, $_[0]) {
		# Test for filter manager file (DW)
		if ($line =~ /<form method='post' name='fg'/) { 
#			print "DW filter line found!\n";
			return $line;
	#		extractfilterids($therightline);
	#		print "$_ $filterhash{$_}\n" for (keys %filterhash);
	
		}
	}
} 	# Takes a whole HTML file as a string, returns just the line with the DW filters specified

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

sub extract_LJfiltermemberships_in {
	# Takes a tokenized content string from an LJ "Modify Friend" page (as 
	# returned by find_LJFilterline_in and then tokenized by tokenizeHTML), 
	# Returns an array of filter NAMES (strings) of which the friend is a member.
	#	print "extractmembership called!\n";
	my @tokenarray = @_;
	
#	loop over the array, looking for the start of our tokens of interest

	my @newtokenarray;
	my @nametokenarray;  # if we kill the name check, we can kill this
####  TRUE=1, FALSE=0
	my $savethese = 0; #FALSE


##### FROM HERE to END, we don't need this anymore?  Except it makes a nice (if unnecessary) check that we've got the right page.  But how would we get the wrong one?
	# get the user's name
	for my $token (@tokenarray) {
		if ($token =~ /set note for/) {
			$savethese = 1; # TRUE
		}
		if ($savethese) {
			if ($token =~ /^a href/) {
				$savethese = 0; # FALSE
			}
		}
		if ($savethese) {
			if ($token =~ /\S+/) {  #$token has at least one non-whitespace char
				$nametokenarray[++$#nametokenarray] = $token;
			}
		}
	}
#	print join("\n", @nametokenarray), "\n";
	my @namearray;
	for my $token (@nametokenarray) {
		if ($token =~ /data-ljuser/) {
			@namearray = split(/\s/, $token);
#			print join("\n", @namearray), "\n";
		}
	}
	for my $token (@namearray) {
		if ($token =~ /data-ljuser="(.*)"/) {
			($1 eq $flj) or die "The filter assignment page downloaded from LJ doesn't seem to be for the right user, ($flj vs. $1). Dying.\n";
#			print $1;
		}
	}
################  END	
	
	# Get the filter list
	for my $token (@tokenarray) {
		if ($token =~ /ul class="flatfriend-groups-items"/) {
			$savethese = 1; # TRUE
		}
		if ($savethese) {
			if ($token =~ /\/ul/) {
				$savethese = 0; # FALSE
			}
		}
		if ($savethese) {
			if ($token =~ /\S+/) {  #$token has at least one non-whitespace char
				$newtokenarray[++$#newtokenarray] = $token;
			}
		}
	}

#	print "Tokens filtered down to the relevant ones, and all-white-space tokens dropped! $#newtokenarray tokens!\n";
#	print join("\n", @newtokenarray), "\n";

#  	okay, we now have (in $newtokenarray) just the tokens for the friends filters
#   What our structure looks like in the original (no linebreaks):
#	<ul class="flatfriend-groups-items">
#		<li class="flatfriend-groups-item"> 
#			<input type="checkbox" name="bit_2" id="fg:bit_2"  checked="checked" >
#			<label for="fg:bit_2">
#				Default View
#			</label>
#		</li>
#		<li class="flatfriend-groups-item">
#			<input type="checkbox" name="bit_13" id="fg:bit_13"  > 
#			<label for="fg:bit_13">
#				Cow-orkers
#			</label>
#		</li>   
#
#
#    So what we can do is loop over our array looking for q_input type="checkbox"_ and if we match, look in it for q_checked="checked"_, and if that matches, then look in the second-next token for the filter subscribed!

	my $secondnext = 0;
	my @filterarray;
	for my $token (@newtokenarray) {
		if ($secondnext == 0) {
			if ($token =~ /^input type="checkbox"/) {
				if ($token =~ /checked="checked"/) {
					$secondnext = 2;
				}
			}
		} elsif ($secondnext == 1) {
			#this is it! this is the filter string!
			$filterarray[++$#filterarray] = $token;
			$secondnext = 0;
		} elsif ($secondnext == 2 ) {
			$secondnext = 1;
		}
	}
#
#  Now @filterarray contains a list of filters names! 
#  Let's just return them as a comma separated list for now:
#
#	print "manage_circle add_access USERNAME ",  join(',', @filterarray), "\n";

	return @filterarray;

# manage_circle add_access <username> [groups]

} # Takes a tokenized content string from an LJ "Modify Friend" page (as returned by find_LJFilterline_in and then tokenized by tokenizeHTML), returns an array of filter NAMES (strings) of which the friend is a member

sub extract_DWfilterids_in {
	# Takes a tokenized content string from an DW "Subscription Manager" page 
	# (as returned by find_DWFilterline_in and then tokenized by tokenizeHTML), 
	# Returns NOTHING but SETS GLOBAL HASH %filterhash, a map of filter name to # filter id number on DW. 

#	print "extractfilterids called!\n";
	my @tokenarray = @_;

#	loop over the array, looking for the start of our tokens of interest

	my @newtokenarray;
####  TRUE=1, FALSE=0
	my $savethese = 0; #FALSE

	# Get the filter list
	for my $token (@tokenarray) {
		if ($token =~ /form method='post' name='fg'/) { #start saving here
			$savethese = 1; # TRUE
		}
		if ($savethese) {
			if ($token =~ /input type='hidden' name="editfriend/) { #stop saving here
				$savethese = 0; # FALSE
			}
		}
		if ($savethese) {
			if ($token =~ /\S+/) {  #$token has at least one non-whitespace char
				#$newtokenarray[++$#newtokenarray] = $token;
				push @newtokenarray, $token;
			}
		}
	}

#	print "Tokens filtered down to the relevant ones, and all-white-space tokens dropped! $#newtokenarray tokens!\n";
#	print join("\n", @newtokenarray), "\n";

#  	okay, we now have (in $newtokenarray) just the tokens for the friends filters
#   What our structure looks like in the original (no linebreaks):
#
#	<form method='post' name='fg' action='editfilters'>
#		<input type='hidden' name="lj_form_auth" value="c0:[REDACTED]" />
#		<input type='hidden' name='mode' value='save' />
#		<input type='hidden' name='efg_set_1_name' value='Default View' />
#		<input type='hidden' name='efg_set_1_sort' value='5' />
#		<input type='hidden' name='efg_delete_1' value='0' />
#		<input type='hidden' name='efg_set_1_public' value='1' />
#		<input type='hidden' name='efg_set_2_name' value='Cow-orkers' />
#		<input type='hidden' name='efg_set_2_sort' value='10' />
#		<input type='hidden' name='efg_delete_2' value='0' />
#		<input type='hidden' name='efg_set_2_public' value='1' />
#
#   So what we can do is loop over our array looking for /name='efg_set_(\d+)_name/ 
#	and if we match, extract $1 and /value='friends_\d+'/ $1 as a key/value pair,
#	only the other way around, so we can look up ids by filter name

	for my $token (@newtokenarray) {
		my $id;
		my $filter;
		if ($token =~ /name='efg_set_(\d+)_name/ ) {
#			print $1, "\n";
			$id = $1;
			if ($token =~ /value='(.*)' / ) {
#				print $1, "\n";
				$filter = $1;
			}
		}
		if ($id && $filter) {
#			print "$filter = $id\n";
			$filterhash{$filter}=$id;
		}

	}
	
#	print "Got the filter hash!\n";
	
} # Takes a tokenized content string from an DW "Subscription Manager" page (as returned by find_DWFilterline_in and then tokenized by tokenizeHTML), returns NOTHING but SETS GLOBAL HASH %filterhash, a map of filter name to filter id number on DW. 

sub map_LJmemberships_toDWfilterids {
	# Takes an array of filter names (strings), 
	# Returns an array of filter id numbers (ints); 
	# Maps a list of filters from LJ to the numbers of the DW filters of the same name (using %filterhash to look it up).
	my @filters = @_;
	my @resultslist;
	for my $filter (@filters) {
		push @resultslist, $filterhash{$filter};
	}
	return @resultslist;
} #Takes an array of filter names (strings), returns an array of filter id numbers (ints); maps a list of filters from LJ to the numbers of the DW filters of the same name (using %filterhash to look it up).

sub make_DWfiltermap {

	#try to read in filtermap file
	# does filtermap exist?
	
	my $mtime = (stat $filtermap)[9];  # the age of $filtermap in seconds since the epoch	
	if (-f $filtermap && (time - $mtime < 360 )) {  
		# and if cache is not expired (expires in 1 hour)

		open ( FILTERMAP, "<", $filtermap );
		while (my $line = <FILTERMAP>) {
#			print "Filtermap line: $line\n";
			#check first line for username
			if ($line =~ /^#(.*)$/) {
				if ( !($1 eq $username) ) {
					# cache is for the wrong user, abort using cache
					close FILTERMAP;
					%filterhash = ();
					last;
				}
				next;
			}
			#explode line
			my ($filter, $id) = split /\|/, $line;
			chomp $id;
#			print "$filter $id\n";
			#populate %filterhash
			$filterhash{$filter}=$id;
		}
		close FILTERMAP;
	} 
	if (! %filterhash) {
		# Only do this if trying to read in the filterfile failed to populate the filterhash:
		my $file =  wget_DWfilterpage_mine() ;
		extract_DWfilterids_in(tokenizeHTML(find_DWFilterline_in($file)));
#		print "$_ $filterhash{$_}\n" for (keys %filterhash);

		# cache those to disk
		# move old cache, if any, out of way
		if (-f $filtermap) {
			rename $filtermap, $filtermap."~";
		}
		open ( FILTERMAP, ">", $filtermap );
		for my $filtername (keys %filterhash) {
			print FILTERMAP "$filtername|$filterhash{$filtername}\n";
		}
		close FILTERMAP;

	}
}


sub main {
	arguer();
	my $file =  wget_LJfiltermembershippage_for $flj ;
	my @filtermemberships =  extract_LJfiltermemberships_in(tokenizeHTML(find_LJFilterline_in($file)));
#	print @filtermemberships;
	make_DWfiltermap ;
#	print "$_ $filterhash{$_}\n" for (keys %filterhash);
	@filtermemberships = map_LJmemberships_toDWfilterids @filtermemberships;
#	print join(',',@filtermemberships);
	print "manage_circle add_access $fdw ", join(',',@filtermemberships), "\n";
}
