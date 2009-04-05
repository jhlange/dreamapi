@echo off
rem this is a DOSish bat file
rem In here you can specify the command line
rem arguments to DreamCSV, for ease of use
rem Or, so you can deligate email subscription
rem tasks to an office administrator/etc.

rem dreamhost login details
SET USERNAME=myemail@email.com
SET APIKEY=AAAAAAAA


rem list details
SET LIST=list1
SET DOMAIN=mydomain.com

rem io details

rem drag and drop the file to use on the .bat file
rem and it will be executed!

SET DHCMD=announcement_list-add_subscriber
SET DIRECTION=send

rem do the action
c:\Perl\bin\perl.exe "%~dp0\dreamcsv.pl" --username "%USERNAME%" --apikey "%APIKEY%" --cmd "%DHCMD%" --listname "%LIST%" --domain "%DOMAIN%" --%DIRECTION% %1

pause
