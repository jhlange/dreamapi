DreamDNS Updater and Other Bulk Updating scripts
=============================

## DreamDNS Updater ##
This script can be used to dynamically update DNS entries on dreamhost's nameservers to track a client machine's IP address.

This script has been in circulation since 2009.--It is believed by the dreamhost staff to have a good amount of use by 3rd parties.-- I just uploaded this to github on 11-16-2014, after several people emailed me about issues with it running under newer releases of perl.-- Two others have previously uploaded it to github and another has published a how-to blog including the script (as I have found through google). I have reached out to them to attempt to merge repositories and update their sources.

The default 'get my ip' service being used by the script is hosted by me and gets about 120 unique IP hits per day by the perl user agent. I would assume that a good number of the users of the script are also using the script's defaults.-- This might not entirely be the case because of a recent disruption that the service had.--I don't know how long it was down for, but changes made the host machine caused my non-standard cgi usage to break ( get_ip.pl was actually, originally, a c program http://www.joshlange.net/cgi/get_ip.c . I made it that way to prevent many short-lived perl interpreters from firing up on every web service call).

If you are interested in using this script there are instuctions on how to do so in the index.html of the dreamapi folder, or at http://www.joshlange.net/dreamapi/dreamdns .

## The Other Scripts ##
The two other scripts in this repository are tuned for bulk updates to the dreamhost API. I do not believe that they are used by many people. You can find instructions on their use on their respective index.html pages or at http://www.joshlange.net/dreamapi .

## Disclaimer ##

These scripts come with absolutely no warranty. None of the contributors will be responsible for damages. Please read the license agreement for the standard lingo.
