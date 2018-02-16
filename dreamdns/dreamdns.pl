#!/usr/bin/perl -w
# Name: DreamDNS updater
# Description: This is a script to update your dreamhost dns, to match
# your local IP. It works much like other dynamic dns services.
#
# Because DreanHost doesn't allow us to change DNS TTL, this isn't a great
# solution if your ip is *CONSTANTLY* changing. But, in general, it should be
# a pretty reasonable solution for people at home, on a DSL/Cable line.
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
# =CHANGELOG=
#
# Fabian Rodriguez <fabian(#AT#)legoutdulibre.com>
#  - Added details and fixed parameter for test command
#  - Added capitals, fixed some typos
#  - Added URL and details for Dreamhost API generation instructions
# David Nagle <david(#AT#)randomfrequency.net> - 2014-08-15 v0.3-dnagle
#  - Removed username option (it is no longer used by the API)
#  - Changed API output from 'perl' to 'json', as 'perl' output was failing in
#    the safe eval
# Joshua Lange <josh(#AT#)joshlange.net>  - 2009-05-04 v0.2-jlange
#  - PATH improperly obeyed, due to missing last statement in nic lookup
#  - Fixed improper return value if IP lookup fails
#  - Added ability to change UserAgent
# Joshua Lange <josh(#AT#)joshlange.net>  - 2009-05-02 v0.1-jlange
#  - Initial release
#
use strict;
use Switch;
use LWP::UserAgent;
use JSON;

my $version = "v0.4-frodriguez";


#######################################################
#         Instructions for setting up a daemon        #
#######################################################
#  
#  1. INSTALL PERL
#    - probably already have it if you're not running Windows,
#      if not, check your package manager
#    - on Windows, install ActivePerl for Windows
#      https://www.activestate.com/activeperl/
#    - ALL USERS: Install Crypt::SSLeay if you get an error
#      connecting to DreamHost. It's a required package.
#      You should be able to get this from your operating
#      system package maneger, and through the ActiveState
#      perl package manager (You shouldn't have to download
#      it directly from cpan.org)
#
#  2. GET AN API KEY
#    - log into your DreamHost panel at https://panel.dreamhost.com/?tree=home.api,
#      choose a name to describe your new API key, check the "All dns functions" checkbox
#      and generate an API key that can manage your DNS records
#
#  3. EDIT CONFIGURATION below
#    - put your domain and API key in (don't forget the single quotes)
#
#  4. TEST IT OUT
#    - run the script with no cli options other than
#      --verbosity 5.
#      E.X.   perl ./dreamdns.pl --verbosity 5
#    - If it works, continue to step 4
#
#  5. EDIT OTHER CONFIGURABLE SETTINGS below
#    - set daemonize  to 1  (UNLESS YOU ARE USING WINDOWS!)
#    - its easy to accidentally start many copies, kill old copies
#      with your task manager before you restart the script.
#
#  6. GET YOUR OS TO RUN IT ON BOOT
#    - Linux: edit /etc/rc.local or /etc/init.d/rc.local, and add:
#      /path/to/script/dreamdns.pl --daemon
#    - Windows: read http://support.microsoft.com/kb/251192
#    - MacOS: read appropriate material
#  

#######################################################
#              CONFIGURATION VARIABLES                #
#######################################################
# If you don't want to specify CLI options
# fill in these variables.

# ORIG: my $domain = undef;
# CUSTOM: my $domain = 'homecomputer.joshlange.net'
my $domain = undef;

# ORIG: my $apikey = undef;
# CUSTOM: my $apikey = 'ABCDEFGHIJKLMNOP';
my $apikey = undef;


#######################################################
#            OTHER CONFIGURABLE SETTINGS              #
#######################################################
# Defaults should work below, but you can edit them.

# Run as a daemon in the background? (DEFAULT=0)
#  0 = false
#  1 = true
my $daemonize = 0;

# Update interval, in seconds (DEFAULT=3600)
#  (default = 1/hour)
my $interval = 60*60;

# Force recheck of DreamHost DNS settings every so often (DEFAULT=86400)
#  (default = 1/day)
my $recheck_secs = 60*60*24;

# Network timeout, in seconds (DEFAULT=15)
my $timeout = 15;

# Number of retries on network errors (DEFAULT=3)
my $tries = 3;

# NIC to watch, if you don't want to do IP lookup service
#  ORIG: my $nic = undef;
#  CUSTOM: my $nic = 'eth0';
#  WINDOWS: my $nic = 'windows';
my $nic = undef;

# IP to always use, if you don't want to do IP lookup service
#  ORIG: my $ip = undef;
#  CUSTOM: my $ip = '74.125.45.100';
my $ip = undef;

# Verbosity level (DEFAULT=4)
#  5  step-by-step info
#  4  info
#  3 transient network errors
#  2 permanent network errors
#  1 environment errors
#  0 quiet
my $verbosity = 4;

# Run once, and don't loop? (DEFAULT=0)
#  0 = false
#  1 = true
my $once = 0;

# IP lookup service URL
#   NOTE: I might disable this if the overuse kills my acct (not likely).
#
#   Should even work on html ip sites, as long as the first ip on the page
#   is the right one to use. NOTE: many sites BLOCK perl's, UserAgent.
#   If this doesn't work on a random html site, thats more
#   likely to be the issue than the html getting parsed wrong.
#
#   ORIG: my $ipurl = "http://www.joshlange.net/cgi/get_ip.pl";
#   THESE ARE LISTED IN THE OPENSOURCE/SF ddclient app, so they should be
#   free to use.
#   CUSTOM: my $ipurl = "http://ipdetect.dnspark.com/";
#   CUSTOM: my $ipurl = "http://checkip.dyndns.org/";
my $ipurl = "http://www.joshlange.net/cgi/get_ip.pl";

# UserAgent
# This is the user agent that perl reports to the DreamHost API, and to 
# the IP lookup service.
#
# ORIG: my $agent = undef;
# CUSTOM: my $agent = 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.0.10) Gecko/2009042708 Fedora/3.0.10-1.fc10 Firefox/3.0.10';
my $agent = undef;

# DreamHost API URL
#  NOTE: only change this if Dreamhost changes the API's
#  location.
#
#  ORIG: my $dreamhost_url = 'https://api.dreamhost.com/';
my $dreamhost_url = 'https://api.dreamhost.com/';


#######################################################
#######################################################
#######################################################


####### DON'T TOUCH ANYTHING BELOW THIS LINE ########
####### (unless you know what you are doing) ########
my $last_ip = undef;
my $last_check = 0;
my $browser;
my $rtrn_val = 0;
my $time_to_quit = 0;
#for random uuids
my @hex = (qw(0 1 2 3 4 5 6 7 8 9 a b c d e f));
######################## FUNCTIONS ########################################
sub usage {
  print STDERR "\nDreamDNS Updater version $version\n\n";
  print STDERR $_[0]."\n" if ($_[0]);
  print STDERR <<ENDOFFILE;
Usage: $0
  --domain <my_dynamic_hostname>     (e.g. myhomecomputer.mydomain.com)
  --apikey <my_dns_api_key>
  [--nic <my_nic_to_watch>]
  [--ip <my_new_ip>]
  [--ipurl <find_my_ip_web_service_url>]
  [--agent <my_user_agent>]
  [--interval <update_interval_secs>]
  [--recheck <force_update_after_secs>]
  [--timeout <network_timeout_secs>]
  [--tries <network_error_retries>]
  [--verbosity <msg_lvl_0-5>]
  [--daemon]  (daemonize in the background)
  [--once]    (update once)
  [--help]    (this message)

NOTE: There are security implications with using CLI arguments on multi-user
systems. If applicable, or you don't WANT TO USE THE CLI options, consider
manually setting these options inside this script.

NOTE2: Open this script in a text editor to get instructions for installing it
as a daemon.

ENDOFFILE
  exit 1;
}

sub logmsg($$) {
  my ($msg, $lvl) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,
  $yday,$isdst)=localtime(time);
  printf("%4d-%02d-%02d %02d:%02d:%02d  $msg\n",
  $year+1900,$mon+1,$mday,$hour,$min,$sec) if ($lvl <= $verbosity);
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
  my ($cmd, $post_data) = @_;
  my %full_post_data = ();
  my $response;
  $full_post_data{$_} = $post_data->{$_} foreach(keys %$post_data);
  $full_post_data{'key'} = $apikey;
  $full_post_data{'format'} = 'json';
  $full_post_data{'cmd'} = $cmd;
  $full_post_data{'unique_id'} = genUUID;

  #gets updated by dreamhost's response ( eval() )
  my $result1 = {'data' => 'failed_dreamhost_connect', 'result' => 'error'};

  for (my $i = 0; $i < $tries; $i++) {
    $response = $browser->post($dreamhost_url,\%full_post_data);
    last if ($response && $response->is_success);
    if ($response && $response->as_string =~ /Crypt::SSLeay/) {
      logmsg("E: You MUST install perl's Crypt::SSLeay library\n",1);
      logmsg("It's often available from linux repositories, or through",1);
      logmsg("Windows' ActivePerl/CPAN INSALLER\n",1);
      logmsg("The redhat/fedora package is called perl-Crypt-SSLeay",1);
      logmsg("The debian/ubuntu package is called libcrypt-ssleay-perl\n",1);
      logmsg("Otherwise you can manually get it at:",1);
      logmsg("http://search.cpan.org/~dland/Crypt-SSLeay-0.57/SSLeay.pm\n",1);
      $result1->{'data'} = 'install_crypt_ssleay';
      return $result1;
    }
    logmsg("W: network issues prevented contacting dreamhost (try ".($i+1).
    " of $tries)",3);
    sleep(8)
  }
  if ($response && $response->is_success) {
    $result1 = decode_json $response->content;
  } else {
    logmsg("E: network issues prevented contacting dreamhost during $cmd",2);
  }
  
  return $result1;
}

sub updateDns($) {
  my ($new_ip) = @_;
  logmsg("I: updating IP for $domain to $new_ip",4);
  if (defined($last_ip) && $new_ip eq $last_ip &&
      $recheck_secs + $last_check > time()) {
    logmsg("I: no dns update needed",4);
    return 0;
  }
  my $response;
  logmsg("I: checking DreamHost dns records",5);
  $response = sendDreamhostCmd('dns-list_records',{});
  unless ($response->{'result'} =~ /^success$/) {
    logmsg("E: ".$response->{'data'}.
      " encountered during dns-list_records",2);
    return 1;
  }
  undef $last_ip;
  foreach(@{$response->{'data'}}) {
    if (uc($_->{'type'}) eq 'A' && $_->{'record'} eq $domain) {
      $last_ip = $_->{'value'};
      if ($last_ip eq $new_ip) {
        logmsg("I: no dns update needed",4);
        return 0;
      }
      last;
    }
  }

  #make sure its not quitting time!
  return $rtrn_val if ($time_to_quit);

  #ok, we really do need up update it...
  if (defined($last_ip)) {
    logmsg("I: removing old DreamHost dns record for $domain",5);
    $response = sendDreamhostCmd('dns-remove_record',
      {'record' => $domain, 'type' => 'A', 'value' => $last_ip});
    unless ($response->{'result'} =~ /^success$/) {
      logmsg("E: ".$response->{'data'}.
        " encountered during dns-remove_record",2);
      return 1;
    }
  }
  
  logmsg("I: adding new DreamHost dns record for $domain",5);
  $response = sendDreamhostCmd('dns-add_record',
    {'record' => $domain, 'type' => 'A', 'value' => $new_ip});
  unless ($response->{'result'} =~ /^success$/) {
    logmsg("E: ".$response->{'data'}." encountered during dns-add_record",2);
    return 1;
  }
  $last_ip = $new_ip;
  $last_check = time();
  return 0;
}

sub downloadIP {
  my $response;
  my $rtrn;
  for(my $i = 0; $i < $tries; $i++) {
    $response = $browser->get($ipurl);
    last if ($response && $response->is_success);
    logmsg("E: network issues prevented contacting IP lookup service (try ".
      ($i+1)." of $tries)",3);
    sleep(8)
  }
  if ($response && $response->is_success) {
    if ($response->content =~ /.*?((\d{1,3}\.){3}\d{1,3})/) {
      $rtrn = $1;
      logmsg("I: IP lookup service returned your IP as $rtrn",5);
    } else {
      logmsg("E: IP lookup service returned bad data",1);
    }
  } else {
    logmsg("E: network issues prevented contacting IP lookup service",2);
  }
  return $rtrn;
}

sub getNICIP {
  my $ip;
  my ($cmd,$regex);
  my $os = $^O;

  switch($os) {
    #windows ipconfig
    case /MSWin32|Windows/i {
      $cmd = "ipconfig"; 
      $regex = '^\W*IP.*Address.*?((\d{1,3}\.){3}\d{1,3}).*$';
    }
    #linux ifconfig
    case /linux/i {
      $cmd = "ifconfig $nic"; 
      #redhat doesn't put ifconfig in $PATH for users
      my @paths = split(/:/,$ENV{'PATH'});
      push(@paths,"/sbin");
      push(@paths,"/usr/sbin");
      foreach (@paths) {
        if (-x "$_/ifconfig") {
          $cmd = "$_/ifconfig $nic";
          last;
        }
      }
      $regex = 'inet addr:\s*((\d{1,3}\.){3}\d{1,3})';
    }
    #Solaris/BSD ifconfig (should also be used in mac os)
    else {
      $cmd = "ifconfig $nic";
      $regex = '\Winet\s*((\d{1,3}\.){3}\d{1,3})';
    }
  }

  #check ip
  if (open IPCONF, "$cmd |") {
    while(<IPCONF>) {
      if ($_ =~ /$regex/i) {
        $ip = $1;
        last;
      }
    }
    if (close IPCONF) {
      if (defined($ip)) {
        logmsg("I: $cmd returned your IP as $ip",5);
      } else {
        logmsg("W: IP not found for NIC",2);
      }
    } else {
      if (defined($ip)) {
        logmsg("W: $cmd returned an error code $?",4);
      } else { #error and no ip
        logmsg("E: $cmd failed to find your NIC",1);
      }
    }
  } else {
    logmsg("E: can't run $cmd: $!",1);
  }
  return $ip;
}

sub runUpdateOnce {
  my $new_ip;
  if (defined($ip)) {
    $new_ip = $ip;
  } elsif (defined($nic)) {
    $new_ip = getNICIP;
  } else {
    $new_ip = downloadIP;
  }

  return $rtrn_val if ($time_to_quit);

  if (defined($new_ip)) {
    return updateDns $new_ip;
  } else {
    logmsg("E: no valid IP to attempt update",2);
    return 1;
  }
}

sub runLoopUpdate {
  my $time_wake;
  while(1) {
    $rtrn_val |= runUpdateOnce;
    return $rtrn_val if ($time_to_quit);

    logmsg("I: sleeping for $interval seconds",5);
    sleep($interval);
    return $rtrn_val if ($time_to_quit);
  }
}

sub handle_signals {
  $time_to_quit = 1;
  logmsg("I: caught signal to quit, please wait...",4);
}
######################## /FUNCTIONS #######################################

#parse command line args
for(my $i = 0; $i <= $#ARGV; $i++) {
  switch($ARGV[$i]) {
    case '--agent' {$agent = $ARGV[++$i];}
    case '--nic' {$nic = $ARGV[++$i];}
    case '--ipurl' {$ipurl = $ARGV[++$i];}
    case '--daemon' {$daemonize = 1;}
    case '--once' {$once = 1;}
    case '--ip' {$ip = $ARGV[++$i];}
    case '--apikey' {$apikey = $ARGV[++$i];}
    case '--verbosity' {$verbosity = $ARGV[++$i];}
    case '--interval' {$interval = $ARGV[++$i];}
    case '--recheck' {$recheck_secs = $ARGV[++$i];}
    case '--timeout' {$timeout = $ARGV[++$i];}
    case '--tries' {$tries = $ARGV[++$i];}
    case '--domain' {$domain = $ARGV[++$i];}
    case '--help' {usage();}
    else { usage("E: INVALID OPTION: ". $ARGV[$i]); }
  }
}

#check options
usage("E: invalid apikey")
    unless(defined($apikey) && !($apikey =~ /^\-\-/));
usage("E: invalid ipurl") unless (defined($ipurl) && $ipurl =~ /^https?:\/\//);
usage("E: invalid IP") if (defined($ip) && !($ip =~ /^(\d{1,3}\.){3}\d{1,3}$/));
usage("E: invalid timeout") unless(defined($timeout) && $timeout =~ /^\d+$/);
usage("E: invalid interval") unless(defined($interval) && $interval =~ /^\d+$/);
usage("E: invalid recheck")
    unless(defined($recheck_secs) && $recheck_secs =~ /^\d+$/);
usage("E: invalid tries") unless(defined($tries) && $tries =~ /^\d+$/);
usage("E: invalid domain") unless(defined($domain) && $domain =~ /\./);
usage("E: invalid verbosity")
    unless(defined($verbosity) && $verbosity =~ /^\d+$/);


#start program
$SIG{'INT'} = 'handle_signals';
$SIG{'TERM'} = 'handle_signals';
$SIG{'QUIT'} = 'handle_signals';

logmsg("DreamDNS Updater version $version\n",4);

$browser = LWP::UserAgent->new;
$browser->agent($agent) if (defined $agent);
#200KB is a big page, for plain text
$browser->max_size(200*1024);
$browser->timeout($timeout);

if ($daemonize) {
  my $pid = fork();
  if (!defined($pid)) {
    logmsg("Daemonize Failed: $!",0);
    exit 1;
  } elsif($pid == 0) {
    close STDERR;
    close STDOUT;
    chdir "/";
    if ($once) {
      exit runUpdateOnce();
    } else {
      exit runLoopUpdate();
    }
  } else {
    logmsg("I: daemon started with pid $pid, no more messages will be seen",4);
    logmsg("W: daemon is only doing one update, --once was used!",1)
                                 if($once);
    exit 0;
  }
} else {
  if ($once) {
    exit runUpdateOnce();
  } else {
    exit runLoopUpdate();
  }
}
