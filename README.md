# lj2dw-filters
A system of kludgy command line scripts to scrape "filter" (access control list) membership info from Livejournal and import it into Dreamwidth by way of the DW console.

Intended for users who have recently imported their Livejournal account into Dreamwidth, and now need to synchronize their DW access filters with their LJ filters.  It works by matching filter names between the two platforms.  It is particularly for people with many friends and many filters, for whom the permutations of which means manually re-establishing filter memberships would be a huge amount of data entry.

Works by screen-scraping, thus could abruptly stop working or break in interesting ways, at any time, if either LJ or DW changes the pages it scrapes.

These scripts have been exclusively tested on perl v5.10.1 "built for arm-linux-gnueabi-thread-multi", which is to say only on the LG N1A1 network attached storage device, upon which approximately nobody else will ever run it.  If they turn out to work on your device in your version of perl, that's great news – faintly miraculous, even – and I'd like to know about it.

That said, I did write with an eye – a lazy, myopic eye – to portability and ease of use.  If I succeeded at either, it's a wonderment.  Nothing here requires any perl modules to be downloaded.  It's intended to be self-sufficient.  Because I have no idea how to install from CPAN on my rooted N1A1, and decided not to shave that yak.

It does, however, require wget. And, of course, perl.  To see if you have these, at your command line, enter:

wget --version; perl --version

To use these scripts, you call them at the command line.  (On the Mac, use the "terminal" application.)  They require no installation or compilation.  Download them, make sure they're executable (chmod u+x friendgrant.pl batchfriendgrant.pl uploadtodwconsole.pl), and you should be able to run them right as they are.

# How to Use: A General Overview
There are three scripts here: friendgrant.pl, batchfriendgrant.pl, and uploadtodwconsole.pl.

To work, all three need the config file (which they share) correctly filled out.  config_EXAMPLE.txt is your example config file.  Save it as a text-only file with your deets, named like "config.txt".  It can have any name; you call it explicitly.  See "Config File" below.

You will also need a couple other files you will have to put together: you're required to come up with the authenticcookies file (see "Config File" below), and batchfriendgrant.pl requires a batch file (see below).

friendgrant.pl takes an LJ username (and optionally a corresponding DW username, if different) and returns the DW console command that will give the DW user access to the filters of the same name as they have access to on LJ.

batchfriendgrant.pl takes a file that is a list of pairs of LJ/DW username correspondences, and runs friendgrant.pl iteratively over it.  Must be in the same folder as friendgrant.pl.

uploadtodwconsole.pl takes a file that is a list of console commands and runs them in batches of three, waiting for user prompting between each batch.  For each command, if successful, it returns the line of raw HTML from the DW console showing the command that was run and the confirmation it was successful.  Silence means it didn't work.

You can construct a file that's a list of LJ/DW username correspondences (say by hosting a poll on LJ asking your friends what their DW usernames are), and then run batchfriendgrant.pl on it once, capturing the results into a file, and then run uploadtodwconsole.pl on the results file once, so add them all to DW.

If you have late stragglers to your poll, you can make a separate correspondence file, and then do the same thing again.

# Config File

The config file consists of field-value pairs, one per a line, with the field name first, separated with a space from the field value.

The config file has three configuration settings: authenticcookies, cookiejar, and filtermap.  They each take a file name, with optional fully qualified paths.

They are in turn:

authenticcookies
	You have to make a cookie file and its name (and optional path) must be set as the value for authenticcookies.  What this is doing: These scripts use your authentication tokens from DW and LJ, i.e. your cookies from when you're logged in; the value of this constant tells the script where a cookie file with those tokens can be found.  
	
	So to use these scripts, you're going to need to generate a cookies.txt file from your browser when you're logged in to both DW and LJ.  See "How to use" below.

cookiejar
	You can change the name of the cookie file these scripts write, if you want to.  Otherwise, ignore this and use the default.  What this is doing: These scripts write cookies to a cookie file.  Rather than risk them overwriting your authentication token cookie file, they are written into a scratch file.  This option allows you to tell it where that file should be, or it will default to cookiejar.txt.  You can delete these files when you're done; no need to keep them around.

filtermap
	You can change the name of the default filtermap cache file here, if you want to.  Otherwise, ignore this and use the default.  What this is doing: You probably don't create or delete filters themselves on DW all that often, so there's no reason not to cache the info on your local machine, so that you're not thrashing DW unnecessarily every time you run friendsgrant.pl, to say nothing of batchfriendsgrant.pl.  That's what this file is.  The filtermap is generated and cached for an hour.  It's a list of your filter names on DW and their id numbers.

# How to use: No, Really, How to Make This Go

To use these scripts, download them onto a computer that has perl and wget.  If you're not on a *nix system and don't have wget, see http://antennapedia.livejournal.com/239955.html about getting wget, and also for discussion of how to get your cookie file together.  About which....

As described under "Config File", above, to use these scripts you have to provide them with a cookie file that has your DW and LJ login cookies; that's how it can act as you, reading your filters on LJ and adding people to them on DW.  Note that these scripts will act as whichever accounts you're logged in as when you copy the cookie file, so if you have more than one pair of accounts to sync, you'll want to be careful about that.  (Suggested best practice: have different folders for different pairs of DW/LJ accounts, each with their own config.txt and other files.  Diskspace is cheap; maybe copy the scripts right there into each.)

So you need to come up with that cookie file that has your DW and LJ loging cookies.

The easiest way to do this is use a sufficiently old browser (like an antique version of Firefox) that just regularly stores cookies in a Netscape-style cookies.txt file and just find it and copy it, after you've logged in to both LJ and DW in the accounts you want to sync.  
	
The second easiest way is to install the "Export Cookies" plug-in to normal Firefox and use it.  Steps: Install plug-in; restart browser; log in to DW; log in to LJ; select "Export Cookies..." from the "Tools" menu, and save them somewhere you can find them.  Wherever that is, put that file name (and path) as the value for this setting.

However you do this, note that these cookies expire after a day or so, so expect to have to do this regularly before using these scripts.  If things abruptly stop working, before trying anything else, go log back into DW and LJ and get a fresh cookie file to use.

The way you use these three scripts is as so:

## friendgrant.pl

If you tell friendgrant.pl the LJ username (and also, optionally, the corresponding DW username of the same person, if different) of a friend, it will emit a statement like "manage_circle add_access exampleuser 4,9".  That is a command that can be run in the DW console, which gives exampleuser on DW access to the same filters they had on LJ.  friendgrant.pl doesn't actually change anything on DW – it doesn't add anyone to any filters – it just tells you the command that would do so if sent to the DW console.  You can literally cut-and-paste the results into the DW console (https://www.dreamwidth.org/admin/console/) and hit the "Execute" button, and it should work.  What this command does for you is look up on LJ what the right filters are, and construct the console command to grant access to those filters.

To call, cd into same directory, and then:
./friendgrant.pl -flj theirLJusername -fdw theirDWusername -config configfile

Example:
./friendgrant.pl -flj codeswitcher -fdw codeswitcher -config config.txt

## batchfriendgrant.pl

If you keep a list of who of your LJ friends has a DW account, and what each LJ friend's DW account name is, batchfriendgrant.pl can read that file, and send each line to friendgrant.pl, and it will generate a list of console commands, to grant each user the same filter access on DW as they had on LJ.  This makes it easy to do a whole lot of friends at once, and also to keep track of which ones you've done.

The batch file has to have one LJ/DW username correspondence pair per line, the LJ username first, then the DW username separated by a pipe, like so:

codeswitcher|codeswitcher
exampleusername|exampleDWusername

batchfriendgrant.pl requires friendgrant.pl to work, and expects to find it in the same directory.

To call, cd into same directory, and then:
./batchfriendgrant.pl -batch batchfile -config configfile

Example:
./friendgrant.pl batch myfriends.txt -config config.txt

Because the next script operates on the results of batchfriendgrant.pl, and expects to find its inputs in a file, you might want to capture the output of batchfriendgrant.pl to a file, like so:

./friendgrant.pl batch myfriends.txt -config config.txt > addmyfriends.txt

## uploadtodwconsole.pl

This script takes console commands, like those created by friendgrant.pl and batchfriendgrant.pl, and sends them to the Dreamwidth command console, actually running them, committing those changes in reality on Dreamwidth.

uploadtodwconsole.pl expects to find the console commands in a file, such as you can generate with batchfriendgrant.pl.  For each line, it reports success with a chunk of really ugly HTML:

Posting: manage_circle add_access myexamplefriend 7,8,9,28
    <p><table class='console_command' summary='' border='1' cellpadding='5'><tr><td><strong>manage_circle</strong></td><td>add_access</td><td>myexamplefriend</td><td>7,8,9,28</td></tr></table><pre><span class='console_text'><span style='color:#008800;'>Done.</span></span></pre></p>

The important part in there is that is the word "Done.", which indicates success.

The program will only do three friends in succession, then pause to wait for the user to press return.  This is to allow you to catch errors and abort (control-C) in what could be a catastrophic process, if you've done it wrong and it applies to a huge number of accounts.

To call:  
./uploadtodwconsole.pl -batch consolecommandfile -config configfile

Example:
./uploadtodwconsole.pl -batch addmyfriends.txt -config config.txt

# You Should Know

• This system of scripts only adds permissions, it doesn't ever take them away.  Thus it does not fully sync filters, it only grants matching permissions.

• At this moment, all calls wget makes to DW use the awful --no-check-certificate option, which is a security problem if you're worried MITM attacks.  Your machine, if it has a newer version of wget installed, might not need that option, and you can delete it.

• Don't be confused: the batch file that batchfriendgrant.pl uses is not the same batch file that uploadtodwconsole.pl uses.  The former is your list of username pairs (LJ|DW) of friends you want to grant permissions to on DW.  The latter is the batch of commands that batchfriendgrant.pl makes.  (You could also make such a thing by hand if you wanted to.  It will throw any commands you want against the DW server, valid or not.)

# License

Haven't figured this out yet.  It's mine, but for now you have my permission to use it to import your journal filter settings.