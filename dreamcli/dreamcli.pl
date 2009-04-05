#!/usr/bin/perl -w
# Name: DreamCLI
# Description: Sometimes the web isn't the right answer. And a lot of us
# are more comfortable with scripting things on our own.
#
# This script is a simple wrapper around the dreamhost web API, which makes
# it available on the command line. Try it out!
#
# On errors, the script returns a bad return code, and outputs the error to
# stderr. This means, that if you are piping the script output to a file or
# other scripts won't have to check for the error strings.
#
# Also, the --nocols option makes it so that you don't get the columns names
# printed, which may help in scripting
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
# Joshua Lange <josh(#AT#)joshlange.net>  - 2009-05-04 v0.2-jlange
#  - Added option to allow selection of desired columns
#  - Renamed nocols option to noheaders
# Joshua Lange <josh(#AT#)joshlange.net>  - 2009-05-02 v0.1-jlange
#  - Initial release
#
use strict;
use Switch;
use LWP::UserAgent;
use Safe;

my $version = "v0.2-jlange";


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
#      E.X.   ./dreamcli.pl --username josh.h.lange@gmail.com   \
#          --key AAAAAAAAAAAAAAAA --cmd api-list_accessible_cmds
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
$configOptions{'cmd'} = 'api-list_accessible_cmds';

#######################################################
#            OTHER CONFIGURABLE SETTINGS              #
#######################################################

# don't print column names?
# 0 - print column names
# 1 - don't print column names
my $nocols = 0;

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
my $requested_columns;
my @column_indexes;
######################## FUNCTIONS ########################################
sub usage {
  print STDERR "\nDreamCLI version $version\n\n";
  print STDERR $_[0]."\n" if ($_[0]);
  print STDERR <<ENDOFFILE;
Usage: $0
  --username <my_webpanel_username>  (e.g. myemail(at)gmail.com)
  --key <my_api_key>
  [--cmd <command_to_run>]  (defaults to listing available commands)
  [--noheaders]   (don't print column names)
  [--cols <columnname>[,<columnname>...]]   (print these columns only, in order)
  [--<dreamhost_option> <value>]
  [--help]    (this message)

e.x. $0 --cmd dns-add_record --record mycomputer.mydomain.com \\
           --type A --value 4.2.2.2
e.x. $0 --cmd announcement_list-list_subscribers   \\
           --listname list1 --domain joshlange.net  \\
           --cols email,name

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
  my $result1 = "error\nfailed_dreamhost_connect";

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
      $result1 = "error\ninstall_crypt_ssleay";
      return $result1;
    }
    print STDERR "WARNING: network issues prevented contacting dreamhost (try ".($i+1).
    " of $tries)\n" if ($tries > 1);
    sleep($timeout)
  }
  if ($response && $response->is_success) {
    if ($response->content =~ /^(error|success)$/m) {
      $result1 = $response->content;
    } else {
      $result1 = "error\nbad_data_from_dreamhost";
    }
  }
  return $result1;
}

######################## /FUNCTIONS #######################################

#parse command line args
for(my $i = 0; $i <= $#ARGV; $i++) {
  switch($ARGV[$i]) {
    case '--noheaders' {$nocols = 1;}
    case '--cols' {$requested_columns = $ARGV[++$i];}
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


#send the command
my $result = sendDreamhostCmd(\%configOptions);

#parse result
my $error_code = 0;
$result =~ s/^(.*?)\n//s;
my $error_string = $1;

if ($error_string !~ /^success/) {
  $error_code = 1;
  #makes it work in either case ;-)
  chomp($result);
  print STDERR "ERROR: $result\n";
} else {
  $result =~ /([^\n].*?)\r?\n/;
  my @column_names = split(/\t/,$1);
  if ($nocols) {
    #strip first line
    $result =~ s/[^\n].*?\n//s;
  }
  chomp($result);
  if (defined $requested_columns) {
    @column_indexes = ();
    #figure out which columns to print
    #O(n^2) if anyone cares ;-) (you shouldn't)
    foreach my $requested_column (split(/,/,$requested_columns)) {
      my $found = 0;
      for (my $i = 0; $i <= $#column_names; $i++) {
        if ($column_names[$i] eq $requested_column) {
          push(@column_indexes, $i);
          $found = 1;
          last;
        }
      }
      unless ($found) {
        print STDERR "ERROR: Invalid column name: $requested_column\n";
        exit 1;
      }
    }
    foreach my $line (split(/\r?\n/,$result)) {
      my @line_cols = split(/\t/,$line);
      my @print_cols = ();
      foreach (@column_indexes) {
        push(@print_cols, $line_cols[$_]);
      }
      print join("\t", @print_cols) . "\n";
    }
  } else {
    print "$result\n";
  }
}

#exit
exit $error_code;
