#!/usr/bin/perl
#
# Authors:  Michael McNamara
#			Karol Perkowski
#
# Filename: switchtftpbackup.pl
#
# Purpose:  Backup (via TFTP) switch configuration.
#
# Supported Switches:
# 	    - Nortel ERS 8600
# 	    - Nortel ERS 1600
# 	    - Nortel ERS 5500
# 	    - Nortel ES 470
# 	    - Nortel ES 460
# 	    - Nortel ES 450
# 	    - HP GbE2 Switch Blade (OEM'd from Blade Networks (now IBM))
# 	    - HP GbE2c Switch Blade (OEM'd from Blade Networks (now IBM))
#
# Requirements:
#           - Net-SNMP
#           - Net-SNMP Perl Module
#           - SNMP MIBS

# Load Modules
use strict;
use SNMP;

# Declare constants
use constant DEBUG      => 1;           # DEBUG settings
use constant RETRIES    => 3;           # SNMP retries
use constant TIMEOUT    => 1000000;     # SNMP timeout, in microseconds
use constant SNMPVER    => 2;           # SNMP version

$SNMP::verbose = DEBUG;
$SNMP::use_enums = 1;
$SNMP::use_sprint_value = 1;
&SNMP::initMib();
&SNMP::loadModules('ALL');

our $TFTPHOST = "127.0.0.1";
our $community = "private";
our $switchlist = "target.switches";	# list of switches
our @devices;
our $snmphost;
our $filename;

our $sysDescr;
our $sysObjectID;
our $sysUpTime;
our $sysContact;
our $sysName;
our $sysLocation;

our $sdate = `date`;

our $PAUSE = 2;

our $MAILTO = 'nulladmin@null.com';							# MAILTO
our $MAILFROM = 'nullbackupadmin@null.com';					# MAILFROM
our $MAILSUBJECT = "Network Switch Configuration Backups";	# MAILSUBJECT

### MAIN PROGRAM ##################################################
{
   # Load list of switches to backup
   &load_switches;

   # Start the HTML report
   &start_html_report;

   # Perform the TFTP backup
   &call_tftp_backup;

   # Finish the HTML report 
   &finish_html_report;

}
### END MAIN PROGRAM #################################################


##########################################################################
# Subroutine load_switches
# Purpose: load the list of switches from a file into an array
##########################################################################
sub load_switches {

   # Open file for input
   open(SWITCHLIST, "<$switchlist"); 

   # Walk through data file
   while (<SWITCHLIST>) {

      # Skip blank lines
      next if (/^\n$/);
      # Skip comments
      next if (/^#/);

      #print "DEBUG: adding $_ to our list of devices \n" if ($DEBUG);

      # Remove the CR/LF
      chomp;

      push (@devices, $_);

   } #end while

   close(SWITCHLIST);

   return 1;

} #end sub load_switches


##########################################################################
# Subroutine check_filename
# Purpose: make sure the filename exists with the proper permissions on
#          the TFTP server (for the local box)
##########################################################################
sub check_filename {

   # Declare Local Variables
   my $temp_filename = shift;

   print "DEBUG: I'm touching the following file /tftpboot/$temp_filename\n" if (DEBUG);
   `touch /tftpboot/$temp_filename`;
   print "DEBUG: I'm chaning the permissions on /tftpboot/$temp_filename\n" if (DEBUG);
   `chmod og-r+w /tftpboot/$temp_filename`;

   return 1;

} #end sub check_filename;


###########################################################################
# Subroutine tftp_filename
# Purpose: compose the TFTP filename from the FQDN of the switch
###########################################################################
sub tftp_filename {

   #Declare Local Variables
   my $host = shift;
   my $stemp;

   $stemp = $host;
   $stemp = $stemp.".backup";

   print "DEBUG: the filename for $host will be $stemp\n" if (DEBUG);

   return $stemp;

} #end sub tftp_filename

##########################################################################
# Subroutine call_tftp_backup
# Purpose: determine which subroutine we should call and then execute
##########################################################################
sub call_tftp_backup {

   foreach $snmphost (@devices) {

      $snmphost =~ s/\n//g;

      #print "DEBUG: starting loop with snmphost = $snmphost\n" if (DEBUG);

      $filename = &tftp_filename($snmphost);

      &check_filename($filename);

      if (&grab_snmpsystem == 99) {
         next;
      }

      print "DEBUG: sysObjectID = $sysObjectID ($snmphost)\n";

      if ( ($sysObjectID eq "rcA8610co") ||
           ($sysObjectID eq "rcA8610")   ||
           ($sysObjectID eq "rcA8606") 	 ||
           ($sysObjectID eq "rcA1648") ) {
         #Ethernet Routing Switch 8600/1600
         &passport_tftp_config;
      } elsif (($sysObjectID eq "sreg-EthernetRoutingSwitch5530-24TFD") ||
               ($sysObjectID eq "sreg-BayStack5520-48T-PWR") 			||
               ($sysObjectID eq "sreg-BayStack5520-24T-PWR") 			||
               ($sysObjectID eq "sreg-BayStack5510-48T-ethSwitchNMM")	||
               ($sysObjectID eq "sreg-BayStack5510-24T-ethSwitchNMM")) {
         #BayStack 5500 Series Switch
         &baystack_tftp_config;
	 &baystack_tftp_config_ascii;
      } elsif (($sysObjectID eq "sreg-BayStack470-48T-PWR-ethSwitchNMM") || 
               ($sysObjectID eq "sreg-BayStack470-48T-ethSwitchNMM") 	 || 
               ($sysObjectID eq "sreg-BayStack470-24T-ethSwitchNMM")) {
         #BayStack 470 Series Switch
         &baystack_tftp_config;
	 &baystack_tftp_config_ascii;
      } elsif ($sysObjectID eq "sreg-BayStack460-24T-PWR-ethSwitchNMM") {
         #BayStack 460 Switch 24T PWR
         &baystack_tftp_config;
	 &baystack_tftp_config_ascii;
      } elsif ($sysObjectID eq "sreg-BayStack450-ethSwitchNMM") {
         #BayStack 450 Switch 12/24T
         &baystack_tftp_config;
	 &baystack_tftp_config_ascii;
      } elsif ($sysObjectID eq "sreg-BayStack350-24T-ethSwitchNMM") {
         #BayStack 350 Switch 12/24T
         &baystack_tftp_config;
	 &baystack_tftp_config_ascii;
      } elsif ($sysObjectID eq "sreg-BPS2000-24T-ethSwitchNMM") {
         #Business Policy Switch
         &baystack_tftp_config;
	 &baystack_tftp_config_ascii;
      } elsif ($sysObjectID eq "hpProLiant-GbE2c-InterconnectSwitch") {
         #HP Gbe2c Switch Blades
         &hpgbe2c_tftp_config;
      } elsif ($sysObjectID eq "hpProLiant-p-GbE2-InterconnectSwitch") {
         #HP Gbe2 Switch Blades
         &hpgbe2_tftp_config;
      } elsif ($sysObjectID eq "ws") {
         # Motorola/Symbol WS5100 Wireless LAN Switch v3.x Software
         &ws5100_config;
      } else {
         print "ERROR: $snmphost ~ $sysObjectID is not TFTP compatible skipping...\n";
         print SENDMAIL "<B>ERROR:</B>$snmphost ~ $sysObjectID is not tftp compatible skipping...<BR>\n";
      }

   } #end foreach $snmphost

   return 1;

} #end sub call_tftp_backup


############################################################################
# Subroutine baystack_tftp_config
# Purpose: use SNMP to instruct switches to TFTP upload their configuration
# file to the central TFTP server
############################################################################
sub baystack_tftp_config {

   # Declare Local Variables
   my $setresult;

   $filename = $snmphost.".bin";

   my $sess = new SNMP::Session (  DestHost  => $snmphost, 
		      		   Community => $community,
				   Version   => SNMPVER );

   my $vars = new SNMP::VarList(
			['s5AgMyIfLdSvrAddr', 1, "$TFTPHOST",],
			['s5AgMyIfCfgFname', 1, $filename,] );
 
   my $go = new SNMP::VarList(
			['s5AgInfoFileAction', 0, 4,] );

   # Set TFTP source and destination strings
   $setresult = $sess->set($vars);
   if ( $sess->{ErrorStr} ) {
      print "ERROR: {BayStack} problem setting the TFTP parameters for $snmphost\n";
      print "ERROR: {BayStack} sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   # Start TFTP copy
   $setresult = $sess->set($go);
   if ( $sess->{ErrorStr} ) {
      print "ERROR: {BayStack} problem setting the TFTP action bit for $snmphost\n";
      print "ERROR: {BayStack} sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   # Pause while the TFTP copy completes
   sleep $PAUSE;

   # Check to see if the TFTP copy completed
   $setresult = $sess->get('s5AgInfoFileStatus.0');
   if ( $sess->{ErrorStr} ) {
      print "ERROR: problem checking the TFTP result for $snmphost\n";
      print "ERROR: sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   # If TFTP failed output error message
   if ($setresult ne "success") {
	while ($setresult eq "inProgress") {
	   print "DEBUG: config upload status = $setresult (waiting)\n" if (DEBUG);
	   sleep $PAUSE;
           $setresult = $sess->get('s5AgInfoFileStatus.0');
	} #end while
   } #end if $test ne "success"

   # If the upload command failed let's try again
   if ($setresult eq "fail") {

      print "DEBUG: initial command returned $setresult\n" if (DEBUG);
      print "DEBUG: lets try the upload command again\n" if (DEBUG);

      # Let's pause here for a few seconds since the previous command failed
      sleep $PAUSE;

      # Start TFTP copy
      $setresult = $sess->set($go);
      if ( $sess->{ErrorStr} ) {
         print "ERROR: problem setting the TFTP action bit for $snmphost\n";
         print "ERROR: sess->{ErrorStr} = $sess->{ErrorStr}\n";
      }

      # Pause while the TFTP copy completes
      sleep $PAUSE;

      # Check to see if the TFTP copy completed
      $setresult = $sess->get('s5AgInfoFileStatus.0');
         if ( $sess->{ErrorStr} ) {
            print "ERROR: problem checking the TFTP result for $snmphost\n";
            print "ERROR: sess->{ErrorStr} = $sess->{ErrorStr}\n";
      }

      # If TFTP failed output error message
      if ($setresult ne "success") {
         while ($setresult eq "inProgress") {
            print "DEBUG: config upload status = $setresult (waiting)\n" if (DEBUG);
            sleep $PAUSE;
            $setresult = $sess->get('s5AgInfoFileStatus.0');
         } #end while
      } #end if 
   } #end if

   if ($setresult eq "fail") {
      print "DEBUG: $snmphost config upload has *FAILED*!\n";
      print SENDMAIL "<FONT COLOR=FF0000><B>ERROR:</B>$snmphost config upload has *FAILED*!</FONT><BR>\n";
   } elsif ($setresult eq "success") {
      print SENDMAIL "$snmphost was successful<BR>\n";
      print "DEBUG: $snmphost was successful\n";
   } else {
      print "DEBUG: unknown error return = $setresult\n" if (DEBUG);
   } #end if

   print "DEBUG: upload config file results = $setresult\n" if (DEBUG);

   return 1;

} #end sub baystack_tftp_config

############################################################################
# Subroutine passport_tftp_config
#
# Purpose: use SNMP to instruct Passport 8600 switches to TFTP upload their
# configuration file to the central TFTP server
############################################################################
sub passport_tftp_config {

   my $test;

   my $sess = new SNMP::Session (  DestHost  => $snmphost,
                                   Community => $community,
                                   Version   => SNMPVER );

   my $vars = new SNMP::VarList(
         ['rc2kCopyFileSource', 0, "/flash/config.cfg",],
         ['rc2kCopyFileDestination', 0, "$TFTPHOST:$filename",] );

   my $go = new SNMP::VarList(
         ['rc2kCopyFileAction', 0, 2,] );

   # Set TFTP source and destination strings
   $test = $sess->set($vars);

   # Start TFTP copy
   $test = $sess->set($go);

   # Pause while the TFTP copy completes
   sleep $PAUSE;

   # Check to see if the TFTP copy completed
   $test = $sess->get('rc2kCopyFileResult.0');

   # If TFTP failed output error message
   if ($test ne "success") {
        while ($test eq "inProgress") {
           print "DEBUG: config upload status = $test (waiting)\n" if (DEBUG);
           sleep $PAUSE;
           $test = $sess->get('s5AgInfoFileStatus.0');
        } #end while
   } #end if
   if ($test eq "fail") {
      print "ERROR: $snmphost config upload has *FAILED*!\n";
      print SENDMAIL "<FONT COLOR=FF0000><B>ERROR:</B>$snmphost config upload has *FAILED*!</FONT><BR>\n";
   } elsif ($test eq "success") {
      print SENDMAIL "$snmphost was successful<BR>\n";
      print "DEBUG: $snmphost was successful\n";
   } #end if

   print "DEBUG: upload config file results = $test\n" if (DEBUG);

   return 1;

} #end sub passport_tftp_config

############################################################################
# Subroutine grab_snmpsystem 
#
# Purpose: use SNMP to identify the type of switch we'll be working with 
############################################################################
sub grab_snmpsystem {

   # Declare Local Variables
   my @vals;

   my $sess = new SNMP::Session (  DestHost   =>  $snmphost,
                                   Community  =>  $community,
                                   Version    =>  SNMPVER );

   my $vars = new SNMP::VarList(
                                ['sysDescr', 0],
                                ['sysObjectID', 0],
                                ['sysUpTime', 0],
                                ['sysContact', 0],
                                ['sysName', 0],
                                ['sysLocation', 0] );

   print "DEBUG: snmphost = $snmphost and community = $community\n" if (DEBUG);

   @vals = $sess->get($vars);   # retreive SNMP information
   if ( $sess->{ErrorStr} ) {
      print "ERROR: retreiving system for $snmphost\n";
      print "ERROR: sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   if ($vals[0] eq "") {
        print "ERROR: Unable to poll the switch $snmphost. !!!\n";
        print SENDMAIL "<B>ERROR:</B>Unable to poll the switch $snmphost. !!!<BR>\n";
        return 99;
   }

   $sysDescr = $vals[0];
   $sysObjectID = $vals[1];
   $sysUpTime = $vals[2];
   $sysContact = $vals[3];
   $sysName = $vals[4];
   $sysLocation = $vals[5];

   $sysObjectID =~ s/.1.3.6.1.4.1/enterprises/;
   print "DEBUG: $snmphost sysObjectID=$sysObjectID \n" if (DEBUG);

   return 1;

}; #end sub grab_snmpsystem ########################################

############################################################################
# Subroutine passport1600_tftp_config
#
# Purpose: use SNMP to instruct Passport 1600 switches to TFTP upload their
# configuration file to the central TFTP server. This subroutine is only
# applicable to ERS 1600 switches runnning release v1.x. Any ERS 1600 series
# switches running v2.x conform to the same SNMP MIBS as the ERS 8600 switch
############################################################################
sub passport1600_tftp_config {

   my $test;

   my $sess = new SNMP::Session (	DestHost  => $snmphost,
                                        Community => $community,
                                        Version   => SNMPVER );
   my $vars = new SNMP::VarList(
       ['swL2DevCtrlUpDownloadImageSourceAddr', 0, "$TFTPHOST",],
       #['s5AgSysBinaryConfigFilename', 0, $filename,] );
       ['swL2DevCtrlUpDownloadImageFileName', 0, $filename,] );

   my $go = new SNMP::VarList(
       ['swL2DevCtrlUpDownloadImage', 0, 2,] );

   # Set TFTP source and destination strings
   $test = $sess->set($vars);
   if ( $sess->{ErrorStr} ) {
      print "DEBUG: sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   # Start TFTP copy
   $test = $sess->set($go);
   if ( $sess->{ErrorStr} ) {
      print "DEBUG: sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   # Pause while the TFTP copy completes
   print "DEBUG: Sleeping 3 seconds while TFTP backup occurs... \n" if (DEBUG);
   sleep $PAUSE;

   # Check to see if the TFTP copy completed
   $test = $sess->get('swL2DevCtrlUpDownloadState.0');
   if ( $sess->{ErrorStr} ) {
      print "DEBUG: sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }
   print "DEBUG: swL2DevCtrlUpDownloadState = $test \n" if (DEBUG);

   # If TFTP failed output error message
   if ($test ne "complete") {
        while ($test eq "in-process") {
           print "DEBUG: config upload status = $test (waiting)\n" if (DEBUG);
           sleep $PAUSE;
           $test = $sess->get('swL2DevCtrlUpDownloadState.0');
           print "DEBUG: swL2DevCtrlUpDownloadState = $test \n" if (DEBUG);
        }
   };

   if (($test ne "complete") & ($test ne "other"))  {
      print "DEBUG: result <> complete and <> other = $test \n" if (DEBUG);
      print "ERROR: $snmphost config upload has *FAILED*!\n";
      print SENDMAIL "<FONT COLOR=FF0000><B>ERROR:</B>$snmphost config upload has *FAILED*!</FONT><BR>\n";
   } elsif ($test eq "complete") {
      print SENDMAIL "$snmphost was successful<BR>\n";
      print "$snmphost was successful\n";
   }
   print "DEBUG: upload config file results = $test\n" if (DEBUG);

   return 1;

} #end sub passoprt1600_tftp_config

###########################################################################
# Subroutine strart_html_report
#
# Purpose: open handle to SENDMAIL and create HTML email report 
###########################################################################
sub start_html_report {

   open(SENDMAIL, "| /usr/lib/sendmail $MAILTO") || die;

   print(SENDMAIL "From: $MAILFROM\nTo: $MAILTO\nSubject: $MAILSUBJECT\n");
   print(SENDMAIL "MIME-Version: 1.0\n");
   print(SENDMAIL "Content-Type: text/html; charset=us-ascii\n\n");
  
   print SENDMAIL << "EOF";
<p><h1>Network Switch Backup Report.</h1>
Date : $sdate
<p>
This is an automated message concerning the status of the automated switch configuration backups for all the ethernet switch.
<p>
Procedures for recovering the switch configurations can be found at this location<BR>
<a href="http://localhost/switch_recovery.pdf">Switch Recover Guide</a>
<p>
The following is a list of the switches and their backup status.
<p>
EOF

return 1;
} #end sub start_html_report 

############################################################################
# Subroutine finish_html_report
#
# Purpose: close out the HTML email report
############################################################################
sub finish_html_report {

   print SENDMAIL <<EOF;
EOF

   close(SENDMAIL);

   return 1;
} #end sub finish_html_report

############################################################################
# Subroutine hpgbe2_tftp_config
#
# Purpose: use SNMP to instruct HP GbE2 Switch Blades to TFTP upload their
# configuration file to the central TFTP server
############################################################################
sub hpgbe2_tftp_config {

   my $setresult;

   my $sess = new SNMP::Session (  DestHost  => $snmphost,
                                   Community => $community,
                                   Version   => SNMPVER );

   my $vars = new SNMP::VarList(
         ['agTftpServer', 0, "$TFTPHOST",],
         ['agTftpCfgFileName', 0, "$filename",] );

   my $go = new SNMP::VarList(
         ['agTftpAction', 0, 4,] );

   # Set TFTP source and destination strings
   my $test = $sess->set($vars);

   # Start TFTP copy
   $test = $sess->set($go);

   # Pause while the TFTP copy completes
   sleep $PAUSE;

   # Check to see if the TFTP copy completed
   $test = $sess->get('agTftpLastActionStatus.0');

   # If TFTP failed output error message
   if ($test =~ /Success/) {
      print SENDMAIL "$snmphost was successful<BR>\n";
      print "DEBUG: $snmphost was successful\n";
   } else {
      print "ERROR: $snmphost config upload *FAILED*!\n";
      print SENDMAIL "<FONT COLOR=FF0000><B>ERROR:</B>$snmphost config upload *FAILED*!</FONT><BR>\n";
   } #end if

   print "DEBUG: upload config file results = $test\n" if (DEBUG);

   return 0;

} # end sub hpgbe2_tftp_config


############################################################################
# Subroutine hpgbe2c_tftp_config
#
# Purpose: use SNMP to instruct HP GbE2 Switch Blades to TFTP upload their
# configuration file to the central TFTP server
############################################################################
sub hpgbe2c_tftp_config {

   my $setresult;

   my $sess = new SNMP::Session (  DestHost  => $snmphost,
                                   Community => $community,
                                   Version   => SNMPVER );

   my $vars = new SNMP::VarList(
         ['agTransferServer', 0, "$TFTPHOST",],
         ['agTransferCfgFileName', 0, "$filename",] );

   my $go = new SNMP::VarList(
         ['agTransferAction', 0, 4,] );

   # Set TFTP source and destination strings
   my $test = $sess->set($vars);

   # Start TFTP copy
   $test = $sess->set($go);

   # Pause while the TFTP copy completes
   sleep $PAUSE;

   # Check to see if the TFTP copy completed
   $test = $sess->get('agTransferLastActionStatus.0');

   # If TFTP failed output error message
   if ($test =~ /Success/) {
      print SENDMAIL "$snmphost was successful<br>";
      print "DEBUG: $snmphost was successful\n";
   } else {
      print "ERROR: $snmphost config upload has *FAILED*!\n";
      print SENDMAIL "<font color=FF0000><b>ERROR:</b>$snmphost config upload has *FAILED*!</font><br>";
   } #end if

   print "DEBUG: upload config file results = $test\n" if (DEBUG);


   return 0;

} # end sub hpgbe2c_tftp_config

############################################################################
# Subroutine baystack_tftp_config_ascii
#
# Purpose: use SNMP to instruct BayStack switches to TFTP upload their
# ASCII configuration file to the central TFTP server
############################################################################
sub baystack_tftp_config_ascii {

   # Declare Local Variables
   my $setresult;

   $filename = $snmphost.".ascii";

   my $sess = new SNMP::Session (  DestHost  => $snmphost,
                                   Community => $community,
                                   Version   => SNMPVER );

   my $vars = new SNMP::VarList(
                        ['s5AgSysTftpServerAddress', 0, $TFTPHOST,],
                        ['s5AgSysAsciiConfigFilename', 0, $filename,] );

   my $go = new SNMP::VarList(
                        ['.1.3.6.1.4.1.45.1.6.4.4.19', 0, 4, 'INTEGER'] );

   &check_filename($filename);

   # Set TFTP source and destination strings
   $setresult = $sess->set($vars);
   if ( $sess->{ErrorStr} ) {
      print "ERROR: {BayStack} problem setting the TFTP parameters (TFTP IP, FILENAME) for $snmphost\n";
      print "ERROR: {BayStack} sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   # Start TFTP copy
   $setresult = $sess->set($go);
   if ( $sess->{ErrorStr} ) {
      print "ERROR: {BayStack} problem setting the TFTP action bit for $snmphost\n";
      print "ERROR: {BayStack} sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   # Pause while the TFTP copy completes
   sleep $PAUSE;

   # Check to see if the TFTP copy completed
   $setresult = $sess->get('.1.3.6.1.4.1.45.1.6.4.4.19.0');
   if ( $sess->{ErrorStr} ) {
      print "ERROR: problem checking the TFTP result for $snmphost\n";
      print "ERROR: sess->{ErrorStr} = $sess->{ErrorStr}\n";
   }

   # If TFTP failed output error message
   if ($setresult != 1) {
        while ($setresult == 2) {
           print "DEBUG: config upload status = $setresult (waiting)\n" if (DEBUG);
           sleep $PAUSE;
           $setresult = $sess->get('.1.3.6.1.4.1.45.1.6.4.4.19.0');
        } #end while
   } #end if $test ne "success"

   # If the upload command failed let's try again
   if ($setresult == 3) {

      print "DEBUG: initial command returned $setresult\n" if (DEBUG);
      print "DEBUG: lets try the upload command again\n" if (DEBUG);

      # Let's pause here for a few seconds since the previous command failed
      sleep $PAUSE;

      # Start TFTP copy
      $setresult = $sess->set($go);
      if ( $sess->{ErrorStr} ) {
         print "ERROR: problem setting the TFTP action bit for $snmphost\n";
         print "ERROR: sess->{ErrorStr} = $sess->{ErrorStr}\n";
      }

      # Pause while the TFTP copy completes
      sleep $PAUSE;

      # Check to see if the TFTP copy completed
      $setresult = $sess->get('.1.3.6.1.4.1.45.1.6.4.4.19.0');
         if ( $sess->{ErrorStr} ) {
            print "ERROR: problem checking the TFTP result for $snmphost\n";
            print "ERROR: sess->{ErrorStr} = $sess->{ErrorStr}\n";
      }

      # If TFTP failed output error message
      if ($setresult != 1) {
         while ($setresult == 2) {
            print "DEBUG: config upload status = $setresult (waiting)\n" if (DEBUG);
            sleep $PAUSE;
            $setresult = $sess->get('.1.3.6.1.4.1.45.1.6.4.4.19.0');
         } #end while
      } #end if
   } #end if

   if ($setresult != 1) {
      print "DEBUG: $snmphost config upload has *FAILED*!\n";
      print SENDMAIL "ERROR:$snmphost config (ASCII) upload has *FAILED*!<br>\n";
   } elsif ($setresult == 1) {
      print SENDMAIL "$snmphost was successful (ASCII)<br>\n";
      print "DEBUG: $snmphost was successful (ASCII)\n";
   } else {
      print "DEBUG: unknown error return = $setresult (ASCII)\n" if (DEBUG);
   } #end if

   print "DEBUG: upload config file results = $setresult (ASCII)\n" if (DEBUG);

   return 1;

} #end sub baystack_tftp_config_ascii