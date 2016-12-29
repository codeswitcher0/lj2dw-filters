#!/usr/bin/perl
#
# Based on scrapefiltermembership.ph and scrapefilterids.pl
#
# All-in-one file runs on a directory of saved HTML pages:
#  • all of the LJ Modify Friend pages 
#  • the DW Access Filter Manager page
# and outputs results like:
#  manage_circle add_access exampleusername 1,13,24
#
# Call as "generateconsoladds.pl *"


my $line = "";
my %memberships;
my @temp;
my %filterhash;
while ($line = <>) {
	# Test for filter membership file (LJ)
	if ($line =~ /<h1 class="b-service-title"> Modify Friend <\/h1>/) { 
		$therightline = $line;
#		print "Membership line found!\n";
#		@temp = extractmembership($therightline);
#		print "$_ \n" for @temp;
		my ($username, @usermemberships) = extractmembership($therightline);
#		print "${username}: ";
#		print "$_, " for @usermemberships;

#		Make a hash of arrays, keyed by username, holding an array of memberships
		$memberships{$username} = [ @usermemberships ];
#		print "${username}:";
#		print "$_, " for @{ $memberships{$username} } ;
		
	}
	# Test for filter manager file (DW)
	if ($line =~ /<form method='post' name='fg'/) { 
		$therightline = $line;
#		print "Line found!\n";
		extractfilterids($therightline);
#		print "$_ $filterhash{$_}\n" for (keys %filterhash);

	}
}

#for each key in memberships

for $username (keys %memberships) {
	@temp = @{ $memberships{$username} };
	#for each item in @temp
	for my $i (0 .. $#temp) {
#		print $temp[$i]."  ";
		$temp[$i] = $filterhash{$temp[$i]};
#		print $temp[$i]."\n";		
	}

	print "$username ", join(',',@temp), "\n";
}

sub extractmembership {
#	print "extract called!\n";
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
			$tokenarray[++$#tokenarray] = $token;
			$token = "";
		} else {
			$token .= $char;
		}
	}

#	print "Line tokenized! $#tokenarray tokens!\n";
#	print join("\n", @tokenarray), "\n";

#	okay, we now have the line tokenized
#	loop over the array, looking for the start of our tokens of interest

	$token = "";
	my @newtokenarray;
	my @nametokenarray;
####  TRUE=1, FALSE=0
	my $savethese = 0; #FALSE

	# get the user's name
	for $token (@tokenarray) {
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
	$token = "";
	for $token (@nametokenarray) {
		if ($token =~ /data-ljuser/) {
			@namearray = split(/\s/, $token);
#			print join("\n", @namearray), "\n";
		}
	}
	$token = "";
	my $username;
	for $token (@namearray) {
		if ($token =~ /data-ljuser="(.*)"/) {
			$username = $1;
#			print $1;
		}
	}
	
	
	# Get the filter list
	for $token (@tokenarray) {
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
#			Default View
#			</label>
#		</li>
#		<li class="flatfriend-groups-item">
#			<input type="checkbox" name="bit_13" id="fg:bit_13"  > 
#			<label for="fg:bit_13">Cow-orkers</label>
#		</li>   
#
#
#    So what we can do is loop over our array looking for q_input type="checkbox"_ and if we match, look in it for q_checked="checked"_, and if that matches, then look in the second-next token for the filter subscribed!

	$token = "";
	my $secondnext = 0;
	my @filterarray;
	for $token (@newtokenarray) {
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
#	print "manage_circle add_access $username ",  join(',', @filterarray), "\n";

#	my %returnarray =  ( $username => @filterarray );
	return $username, @filterarray;

# manage_circle add_access <username> [groups]

}

sub extractfilterids {
#	print "extract called!\n";
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
			$tokenarray[++$#tokenarray] = $token;
			$token = "";
		} else {
			$token .= $char;
		}
	}

#	print "Line tokenized! $#tokenarray tokens!\n";
#	print join("\n", @tokenarray), "\n";

#	okay, we now have the line tokenized
#	loop over the array, looking for the start of our tokens of interest

	$token = "";
	my @newtokenarray;
	my @nametokenarray;
####  TRUE=1, FALSE=0
	my $savethese = 0; #FALSE

	# Get the filter list
	for $token (@tokenarray) {
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
				$newtokenarray[++$#newtokenarray] = $token;
			}
		}
	}

#	print "Tokens filtered down to the relevant ones, and all-white-space tokens dropped! $#newtokenarray tokens!\n";
#	print join("\n", @newtokenarray), "\n";

#  	okay, we now have (in $newtokenarray) just the tokens for the friends filters
#   What our structure looks like in the original (no linebreaks):
#
#	<form method='post' name='fg' action='editfilters'>
#		<input type='hidden' name="lj_form_auth" value="c0:1482976800:[REDACTED]" />
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

#	my %filterhash;
	my $id, $filter;
	$token = "";
	for $token (@newtokenarray) {
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
	
}