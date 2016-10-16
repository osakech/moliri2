#!/usr/bin/perl
 
#===============================================================================
#
#  FILE:  module.pl
#  
#  In diesem Skript werden Module installiert, die für Moliri gebraucht werden.
#  Dazu ist eine Internetverbindung notwendig. Zum installieren der Module wird
#  apt-get verwendet, was mit jedem Debian-basiertem Linux-System mitgeliefert 
#  wird. 
#
#===============================================================================

use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';    # Konsolenausgabe in Unicode
use Data::Dumper;
use English qw( -no_match_vars );
use APT;

my $apt = APT->new();

my %modules = (
    'perl-tk'                   => '^perl-tk$',
    'libxml-writer-perl'        => '^libxml-writer-perl$',
    'libtk-filedialog-perl '    => '^libtk-filedialog-perl$',
    'libopenoffice-oodoc-perl'  => '^libopenoffice-oodoc-perl$',
    'libimage-size-perl'        => '^libimage-size-perl$',
    'libarchive-zip-perl'       => '^libarchive-zip-perl$',
    'libxml-writer-perl'        => '^libxml-writer-perl$',
);

`clear`;
print "***********************************************************************\n"
  .   "*                         Moliri-Installation                         *\n"
  .   "***********************************************************************\n"
  .   "\n\n"
  .   "Dieses Skript überprüft ob alle benötigten Perl-Module installiert sind.\n"
  .   "\n"
  .   "Möchten Sie fortfahren?\n"
  .   "[j]a/[n]ein\t: ";

#---------------------------------------------------------------------------
#  Beuntzereingabe abfragen
#---------------------------------------------------------------------------
while (<ARGV>) {
    if ( $_ =~ /^j(a)?$/i ) {
        last;
    }
    elsif ( $_ =~ /^(\s*|n(ein)?)$/i ) {
        exit;
    }
}
my @installieren;

#my $install;
print "\n\nBitte haben Sie einen Moment Geduld : ";

#---------------------------------------------------------------------------
#  Testen ob alle notwendigen Module installiert sind
#---------------------------------------------------------------------------
foreach my $mod ( keys %modules ) {
    my $install = $apt->install( '-test', $modules{$mod} );
    if ( ${$install}{'intended'}{'installed'} ) {
        push @installieren, $mod;
        print '.';
    }
    else {
        print '.';
    }
}

#---------------------------------------------------------------------------
#  Sollten noch Module zu installieren sein,  Liste diese auf
#---------------------------------------------------------------------------
if ( scalar @installieren ) {
    print "\n\nFolgende Module müssen noch installiert werden:\n";
    foreach my $mod (@installieren) {
        print ' - ' . $mod . "\n";
    }

#---------------------------------------------------------------------------
#  Frage ob Benutzer die Modukle jetzt installieren möchte
#---------------------------------------------------------------------------
    print "\n\nSoll das Skript die Module jetzt für Sie installieren?\n"
      . "\nFür die Installation ist eine Internetverbindung notwendig\n\n"
      . "([j]a/[n]ein)\t: ";
    while (<ARGV>) {
        if ( $_ =~ /^j(a)?$/i ) {

#---------------------------------------------------------------------------
#  Überprüfe ob das Skript root-Rechte hat
#---------------------------------------------------------------------------
            if ( $UID eq '0' ) {
               # Wenn ja, installiere  die fehlenden Module
                foreach my $mod ( @installieren ) {
                    print "\n\nInstalliere Modul $mod ...";
                    my $install = $apt->install( $modules{$mod});
                    print "\nOK.";
                }
            }
            else {
                # Wenn nein, mache den Benutzer darauf aufmerksam
                print
                  "\n\nSie haben leider nicht die nötigen Rechte um Software\n"
                  . "zu installieren.";
                print "\n\nStarten sie das Skript mit dem Befehl: \n\nsudo installation.pl\n";
            }
            last;
        }
        elsif ( $_ =~ /^(\s*|n(ein)?)$/i ) {

#---------------------------------------------------------------------------
#  Wenn der Benutzer die Module nicht automatisch installieren will, baue
#  für Ihn den erforderlichen befehl zusammen
#---------------------------------------------------------------------------
            print "\n\nDie fehlenden Module können Sie auch ganz einfach\n"
              . "selber über die Linuxkonsole installieren. \nMit folgendem Befehl: \t\n\n"
              . 'sudo apt-get install ';
            print join ' ', @installieren;
            print "\n\n";
            exit;
        }
    }
}else{

#---------------------------------------------------------------------------
#  Alles OK
#---------------------------------------------------------------------------
    print "\n\nAlle benötigten Module bereits installiert\n";
}

