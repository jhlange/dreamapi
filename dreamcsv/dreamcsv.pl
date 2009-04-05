#!/usr/bin/perl -w
# Name: DreamCSV
# Description: Sometimes the web isn't the right answer. And a lot of us
# are more comfortable with Excel or OOo Calc.
#
# This script is a simple CSV importer and exporter for the DreamHost API.
# Try it out!
#
# Project URL: http://www.joshlange.net/dreamapi
#
# =Josh Public License=
# You are free to modify/distribute this script as you like, but know that you
# are using this script AT YOUR OWN RISK! None of the script's contributors
# take any liability for the scripts actions, inactions, bugs, vulnerabilities
# or any malicious content which could have easily been added by a third party.
# IT IS YOUR RESPONSIBILITY TO INSPECT THE CODE.
#
# RULES FOR MODIFICATIONS
# 1. Keep this disclaimer and set of rules in the script.
# 2. Attribute your changes, with a small amount of detail in the changelog
# below.
# 3. Change the version info to include your name.
# 4. Leave comments where appropriate.
# 5. (optional) Contact the script maintainers if you want to contribute
# improvements.
# 
#
# =CHANGELOG=
#
# Joshua Lange <josh(#AT#)joshlange.net>  - 2009-05-05 v0.3-jlange
#  - Fixed escape_char to default to Excel default
# Joshua Lange <josh(#AT#)joshlange.net>  - 2009-05-04 v0.2-jlange
#  - Column order now stable
#  - Print out list of commands if none is specified
# Joshua Lange <josh(#AT#)joshlange.net>  - 2009-05-02 v0.1-jlange
#  - Initial release
#
use strict;
use Switch;
use LWP::UserAgent;
use Safe;
use Text::CSV_XS;

my $version = "v0.3-jlange";


#######################################################
#         Instructions for use                        #
#######################################################
#  
#  1. INSTALL PERL
#    - probably already have it if your not running windows,
#      if not, check your package manager
#    - on windows, install activeperl for windows
#      http://www.activestate.com/activeperl/
#    - ALL USERS: Install Crypt::SSLeay, IF you get an error
#      connecting to DreamHost. It's a required package.
#      You should be able to get this from your operating
#      system package maneger, and through the ActiveState
#      perl package manager (You shouldn't have to download
#      it directly from cpan.org)
#    - INSTALL Text::CSV_XS, If its included in the directory
#      with this script, just leave it there. Otherwise install
#      it from your OS package manager, or ActivePerl's package
#      manager, or manually from CPAN.org
#
#  2. GET AN API KEY
#    - log into your DreamHost panel, and generate an
#      api key that can manage your dns records
#
#  3. EDIT CONFIGURATION below
#    - put username, and apikey in, if you don't want to specify it on the cli
#
#  4. TEST IT OUT
#    - run the script with no cli options other than
#      --verbose 5.
#      E.X.   ./dreamcsv.pl --username josh.h.lange@gmail.com   \
#          --key AAAAAAAAAAAAAAAA --cmd api-list_accessible_cmds \
#          --receive asdf.csv
#

#######################################################
#              CONFIGURATION VARIABLES                #
#######################################################
#you can specify ALL command options for dreamhost here, or on the CLI
my %configOptions = ();
#if you don't want to specify cli options
#fill in these vars

#USERNAME
# ORIG: $configOptions{'username'} = undef;
# CUSTOM: $configOptions{'username'} = 'webpanelemail@gmail.com';
$configOptions{'username'} = undef;

#API KEY
# ORIG: $configOptions{'key'} = undef;
# CUSTOM: $configOptions{'key'} = 'ABCDEFGHIJKLMNOP';
$configOptions{'key'} = undef;

#DEFAULT COMMAND TO RUN
# ORIG: $configOptions{'cmd'} = 'api-list_accessible_cmds';
# if you don't want a default command:
# CUSTOM $configOptions{'cmd'} = undef;

#######################################################
#            OTHER CONFIGURABLE SETTINGS              #
#######################################################

# this character is put in front of quote chars, in case
# they show up in the data.
# excel uses the " char for escaping quotes
my $csv_escape_char = "\"";

# this is the character that is put around individual values
# when a space appears in them, or seemingly randomly when
# the program saving the document decides to put them in.
my $csv_quote_char = "\"";

# network timeout, in seconds (DEFAULT=15)
my $timeout = 10;

# number of retries on network errors (DEFAULT=3)
my $tries = 3;

# DreamHost API URL
#  NOTE: only change this if dreamhost changes the API's
#  location.
#
#  ORIG: my $dreamhost_url = 'https://api.dreamhost.com/';
my $dreamhost_url = 'https://api.dreamhost.com/';


#######################################################
#######################################################
#######################################################


####### DONT TOUCH ANYTHING BELOW THIS LINE #########
####### (unless you know what you are doing) ########

my $browser;
#for random uuids
my @hex = (qw(0 1 2 3 4 5 6 7 8 9 a b c d e f));
my ($import, $export);
my $csv;
my $exit_code;
######################## FUNCTIONS ########################################
sub usage {
  print STDERR "\nDreamCSV version $version\n";
  print STDERR $_[0]."\n" if ($_[0]);
  print STDERR <<ENDOFFILE;
Usage: $0
  --username <my_webpanel_username>  (e.g. myemail(at)gmail.com)
  --key <my_api_key>
  --send <csv_to_send> -or-  --receive <csv_to_receive>
  [--cmd <command_to_run>] (if ommited, prints a list of available commands)
  [--<dreamhost_option> <value>]
  [--help]    (this message)

e.x. $0 --cmd dns-list_records --receive my_dns_records.csv
e.x. $0 --cmd dns-add_record --send my_new_dns_records.csv

e.x. $0 --cmd announcement_list-add_subscriber  \\
      --listname list1 --domain joshlange.net --send test.csv

Forgot a command? Then omit --cmd (and a list of cmds will be printed):
e.x. $0 --send my_new_dns_records.csv

NOTE: There are security implications with using cli arguments on multi-user
systems. If applicable, or you don't WANT TO USE THE CLI options, consider
manually setting these options inside this script.

ENDOFFILE
  exit 1;
}

#so we don't rely on Data::UUID
sub genUUID {
  my $rtrn = '';
  for (my $i = 0; $i < 32; $i++) {
    $rtrn .= $hex[int rand($#hex+.999)];
  }
  $rtrn =~ s/(.{8})(.{4})(.{4})(.{4})(.*)/$1-$2-$3-$4-$5/;
  return $rtrn;
}

sub sendDreamhostCmd {
  my ($post_data) = @_;
  my %full_post_data = ();
  my $response;
  $full_post_data{$_} = $post_data->{$_} foreach(keys %$post_data);
  $full_post_data{'format'} = 'tab';
  $full_post_data{'unique_id'} = genUUID;

  #gets updated by dreamhost's response ( eval() )
  my $result1 = {'result' => 'error', 'data' => 'failed_dreamhost_connect'};

  for (my $i = 0; $i < $tries; $i++) {
    $response = $browser->post($dreamhost_url,\%full_post_data);
    last if ($response && $response->is_success);
    if ($response && $response->as_string =~ /Crypt::SSLeay/) {
      print STDERR <<ENDOFFILE;
You MUST install perl's Crypt::SSLeay library
It's often available from linux repositories, or through
Windows' ActivePerl/CPAN INSALLER
The redhat/fedora package is called perl-Crypt-SSLeay
The debian/ubuntu package is called libcrypt-ssleay-perl
Otherwise you can manually get it at:
http://search.cpan.org/~dland/Crypt-SSLeay-0.57/SSLeay.pm

ENDOFFILE
      $result1 = {'result' => 'error', 'data' => 'install_crypt_ssleay'};
      return $result1;
    }
    print STDERR "WARNING: network issues prevented contacting dreamhost (try ".($i+1).
    " of $tries)\n" if ($tries > 1);
    sleep($timeout)
  }
  if ($response && $response->is_success) {
    my $content = $response->content;
    if ($content =~ s/^(\r?\n)?(error|success)\s*(\r?\n)//) {
      $result1 = {'result' => $2, 'data' => $content};
    } else {
      $result1 = {'result' => 'error', 'data' => 'bad_data_from_dreamhost'};
    }
  }
  return $result1;
}


######################## /FUNCTIONS #######################################

for (my $i = 0; $i <= $#ARGV; $i++) {
  switch($ARGV[$i]) {
    case '--send' {$import = $ARGV[++$i];}
    case '--receive' {$export = $ARGV[++$i];}
    case '--apikey' {$configOptions{'key'} = $ARGV[++$i];}
    case '--help' {usage();}
    else { 
      if ($ARGV[$i] =~ /^\-\-(.*)$/) {
        my $option = $1;
        $i++;
        if (defined($ARGV[$i]) && length($ARGV[$i]) > 0 &&
          $ARGV[$i] !~ /^\-\-/) {
          $configOptions{$option} = $ARGV[$i];
        } else {
          usage("INVALID VALUE FOR: ". $option);
        }
      } else {
        usage("INVALID OPTION: ". $ARGV[$i]);
      }
    }
  }
}

$browser = LWP::UserAgent->new;
#200KB is a big page, for plain text
$browser->max_size(200*1024);
$browser->timeout($timeout);

#csv
$csv = Text::CSV_XS->new (
      {quote_char => $csv_quote_char,
       escape_char => $csv_escape_char,
       binary => 0, eol => $/});

# output records correctly, for the platform
# $\ = $/; #nevermind, that screws up the csv lib

# we are reading from dh, I doubt its
# even worth checking to see whether they use \r\n ;-)
#anyway, we can cut them out later
$/ = "\n";

# exit code
$exit_code = 0;

#check import export
if ( (defined $import && defined $export) ||
     !(defined $import || defined $export)) {
  usage("ERROR: must either, send *OR* receive a CSV");
}

# check if there is a command, if not, lets print out list of available
# commands this is done after the last one, so usage is printed out if no cli
# opts are used ;-)
unless (defined $configOptions{'cmd'}) {
  my %postData = ();
  $postData{$_} = $configOptions{$_} foreach(keys %configOptions);
  $postData{'cmd'} = 'api-list_accessible_cmds'; 
  my $result = sendDreamhostCmd(\%postData);
  if ($result->{'result'} =~ /^success/) {
    print "Available commands:\n";
    $result->{'data'} =~ s/^cmd\r?\n//;
    print $result->{'data'};
  } else {
    #poor man's chomp (no, actually, CR LF issues)
    $result->{'data'} =~ s/\r?\n$//;
    print STDERR "ERROR WHILE ASKING FOR AVAIL CMDS: ".$result->{'data'}."\n";
  }
  exit 1;
}

if (defined $import) {
  my $line;
  my $linenum = 1;
  open(FH, "<", $import) or die ("Failed to open $import: $!");
  defined($line = <FH>) or die("No rows in $import!");
  $line =~ s/\r//g;
  $csv->parse($line) or die(
    "Bad CSV format on line $linenum: $! (' on the line?)");
  my @col_names = $csv->fields();
  while(my $csv_line = <FH>) {
    #remove all \r or \n or whatever!
    $csv_line =~ s/[\r\n]//g;

    $linenum++;
    my %postData = ();
    $csv->parse($csv_line) or
      die("Bad CSV format on line $linenum: $! (' on the line?)");
    my @rowdata = $csv->fields();
    if ($#rowdata != $#col_names) {
      die(
       "Bad column length on line $linenum, (' on the line?)");
    }
    for(my $i = 0; $i <= $#col_names; $i++) {
      $postData{$col_names[$i]} = $rowdata[$i];
    }
    $postData{$_} = $configOptions{$_} foreach(keys %configOptions);
    my $result = sendDreamhostCmd(\%postData);
    if ($result->{'result'} =~ /^success/) {
      print "processed record ".($linenum - 1)."\n";
    } else {
      $result->{'data'} =~ s/\r?\n$//;
      print STDERR "ERROR SENDING RECORD ".($linenum - 1).": ".$result->{'data'}."\n";
      $exit_code = 1;
    }
  }
  close(FH);
} else { #exporting

  my $result = sendDreamhostCmd(\%configOptions);
  if ($result->{'result'} =~ /^success/) {
    my $fh;
    open($fh, ">", $export) or die("Failed to open $export: $!");
    foreach my $line (split(/\r?\n/,$result->{'data'})) {
      my @line_cols = split(/\t/, $line);
      $csv->print($fh, \@line_cols) or die("Failed to write col names: ".
        $csv->error_diag());
    }
    close($fh);
    print "Wrote $export\n";
  } else {
    $result->{'data'} =~ s/\r?\n$//;
    die("CMD failed to execute: ".$result->{'data'});
  }
}

exit $exit_code;
