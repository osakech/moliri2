#!/usr/bin/perl

#-------------------------------------------------------------------------------
#
# File: moliri2_verwaltung.pl
#
#     Diese Datei ist die Oberfläche der Pflichtenheftverwaltung.
#     Mann kann Pflichtenhefte anlegen, bearbeiten, löschen und exportieren.
#     Der Export erfolgt in den Formaten ODT und TXT. Zum Bearbeiten des
#     Pflichtenhefts wird <pflichtenheft_laden> aufgerufen, die Bearbeitung findet in
#     <moliri2.pl> statt.
#
#
#     Zum Ausführen des Programms müssen folgende Module installiert sein.
#     - Tk                 -- <http://search.cpan.org/~srezic/Tk-804.028/>
#     - Image::Size        -- <http://search.cpan.org/~rjray/Image-Size-3.220/>
#     - OpenOffice::OODoc  -- <http://search.cpan.org/~jmgdoc/OpenOffice-OODoc-2.112/>
#     - XML::LibXML        -- <http://search.cpan.org/~pajas/XML-LibXML-1.70/>
#     - XML::Writer        -- <http://search.cpan.org/~josephw/XML-Writer-0.605/>
#     - File::HomeDir      -- <http://search.cpan.org/~adamk/File-HomeDir-0.86/>
#     - Archive::Zip       -- <http://search.cpan.org/~adamk/Archive-Zip-1.30/>
#
#
#  >Autor:       Alexandros Kechagias (Alexandros.Kechagias@gmx.de)
#  >Firma:       Fachhochschule Südwestfalen
#  >Version:     1.0
#  >Erstellt am: 18.10.2010 17:19:05
#  >Revision:    0.2
#
#-------------------------------------------------------------------------------

use strict;
use warnings;
use utf8;

#use Carp;
use English qw( -no_match_vars );
binmode STDOUT, ':utf8';    # Konsolenausgabe in Unicode
use Readonly;

use Cwd;
use lib Cwd::cwd() . '/lib';    # /lib-Ordner einbinden
use Tk;
use Tk::Tree;
use Tk::Photo;
use Tk::JPEG;
use Tk::PNG;
use Tk::Spinbox;
use Tk::FileDialog;
use Tk::Pane;
use Tk::NoteBook;               # Tabulatoren
use File::HomeDir;
use File::Find;
use File::Path 'rmtree';
use Data::Dumper;
use Encode;
use ComboEntry;                 # Dropdown Menü
use MoliriCFG;
use MoliriXML;
use MoliriHistory;
use MoliriMLR;
use MoliriODT;
use MoliriTXT;

print "Skriptname:\t$PROGRAM_NAME\n";
print "Perl:\t\t$PERL_VERSION\n";
print "Tk:\t\t$Tk::VERSION\n";

my $mw = MainWindow->new();

#---------------------------------------------------------------------------
#  About: Globalle Widget-optionen setzen
# zB.: $mw->optionAdd( '*Entry.background', 'snow1' );
# Setzt für alle Tk-Objekte vom Typ Entry die Option auf backgound auf 'snow1'
#---------------------------------------------------------------------------
$mw->optionAdd( '*Entry.background',      'snow1' );
$mw->optionAdd( '*Text.background',       'snow1' );
$mw->optionAdd( '*font',                  'Helvetica -12' );
$mw->optionAdd( '*MatchEntry.background', 'snow1' );
$mw->optionAdd( '*Tree.background',       'snow1' );
$mw->optionAdd( '*ComboEntry.background', 'snow1' );
$mw->optionAdd( '*borderWidth',           '1' );
$mw->optionAdd( '*Menu.tearOff',          '0' );

# Variable: $konfiguration
#
# Erhält nach dem Start des Programms durch <lade_konfig>
# eine Hash-Referenz auf die Konfigurationseinstellungen.
# - rschreib -> Rechtschreibprüfung
# - azeit    -> Intervall des automatischen Speicherns in Minuten
# - aan      -> Autoamtisches Speichern aktiviert ja/nein-1/0
# - sordner  -> Sicherungsordner
# - aordner  -> Arbeitsordner
#
# Dumperausgabe:
# >$VAR1 = {
# >         'rschreib' => '0',
# >         'azeit' => '1',
# >         'aan' => '0',
# >         'sordner' => '/home/alexandros/',
# >         'aordner' => '/home/alexandros/Desktop/moliri-pflichtenhefte'
# >};
#

my $konfiguration;

# setze Titel des Pflichtenheftes
$mw->title('Moliri - Verwaltung');

# setze Fenstergröße auf 800x640
Readonly my $MW_WIDTH  => 800;
Readonly my $MW_HEIGHT => 640;
$mw->geometry( $MW_WIDTH . q{x} . $MW_HEIGHT );

# Program-Icon setzen
my $icon = $mw->Photo( -file => 'img/mu.png' );
$mw->iconimage($icon);

my $EMPTY = q{};

# Variable: %pfade
#
# Enthält alle Pfade und Ordner in einem Hash, wird gefüllt durch
# <baum_aktualisieren>. Dieser Hash wird dazu benutzt um anhand der Keys
# die vollständigen Pfade der Pflichtenhefte herauszufinden. Dies Keys werden
# in diesem Programm zur Identifizierung der Pflichtenhefte benutzt.
# Siehe <pflichtenheft_laden>. Einträge mit dem Wert 'ordner' sind die
# Titel der Pflichtenhe und auf dem Dateisystem Ordner
#
# Dumperausgabe:
# ungerade Zahlen sind keys / gerade Zahlen sind Values
#
# >$VAR1 = 'Testheft/1.0.xml';
# >$VAR2 = '/home/alexandros/Desktop/moliri-pflichtenhefte/Testheft/1.0.xml';
# >$VAR3 = 'moliri2/2.0.xml';
# >$VAR4 = '/home/alexandros/Desktop/moliri-pflichtenhefte/moliri2/2.0.xml';
# >$VAR5 = 'Testheft/3.0.xml';
# >$VAR6 = '/home/alexandros/Desktop/moliri-pflichtenhefte/Testheft/3.0.xml';
# >$VAR7 = 'Testheft/2.0.xml';
# >$VAR8 = '/home/alexandros/Desktop/moliri-pflichtenhefte/Testheft/2.0.xml';
# >$VAR9 = 'moliri2/3.0.xml';
# >$VAR10 = '/home/alexandros/Desktop/moliri-pflichtenhefte/moliri2/3.0.xml';
# >$VAR11 = 'moliri2/1.0.xml';
# >$VAR12 = '/home/alexandros/Desktop/moliri-pflichtenhefte/moliri2/1.0.xml';
# >$VAR13 = 'moliri2';
# >$VAR14 = 'ordner';
# >$VAR15 = 'Testheft';
# >$VAR16 = 'ordner';
my %pfade;

#--------------------------------------------------------------------------
#  About: Fenster mittig positionieren
#
# Setzt die obere linke Ecke des Programmfesters so,  dass das Programm mittig
# auf dem Desktop erscheint.
# Es wird dazu die Mitte des Desktops in waagerechter und senkrechter Richung
# ermittelt
# - $screen_width / 2 und $screen_height / 2
#
# und anschließend die Mitte der Applikation
#
# - $mw_width / 2 und $mw_height / 2
#
#--------------------------------------------------------------------------

Readonly my $SCREEN_HEIGHT => $mw->screenheight();
Readonly my $SCREEN_WIDTH  => $mw->screenwidth();

# Fenster mittig positionieren
$mw->geometry( q{+}
      . int( $SCREEN_WIDTH / 2 - $MW_WIDTH / 2 ) . q{+}
      . int( $SCREEN_HEIGHT / 2 - $MW_HEIGHT / 2 ) );

#---------------------------------------------------------------------------
#  Variables: Icons
# Enthalten die Bilder die im Programm benutzt werden
#
# $pic_neu       - Datei -> *Neu*
# $pic_history   - Datei -> *History*
# $pic_exit      - Datei -> *Beenden* und alle Buttons zum Abbrechen
# $pic_delete    - Datei-> *Löschen*
# $pic_import    - Datei -> *Laden*
# $pic_export    - Datei -> *Speichern*
# $pic_web       - Datei -> *Webserver*
# $pic_web_up    - Datei -> Webserver -> *Laden*
# $pic_web_down  - Datei -> Webserver -> *Sichern*
# $pic_conf      - Konfiguration -> *Programm*
# $pic_wartung   - Konfiguration -> *Wartung*
# $pic_oeffne_db - Konfiguration -> *Webserver*
# $pic_tex       - Export -> *LaTeX*
# $pic_text      - Export -> *Text*
# $pic_odf       - Export -> *ODT*
# $pic_ueber     - Hilfe -> *Version*
#
# $pic_oeffne    - Überall wo etwas geöffnet wird
# $pic_ok        - Alle OK-Buttons
#---------------------------------------------------------------------------
my $pic_neu       = $mw->Photo( -file => 'img/16x16/document-new-5.png' );
my $pic_oeffne    = $mw->Photo( -file => 'img/16x16/document-open-folder.png' );
my $pic_oeffne_db = $mw->Photo( -file => 'img/16x16/document-open-remote.png' );
my $pic_exit      = $mw->Photo( -file => 'img/16x16/application-exit-2.png' );
my $pic_ueber     = $mw->Photo( -file => 'img/16x16/help-about.png' );
my $pic_delete    = $mw->Photo( -file => 'img/16x16/edit-delete-5.png' );
my $pic_ok        = $mw->Photo( -file => 'img/16x16/dialog-ok.png' );
my $pic_history   = $mw->Photo( -file => 'img/16x16/edit-history-3.png' );
my $pic_import    = $mw->Photo( -file => 'img/16x16/document-import-2.png' );
my $pic_export    = $mw->Photo( -file => 'img/16x16/document-export-4.png' );
my $pic_web       = $mw->Photo( -file => 'img/16x16/network.png' );
my $pic_web_up    = $mw->Photo( -file => 'img/16x16/network-up.png' );
my $pic_web_down  = $mw->Photo( -file => 'img/16x16/network-down.png' );
my $pic_conf      = $mw->Photo( -file => 'img/16x16/configure-4.png' );
my $pic_wartung   = $mw->Photo( -file => 'img/16x16/edit-clear-2.png' );
my $pic_tex       = $mw->Photo( -file => 'img/16x16/tex.png' );
my $pic_text      = $mw->Photo( -file => 'img/16x16/text.png' );
my $pic_odf       = $mw->Photo( -file => 'img/16x16/loffice.png' );

#---------------------------------------------------------------------------
#  Variable: $menubar
#
#  das Menü wird in der Funktion <menu_aktualisieren> aufgebaut und aktualisiert
#
#  und hat folgenden Aufbau
#
# -> steht für : ist Elternwidget von
#
# - <$menubar> ->  <$file>   -> <$neu>       -> <$neu_pflicht>
# - <$menubar> ->  <$file>   -> <$neu>       -> <$neu_version>
# - <$menubar> ->  <$file>   -> <$laden>
# - <$menubar> ->  <$file>   -> <$speichern>
# - <$menubar> ->  <$file>   -> <$loeschen>
# - <$menubar> ->  <$file>   -> <$webserver> -> wurde nicht implementiert
# - <$menubar> ->  <$config> -> <$c_server>
# - <$menubar> ->  <$config> -> <$c_programm>
# - <$menubar> ->  <$config> -> <$c_wartung>
# - <$menubar> ->  <$export> -> <$x_odt>
# - <$menubar> ->  <$export> -> <$x_latex>
# - <$menubar> ->  <$export> -> <$x_text>
# - <$menubar> ->  <$help>   -> <$version>
#
# In der Gui siehr das ganze dann so aus:
#
# - Datei -> Neues Pflichtenheft -> Neues Pflichtenheft
# - Datei -> Neues Pflichtenheft -> Neue Version
# - Datei -> Laden
# - Datei -> Speichern
# - Datei -> Löschen
# - Datei -> Webserver -> Laden *nicht implementiert*
# - Datei -> Webserver -> Speichern *nicht implementiert*
# - Datei -> Webserver -> Löschen *nicht implementiert*
# - Konfiguration -> Webserver
# - Konfiguration -> Programm
# - Konfiguration -> Wartung
# - Export -> ODT
# - Export -> LaTeX
# - Export -> Text
# - Hilfe  -> Version
#---------------------------------------------------------------------------

my $menubar = $mw->Menu();
$mw->configure( -menu => $menubar );

#-------------------------------------------------------------------------------
# About: Tastenkürzel
#
# - Strg+n       Lädt Dialog zum Anlegen eines neues Pflichtenheftes <gui_neues_pflichtenheft>
# - Strg-Umsch-N Lädt Dialog zum Anlegen einer neuen Version <gui_neue_version>
# - F1           Infobox <gui_info_box>
# - Strg+l       Lädt Dialog zum Laden des Pflichtenheftes <gui_laden>
# - Strg+s       Lädt Dialog zum Speichern des Pflichtenheftes <gui_speichern>
# - Strg+x       Löscht ein Pflichtenheft <pflichtenheft_loeschen>
# - Strg+k       Lädt Dilaog zur Konfiguration <gui_programm_konfig>
# - Strg+w       Lädt Dilaog zur Wartung <gui_wartung>
# - Strg+q       Schließt das Programm <beenden>
#
#-------------------------------------------------------------------------------
$mw->bind( '<Control-n>',       \&gui_neues_pflichtenheft );
$mw->bind( '<Control-Shift-N>', \&gui_neue_version );
$mw->bind( '<F1>',              \&gui_info_box );
$mw->bind( '<Control-l>',       \&gui_laden );
$mw->bind( '<Control-s>',       \&gui_speichern );
$mw->bind( '<Control-k>',       \&gui_programm_konfig );
$mw->bind( '<Control-w>',       \&gui_wartung );
$mw->bind( '<Control-q>',       \&exit );
$mw->bind( '<Control-x>',       \&pflichtenheft_loeschen );

#---------------------------------------------------------------------------
#  about: Arbeitsfläche
#  Der <$main_frame> stellt die Hauptarbeitsfläche des Programms da.
#  <$tree> beinhaltet die Baumansicht aller Pflichtenhefte. Nach dem
#  Drücken auf einen Eintrag der Baumansicht wird die Funktion <gui_vorschau>
#  aufgerufen die eine Vorschau des Pflichtenheftes in <$preview_frame>
#  anzeigt.
#
# > $main_frame
# >+---------------------------------------------------------------------+
# >| $pflicht_frame     $preview_frame                                   |
# >| +---------------+ +-----------------------------------------------+ |
# >| |$tree          | |                                               | |
# >| |               | |   Vorschau des Pflichtenheftes                | |
# >| |Baumansicht    | |                                               | |
# >| |des            | |                                               | |
# >| |Pflichtenheftes| |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| |               | |                                               | |
# >| +---------------+ +-----------------------------------------------+ |
# >| $button_frame                                                       |
# >| +-----------------------------------------------------------------+ |
# >| | $laden_button $neu_button $loeschen_button      $beenden_button | |
# >| +-----------------------------------------------------------------+ |
# >+---------------------------------------------------------------------+
#
#---------------------------------------------------------------------------

#Hauptframe
my $main_frame = $mw->Frame( -relief => 'raised' );

#Ansicht aller Pflichtenhefte
my $pflicht_frame = $main_frame->Frame( -relief => 'raised' );

# Variable: $tree
#
# Beinhaltet alle Pflichtenhefte aus dem Projektordner des Programms
# Bei Klick auf einen Eintrag wird durch die Funktion <gui_vorschau>
# die Vorschau im <$preview_frame> angezeigt

# BUG:13.07.2011 20:11:19:: Der Doppelklick von der Option -command
# wird ignoriert wenn -browsecommand benutzt wird
my $tree = $pflicht_frame->Scrolled(
    'Tree',
    -selectmode       => 'single',
    -separator        => q{/},
    -scrollbars       => 'oe',
    -selectbackground => 'lightblue',
    -width            => '25',
    -command          => \sub {
        pflichtenheft_laden();
    },
    -browsecmd => \sub {
        my ($pfad) = @ARG;
        gui_vorschau($pfad);
      }

);

$tree->autosetmode();
$tree->pack( -fill => 'x' );

# Variable: $preview_frame
#
# In diesem Frame wird die Vorschau des Pflichtenheftes angezeigt
# Die Vorschau wird durch <gui_vorschau> erzeugt.
my $preview_frame =
  $main_frame->Scrolled( 'Pane', -scrollbars => 'oe', -sticky => 'n' );

# Variable: $button_frame
# Der Frame beinhaltet 3 Buttons und zwar Laden, Neu, Löschen und Beenden
my $button_frame =
  $main_frame->Frame( -relief => 'raised', -borderwidth => '1' );

# Variable: $laden_button
# Lädt das in der Baumansicht ausgewählte Pflichtenheft über die Funktion
# <pflichtenheft_laden>
my $laden_button = $button_frame->Button(
    -text     => 'Laden',
    -image    => $pic_oeffne,
    -compound => 'left',
    -command  => \sub {
        pflichtenheft_laden();
    }
);

# Variable: $neu_button
# Lädt den Dialog zum Erstellen eines neuen Pflichtenhefts über die Funktion
# <gui_neues_pflichtenheft>
my $neu_button = $button_frame->Button(
    -text     => 'Neu',
    -image    => $pic_neu,
    -compound => 'left',
    -command  => \sub {
        gui_neues_pflichtenheft();
    }
);

# Variable: $loeschen_button
# Löscht das in der Baumansicht ausgewählte Pflichtenheft über die Funktion
# <pflichtenheft_loeschen>
my $loeschen_button = $button_frame->Button(
    -text     => 'Löschen',
    -image    => $pic_delete,
    -compound => 'left',
    -command  => \sub {
        pflichtenheft_loeschen();
    }
);

# Variable: $beenden_button
# Beendet das Programm
my $beenden_button = $button_frame->Button(
    -text     => 'Beenden',
    -image    => $pic_exit,
    -compound => 'left',
    -command  => \&exit,
);

$laden_button->pack( -side => 'left' );
$neu_button->pack( -side => 'left' );
$loeschen_button->pack( -side => 'left' );
$beenden_button->pack( -side => 'right' );
$tree->pack( -fill => 'y', -expand => '1' );
$main_frame->pack( -fill => 'both', -expand => '1' );
$button_frame->pack( -fill => 'x', -side => 'bottom', -anchor => 'sw' );
$pflicht_frame->pack( -fill => 'y', -side => 'left' );
$preview_frame->pack( -fill => 'both', -expand => '1', -side => 'left' );

#---------------------------------------------------------------------------
#  MainLoop
#---------------------------------------------------------------------------

initialisieren();

MainLoop();

#-------------------------------------------------------------------------------
#   Subroutine: initialisieren
#
#   Beim starten des Programms wird Sie einmalig aufgerufen. Sie ruft direkt
#   nach dem Start die Funktionen <lade_konfig>, <baum_aktualisieren> und
#   menu_aktualisieren auf
#
#-------------------------------------------------------------------------------
sub initialisieren {

    #---------------------------------------------------------------------------
    #  Konfigurationsdaten laden
    #---------------------------------------------------------------------------
    lade_konfig();

    #---------------------------------------------------------------------------
    #  Baum mit Pflichtenhefteinträgen generieren
    #---------------------------------------------------------------------------
    baum_aktualisieren();

    #---------------------------------------------------------------------------
    #  Menü erstellen
    #---------------------------------------------------------------------------
    menu_aktualisieren();

    return;
}    # ----------  end of subroutine initialisieren  ----------

#---------------------------------------------------------------------------
#   Subroutine: gui_neues_pflichtenheft
#
#   Erstellt den Dialog zum Erstellen eines neuen Pflichtenheftes.
#---------------------------------------------------------------------------
sub gui_neues_pflichtenheft {
    my $gui = $mw->Toplevel( -title => 'Neues Pflichtenheft.' );

    # Fenster mittig positionieren
    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 150;
    modal( \$gui, $BREITE, $HOEHE );
    my %phefte;

    # Hole alle Pflichtenheftnamen aus dem hash <%pfade>
    foreach my $key ( keys %pfade ) {

        # Ein Ordner ist auch gleichzeitig ein Pflichtenheftname
        if ( $pfade{$key} eq 'ordner' ) {
            $phefte{$key} = $key;
        }
    }

    my $label = $gui->Label( -text => 'Titel des Pflichtenhefts' );
    my $pheft;
    my $entry = $gui->Entry(
        -textvariable    => \$pheft,
        -validate        => 'key',
        -validatecommand => sub {

            # Keine '/' im Pflichtenheftnamen zulassen, da er auch
            # gleichzeiteig der Name eines Ordners wird.
            # / ist in ext2/3/4 kein erlaubtes Zeichen
            #
            # BUG: Tk macht Probleme mit dem darstellen von Umlauten
            # Es konnte währen der Entwicklungszeit keine Lösung
            # dafür gefunden werden, deshalb wird das eingeben
            # von Umlauten blockiert
            $ARG[1] !~ m/(\/|ö|ä|ü)/i;
        },
    );
    $entry->focus();

    my $vlabel = $gui->Label( -text => 'Versionsbezeichnung' );
    my $version;
    my $ventry = $gui->Entry(
        -textvariable    => \$version,
        -validate        => 'key',
        -validatecommand => sub {

            # Keine '/' im Pflichtenheftnamen zulassen, da er auch
            # gleichzeiteig der Name eines Ordners wird.
            # / ist in ext2/3/4 kein erlaubtes Zeichen

            # BUG: Tk macht Probleme mit dem darstellen von Umlauten
            # Es konnte währen der Entwicklungszeit keine Lösung
            # dafür gefunden werden, deshalb wird das eingeben
            # von Umlauten blockiert
            $ARG[1] !~ m/(\/|ö|ä|ü)/i;
        },
    );

    my $frame_button = $gui->Frame();

    my $button_erstellen = $frame_button->Button(
        -state    => 'disabled',
        -text     => 'Erstellen',
        -image    => $pic_ok,
        -compound => 'left',
        -command  => \sub {
            trimm($pheft);
            trimm($version);

            # Erstelle Ordner aus dem Titel des Pflichtenheftes, der Pfad
            # besteht aus dem Projektpfad und dem Titel des Pflichtenheftes
            my $pflichten_pfad = ${$konfiguration}{'aordner'} . q{/} . $pheft;
            my $check          = mkdir $pflichten_pfad;
            if ($check) {

                # Erstelle Pflichtenheftversion
                my $pfad = $pflichten_pfad . q{/} . $version . '.xml';
                my $neu  = MoliriXML->new($pfad);

                # Leeres Pflichtenheft besteht nur aus Titel und Version
                $neu->export_xml(
                    {
                        Titel   => $pheft,
                        Version => $version,
                    }
                );

                # Damit die neu angelegte Datei in der Baumansicht erscheint
                # muss Projektordner neu eingelesen werden
                baum_aktualisieren();

                # Lade direkt nach dem Erstellen das Pflichtenheft
                pflichtenheft_laden($pfad);
                $gui->destroy();
            }
            else {
                print "Es konnte kein neues Pflichtenheft erstellt werden.\n";
            }
        },
    );
    my $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    #---------------------------------------------------------------------------
    #  Mann kann nur eine Version zu einem Pflichtenheft erstellen wenn
    #  Pflichtenheft bereits vorhanden und Versionsbezeichnung nicht vergeben.
    #  Das wird mit dem binding bind_pheft_check sichergestellt. Der
    #  Erstellen-Button wird nur aktiviert wenn Bedingungen erfüllt.
    #---------------------------------------------------------------------------
    $gui->bind(
        '<KeyRelease>',
        [
            \&bind_pheft_check,
            {
                pheft            => \$pheft,
                version          => \$version,
                button_erstellen => \$button_erstellen,
                entry            => \$entry,
                ventry           => \$ventry,
                phefte           => \%phefte
            }
        ]
    );

    #---------------------------------------------------------------------------
    #  Packstube
    #---------------------------------------------------------------------------
    $label->pack( -anchor => 'w' );
    $entry->pack( -anchor => 'w', -fill => 'x', -expand => '1' );
    $vlabel->pack( -anchor => 'w' );
    $ventry->pack( -anchor => 'w', -fill => 'x', -expand => '1' );
    $frame_button->pack( -fill => 'x', -expand => '1' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine gui_neues_pflichtenheft  ----------

#---------------------------------------------------------------------------
#   Subroutine: gui_neue_version
#
#   Erstellt den Dialog zum Erstellen einer neuen Version eines
#   Pflichtenhefts
#---------------------------------------------------------------------------
sub gui_neue_version {
    my $gui = $mw->Toplevel( -title => 'Neue Version' );

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 180;
    modal( \$gui, $BREITE, $HOEHE );

    my $p_label    = $gui->Label( -text => 'Pflichtenheft auswählen' );
    my $v_label    = $gui->Label( -text => 'Versionsbezeichnung eingeben' );
    my $oldv_label = $gui->Label( -text => 'Inhalt kopieren aus' );

    # hole den im Baum markierten Eintrag
    my @auswahl = $tree->info('selection');
    my %phefte;
    my %versionen;

    # hole alle Pflichtenheftnamen aus dem hash %pfade
    foreach my $key ( keys %pfade ) {

        # Ein Ordner ist auch gleichzeitig ein Pflichtenheft
        if ( $pfade{$key} eq 'ordner' ) {
            $phefte{$key} = $key;
        }
        else {

            # Plichtenheftnamen mit ihren dazugehörigen Versionen in
            # %version abspeichern, da diese später im binding
            # bind_version_check gebraucht werden
            my $tmp_version = substr $key, ( rindex $key, q{/} ) + 1;
            my $tmp_pheft = substr $key, 0, ( rindex $key, q{/} );
            $versionen{$tmp_pheft}{$tmp_version} = $tmp_version;
        }
    }

    # Liste aller Pflichtenhefte wird geholt und in der ComboEntry
    # gespeichert.
    my @p_liste = keys %phefte;
    my $pheft;
    my $p_combo = $gui->ComboEntry(
        -textvariable => \$pheft,
        -itemlist     => \@p_liste,
        -width        => 28,
    );

    # Eingabe der Version
    # $version wird im binding bind_version_check gebraucht
    my $version;
    my $v_entry = $gui->Entry(
        -textvariable    => \$version,
        -validate        => 'key',
        -validatecommand => sub {

            # Keine '/' in der  Versionsbezeichung zulassen, da
            # dieser auch gleichzeiteig der Name einer Datei wird.
            # Das Zeichen '/' ist in ext2/3/4 kein erlaubtes Zeichen.
            not $ARG[1] =~ m/(\/|ö|ä|ü)/i;
        }
    );
    $v_entry->focus();

    # Zuweisen der Referenz $old_version auf das ComboEntry. $old_version
    # wird im binding bind_version_check verwendet. Es zeigt die bereits
    # vorhandenen Versionen des im $p_combo ausgewählten Pflichtenhefts an.
    my $old_version;
    my $oldv_combo = $gui->ComboEntry(
        -textvariable => \$old_version,
        -width        => 28,
    );

    my $frame_button     = $gui->Frame();
    my $button_erstellen = $frame_button->Button(
        -state    => 'disabled',
        -text     => 'Erstellen',
        -image    => $pic_ok,
        -compound => 'left',
        -command  => \sub {

            #Erstelle XML-Datei aus der Versionsnummer
            my $neu_version =
                ${$konfiguration}{'aordner'} . q{/} 
              . $pheft . q{/} 
              . $version . '.xml';

            my $xml = MoliriXML->new($neu_version);

            # Wenn $old_version angegeben, soll aus einer anderen Version
            # der Inhalt kopiert werden, dazu wird version_xml aufgerufen.
            if ($old_version) {
                my $alt_version =
                    ${$konfiguration}{'aordner'} . q{/} 
                  . $pheft . q{/}
                  . $old_version . '.xml';

                # Leeres Pflichtenheft besteht nur aus Titel und Version
                $xml->version_xml( $neu_version, $alt_version, $version );
            }
            else {

                # Wenn $old_version nicht angegeben wurde, erstelle einfach
                # ein neues Pflichtenheft.
                $xml->export_xml(
                    {
                        Titel   => $pheft,
                        Version => $version,
                    }
                );
            }

            # Nach Export aktualisiere die Baumansicht und lade direkt das
            # Pflichtenheft.
            baum_aktualisieren();
            pflichtenheft_laden($neu_version);
            $gui->destroy();
        }
    );
    my $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    #---------------------------------------------------------------------------
    #  Mann kann nur eine Version zu einem Pflichtenheft erstellen wenn
    #  Pflichtenheft bereits vorhanden und Versionsbeziechung nicht vergeben.
    #  Das wird mit dem bindingbind_version_check sichergestellt. Der
    #  Erstellen-Button wird nur aktiviert wenn Bedingungen erfüllt.
    #---------------------------------------------------------------------------
    $gui->bind(
        '<KeyRelease>',
        [
            \&bind_version_check,
            {
                p_combo          => \$p_combo,
                v_entry          => \$v_entry,
                phefte           => \%phefte,
                versionen        => \%versionen,
                pheft            => \$pheft,
                version          => \$version,
                button_erstellen => \$button_erstellen,
                oldv_combo       => \$oldv_combo,
                old_version      => \$old_version
            }
        ]
    );

    $gui->bind(
        '<Button>',
        [
            \&bind_version_check,
            {
                p_combo          => \$p_combo,
                v_entry          => \$v_entry,
                phefte           => \%phefte,
                versionen        => \%versionen,
                pheft            => \$pheft,
                version          => \$version,
                button_erstellen => \$button_erstellen,
                oldv_combo       => \$oldv_combo,
                old_version      => \$old_version
            }
        ]
    );

    if (@auswahl) {

        # Wenn bereits ein Pflichtenheft markiert wurde, dann Varaible mit
        # Referenz auch Eingabefeld "p_combo" direkt setzen
        if ( $pfade{ $auswahl[0] } eq 'ordner' ) {
            $pheft = $auswahl[0];
        }
        else {

            # Wenn Version markiert dann Pflichtenheftnamen herausfinden und
            # Varaible mit Referenz auch Eingabefeld "p_combo" direkt setzen
            $pheft = substr $auswahl[0], 0, ( rindex $auswahl[0], q{/} );
        }

        # Pflichtenheft setzen und jegliche Eingaben blockieren
        $p_combo->configure(
            -state           => 'disabled',
            -validate        => 'key',
            -validatecommand => sub {

                #keine Eingaben mehr zulassen
                return 0;
            }
        );
    }

    #---------------------------------------------------------------------------
    #  Packstube
    #---------------------------------------------------------------------------
    $p_label->pack( -anchor => 'w' );
    $p_combo->pack( -anchor => 'w', -fill => 'x', -expand => '1' );
    $v_label->pack( -anchor => 'w' );
    $v_entry->pack( -anchor => 'w', -fill => 'x', -expand => '1' );
    $oldv_label->pack( -anchor => 'w' );
    $oldv_combo->pack( -anchor => 'w', -fill => 'x', -expand => '1' );
    $frame_button->pack( -fill => 'x', -expand => '1' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine gui_neues_pflichtenheft  ----------

#-------------------------------------------------------------------------------
#   Subroutine: gui_laden
#
#   Ein oder mehrere Pflichtenhefte werden aus einer MLR-Datei aus gelesen
#   und in den Projektordner kopiert
#-------------------------------------------------------------------------------
sub gui_laden {
    my ($par1) = @_;
    my $gui = $mw->Toplevel( -title => 'Pflichtenheft laden' );

    my ( $frame_dname, $label_dname, $dname, $entry_dname, $button_dname,
        $button_erstellen, $button_abbrechen );

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 300;
    modal( \$gui, $BREITE, $HOEHE );

    $gui->Label( -text =>
          "Bitte das Pflichtenheft wählen, dass geladen \nwerden soll " )
      ->pack( -side => 'top' );

    $gui->Label(
        -text => 'Achtung: Es können nur MLR-Dateien ausgewählt werden',
        -font => 'Helvetica -10',
    )->pack( -side => 'top' );

    $frame_dname  = $gui->Frame();
    $label_dname  = $frame_dname->Label( -text => 'Dateiname: ' );
    $entry_dname  = $frame_dname->Entry( -textvariable => \$dname );
    $dname        = File::HomeDir->my_home();
    $button_dname = $frame_dname->Button(
        -image   => $pic_oeffne,
        -command => sub {
            my $dialog = $frame_dname->FileDialog(
                -Title => 'Dateinamen und Pfad wählen',
                -FPat  => '*mlr',
            );
            $dname = $dialog->Show();
            $entry_dname->focus();
            $entry_dname->focusNext();
        }
    );

    $entry_dname->focus();

    my $frame_scrld =
      $gui->Scrolled( 'Frame', -sticky => 'nw', -scrollbars => 'oe' );

    # Der Hash %auswahl speichert die vom Benutzer ausgewälten Dateien
    # die geladen werden sollen
    my %auswahl = ();

    # in dem binding bind_rechte_laden wird überprüft ob die ausgewählte
    # Datei eine MLR-Datei ist und die Programmdialog mit entsprechenen
    # Checkboxen ausgestattet zur Auswahl der zu ladenden Pflichtenhefte
    # Dies geschieht immer wenn eine Taste innerhalb des Entrys gedrückt
    # wird oder er den Focus verliert. Nur alle Bedingungen erfüllt sind
    # wird $button_erstellen aktiviert.
    $entry_dname->bind( '<KeyRelease>',
        [ \&bind_rechte_laden, \$button_erstellen, \$frame_scrld, \%auswahl ] );
    $entry_dname->bind( '<FocusOut>',
        [ \&bind_rechte_laden, \$button_erstellen, \$frame_scrld, \%auswahl ] );

    my $frame_button = $gui->Frame();
    $button_erstellen = $frame_button->Button(
        -text     => 'Laden',
        -image    => $pic_import,
        -compound => 'left',
        -state    => 'disabled',
        -command  => \sub {

    #---------------------------------------------------------------------------
    #  Überprüfe ob Einträge bereits vorhanden sind und wenn ja, frage nach
    #  ob sie überschrieben werden sollen.
    #---------------------------------------------------------------------------

           # Der Rückgabewert von child_entries ohne Parameter ist ein Feld von
           # Einträgen der ersten Ebene der Baumstruktur, in diesem Programm
           # sind das die Pflichtenhefte.
            foreach my $ordner ( $tree->child_entries() ) {

                # In der zweiten Schleife werden jetzt die einzelnen Versionen
                # die sich ind er zweiten Ebene der Baumstruktur befinden,
                # ausgelesen
                foreach my $datei ( $tree->child_entries($ordner) ) {

                   # Wenn einer der Einträge die gleiche Bezeichnung hat wie
                   # einer unserer zuvor ausgewählten Einträgen aus der
                   # MLR-Datei dann Frage ob sie im Projektordner ersetzt werden
                   # soll
                    if ( $auswahl{$datei} ) {
                        my $antw = $mw->Dialog(
                            -title => 'Achtung',
                            -text  => "Das Pflichtenheft $datei"
                              . " ist bereits vorhanden.\n"
                              . 'Soll es überschrieben werden?',
                            -buttons => [ 'Nein', 'Ja' ],
                            -bitmap  => 'warning'
                        )->Show();

                        # Wenn sie nicht überschrieben werden soll dann lösche
                        # den Eintrag aus dem Hash %auswahl, der unsere zuvor
                        # ausgewählten Pflichtenhefte repräsentiert
                        if ( $antw eq 'Nein' ) {
                            $auswahl{$datei} = undef;
                        }
                    }
                }
            }

            # Erstelle ein Array aus den Werten des Hashes und entferne alle
            # nicht zu ladenden Pflichtenhefte, da import_mlr nur array aufnimmt
            my @dateien = grep { defined $ARG } values %auswahl;

            my $mlr = MoliriMLR->new($dname);
            $mlr->import_mlr( ${$konfiguration}{'aordner'}, @dateien );
            $gui->destroy();
            baum_aktualisieren();
        },
    );

    $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    $frame_dname->pack( -fill => 'x', -expand => '1' );
    $label_dname->pack( -side => 'left' );
    $entry_dname->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $button_dname->pack( -side => 'left' );
    $frame_scrld->pack(
        -fill   => 'both',
        -expand => '1',
        -anchor => 'w',
        -side   => 'top'
    );

    $frame_button->pack( -fill => 'x', -side => 'bottom' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine gui_laden  ----------

#-------------------------------------------------------------------------------
#   Function :  gui_speichern
#
#   Ein oder mehrere Pflichtenhefte werden aus dem Projektordner in eine
#   MLR-Datei abgespeichert
#-------------------------------------------------------------------------------
sub gui_speichern {
    my ($par1) = @_;
    my $gui = $mw->Toplevel( -title => 'Pflichtenheft speichern' );
    my ( $frame_dname, $label_dname, $dname, $entry_dname, $button_dname,
        $button_erstellen, $button_abbrechen );

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 300;
    modal( \$gui, $BREITE, $HOEHE );

    $gui->Label( -text =>
          "Bitte das Pflichtenheft wählen, dass gespeichert \nwerden soll " )
      ->pack( -side => 'top' );

    $gui->Label(
        -text => 'Tipp: Es können auch mehrere ausgewählt werden',
        -font => 'Helvetica -10',
    )->pack( -side => 'top' );
    my %auswahl;
    my $frame_scrld =
      $gui->Scrolled( 'Frame', -sticky => 'nw', -scrollbars => 'oe' );

    #---------------------------------------------------------------------------
    #  Es werden alle Einträge aus der Baumstruktur ausgelesen und als
    #  Checkbuttons dargestellt
    #---------------------------------------------------------------------------
    foreach my $ordner ( $tree->child_entries() ) {

        # Für jedes Pflichtenheft ...
        $frame_scrld->Label( -text => $ordner )->pack( -anchor => 'w' );
        foreach my $datei ( $tree->child_entries($ordner) ) {

            # alle Einträge aus der Baumstruktur haben die Form
            # "Pflichtenheftname/Version.xml"
            # In den folgenden beiden Schritten wird die Version zur
            # Bezeichung der Checkbox gebraucht.
            # 1. Schritt : Es bleibt der Teilstring 'Version.xml'
            # 2. Schritt : Es bleibt der Teilstring 'Version' und wird
            # in $name abgespeichert
            my $name = substr $datei, ( index $datei, q{/} ) + 1;
            $name = substr $name, 0, ( rindex $name, '.xml' );

            # Beim Drücken der Checkbuttons wird nun im Hash %auswahl
            # eine neues Wertepaar angelegt.
            my $tmp_cb = $frame_scrld->Checkbutton(
                -text     => $name,
                -onvalue  => $datei,
                -offvalue => undef,
                -variable => \$auswahl{ $ordner . q{/} . $name },
            )->pack( -anchor => 'w', -padx => '30', -side => 'top' );

            # In dem binding bind_auswahl_check wird überprüft ob mindestens
            # ein Checkbuton markiert wurde. Wenn ja, wir $button_erstellen
            # aktiviert, ansonsten deaktiviert
            $tmp_cb->bind( '<ButtonPress>',
                [ \&bind_auswahl_check, \%auswahl, \$entry_dname ] );
        }
    }

    $frame_dname = $gui->Frame();
    $label_dname = $frame_dname->Label( -text => 'Dateiname: ' );
    $entry_dname =
      $frame_dname->Entry( -textvariable => \$dname, -state => 'disabled' );
    $dname        = File::HomeDir->my_home();
    $button_dname = $frame_dname->Button(
        -image   => $pic_oeffne,
        -command => sub {

            # Auswahl des Dateipfades
            if ( $entry_dname->cget( -state ) eq 'normal' ) {
                my $dialog = $frame_dname->FileDialog(
                    -FPat  => '*mlr',
                    -Title => 'Dateinamen und Pfad wählen',
                );
                $dname = $dialog->Show();
                $entry_dname->focus();
                $entry_dname->focusNext();
            }
        }
    );

    # Im binding bind_rechte_speichern wird überprüft ob der angegebene
    # Pfad gültig ist. Das geschieht nach jedem Tastenanschlag und wenn
    # das Entry den Fokus verliert. Wenn nicht wird der $botton_erstellen
    # deaktiviert
    $entry_dname->bind( '<KeyRelease>',
        [ \&bind_rechte_speichern, \$button_erstellen ] );
    $entry_dname->bind( '<FocusOut>',
        [ \&bind_rechte_speichern, \$button_erstellen ] );
    my $frame_button = $gui->Frame();
    $button_erstellen = $frame_button->Button(
        -text     => 'Speichern',
        -image    => $pic_export,
        -compound => 'left',
        -state    => 'disabled',
        -command  => \sub {
            my $mlr = MoliriMLR->new($dname);
            my @pfade;
            foreach ( keys %auswahl ) {
                if ( $auswahl{$ARG} ) {
                    push @pfade,
                      ${$konfiguration}{'aordner'} . q{/} . $auswahl{$ARG};
                }
            }
            $mlr->export_mlr(@pfade);
            $gui->destroy();
        },
    );

    $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );
    $frame_scrld->pack(
        -fill   => 'both',
        -expand => '1',
        -anchor => 'w',
        -side   => 'top'
    );
    $frame_dname->pack( -fill => 'x', -expand => '1' );
    $label_dname->pack( -side => 'left' );
    $entry_dname->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $button_dname->pack( -side => 'left' );

    $frame_button->pack( -fill => 'x', -side => 'bottom' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine gui_speichern  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  gui_vorschau
#   Erstellt eine Vorschau vom ausgewählten Pflichtenheft in <$preview_frame>
#
#-------------------------------------------------------------------------------

sub gui_vorschau {
    my ($pfad) = @_;
    my $xml_pfad = $pfade{$pfad};

    # Wenn Ordner ausgewählt, raus aus Funktion
    if ( $xml_pfad eq 'ordner' ) {
        return;
    }

    # Zuvor alle Widgets von $preview_frame löschen, damit nach nach jedem
    # Klick auf einen Eintrag immer wieder neue Widgets gezeichnet werden
    foreach my $s ( $preview_frame->packSlaves() ) {
        if ( $s->class() eq 'Pane' ) {
            foreach my $widget ( $s->packSlaves() ) {
                $widget->destroy();
            }
        }
    }
    my $xml   = MoliriXML->new($xml_pfad);
    my $pheft = $xml->import_xml();

    #---------------------------------------------------------------------------
    #  Pflichtenheftdetails
    #---------------------------------------------------------------------------
    my $kapitel1 = $preview_frame->Label(
        -text       => 'Pflichtenheftdetails',
        -background => 'lightblue',
    );
    my $titel = $preview_frame->Label(
        -text => "Titel: \t\t" . ${$pheft}{'details'}{'titel'} );
    my $version = $preview_frame->Label(
        -text => "Version: \t\t" . ${$pheft}{'details'}{'version'} );
    my $autor = $preview_frame->Label(
        -text => "Autor: \t\t" . ${$pheft}{'details'}{'autor'} );
    my $datum = $preview_frame->Label(
        -text => "Datum: \t\t" . ${$pheft}{'details'}{'datum'} );
    my $status = $preview_frame->Label(
        -text => "Status: \t\t" . ${$pheft}{'details'}{'status'} );

    my $kframe = $preview_frame->Frame();
    my $kommentar = $kframe->Label( -text => 'Kommentar: ' );
    my $kbox = $kframe->Scrolled( 'Text', -scrollbars => 'oe', -height => '5' );
    $kbox->insert( '1.0', ${$pheft}{'details'}{'kommentar'} );

    # Textbox nicht editierbar
    $kbox->configure( -state => 'disabled' );
    my $canvas1 = $preview_frame->Canvas( -height => '8' );
    $canvas1->createLine( '10', '3', '570', '3', -width => '3' );
    $kapitel1->pack( -anchor => 'nw' );
    $titel->pack( -anchor => 'nw' );
    $version->pack( -anchor => 'nw' );
    $autor->pack( -anchor => 'nw' );
    $datum->pack( -anchor => 'nw' );
    $status->pack( -anchor => 'nw' );
    $kframe->pack( -anchor => 'nw', -fill => 'x' );
    $kommentar->pack( -side => 'left', -anchor => 'nw' );
    $kbox->pack( -side => 'left' );
    $canvas1->pack( -fill => 'x' );

    #---------------------------------------------------------------------------
    #  Zielbestimmung
    #---------------------------------------------------------------------------
    my @keys = keys %{ ${$pheft}{'zielbestimmungen'} };
    if (@keys) {
        $preview_frame->Label(
            -text       => 'Zielbestimmung:',
            -background => 'lightblue'
        )->pack( -anchor => 'w' );
        my $iterator;
        foreach ( sort @keys ) {
            my $zielbestimmung =
              \${ ${ ${$pheft}{'zielbestimmungen'} }{$ARG} }[0];
            my $beschreibung =
              \${ ${ ${$pheft}{'zielbestimmungen'} }{$ARG} }[1];

            # Zeilenumbrüche entfernen
            umbruch_entfernen($beschreibung);

            # Wenn Text nicht mehr auf das Frame past, dann abschneiden
            cut_bei_64($beschreibung);

            # Da das Wort Abgrenzungskriterium über einen Tab hinausgeht
            # muss jedesmal wenn es vorkommt nur ein Tab zwischen Typ und
            # Beschreibung eingefügt werden
            if ( ${$zielbestimmung} eq 'Abgrenzungskriterium' ) {
                $preview_frame->Label(
                    -text => "${$zielbestimmung}\t${$beschreibung}" )
                  ->pack( -anchor => 'w' );
            }
            else {
                $preview_frame->Label(
                    -text => "${$zielbestimmung}\t\t${$beschreibung}" )
                  ->pack( -anchor => 'w' );
            }

            # Zählt die Schleifen durchläufe mit, beim max 5 Abbrechen, da
            # der Abschnitt in der Vorschau zu viel Platz wegnehmen würde
            Readonly my $MAX_ELEMENTE => 5;
            $iterator++;
            if ( $iterator == $MAX_ELEMENTE ) {
                last;
            }
        }

        my $canvas = $preview_frame->Canvas( -height => '8' );
        $canvas->createLine( '10', '3', '570', '3', -width => '3' );
        $canvas->pack( -fill => 'x' );
    }

    #---------------------------------------------------------------------------
    #  Produkteinsatz
    #---------------------------------------------------------------------------
    my @inhalt = (
        \${$pheft}{'einsatz'}{'produkteinsatz'},
        \${$pheft}{'einsatz'}{'zielgruppen'},
        \${$pheft}{'einsatz'}{'arbeitsbereiche'},
        \${$pheft}{'einsatz'}{'betriebsbedingungen'},
    );

    my @label = (
        "Produkteinsatz\t\t",  "Zielgruppen\t\t",
        "Arbeitsbereiche\t\t", "Betriebsbed.\t\t",
    );

    gui_vorschau_boxen( 'Produkteinsatz', \@inhalt, \@label );

    #---------------------------------------------------------------------------
    #  Übersicht
    #---------------------------------------------------------------------------
    @inhalt = (
        \${$pheft}{'uebersicht'}{'bildpfad'},
        \${$pheft}{'uebersicht'}{'bildbeschreibung'},
        \${$pheft}{'uebersicht'}{'uebersicht'},
    );
    @label = ( "Bildpfad\t\t\t", "Bildbeschr.\t\t", "Übersicht\t\t" );
    gui_vorschau_boxen( 'Produktübersicht', \@inhalt, \@label );

    #---------------------------------------------------------------------------
    #  Funktionen
    #---------------------------------------------------------------------------
    gui_vorschau_tabellen( 'Funktionen', ${$pheft}{'funktionen'} );

    #---------------------------------------------------------------------------
    #  Daten
    #---------------------------------------------------------------------------
    gui_vorschau_tabellen( 'Daten', ${$pheft}{'daten'} );

    #---------------------------------------------------------------------------
    #  Leistungen
    #---------------------------------------------------------------------------
    gui_vorschau_tabellen( 'Leistungen', ${$pheft}{'leistungen'} );

    #---------------------------------------------------------------------------
    #  Qualität
    #---------------------------------------------------------------------------
    my $ref_inhalt = ${$pheft}{'qualitaet'};

    # Wenn zumindest eine der Qualitätsanforderungen angegeben wurde dann
    # erstelle den Eintrag Qualitätsanforderungen
    my $res = join q{}, map { trimm($ARG) } values %{$ref_inhalt};

    if ($res) {
        my @art = keys %{$ref_inhalt};
        $preview_frame->Label(
            -text       => 'Qualitätsanforderungen:',
            -background => 'lightblue'
        )->pack( -anchor => 'w' );
        my $iterator;
        foreach (@art) {
            if ( ${$ref_inhalt}{$ARG} ) {
                my $temp_anford = $ARG;
                $temp_anford = ucfirst $temp_anford;
                $temp_anford =~ s/ae/ä/g;
                $temp_anford =~ s/ue/ü/g;
                $temp_anford =~ s/oe/o/g;
                $preview_frame->Label(
                    -text => $temp_anford . "\t" . ${$ref_inhalt}{$ARG} )
                  ->pack( -anchor => 'w' );
            }

            # Zählt die Schleifen durchläufe mit, beim max 5 Abbrechen, da
            # der Abschnitt in der Vorschau zu viel Platz wegnehmen würde
            Readonly my $MAX_ELEMENTE => 5;
            $iterator++;
            if ( $iterator == $MAX_ELEMENTE ) {
                last;
            }
        }
        my $canvas = $preview_frame->Canvas( -height => '8' );
        $canvas->createLine( '10', '3', '570', '3', -width => '3' );
        $canvas->pack( -fill => 'x' );
    }

    #---------------------------------------------------------------------------
    #  GUI
    #---------------------------------------------------------------------------
    gui_vorschau_tabellen( 'GUI', ${$pheft}{'gui'} );

    #---------------------------------------------------------------------------
    #  nichtfunktionale Anforderungen
    # $pflichtenheft{'nfanforderungen'}
    #---------------------------------------------------------------------------
    @inhalt = ( \${$pheft}{'nfanforderungen'}, );
    @label  = ();
    gui_vorschau_boxen( 'Nichtfunktionale Anforderungen', \@inhalt, \@label );

    #---------------------------------------------------------------------------
    #  Technische Umgebung
    #---------------------------------------------------------------------------

    @inhalt = (
        \${$pheft}{'tumgebung'}{'produktumgebung'},
        \${$pheft}{'tumgebung'}{'software'},
        \${$pheft}{'tumgebung'}{'hardware'},
        \${$pheft}{'tumgebung'}{'orgware'},
        \${$pheft}{'tumgebung'}{'schnittstellen'},
    );
    @label = (
        "Produktumgebung\t\t", "Software\t\t\t",
        "Hardware\t\t\t",      "Orgware\t\t\t",
        "Schnittstellen\t\t",
    );
    gui_vorschau_boxen( 'Technische Umgebung', \@inhalt, \@label );

    #---------------------------------------------------------------------------
    #  Entwicklungsumbebung
    #---------------------------------------------------------------------------

    @inhalt = (
        \${$pheft}{'eumgebung'}{'produktumgebung'},
        \${$pheft}{'eumgebung'}{'software'},
        \${$pheft}{'eumgebung'}{'hardware'},
        \${$pheft}{'eumgebung'}{'orgware'},
        \${$pheft}{'eumgebung'}{'schnittstellen'},
    );
    @label = (
        "Entwicklungsumbebung\t", "Software\t\t\t",
        "Hardware\t\t\t",         "Orgware\t\t\t",
        "Schnittstellen\t\t",
    );

    #---------------------------------------------------------------------------
    #  Teilprodukte
    #---------------------------------------------------------------------------
    @keys = keys %{ ${$pheft}{'teilprodukte'} };
    if (@keys) {
        $preview_frame->Label(
            -text       => 'Teilprodukte',
            -background => 'lightblue'
        )->pack( -anchor => 'w' );
        my $text = "Beschreibung \t\t" . ${$pheft}{'teilprodukte_beschreibung'};
        umbruch_entfernen( \$text );
        cut_bei_81( \$text );
        $preview_frame->Label( -text => $text )->pack( -anchor => 'w' );
        my $tmp_zeile = "\t\t\t";
        foreach (@keys) {
            $tmp_zeile = $tmp_zeile . ${$pheft}{'teilprodukte'}{$ARG}[0] . q{-};
            umbruch_entfernen( \$tmp_zeile );
            cut_bei_81( \$tmp_zeile );
        }
        chop $tmp_zeile;
        $preview_frame->Label( -text => $tmp_zeile )->pack( -anchor => 'w' );
        my $canvas = $preview_frame->Canvas( -height => '8' );
        $canvas->createLine( '10', '3', '570', '3', -width => '3' );
        $canvas->pack( -fill => 'x' );
    }

    #---------------------------------------------------------------------------
    #  Ergänzungen
    #---------------------------------------------------------------------------

    @inhalt = (
        \${$pheft}{'pergaenzungen'}{'bildpfad'},
        \${$pheft}{'pergaenzungen'}{'bildbeschreibung'},
        \${$pheft}{'pergaenzungen'}{'ergaenzungen'},
    );
    @label = ( "Bildpfad\t\t\t", "Bildbeschr.\t\t", "Ergänzungen\t\t" );
    gui_vorschau_boxen( 'Ergänzungen', \@inhalt, \@label );

    #---------------------------------------------------------------------------
    #  Testfälle
    #---------------------------------------------------------------------------

    gui_vorschau_tabellen( 'Testfälle', ${$pheft}{'testfaelle'} );

    #---------------------------------------------------------------------------
    #  Glossar
    #---------------------------------------------------------------------------

    gui_vorschau_tabellen( 'Glossar', ${$pheft}{'glossar'} );

    return;
}    # ----------  end of subroutine gui_vorschau  ----------

#-------------------------------------------------------------------------------
#      Subroutine:  gui_vorschau_tabellen
#
#      Wird innerhalb von <gui_vorschau> aufgerufen und erstellt eine Vorschau
#      von unbestimmt vielen Einträgen wie Funktionen, Daten, Leistungen usw ...
#
#      Parameters:
#
#      $name     - Name des Abschnitts
#      $ref_hash - Referenz auf Hash mit den Werten des Abschnitts
#
#-------------------------------------------------------------------------------
sub gui_vorschau_tabellen {

    my ( $name, $ref_hash ) = @_;
    my @funk_keys = keys %{$ref_hash};
    if (@funk_keys) {
        $preview_frame->Label(
            -text       => $name,
            -background => 'lightblue'
        )->pack( -anchor => 'w' );
        my $iterator = 1;
        foreach (@funk_keys) {

            # Eine Referenz auf anonymes Array mit den Einträgen
            # einer Funktion
            my $eintraege = \@{ ${$ref_hash}{$ARG} };

            my $anzeigen = $ARG . "\t";
            foreach my $feld ( @{$eintraege} ) {
                if ( not $feld ) {
                    next;
                }

                # Unterhashes wie Anhalt der
                if ( $feld =~ m/^HASH/ ) {
                    next;
                }
                $anzeigen = $anzeigen . $feld . q{-};

                # Wenn String länger als 85 abschneiden

                Readonly my $MAX_LAENGE => 85;

                if ( length $anzeigen >= $MAX_LAENGE ) {
                    chop $anzeigen;    #entferne das letzte '-'
                    cut_bei_81( \$anzeigen );

                    # Zeilenumbrüche entfernen
                    umbruch_entfernen( \$anzeigen );
                    last;
                }

                # Zählt die Schleifen durchläufe mit, beim max 5 Abbrechen, da
                # der Abschnitt in der Vorschau zu viel Platz wegnehmen würde

            }
            if ( not $anzeigen =~ m/\.\.\.$/ ) {

                # entferne das letzte '-' wenn nicht bereits in der Schleife
                # geschehen,  wo es durch '...' ersetzt wurde
                chop $anzeigen;
            }
            $preview_frame->Label( -text => $anzeigen )->pack( -anchor => 'w' );

            Readonly my $MAX_ELEMENTE => 5;
            if ( $iterator == $MAX_ELEMENTE ) {
                last;
            }
            $iterator++;
        }

        my $canvas = $preview_frame->Canvas( -height => '8' );
        $canvas->createLine( '10', '3', '570', '3', -width => '3' );
        $canvas->pack( -fill => 'x' );
        return;
    }    # ----------  end of subroutine gui_vorschau_tabellen  ----------
}

#-------------------------------------------------------------------------------
#   Subroutine:  gui_vorschau_boxen
#
#   Wird innerhalb von <gui_vorschau> aufgerufen und erstellt eine Vorschau
#   von den Textboxen wie Produktumgebung oder Entwicklungsumgebung.
#
#   Parameters:
#
#   $titel  - Name des Abschnitts
#   $inhalt - Referenz auf ein Array mit dem Inhalt der Textboxen
#   $label  - Titel der einzelnen Textboxen
#
#-------------------------------------------------------------------------------
sub gui_vorschau_boxen {
    my ( $titel, $inhalt, $label ) = @_;
    my @temp_check;

    # kopiere Inhalt der Referenzen des Arrays in ein Feld
    foreach my $c ( @{$inhalt} ) {
        push @temp_check, ${$c};
    }

    # Wenn irgend ein Feld einen Inhalt hat, gebe alle aus
    if ( $EMPTY ne join $EMPTY, @temp_check ) {
        my $tmp_lab = $preview_frame->Label(
            -text       => $titel,
            -background => 'lightblue',
        )->pack( -anchor => 'w' );

        foreach ( @{$inhalt} ) {
            umbruch_entfernen($ARG);
            cut_bei_64($ARG);
        }
        if ( @{$label} ) {
            for ( 0 .. scalar @{$label} - 1 ) {
                if ( ${ ${$inhalt}[$ARG] } ) {
                    $preview_frame->Label(
                        -text => ${$label}[$ARG] . ${ ${$inhalt}[$ARG] } )
                      ->pack( -anchor => 'w' );
                }
            }
        }
        else {
            if ( ${ ${$inhalt}[0] } ) {
                $preview_frame->Label( -text => "\t\t\t" . ${ ${$inhalt}[0] } )
                  ->pack( -anchor => 'w' );
            }

        }

        my $canvas = $preview_frame->Canvas( -height => '8' );
        $canvas->createLine( '10', '3', '570', '3', -width => '3' );
        $canvas->pack( -fill => 'x' );
    }
    return;
}    # ----------  end of subroutine gui_vorschau_boxen  ----------

#---------------------------------------------------------------------------
#  Subroutine: gui_programm_konfig
#
#  Erstellt den Dialog zur Konfiguration des Programms
#---------------------------------------------------------------------------
sub gui_programm_konfig {
    my $gui = $mw->Toplevel( -title => 'Konfiguration' );

    #Fenster mittig positionieren
    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 150;
    modal( \$gui, $BREITE, $HOEHE );

    my $frame_label_entry = $gui->Frame();

    my $frame_label  = $frame_label_entry->Frame();
    my $label_arbeit = $frame_label->Label( -text => 'Arbeitsordner' );
    my $label_sicher = $frame_label->Label( -text => 'Sicherungsordner' );

    my $frame_entry        = $frame_label_entry->Frame();
    my $frame_entry_arbeit = $frame_entry->Frame();
    my $frame_entry_sicher = $frame_entry->Frame();

    my $pfad_arbeit;
    my $entry_arbeit =
      $frame_entry_arbeit->Entry( -textvariable => \$pfad_arbeit );
    my $button_arbeit = $frame_entry_arbeit->Button(
        -image   => $pic_oeffne,
        -command => sub {

            # Auswahl des Ordners
            my $dialog = $frame_entry_arbeit->FileDialog(
                -Title => 'Arbeitsordner wählen',

                # durch SelDir sind nur Ordner anwählbar
                -SelDir => '1'
            );
            $pfad_arbeit = $dialog->Show();
            $entry_arbeit->focus();
            $entry_arbeit->focusNext();
        }
    );

    my $pfad_sicher;
    my $entry_sicher = $frame_entry_sicher->Entry(
        -textvariable => \$pfad_sicher,
        -state        => 'disabled'
    );
    my $button_sicher = $frame_entry_sicher->Button(
        -state   => 'disabled',
        -image   => $pic_oeffne,
        -command => sub {

            #Auswahl des Ordners
            my $dialog = $frame_entry_sicher->FileDialog(
                -Title  => 'Arbeitsordner wählen',
                -SelDir => '1'
            );
            $pfad_sicher = $dialog->Show();
            $entry_sicher->focus();
            $entry_sicher->focusNext();
        }
    );

    #--------------------------------------------------------------------------

    my $frame_check_descr = $gui->Frame();
    my $frame_check       = $frame_check_descr->Frame();
    my $speichern;
    my $check_speicher = $frame_check->Checkbutton( -variable => \$speichern );
    my $pruefen;
    my $check_pruefen =
      $frame_check->Checkbutton( -variable => \$pruefen, -state => 'disabled' );

    my $frame_label_descr = $frame_check_descr->Frame();
    my $frame_spin        = $frame_label_descr->Frame();
    my $label_speicher =
      $frame_spin->Label( -text => 'auto. Speichern aktivieren' );
    my $minuten;
    my $spin = $frame_spin->Spinbox(
        -width           => '3',
        -validate        => 'key',
        -textvariable    => \$minuten,
        -validatecommand => sub {

            # nur Zahlen zulassen, da Minutenangabe
            $ARG[1] =~ m/[[:digit:]]/;
        },
        -command => sub {

            # Spinboxfunktionalität

            # Wenn oberer Pfeil gedrückt
            if ( $ARG[1] eq 'up' ) {
                if ( not defined $minuten )
                {    # ++ Operator nur bei definierter Zahl anwendbar
                    $minuten = 1;    # Deshalb manuel setzen wenn undefiniert
                    return;
                }
                $minuten++;          # Minute +1
            }

            # Wenn unterer Pfeil gedrückt und Minuten nicht bereits 0.
            # Nur wenn $minuten defininiert den Vergleich starten um
            # Warnung 'use of uninitialized value ...'beim '!='-Operator
            # zu vermeiden.
            elsif ( $minuten and $ARG[1] eq 'down' and $minuten != 0 ) {
                if ( not defined $minuten ) {
                    $minuten = 0;
                    return;
                }
                $minuten--;          # Minute -1

                # Wenn Minuten auf 0 dann Checkbutton auto. Markieren in dem
                # Dialog demarkieren
                if ( $minuten == 0 ) {
                    $speichern = 0;
                }
            }
        }
    );
    my $label_minuten = $frame_spin->Label( -text => ' Minuten' );
    my $label_pruefen =
      $frame_label_descr->Label( -text => 'Rechtschreibprüfung aktivieren' );

    my $frame_button     = $gui->Frame();
    my $button_erstellen = $frame_button->Button(
        -text     => 'Speichern',
        -image    => $pic_ok,
        -compound => 'left',
        -command  => \sub {
            my %save_config;

            # Setze %save_config auf eingegebene Werte
            $save_config{'aordner'}  = trimm($pfad_arbeit);
            $save_config{'sordner'}  = trimm($pfad_sicher);
            $save_config{'aan'}      = $speichern;
            $save_config{'azeit'}    = trimm($minuten);
            $save_config{'rschreib'} = $pruefen;
            my $con = MoliriCFG->new();

            # Einstellungen abspeichern
            $con->set_config( \%save_config );

            # gespeicherte Einstellungen wieder laden
            $konfiguration = $con->get_config();

            # Baumansicht aktualisieren da vielleicht der Arbeitsordner
            # geändert wurde.
            baum_aktualisieren();
            $gui->destroy();
        }
    );
    my $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    #Wenn $entry_arbeit den Focus verliert, wird in Funktion
    #check_rechte die Datei auf Gültigkeit überprüft.
    $entry_arbeit->bind( '<KeyRelease>',
        [ \&bind_rechte_config, \$button_erstellen ] );

    # Wenn $entry_sicher den Focus verliert, wird in Funktion
    # check_rechte die Datei auf Gültigkeit überprüft.
    $entry_sicher->bind( '<KeyRelease>',
        [ \&bind_rechte_config, \$button_erstellen ] );

    #---------------------------------------------------------------------------
    #  Einstellungen in die Oberfläche laden
    #  Wenn der Konfigurationsdialog geladen, fülle den Inhalt
    #---------------------------------------------------------------------------
    $pfad_arbeit = ${$konfiguration}{'aordner'};
    $pfad_sicher = ${$konfiguration}{'sordner'};
    $speichern   = ${$konfiguration}{'aan'};
    $spin->insert( 0, ${$konfiguration}{'azeit'} );
    $pruefen = ${$konfiguration}{'rschreib'};

    #---------------------------------------------------------------------------
    #  Packstube
    #---------------------------------------------------------------------------
    $frame_label_entry->pack( -fill => 'x', -expand => '1' );

    $frame_label->pack( -side => 'left' );
    $label_arbeit->pack( -anchor => 'w' );
    $label_sicher->pack( -anchor => 'w' );

    $frame_entry->pack( -fill => 'x', -expand => '1', -side => 'left' );
    $frame_entry_arbeit->pack( -fill => 'x', -expand => '1' );
    $frame_entry_sicher->pack( -fill => 'x', -expand => '1' );
    $button_arbeit->pack( -side => 'right' );
    $button_sicher->pack( -side => 'right' );
    $entry_arbeit->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $entry_sicher->pack( -side => 'left', -fill => 'x', -expand => '1' );

    $frame_check_descr->pack( -fill => 'x', -expand => '1' );

    $frame_check->pack( -side => 'left' );
    $check_speicher->pack();
    $check_pruefen->pack();

    $frame_label_descr->pack( -side => 'left' );

    $frame_spin->pack();
    $label_speicher->pack( -side => 'left' );
    $spin->pack( -side => 'left' );
    $label_minuten->pack( -side   => 'left' );
    $label_pruefen->pack( -anchor => 'w' );

    $frame_button->pack( -fill => 'x', -expand => '1' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine gui_programm_konfig  ----------

#---------------------------------------------------------------------------
#  Subroutine: gui_wartung
#
#  Erstellt den Dialog zur Wartung des Programms
#---------------------------------------------------------------------------

sub gui_wartung {

    my $gui = $mw->Toplevel( -title => 'Wartung' );

    #Fenster mittig positionieren
    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 150;
    modal( \$gui, $BREITE, $HOEHE );

    my $button_1 = $gui->Button(
        -text    => 'Sichern aller Pflichtenhefte',
        -command => \sub {
            gui_sichern($gui);
        }
    );
    my $button_2 = $gui->Button(
        -text    => 'Wiederherstellen aller Pflichtenhefte',
        -command => \sub {
            gui_wiederherstellen();
          }

    );
    my $button_3 = $gui->Button(
        -text    => 'Löschen aller Pflichtenhefte',
        -command => \sub {
            alles_loeschen($gui);
        }
    );

    my $frame_button     = $gui->Frame();
    my $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    #---------------------------------------------------------------------------
    #  Packstube
    #---------------------------------------------------------------------------

    $button_1->pack( -fill => 'x', -expand => '1' );
    $button_2->pack( -fill => 'x', -expand => '1' );
    $button_3->pack( -fill => 'x', -expand => '1' );
    $frame_button->pack( -fill => 'x', -expand => '1' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine gui_wartung  ----------

#---------------------------------------------------------------------------
#  gui_webserver_konfig
#
#  Konfiguration des Webservers, undokumentiert, da nicht implementiert
#---------------------------------------------------------------------------
sub gui_webserver_konfig {

    my $gui = $mw->Toplevel( -title => 'Webserververbindung' );

    #Fenster mittig positionieren
    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 130;
    modal( \$gui, $BREITE, $HOEHE );

    my $frame_label_entry = $gui->Frame();

    my $frame_label    = $frame_label_entry->Frame();
    my $label_login    = $frame_label->Label( -text => 'Login' );
    my $label_passwort = $frame_label->Label( -text => 'Passwort' );
    my $label_ip       = $frame_label->Label( -text => 'IP' );
    my $label_port     = $frame_label->Label( -text => 'Port' );

    my $frame_entry    = $frame_label_entry->Frame();
    my $entry_login    = $frame_entry->Entry( -state => 'disabled' );
    my $entry_passwort = $frame_entry->Entry( -state => 'disabled' );
    my $entry_ip       = $frame_entry->Entry( -state => 'disabled' );
    my $entry_port     = $frame_entry->Entry( -state => 'disabled' );

    my $frame_button     = $gui->Frame();
    my $button_erstellen = $frame_button->Button(
        -state    => 'disabled',
        -text     => 'Speichern',
        -image    => $pic_ok,
        -compound => 'left',
    );
    my $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    #$entry_login->focus();
    $gui->Dialog(
        -title => 'Achtung',
        -text  => "Funktion konnte innerhalb der Entwicklungszeit\n"
          . 'nicht implemeniert werden.',
        -buttons => ['OK'],
        -bitmap  => 'warning'
    )->Show();

    #---------------------------------------------------------------------------
    #  Packstube
    #---------------------------------------------------------------------------
    $frame_label_entry->pack( -fill => 'x', -expand => '1', -anchor => 'w' );
    $frame_label->pack( -side   => 'left' );
    $label_login->pack( -anchor => 'w' );
    $label_passwort->pack( -anchor => 'w' );
    $label_ip->pack( -anchor => 'w' );
    $label_port->pack( -anchor => 'w' );
    $frame_entry->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $entry_login->pack( -fill => 'x', -expand => '1' );
    $entry_passwort->pack( -fill => 'x', -expand => '1' );
    $entry_ip->pack( -fill => 'x', -expand => '1' );
    $entry_port->pack( -fill => 'x', -expand => '1' );
    $frame_button->pack( -fill => 'x', -expand => '1', -side => 'bottom' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );

    return;
}    # ----------  end of subroutine gui_webserver_konfig  ----------

#---------------------------------------------------------------------------
#  Subroutine: gui_sichern
#
#  Sichert den gesamten Inhalt des Projektordners in die angegebene MLR-Datei
#
#  Parameters:
#  $gui_parent   -   Toplevel-widget von aufrufender Funktion zum Anzeigen der Fehlermeldung
#---------------------------------------------------------------------------
sub gui_sichern {
    my ($gui_parent) = @_;

    # das Toplevel-widget der aufrufenden FUnktion wird benötigt, da
    # Fehlermeldung angezeigt werden muss, bevor das aktuelle widget
    # aufgebaut wird.

    # hole alle Pflichtenheftpfade aus dem Hash %pfade
    my @export_pfade;
    foreach my $phefte ( values %pfade ) {
        if ( $phefte ne 'ordner' ) {
            push @export_pfade, $phefte;
        }
    }

    # Wenn keine Pflichtenhefte vorhanden, Meldung und raus
    if ( not $export_pfade[0] ) {
        $gui_parent->Dialog(
            -title => 'Achtung',
            -text => "Es sind keine Pflichtenhefte\n" . 'zum Sichern vorhanden',
            -buttons => ['OK'],
            -bitmap  => 'warning'
        )->Show();
        return;
    }

    my $gui = $mw->Toplevel( -title => 'Pfad auswählen' );
    my ( $frame_dname, $label_dname, $dname, $entry_dname, $button_dname,
        $button_erstellen, $button_abbrechen );

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 100;
    modal( \$gui, $BREITE, $HOEHE );

    $frame_dname  = $gui->Frame();
    $label_dname  = $frame_dname->Label( -text => 'Dateiname: ' );
    $entry_dname  = $frame_dname->Entry( -textvariable => \$dname );
    $dname        = File::HomeDir->my_home();
    $button_dname = $frame_dname->Button(
        -image   => $pic_oeffne,
        -command => sub {

            # Auswahl des Dateipfades
            my $dialog = $frame_dname->FileDialog(
                -FPat  => '*mlr',
                -Title => 'Dateinamen und Pfad wählen',
            );
            $dname = $dialog->Show();
            $entry_dname->focus();
            $entry_dname->focusNext();
        }
    );

    # Das binding ist identisch dem von gui_speichern
    $entry_dname->bind( '<KeyRelease>',
        [ \&bind_rechte_speichern, \$button_erstellen ] );
    $entry_dname->bind( '<FocusOut>',
        [ \&bind_rechte_speichern, \$button_erstellen ] );
    my $frame_button = $gui->Frame();
    $button_erstellen = $frame_button->Button(
        -text     => 'Speichern',
        -image    => $pic_export,
        -compound => 'left',
        -state    => 'disabled',
        -command  => \sub {

            # alle Pflichtenhefte speichern
            my $mlr = MoliriMLR->new($dname);
            $mlr->export_mlr(@export_pfade);
            $gui->destroy();
        }
    );

    $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    $frame_dname->pack( -fill => 'x', -expand => '1' );
    $label_dname->pack( -side => 'left' );
    $entry_dname->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $button_dname->pack( -side => 'left' );

    $frame_button->pack( -fill => 'x', -side => 'bottom' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine gui_speichern  ----------

#---------------------------------------------------------------------------
#   Subroutine: gui_wiederherstellen
#
#   Löscht alle Pflichtenhefte aus einem Ordner und ersetzt sie mit
#   denen aus der ausgewählten MLR-Datei.
#---------------------------------------------------------------------------
sub gui_wiederherstellen {
    my $gui = $mw->Toplevel( -title => 'Pflichtenheft auswählen' );

    my ( $frame_dname, $label_dname, $dname, $entry_dname, $button_dname,
        $button_erstellen, $button_abbrechen );

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 100;

    modal( \$gui, $BREITE, $HOEHE );

    $gui->Label( -text =>
"Bitte mlr. Datei auswählen, aus der wiederhergestellt \nwerden soll "
    )->pack( -side => 'top' );

    $frame_dname  = $gui->Frame();
    $label_dname  = $frame_dname->Label( -text => 'Dateiname: ' );
    $entry_dname  = $frame_dname->Entry( -textvariable => \$dname );
    $dname        = File::HomeDir->my_home();
    $button_dname = $frame_dname->Button(
        -image   => $pic_oeffne,
        -command => sub {
            my $dialog = $frame_dname->FileDialog(
                -Title => 'Dateinamen und Pfad wählen',
                -FPat  => '*mlr',
            );
            $dname = $dialog->Show();
            $entry_dname->focus();
            $entry_dname->focusNext();
        }
    );

    $entry_dname->focus();
    $entry_dname->bind( '<KeyRelease>',
        [ \&bind_rechte_wiederherstellen, \$button_erstellen ] );
    $entry_dname->bind( '<FocusOut>',
        [ \&bind_rechte_wiederherstellen, \$button_erstellen ] );

    my $frame_button = $gui->Frame();
    $button_erstellen = $frame_button->Button(
        -text     => 'Laden',
        -image    => $pic_import,
        -compound => 'left',
        -state    => 'disabled',
        -command  => \sub {
            my $check = alles_loeschen($gui);

            # Wenn Rückgabewert 2 dann wurde alles gelöscht und es kann
            # importiert werden
            if ( $check eq '2' ) {
                my $mlr    = MoliriMLR->new($dname);
                my @phefte = $mlr->check_mlr();
                $mlr->import_mlr( ${$konfiguration}{'aordner'}, @phefte );
                $gui->destroy();
                baum_aktualisieren();
            }
        },
    );

    $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    $frame_dname->pack( -fill => 'x', -expand => '1' );
    $label_dname->pack( -side => 'left' );
    $entry_dname->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $button_dname->pack( -side => 'left' );

    $frame_button->pack( -fill => 'x', -side => 'bottom' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine gui_wiederherstellen  ----------

#---------------------------------------------------------------------------
#   Subroutine: gui_export_odt
#
#   Dialog zum Exportieren von Pflichtenheften. Dieser Dialog ähnlich wie
#   der von <gui_speichern>, nur mit Radio- anstatt Checkbuttons, da immer nur
#   ein Pflichtenheft exportiert werden kann.
#---------------------------------------------------------------------------
sub gui_export_odt {
    my ($par1) = @_;
    my $gui = $mw->Toplevel( -title => 'Pflichtenheft exportieren -> ODT' );

    my ( $frame_dname, $label_dname, $dname, $entry_dname, $button_dname,
        $button_erstellen, $button_abbrechen );

    my ($a) = $tree->info('selection');

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 300;
    modal( \$gui, $BREITE, $HOEHE );
    $gui->Label( -text =>
          "Bitte das Pflichtenheft wählen, dass exportiert \nwerden soll " )
      ->pack( -side => 'top' );

    my $auswahl = undef;
    my $frame_scrld =
      $gui->Scrolled( 'Frame', -sticky => 'nw', -scrollbars => 'oe' );
    foreach my $ordner ( $tree->child_entries() ) {

        #Für jedes Pflichtenheft ...
        $frame_scrld->Label( -text => $ordner )->pack( -anchor => 'w' );
        foreach my $datei ( $tree->child_entries($ordner) ) {

            # ... alle Versionen
            my $name = substr $datei, ( index $datei, q{/} ) + 1;
            $name = substr $name, 0, ( rindex $name, '.xml' );
            my $tmp_cb = $frame_scrld->Radiobutton(
                -text     => $name,
                -value    => $ordner . q{/} . $name,
                -variable => \$auswahl,
            )->pack( -anchor => 'w', -padx => '30', -side => 'top' );
            $tmp_cb->bind( '<ButtonPress>',
                [ \&bind_auswahl_radio, \$auswahl, \$entry_dname ] );

            # Wenn eine Pflichtenheftversion bereits markiert wurde
            # dann setze den Radiobutton bereits diesen Eintrag
            if ( $a and $tmp_cb->cget('-value') . '.xml' eq $a ) {
                $auswahl = $a;
                $tmp_cb->select();
            }
        }
    }

    $frame_dname = $gui->Frame();
    $label_dname = $frame_dname->Label( -text => 'Dateiname: ' );
    $entry_dname =
      $frame_dname->Entry( -textvariable => \$dname, -state => 'disabled' );
    $dname        = File::HomeDir->my_home();
    $button_dname = $frame_dname->Button(
        -image   => $pic_oeffne,
        -command => sub {

            # Auswahl des Dateipfades
            if ( $entry_dname->cget( -state ) eq 'normal' ) {
                my $dialog = $frame_dname->FileDialog(
                    -FPat  => '*odt',
                    -Title => 'Dateinamen und Pfad wählen',
                );
                $dname = $dialog->Show();
                $entry_dname->focus();
                $entry_dname->focusNext();
            }
        }
    );

    $entry_dname->bind( '<KeyRelease>',
        [ \&bind_rechte_speichern, \$button_erstellen ] );
    $entry_dname->bind( '<FocusOut>',
        [ \&bind_rechte_speichern, \$button_erstellen ] );
    my $frame_button = $gui->Frame();
    $button_erstellen = $frame_button->Button(
        -text     => 'Export',
        -image    => $pic_export,
        -compound => 'left',
        -state    => 'disabled',
        -command  => \sub {

            # Hole Einträge Hash mit ausgewähltem Eintrag aus der
            # XML-Datei und übergebe ihn an MoliriODT zum Export
            my $xml = MoliriXML->new(
                ${$konfiguration}{'aordner'} . q{/} . $auswahl . '.xml' );
            my $ref_pflicht = $xml->import_xml();
            print $auswahl;
            my $odt = MoliriODT->new($dname);
            $odt->export_odt( %{$ref_pflicht} );
            $gui->destroy();
        },
    );

    $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );
    if ($auswahl) {
        bind_auswahl_radio( 'foo', \$auswahl, \$entry_dname );
        $entry_dname->focus();
    }

    $frame_scrld->pack(
        -fill   => 'both',
        -expand => '1',
        -anchor => 'w',
        -side   => 'top'
    );
    $frame_dname->pack( -fill => 'x', -expand => '1' );
    $label_dname->pack( -side => 'left' );
    $entry_dname->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $button_dname->pack( -side => 'left' );

    $frame_button->pack( -fill => 'x', -side => 'bottom' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine export_odt  ----------

#---------------------------------------------------------------------------
#   Subroutine: gui_export_txt
#
#   Dialog zum Exportieren von Pflichtenheften. Dieser Dialog ist ähnlich
#   wie <gui_export_odt>. Nur hier wird ins Textformat exportiert.
#---------------------------------------------------------------------------
sub gui_export_txt {
    my $gui = $mw->Toplevel( -title => 'Pflichtenheft exportieren -> TXT' );

    my ( $frame_dname, $label_dname, $dname, $entry_dname, $button_dname,
        $button_erstellen, $button_abbrechen );

    my ($a) = $tree->info('selection');

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 300;
    modal( \$gui, $BREITE, $HOEHE );

    $gui->Label( -text =>
          "Bitte das Pflichtenheft wählen, dass exportiert \nwerden soll " )
      ->pack( -side => 'top' );

    my $auswahl = undef;
    my $frame_scrld =
      $gui->Scrolled( 'Frame', -sticky => 'nw', -scrollbars => 'oe' );
    foreach my $ordner ( $tree->child_entries() ) {

        #Für jedes Pflichtenheft ...
        $frame_scrld->Label( -text => $ordner )->pack( -anchor => 'w' );
        foreach my $datei ( $tree->child_entries($ordner) ) {

            # ... alle Versionen
            my $name = substr $datei, ( index $datei, q{/} ) + 1;
            $name = substr $name, 0, ( rindex $name, '.xml' );
            my $tmp_cb = $frame_scrld->Radiobutton(
                -text     => $name,
                -value    => $ordner . q{/} . $name,
                -variable => \$auswahl,
            )->pack( -anchor => 'w', -padx => '30', -side => 'top' );
            $tmp_cb->bind( '<ButtonPress>',
                [ \&bind_auswahl_radio, \$auswahl, \$entry_dname ] );
            if ( $a and $tmp_cb->cget('-value') . '.xml' eq $a ) {
                $auswahl = $a;
                $tmp_cb->select();
            }
        }
    }

    $frame_dname = $gui->Frame();
    $label_dname = $frame_dname->Label( -text => 'Dateiname: ' );
    $entry_dname =
      $frame_dname->Entry( -textvariable => \$dname, -state => 'disabled' );
    $dname        = File::HomeDir->my_home();
    $button_dname = $frame_dname->Button(
        -image   => $pic_oeffne,
        -command => sub {

            # Auswahl des Dateipfades
            if ( $entry_dname->cget( -state ) eq 'normal' ) {
                my $dialog = $frame_dname->FileDialog(
                    -FPat  => '*txt',
                    -Title => 'Dateinamen und Pfad wählen'
                );
                $dname = $dialog->Show();
                $entry_dname->focus();
                $entry_dname->focusNext();
            }
        }
    );

    $entry_dname->bind( '<KeyRelease>',
        [ \&bind_rechte_speichern, \$button_erstellen ] );
    $entry_dname->bind( '<FocusOut>',
        [ \&bind_rechte_speichern, \$button_erstellen ] );
    my $frame_button = $gui->Frame();
    $button_erstellen = $frame_button->Button(
        -text     => 'Export',
        -image    => $pic_export,
        -compound => 'left',
        -state    => 'disabled',
        -command  => \sub {
            my $xml = MoliriXML->new(
                ${$konfiguration}{'aordner'} . q{/} . $auswahl . '.xml' );
            my $ref_pflicht = $xml->import_xml();
            print $auswahl;
            my $txt = MoliriTXT->new($dname);
            $txt->export_txt( %{$ref_pflicht} );
            $gui->destroy();
        },
    );

    $button_abbrechen = $frame_button->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Abbrechen',
        -command  => \sub {
            $gui->destroy();
        },
    );
    if ($auswahl) {
        bind_auswahl_radio( 'foo', \$auswahl, \$entry_dname );
        $entry_dname->focus();
    }
    $frame_scrld->pack(
        -fill   => 'both',
        -expand => '1',
        -anchor => 'w',
        -side   => 'top'
    );
    $frame_dname->pack( -fill => 'x', -expand => '1' );
    $label_dname->pack( -side => 'left' );
    $entry_dname->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $button_dname->pack( -side => 'left' );

    $frame_button->pack( -fill => 'x', -side => 'bottom' );
    $button_erstellen->pack( -side => 'left' );
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine export_txt  ----------

#---------------------------------------------------------------------------
#  nicht implementiert
#---------------------------------------------------------------------------
sub gui_export_latex {
    my ($par1) = @_;
    $mw->Dialog(
        -title => 'Fehler',
        -text  => "Der Export in LaTeX konnte während der\n"
          . 'Entwicklungszeit nicht implementiert werden',
        -buttons => ['OK'],
        -bitmap  => 'warning'
    )->Show();

    #---------------------------------------------------------------------------
    #  TODO : Export in latex konnte nicht mehr realisiert werden.
    #---------------------------------------------------------------------------

    return;
}

#---------------------------------------------------------------------------
#   Subroutine: gui_info_box
#
#   Erstellt den Dialog der Infobox
#---------------------------------------------------------------------------
sub gui_info_box {
    my $gui = $mw->Toplevel( -title => 'Version' );

    Readonly my $BREITE => 400;
    Readonly my $HOEHE  => 350;
    modal( \$gui, $BREITE, $HOEHE );

    my $pic_moliri  = $mw->Photo( -file => 'img/moliri_help.png' );
    my $pic_moliri2 = $mw->Photo( -file => 'img/moliri_help2.png' );
    my $lab_pic_gross = $gui->Label( -image => $pic_moliri );
    my $lab_titel =
      $gui->Label( -text => 'Moliri - Pflichtenheftgenerator 0.2' );
    my $autor    = $gui->Label( -text => 'Autor : Alexandros Kechagias' );
    my $notebook = $gui->NoteBook();
    my $tab1     = $notebook->add( 'ueber', -label => 'Über' );
    my $tab2     = $notebook->add( 'module', -label => 'Verwendete Software' );
    my $tab3     = $notebook->add( 'lizenz', -label => 'Lizenz' );
    my $tab1_frame      = $tab1->Frame();
    my $tab1_lab_pic    = $tab1_frame->Label( -image => $pic_moliri2 );
    my $tab1_lab_beschr = $tab1_frame->Label(
        -text => " Moliri - Pflichtenheftgenerator ist freie Software\n\n"
          . "Er enstand im Rahmen einer Diplomarbeit für die\n"
          . "Fachhochschule Südwestfalen. Moliri ermöglicht\n"
          . "das Erstellen von Pflichtenheften, sowie den\n"
          . "Export als ODF oder Text Dokument.\n",
        -justify => 'left'
    );
    my @software = (
        "Perl\t\tLarry Wall",
        "Tk\t\tNick Ing-Simmons, Slaven Rezic",
        "Tk::MatchEntry\tWolfgang Hommel",
        "Tk::DateEntry\tHans J. Helgesen, Slaven Rezic",
        "Tk::ComboEntry\tDamion K. Wilson",
        "Image::Size\tRandy J. Ray",
        "OpenOffice::OODoc\tJean-Marie Gouarne",
        "XML::LibXML\tMatt Sergeant, Christian Glahn, Petr Pajas",
        "XML::Writer\tDavid Megginson, Joseph Walton",
        "File::HomeDir\tA. Kennedy, S.M. Burke, C.Nandor, S.Steneker",
        "Linux::APT\tMegagram",
        "Archive::Zip\tAdam Kennedy, Steve Peters, Ned Konz",
        "Oxygen Icons\tKDE-Icons",
        "TeX-, Text-Icon\tMarco Martin (Glaze Icons)",
        "Odt-Icon\tThe Document Foundation",
    );
    my @links = (
        'http://www.perl.org/',
        'http://search.cpan.org/~srezic/Tk-804.028/',
        'http://search.cpan.org/~whom/Tk-MatchEntry-0.4/MatchEntry.pm',
        'http://search.cpan.org/~srezic/Tk-DateEntry-1.39/',
        'http://search.cpan.org/~dkwilson/Tk-DKW-0.03/Tk/ComboEntry.pm',
        'http://search.cpan.org/~rjray/Image-Size-3.220/',
        'http://search.cpan.org/~jmgdoc/OpenOffice-OODoc-2.112/',
        'http://search.cpan.org/~pajas/XML-LibXML-1.70/',
        'http://search.cpan.org/~josephw/XML-Writer-0.605/',
        'http://search.cpan.org/~adamk/File-HomeDir-0.86/',
        'http://search.cpan.org/~wilsond/Linux-APT-0.02/',
        'http://search.cpan.org/~adamk/Archive-Zip-1.30/',
        'http://www.oxygen-icons.org/',
        'http://www.iconarchive.com/show/glaze-icons-by-mart/tex-icon.html',
'http://wiki.documentfoundation.org/Design/LibreOffice_Initial_Icons#Present_State_of_the_Icon_Design',
    );
    my $scr_frame = $tab2->Scrolled( 'Frame', -scrollbars => 'se' );

    foreach ( 0 .. scalar @software - 1 ) {
        my $tmp_frame =
          $scr_frame->Frame()->pack( -fill => 'x', -expand => '1' );
        $tmp_frame->Label(
            -text    => $software[$ARG],
            -justify => 'left',
        )->pack( -side => 'left', -anchor => 'w' );
        my $link = $tmp_frame->Button(
            -textvariable => \$links[$ARG],
            -fg           => '#0000FF',
            -relief       => 'flat',
            -height       => '1',
            -command      => sub { system 'gnome-open', $links[$ARG] },
        )->pack( -side => 'left' );
    }
    my $gpl = q{
Moliri - Pflichtenheftgenerator
Copyright (C) 2011  Alexandros Kechagias

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

            -- DEUTSCHE ÜBERSETZUNG --
Diese Übersetzung ist kein rechtskräftiger Ersatz für die 
englischsprachige Originalversion!

Dieses Programm ist freie Software. Sie können es unter den 
Bedingungen der GNU General Public License, wie von der Free 
Software Foundation veröffentlicht, weitergeben und/oder 
modifizieren, entweder gemäß Version 2 der Lizenz oder (nach Ihrer 
Option) jeder späteren Version.

Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es 
Ihnen von Nutzen sein wird, aber OHNE IRGENDEINE GARANTIE, sogar ohne 
die implizite Garantie der MARKTREIFE oder der VERWENDBARKEIT FÜR 
EINEN BESTIMMTEN ZWECK. Details finden Sie in der GNU General 
Public License.

Sie sollten ein Exemplar der GNU General Public License zusammen 
mit diesem Programm erhalten haben. Falls nicht, schreiben Sie 
an die Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, 
Boston, MA 02110, USA.
};
    my $lic_frame = $tab3->Scrolled( 'Frame', -scrollbars => 'se' );
    my $tab3_label = $lic_frame->Label( -text => $gpl, -justify => 'left' );
    my $button_abbrechen = $gui->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text     => 'Schließen',
        -command  => \sub {
            $gui->destroy();
        },
    );

    #---------------------------------------------------------------------------
    #  Packstube
    #---------------------------------------------------------------------------
    $lab_titel->pack();
    $lab_pic_gross->pack();
    $autor->pack();
    $notebook->pack();
    $tab1_frame->pack();
    $tab1_lab_pic->pack(
        -side   => 'left',
        -anchor => 'n',
        -padx   => '9',
        -pady   => '30'
    );
    $tab1_lab_beschr->pack( -side => 'top', -anchor => 'w', -pady => '25' );
    $notebook->pack( -fill => 'both', -expand => '1' );
    $scr_frame->pack( -fill => 'both', -expand => '1' );
    $lic_frame->pack( -fill => 'both', -expand => '1' );
    $tab3_label->pack();
    $button_abbrechen->pack( -side => 'bottom' );
    return;
}    # ----------  end of subroutine gui_info_box  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_rechte_wiederherstellen
#
#   In diesem binding wird der Pfad der im Entry eingegeben wird auf
#   gültigkeit überprüft. Überprüft wird ob er existriert, kein Verzeichnis,
#   lesbar und MLR-Suffix hat.
#
#   *Nicht gültig:*
#   - Button wird deaktiviert
#   - Hintergrundfarbe des Entrys '#ff9696' ( helles rot )
#
#   *Gültig*
#   - Button wird aktiviert
#   - Hintergrundfarbe des Entrys 'snow1'
#
#   Parameters:
#
#   $e_widget         - aufrufendes Entry
#   $button_erstellen - Button des aufrufendes Dialoges
#---------------------------------------------------------------------------
sub bind_rechte_wiederherstellen {
    my ( $e_widget, $button_erstellen ) = @_;

    my $pfad = $e_widget->get();

    # Wenn Pfad existiert, kein Verzeichnis, lesbar und mlr-suffix hat
    if ( -e $pfad and not -d $pfad and -r $pfad and $pfad =~ /\.mlr$/ ) {

        # Hintergrund auf 'snow1' setzen
        $e_widget->configure( -background => 'snow1' );
        ${$button_erstellen}->configure( -state => 'normal' );
    }
    else {
        $e_widget->configure( -background => '#ff9696' );   #(RGB)ein helles rot
        ${$button_erstellen}->configure( -state => 'disabled' );
    }

    return;
}    # ----------  end of subroutine bind_rechte_speichern  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_rechte_laden
#
#   Überprüft den übergebenen Pfad auf Gültigkeit und baut dynamisch die
#   Checkboxen auf. Überprüft wird ob Pfad existiert, kein Verzeichnis,
#   lesbar und MLR-Suffix hat
#
#   *Nicht Gültig*
#   - Button wird deaktiviert
#   - Hintergrundfarbe des Entrys '#ff9696' ( helles rot )
#   - alle Checkboxen löschen
#
#   *Gültig*
#   - Baue die Checkboxen mit dem Inhalt der MLR-Datei auf
#   - Button wird aktiviert
#   - Hintergrundfarbe des Entrys 'snow1'
#
#   Parameters:
#
#   $e_widget         - aufrufendes Entry
#   $button_erstellen - Button der aufrufenden Entrys
#   $frame_scrld      - Scrollbarer Frame des aufrufenden Entrys
#   $auswahl          - Hashreferenz damt die aufrufende Funktion weiß, welche
#                       Pflichtenhefte ausgesucht wurden
#
#---------------------------------------------------------------------------
sub bind_rechte_laden {
    my ( $e_widget, $button_erstellen, $frame_scrld, $auswahl ) = @_;

    my $pfad = $e_widget->get();

    if ( $pfad =~ /\/$/ ) {
        chop $pfad;
    }
    %{$auswahl} = ();

    # Wenn Pfad existiert, kein Verzeichnis, lesbar und mlr-suffix hat
    if ( -e $pfad and not -d $pfad and -r $pfad and $pfad =~ /\.mlr$/ ) {

        my $mlr      = MoliriMLR->new($pfad);
        my @phefte   = $mlr->check_mlr();
        my $tmp_name = $EMPTY;

        #Oberfläche vorher freiräumen
        foreach my $s ( ${$frame_scrld}->packSlaves() ) {
            if ( $s->class() eq 'Pane' ) {
                foreach my $widget ( $s->packSlaves() ) {
                    $widget->destroy();
                }
            }
        }

        foreach my $datei ( sort @phefte ) {
            my ( $ordner, $name ) = split m/[\/]/, $datei;
            if ( $tmp_name ne $ordner ) {
                ${$frame_scrld}->Label( -text => $ordner )
                  ->pack( -anchor => 'w' );
                $tmp_name = $ordner;
            }
            my $tmp_cb = ${$frame_scrld}->Checkbutton(
                -text     => $name,
                -onvalue  => $datei,
                -offvalue => undef,
                -variable => \${$auswahl}{$datei},
            )->pack( -anchor => 'w', -padx => '30', -side => 'top' );
            $tmp_cb->bind( '<ButtonPress>',
                [ \&bind_auswahl_check_import, $button_erstellen, $auswahl ] );
        }

        # Hintergrund auf 'snow1' setzen
        $e_widget->configure( -background => 'snow1' );
    }
    else {

        #Wenn keine gültige Datei Oberfläche freiräumen
        foreach my $s ( ${$frame_scrld}->packSlaves() ) {
            if ( $s->class() eq 'Pane' ) {
                foreach my $widget ( $s->packSlaves() ) {
                    $widget->destroy();
                }
            }
        }
        $e_widget->configure( -background => '#ff9696' );   #(RGB)ein helles rot
        ${$button_erstellen}->configure( -state => 'disabled' );

    }

    return;
}    # ----------  end of subroutine bind_rechte_speichern  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_auswahl_check_import
#
#   Überprüft ob irgend ein Checkbutton gedrückt wurde.
#
#   *Ein Checkbutton wurde gedrückt*
#   - Button wird aktiviert
#
#   *Checkbutton wurde nicht gedrückt*
#   - Button wird nicht aktiviert
#
#   Parameters:
#
#   $e_widget         - aufrufendes Entry
#   $button_erstellen - Button der aufrufenden Entrys
#   $auswahl          - Hashreferenz beinhaltet die Auswahl des Benutzers
#
#---------------------------------------------------------------------------
sub bind_auswahl_check_import {
    my ( $e_widget, $button_erstellen, $auswahl ) = @_;
    foreach ( keys %{$auswahl} ) {

        # Wenn Eintrag ausgewählt, Button deaktivieren
        if ( ${$auswahl}{$ARG} ) {
            ${$button_erstellen}->configure( -state => 'normal' );
            last;
        }
        else {
            ${$button_erstellen}->configure( -state => 'disabled' );
        }
    }
    return;
}    # ----------  end of subroutine bind_auswahl_check_import  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_rechte_speichern
#
#   Überprüft den übergebenen Pfad auf Gültigkeit. Überprüft wird ob Pfad
#   existiert, kein Verzeichnis und beschreibbar ist.
#
#   *Gültig*
#   - Button wird aktiviert
#
#   *Nicht gültig*
#   - Button wird nicht aktiviert
#
#   Parameters:
#
#   $e_widget         - aufrufendes Entry
#   $button_erstellen - Button der aufrufenden Entrys
#
#---------------------------------------------------------------------------
sub bind_rechte_speichern {
    my ( $e_widget, $button_erstellen ) = @_;

    my $pfad = $e_widget->get();

    if ( $pfad =~ /\/$/ ) {
        chop $pfad;
    }

    # Ordner ermitteln
    my $ordner = substr $pfad, 0, ( rindex $pfad, q{/} );

    # Wenn er existiert, kein Verszichnis und beschreibbar ist
    if ( -e $ordner and not -d $pfad and -w $ordner ) {

        #Hintergrund auf 'snow1' setzen
        $e_widget->configure( -background => 'snow1' );
        ${$button_erstellen}->configure( -state => 'normal' );
    }
    else {
        $e_widget->configure( -background => '#ff9696' );   #(RGB)ein helles rot
        ${$button_erstellen}->configure( -state => 'disabled' );
    }

    return;
}    # ----------  end of subroutine bind_rechte_speichern  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_rechte_config
#
#   Überprüft den übergebenen Pfad auf Gültigkeit. Überprüft wird ob Pfad
#   existiert, ein Verzeichnis und beschreibbar ist.
#
#   *Gültig*
#   - Button wird aktiviert
#
#   *Nicht gültig*
#   - Button wird nicht aktiviert
#
#   Parameters:
#
#   $e_widget         - aufrufendes Entry
#   $button_erstellen - Button der aufrufenden Entrys
#
#---------------------------------------------------------------------------
sub bind_rechte_config {
    my ( $e_widget, $button_erstellen ) = @_;

    my $pfad = $e_widget->get();

    if ( $pfad =~ /\/$/ ) {
        chop $pfad;
    }

    # Wenn er existiert, kein Pfad und beschreibbar ist
    if ( -e $pfad and -d $pfad and -w $pfad ) {

        # Hintergrund auf 'snow1' setzen
        $e_widget->configure( -background => 'snow1' );
        ${$button_erstellen}->configure( -state => 'normal' );
    }
    else {
        $e_widget->configure( -background => '#ff9696' );   #(RGB)ein helles rot
        ${$button_erstellen}->configure( -state => 'disabled' );
    }

    return;
}    # ----------  end of subroutine bind_rechte_config  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_pheft_check
#
#   Überprüft wird ob das im Entry angegebene Pflichtenheft nicht bereits
#   vorhanden ist und eine Version angegeben wurde.
#
#   *Pflichtenheft bereits vorhanden*
#   - Die Hintergrundfarbe vom Pflichtenheft-Entry auf rot
#   - Button deaktivieren
#
#   *Pflichtenheft OK aber Version nicht angegeben*
#   - Die Hintergrundfarbe vom Pflichtenheft-Entry auf weiss
#   - Die Hintergrundfarbe vom Versions-Entry auf rot
#   - Button deaktivieren
#
#   *Pflichtenheft bereits vorhanden aber Version OK*
#   - Die Hintergrundfarbe vom Pflichtenheft-Entry auf rot
#   - Die Hintergrundfarbe vom Versions-Entry auf weiss
#   - Button deaktivieren
#
#   *Pflichtenheft OK und Version OK*
#   - Die Hintergrundfarbe vom Versions-Entry auf weiss
#   - Die Hintergrundfarbe vom Pflichtenheft-Entry auf weiss
#   - Button aktivieren
#
#
#   Parameters:
#
#   $w                - aufrufendes Widget ( hier nicht genutzt )
#   $parameter_ref    - folgende Parameter wurden per Hash-Referenz übergeben:
#   pheft             - eingegebene Pflichtenheftbezeichnung
#   version           - eingegebene Pflichtenheftversion
#   button_erstellen  - zu kontrollierender Butoon
#   entry             - Pflichtenheft-Entry
#   ventry            - Versions-Entry
#   phefte            - Namen aller bereits vorhandenen Pflichtenhefte
#
#---------------------------------------------------------------------------
sub bind_pheft_check {
    my ( $w, $parameter_ref ) = @_;

    my $pheft            = ${$parameter_ref}{'pheft'};
    my $version          = ${$parameter_ref}{'version'};
    my $button_erstellen = ${$parameter_ref}{'button_erstellen'};
    my $entry            = ${$parameter_ref}{'entry'};
    my $ventry           = ${$parameter_ref}{'ventry'};
    my $phefte           = ${$parameter_ref}{'phefte'};

    if ( defined ${$pheft} ) {

        # Bereits vorhandene Pflichtenheftnamen nicht zulassen, da hier nur
        # neue Pflichtenhefte erzeugt werden.
        if ( ${$phefte}{ ${$pheft} } or ${$pheft} eq q{} ) {

            # Wenn ausgewähltes Pflichtenheft vorhanden,
            # Hintergrund auf rot setzen und deaktivieren des Erstellen-Buttons
            ${$entry}->configure( -background => '#ff9696' );
            ${$button_erstellen}->configure( -state => 'disabled' );
        }
        else {

            # Wenn ausgewähltes Pflichtenheft nicht vorhanden
            # Hintergrung wieder auf weiss setzen
            ${$entry}->configure( -background => 'ivory1' );

            # Wenn Versions-Entry definiert und nicht leer ist
            # aktiviere den Button
            if ( ${$version} and ${$version} ne q{} ) {
                ${$ventry}->configure( -background => 'ivory1' );

                if ( not ${$phefte}{ ${$pheft} } and ${$pheft} ne q{} ) {
                    ${$button_erstellen}->configure( -state => 'normal' );
                }

            }
            else {

                # Ansonsten deaktiviere den Button und setze den Hintergund
                # des Versions-Entrys auf rot
                ${$ventry}->configure( -background => '#ff9696' );
                ${$button_erstellen}->configure( -state => 'disabled' );
            }
        }
    }

    return;
}    # ----------  end of subroutine bind_pheft_check  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_auswahl_radio
#
#   Überprüft ob ein Radiobutton gedrückt wurde
#
#   *Ein Radiobutton gedrückt*
#   -Entry aktivieren
#
#   *Kein Radiobutton gedrückt*
#   -Entry deaktivieren
#
#   Parameters:
#   $w           - aufrufendes widget (nicht benutzt)
#   $auswahl     - Wert der von allen Radiobuttons benutzt wird, wenn er belegt
#                  ist, ist ein Radiobutton aktiviert.
#   $entry_dname - Entry
#
#---------------------------------------------------------------------------
sub bind_auswahl_radio {
    my ( $w, $auswahl, $entry_dname ) = @_;

    if ( ${$auswahl} ) {
        ${$entry_dname}->configure( -state => 'normal' );
        return;
    }
    else {
        ${$entry_dname}->configure( -state => 'disabled' );
    }
    return;
}    # ----------  end of subroutine bind_auswahl_radio  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_auswahl_check
#
#   Überprüft ob ein oder mehrere Checkbuttons aktiviert wurden
#
#   *Ein Radiobutton gedrückt*
#   - Entry aktivieren
#
#   *Kein Radiobutton gedrückt*
#   - Entry deaktivieren
#
#   Parameters:
#
#   $w           - aufrufendes widget (nicht benutzt)
#   $ref_auswahl - Wert der von allen Radiobuttons benutzt wird, wenn er belegt
#                  ist, ist ein Radiobutton aktiviert.
#   $entry_dname - Entry
#
#---------------------------------------------------------------------------
sub bind_auswahl_check {
    my ( $w, $ref_auswahl, $entry_dname ) = @_;
    foreach my $k ( keys %{$ref_auswahl} ) {
        if ( ${$ref_auswahl}{$k} ) {
            ${$entry_dname}->configure( -state => 'normal' );
            return;
        }
    }
    ${$entry_dname}->configure( -state => 'disabled' );

    return;
}    # ----------  end of subroutine bind_auswahl_check  ----------

#sub pflichtenheft_waehlen_gui {
#    my $gui = $mw->Toplevel( -title => 'Neue Version' );
#
#    #Fenster mittig positionieren
#    $gui->geometry('300x140');
#    $gui->geometry( '+'
#          . int( $screen_width / 2 - 300 / 2 ) . '+'
#          . int( $screen_height / 2 - 150 / 2 ) );
#
#    $gui->raise($mw);
#    $gui->grab();    #macht Fenster modal
#    my $auswahl = 'wat wat';
#    foreach ( keys %pfade ) {
#
#        # Ordner sind bennant nach den Pflichtenheften
#        if ( $pfade{$ARG} eq 'ordner' ) {    # Wenn Ordner
#            print "$ARG\n";
#
#            #Erstelle Radiobuttun mit dem Namen vom Ordner
#            $gui->Radiobutton(
#                -text         => $ARG,
#                -value        => $ARG,
#                -textvariable => \$auswahl,
#            )->pack( -anchor => 'center', -padx => '10' );
#        }
#    }
#
#    my $frame_button = $gui->Frame();
#    my $button_ok    = $frame_button->Button(
#        -text     => 'OK',
#        -image    => $pic_ok,
#        -compound => 'left',
#        -command  => \sub {
#            $gui->destroy();
#            return ($auswahl);
#        }
#    );
#    my $button_abbrechen = $frame_button->Button(
#        -text    => 'Abbrechen',
#        -command => \sub {
#            $gui->destroy();
#        },
#    );
#
#    #---------------------------------------------------------------------------
#    #  Packstube
#    #---------------------------------------------------------------------------
#    $frame_button->pack( -fill => 'x', -expand => '1' );
#    $button_ok->pack( -side => 'left' );
#    $button_abbrechen->pack( -side => 'right' );
#    return;
#}    # ----------  end of subroutine pflichtenheft_waehlen_gui  ----------

#---------------------------------------------------------------------------
#  Subroutine: bind_version_check
#
#   Es wird überprüft ob das angegebene Pflichtenheft vorhanden
#   und die Versionnummer dazu nicht bereits vergeben ist.
#
#   *Pflichtenheft nicht vorhanden*
#   - Die Hintergrundfarbe vom Pflichtenheft-Entry auf rot
#   - 'Inhalt kopieren aus'-ComboEntry deaktivieren ($oldv_combo)
#   - Button deaktivieren
#
#   *Pflichtenheft OK aber Version nicht angegeben*
#   - Die Hintergrundfarbe vom Pflichtenheft-Entry auf weiss
#   - Die Hintergrundfarbe vom Versions-Entry auf rot
#   - Button deaktivieren
#
#   *Pflichtenheft nicht vorhanden aber Version OK*
#   - Die Hintergrundfarbe vom Pflichtenheft-Entry auf rot
#   - Die Hintergrundfarbe vom Versions-Entry auf weiss
#   - 'Inhalt kopieren aus'-ComboEntry deaktivieren ($oldv_combo)
#   - Button deaktivieren
#
#   *Pflichtenheft OK und Version OK*
#   - Die Hintergrundfarbe vom Versions-Entry auf weiss
#   - Die Hintergrundfarbe vom Pflichtenheft-Entry auf weiss
#   - Button aktivieren
#
#
#   Parameters:
#
#   $w               - aufrufendes Widget ( hier nicht genutzt )
#   $parameter_ref   - folgende Parameter wurden per Hash-Referenz übergeben:
#   p_combo          - ComboEntry zur Auswahl des Pflichtenhefts
#   v_entry          - Versions-Entry
#   phefte           - Namen aller bereits vorhandenen Pflichtenhefte
#   versionen        - alle Versionen zu einem Pflichtenheft
#   pheft            - eingegebene Pflichtenheftbezeichnung
#   version          - eingegebene Pflichtenheftversion
#   button_erstellen - zu kontrollierender Butoon
#   oldv_combo       - ComboEntry zur Auswahl der zu kopierenden Version
#   old_version      - Variable mit der zu kopierenden Version
#
#---------------------------------------------------------------------------
sub bind_version_check {
    my ( $w, $parameter_ref ) = @_;
    my $p_combo          = ${$parameter_ref}{'p_combo'};
    my $v_entry          = ${$parameter_ref}{'v_entry'};
    my $phefte           = ${$parameter_ref}{'phefte'};
    my $versionen        = ${$parameter_ref}{'versionen'};
    my $pheft            = ${$parameter_ref}{'pheft'};
    my $version          = ${$parameter_ref}{'version'};
    my $button_erstellen = ${$parameter_ref}{'button_erstellen'};
    my $oldv_combo       = ${$parameter_ref}{'oldv_combo'};
    my $old_version      = ${$parameter_ref}{'old_version'};

    if ( defined ${$pheft} ) {

        # Nur bereits vorhandene Pflichtenhefte zulassen, da hier nur Versionen
        # den Pflichtenheften hinzugefügt werden und keine neun Pflichtenhefte
        # erstellt werden
        if ( not ${$phefte}{ ${$pheft} } or ${$phefte}{ ${$pheft} } eq q{} ) {

            # Wenn ausgewähltes Pflichtenheft nicht vorhanden,
            # Hintergrund auf rot setzen und deaktivieren des Erstellen-Buttons
            # und der Versionsbox.
            ${$p_combo}->configure( -background => '#ff9696' );
            ${$button_erstellen}->configure( -state => 'disabled' );
            ${$oldv_combo}->configure( -state => 'disabled' );
        }
        else {

            # Wenn ausgewähltes Pflichtenheft vorhanden,
            # Hintergrung auf weiss setzen und aktivieren des Erstellen-Buttons
            # und Versionsbox mit den Versionen des ausgesuchten Pflichtenheftes
            # füllen
            ${$p_combo}->configure( -background => 'ivory1' );
            ${$oldv_combo}->configure( -state => 'normal' );
            my @temp_versionen = keys %{ ${$versionen}{ ${$pheft} } };

          # Dateieundung '.xml' in allen Elementen von @temp_version abschneiden
            @temp_versionen =
              map { substr $ARG, 0, ( rindex $ARG, '.xml' ) } @temp_versionen;
            ${$oldv_combo}->configure( -itemlist => \@temp_versionen );
            if ( defined ${$version} ) {

                #Bereits vorhandene Versionen oder leere Eingabe nicht zulassen
                if (   ${$versionen}{ ${$pheft} }{ ${$version} . '.xml' }
                    or ${$version} eq q{} )
                {
                    ${$v_entry}->configure( -background => '#ff9696' );
                    ${$button_erstellen}->configure( -state => 'disabled' );
                }
                else {
                    ${$v_entry}->configure( -background => 'ivory1' );
                    ${$button_erstellen}->configure( -state => 'normal' );
                }

                if ( defined ${$old_version} ) {

              #Nur vorhandene Versionenen zulassen und leere Eingabe da optional
                    if (
                        ${$version} ne
                        q{}    #nur wenn versionsbezeichnug angegeben
                        and
                        ${$versionen}{ ${$pheft} }{ ${$old_version} . '.xml' }
                        or ${$old_version} eq q{}
                      )
                    {
                        ${$oldv_combo}->configure( -background => 'white' );
                        ${$button_erstellen}->configure( -state => 'normal' );
                    }
                    else {
                        ${$oldv_combo}->configure( -background => '#ff9696' );
                        ${$button_erstellen}->configure( -state => 'disabled' );
                    }
                }
            }
        }
    }
    return;
}

#---------------------------------------------------------------------------
#   Subroutine: pflichtenheft_laden
#
#   Lädt das ausgewählte Pflichtenheft indem es moliri2.pl ausführt. Dazu
#   wird dem Programm der Pfad zur XML-Datei übergeben. Aus den globallen
#   Konfigurationseinstellungen ${$konfiguration}{'aan'} und
#   ${$konfiguration}{'azeit'} wird der Editieroberfläche gesagt ob das
#   automatische Speichern ('aan') aktiviert werden soll und in welchen
#   Intervallen ('azeit') in Minuten.
#
#   Parameters:
#
#   $par1_pfad - Pfad der geladen werden soll
#---------------------------------------------------------------------------
sub pflichtenheft_laden {
    my ($par1_pfad) = @_;
    my $pfad;

    # Wenn kein Pfad angegeben, nimm das aus der Baumansicht ausgewählte
    # Pflichtenheft
    if ($par1_pfad) {
        $pfad = $par1_pfad;
    }
    else {
        my @auswahl = $tree->info('selection');
        if ( not $auswahl[0] ) {
            return;
        }
        $pfad = $pfade{ $auswahl[0] };
    }

    # dies ist moeglich, da während des einlesens in Funktion 'eintrag'
    # gespeichert wird ob ein Eintrag ein Ordner ist.
    if ( $pfad ne 'ordner' ) {

        # Eintrag zur History hinzufügen
        my $mhistory = MoliriHistory->new( ${$konfiguration}{'aordner'} );
        $mhistory->history_hinzu($pfad);

        # Menü aktualisieren
        menu_aktualisieren();
        my @param =
          ( $pfad, ${$konfiguration}{'aan'}, ${$konfiguration}{'azeit'} );
        my $check = system './moliri2.pl', @param;
        if ( $CHILD_ERROR == -1 ) {
            print "failed to execute: $CHILD_ERROR!\n";
            $mw->Dialog(
                -title   => 'Fehler',
                -text    => "moliri2.pl konnte nicht ausgefüht werden\n",
                -buttons => ['OK'],
                -bitmap  => 'warning'
            )->Show();
        }

    }
    return;
}    # ----------  end of subroutine pflichtenheft_laden  ----------

#---------------------------------------------------------------------------
#   Subroutine: pflichtenheft_loeschen
#
#   Löscht wenn eine einzelne Pflichtenheftversion markiert ist, die einzelne
#   Version und wenn das Pflichtenheft selber markiert ist, das gesamte
#   Pflichtenheft inkl. aller Versionen. Das markierte Pflichtenheft wird
#   aus der Baumansicht geholt
#
#---------------------------------------------------------------------------
sub pflichtenheft_loeschen {

    # Welches Pflichtenheft wurde in der Baumansicht markiert?
    my @auswahl   = $tree->info('selection');
    my $temp_pfad = $pfade{ $auswahl[0] };

    # Ist es ein komplettes Pflichtenheft?
    if ( $temp_pfad eq 'ordner' ) {

        # Arbeitsordner + ausgewähler Ordner = Pflichtenheftordner
        my $pordner = ${$konfiguration}{'aordner'} . q{/} . $auswahl[0];

        # Wenn Ordner, Frage ob der gesamte Inhalt gelöscht werden soll
        my $antw = $mw->Dialog(
            -title => 'Achtung',
            -text  => "Es wird das Pflichtenheft $auswahl[0]"
              . " mit allen Versionen gelöscht.\nMöchten Sie fortfahren?",
            -buttons => [ 'Nein', 'Ja' ],
            -bitmap  => 'warning'
        )->Show();
        if ( $antw eq 'Ja' ) {
            rmtree($pordner);
        }
    }
    else {

        # Versionsnamen aus Pfad extrahieren
        my $version = substr $temp_pfad, ( rindex $temp_pfad, q{/} ) + 1;
        my $antw = $mw->Dialog(
            -title => 'Achtung',
            -text  => 'Es wird Version ' 
              . $version
              . " gelöscht.\nMöchten Sie fortfahren?",
            -buttons => [ 'Nein', 'Ja' ],
            -bitmap  => 'warning',
        )->Show();

        if ( $antw eq 'Ja' ) {

            # Pflichtenheftversion löschen
            if ( unlink $temp_pfad ) {

                # Wenn keine Versionen mehr dann den dazugehörigen
                # Pflichtenheftordner löschen . Ohne Abfrage da rmdir nur leere
                # Ordner löscht.
                rmdir substr $temp_pfad, 0, ( rindex $temp_pfad, q{/} );
            }
        }
    }
    menu_aktualisieren();
    baum_aktualisieren();

    return;
}    # ----------  end of subroutine pflichtenheft_loeschen  ----------

#---------------------------------------------------------------------------
#   Subroutine: alles_loeschen
#
#   Löscht alle Pflichtenhefte aus dem Projektverzeichnis.
#
#   Parameter:
#   $gui_parent - Toplevel Frame des aufrufenden Widgets
#
#   Returns:
#   2 - Alles OK
#---------------------------------------------------------------------------
sub alles_loeschen {
    my ($gui_parent) = @_;
    my @export_pfade;

    # Hole eine Liste aller Pflichtenhefte
    foreach my $phefte ( values %pfade ) {
        if ( $phefte eq 'ordner' ) {
            push @export_pfade, $phefte;
        }
    }

    # Wenn keine vorhanden sind dann raus
    if ( not $export_pfade[0] ) {
        $gui_parent->Dialog(
            -title   => 'Achtung',
            -text    => "Es sind keine Pflichtenhefte\nzum Löschen vorhanden",
            -buttons => ['OK'],
            -bitmap  => 'warning'
        )->Show();
        return (2);
    }

    # Noch einmal nachfragen
    my $antw = $gui_parent->Dialog(
        -title => 'Achtung',
        -text  => "Es werden alle Pflichtenhefte gelöscht\n"
          . 'Möchten Sie fortfahren?',
        -buttons => [ 'Nein', 'Ja' ],
        -bitmap  => 'warning'
    )->Show();

    # Wenn positiv bestätigt wird, alles löschen
    if ( $antw eq 'Ja' ) {
        foreach my $ordner ( $tree->child_entries() ) {
            my $pordner = ${$konfiguration}{'aordner'} . q{/} . $ordner;
            rmtree($pordner);
        }
        baum_aktualisieren();
        menu_aktualisieren();
        return (2);
    }
    return;
}    # ----------  end of subroutine alles_loeschen  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  menu_aktualisieren
#
#   Nach jedem Eintrag in der History ist es notwendig das gesamte
#   Menü noch einmal neu zu erstellen. Es wurde während der Entwicklungszeit
#   keine andere Möglichkeit gefunden einzelne Elemente, wie zum
#   Beispiel die Unterelemente des Verlaufs, zu löschen.
#-------------------------------------------------------------------------------
sub menu_aktualisieren {

    Readonly my $ANZ_EINTRAEGE => 4;

    # lösche alle Einträge
    $menubar->delete( 0, $ANZ_EINTRAEGE );

    #---------------------------------------------------------------------------
    #  $file
    #
    #  Beinhaltet 3 ausfaltbare Menüs (<$neu>, <$webserver>, <$history>).
    #  Sowie folgende Menüeinträge:
    #  - Neu
    #  - History
    #  - Laden
    #  - Speichern
    #  - Löschen
    #  - Webserver
    #  - Beenden
    #---------------------------------------------------------------------------
    my $file = $menubar->cascade( -label => '~Datei' );

    #---------------------------------------------------------------------------
    #  $config
    #
    #  Hat folgende Menüeinträge:
    #  - Webserver
    #  - Programm
    #  - Wartung
    #---------------------------------------------------------------------------
    my $config = $menubar->cascade( -label => '~Konfiguration' );

    #---------------------------------------------------------------------------
    #  $export
    #
    #  Hat folgende Menüeinträge:
    #  - ODF
    #  - LaTeX
    #  - Text
    #---------------------------------------------------------------------------
    my $export = $menubar->cascade( -label => 'E~xport' );

    #---------------------------------------------------------------------------
    #  $x_odt
    #
    #  Ruft Funktion <gui_export_odt> auf zum Exportieren ins ODT-Format
    #---------------------------------------------------------------------------
    my $x_odt = $export->command(
        -label    => 'ODT ...',
        -image    => $pic_odf,
        -compound => 'left',
        -command  => sub {
            gui_export_odt();
        },
    );

    #---------------------------------------------------------------------------
    #  $x_latex
    #
    #  Ruft Funktion <gui_export_latex> auf zum Exportieren ins LaTeX-Format
    #  *nicht implementiert*
    #---------------------------------------------------------------------------
    my $x_latex = $export->command(
        -label    => 'LaTeX ...',
        -image    => $pic_tex,
        -state    => 'disabled',
        -compound => 'left',
        -command  => sub {
            gui_export_latex();
        },
    );

    #---------------------------------------------------------------------------
    #  $x_text
    #
    #  Ruft Funktion <gui_export_txt> auf zum Exportieren ins Text-Format
    #---------------------------------------------------------------------------
    my $x_text = $export->command(
        -label    => 'Text ...',
        -image    => $pic_text,
        -compound => 'left',
        -command  => sub {
            gui_export_txt();
        },
    );

    #---------------------------------------------------------------------------
    #  $help
    #
    #  Hat folgende Menüeinträge:
    #  - Version
    #---------------------------------------------------------------------------
    my $help = $menubar->cascade( -label => '~Hilfe' );

    #---------------------------------------------------------------------------
    #  $neu
    #
    #  Untermenü von <$neu>, hat folgende Menüeinträge:
    #  - aus Pflichtenheft ...
    #  - aus Version ...
    #---------------------------------------------------------------------------
    my $neu = $file->cascade(
        -label     => 'Neu',
        -underline => 0,
        -compound  => 'left',
        -image     => $pic_neu,
    );

    #---------------------------------------------------------------------------
    #  $neu_pflicht
    #
    #  Ruft Funktion <gui_neues_pflichtenheft> zum Erstellen eines
    #  neuen Pflichtenheftes
    #---------------------------------------------------------------------------
    my $neu_pflicht = $neu->command(
        -label       => 'Pflichtenheft ...',
        -compound    => 'left',
        -command     => \&gui_neues_pflichtenheft,
        -accelerator => 'Strg-n',
    );

    #---------------------------------------------------------------------------
    #  $neu_version
    #
    #  Ruft Funktion <gui_neue_version> zum Erstellen einer
    #  neuen Pflichtenheftversion
    #---------------------------------------------------------------------------
    my $neu_version = $neu->command(
        -label   => 'Version ...',
        -command => \sub {
            gui_neue_version();
        },
        -compound    => 'left',
        -accelerator => 'Strg-Umsch-n',
    );

    #---------------------------------------------------------------------------
    #  $history
    #
    #  Zeigt den Verlauf der aufgerufenen Pflichtenhefte, wird über
    #  <verlauf_fuellen> gefüllt
    #---------------------------------------------------------------------------

    my $mhistory = MoliriHistory->new( ${$konfiguration}{'aordner'} );
    my @his_in   = $mhistory->history_rein();
    my $history  = $file->cascade(
        -label     => 'Verlauf',
        -underline => 0,
        -compound  => 'left',
        -image     => $pic_history,
    );
    verlauf_fuellen( $history, @his_in );

    $file->separator;

    #---------------------------------------------------------------------------
    #  $laden
    #
    #  Ruft den Dialog zum Laden des Pflichtenheftes auf über die Funktion
    #  <gui_laden>
    #---------------------------------------------------------------------------
    my $laden = $file->command(
        -label       => 'Laden ...',
        -compound    => 'left',
        -image       => $pic_import,
        -underline   => 0,
        -accelerator => 'Strg-l',
        -command     => \sub {
            gui_laden();
        }
    );

    #---------------------------------------------------------------------------
    #  $speichern
    #
    #  Ruft den Dialog zum Speichern des Pflichtenheftes auf über die Funktion
    #  <gui_speichern>
    #---------------------------------------------------------------------------
    my $speichern = $file->command(
        -label       => 'Speichern ...',
        -compound    => 'left',
        -image       => $pic_export,
        -underline   => 0,
        -accelerator => 'Strg-s',
        -command     => \sub {
            gui_speichern();
        }
    );

#---------------------------------------------------------------------------
#  $loeschen
#
#  Löscht das markierte Pflichtenheft über die Funktion <pflichtenheft_loeschen>
#---------------------------------------------------------------------------
    my $loeschen = $file->command(
        -label       => 'Löschen',
        -underline   => 0,
        -compound    => 'left',
        -accelerator => 'Strg-x',
        -image       => $pic_delete,
        -command     => \sub {
            pflichtenheft_loeschen();
        }
    );
    $file->separator;

    #---------------------------------------------------------------------------
    #  $webserver
    #
    #  *würde nicht implementiert*
    #  Untermenü von <$webserver>, hat folgende Menüeinträge:
    #  - Laden ...
    #  - Sichern ...
    #  - Löschen ...
    #---------------------------------------------------------------------------

    my $webserver = $file->cascade(
        -label     => 'Webserver',
        -underline => 0,
        -compound  => 'left',
        -state     => 'disabled',
        -image     => $pic_web,
    );

    #    my $w_laden = $webserver->command(
    #        -label     => 'Laden ...',
    #        -underline => 0,
    #        -compound  => 'left',
    #        -image     => $pic_web_down,
    #        -command   => \sub {
    #            gui_web_laden();
    #        }
    #    );
    #
    #    my $w_sichern = $webserver->command(
    #        -label     => 'Sichern ...',
    #        -underline => 0,
    #        -compound  => 'left',
    #        -image     => $pic_web_up,
    #        -command   => \sub {
    #            gui_web_laden();
    #        }
    #    );
    #
    #    my $w_loeschen = $webserver->command(
    #        -label     => 'Löschen ...',
    #        -underline => 0,
    #        -compound  => 'left',
    #        -image     => $pic_delete,
    #    );
    #    $file->separator();

    #---------------------------------------------------------------------------
    #  Beenden
    #---------------------------------------------------------------------------
    $file->command(
        -label       => 'Beenden',
        -accelerator => 'Strg-q',
        -underline   => 0,
        -command     => \&exit,
        -compound    => 'left',
        -image       => $pic_exit,
    );

    #---------------------------------------------------------------------------
    #  $config
    #
    #  Ist das Konfigurationsmenü und hat folgende Einträge:
    #  - Webserver
    #  - Programm
    #  - Wartung
    #---------------------------------------------------------------------------

    #---------------------------------------------------------------------------
    #  $c_server
    #
    #  Lädt das Menü zum Konfigurieren des Webservers über die
    #  Funktion <gui_webserver_konfig>
    #---------------------------------------------------------------------------
    my $c_server = $config->command(
        -label    => 'Webserver ...',
        -state    => 'disabled',
        -compound => 'left',
        -image    => $pic_oeffne_db,
        -command  => \sub {
            gui_webserver_konfig();
        },

    );

    #---------------------------------------------------------------------------
    #  $c_programm
    #
    #  Lädt das Menü zum Konfigurieren des Programms über die
    #  Funktion <gui_programm_konfig>
    #---------------------------------------------------------------------------
    my $c_programm = $config->command(
        -label       => 'Programm ...',
        -compound    => 'left',
        -image       => $pic_conf,
        -accelerator => 'Strg-k',
        -command     => \sub {
            gui_programm_konfig();
        },

    );

    #---------------------------------------------------------------------------
    #  $c_wartung
    #
    #  Lädt das Menü zur Wartung der Pflichtenhefte über die
    #  Funktion <gui_wartung>
    #---------------------------------------------------------------------------
    my $c_wartung = $config->command(
        -label       => 'Wartung ...',
        -compound    => 'left',
        -image       => $pic_wartung,
        -accelerator => 'Strg-w',
        -command     => \sub {
            gui_wartung();
        },

    );

    #---------------------------------------------------------------------------
    #  $version
    #
    #  Lädt den Infodialog über die Funktion <gui_info_box>
    #---------------------------------------------------------------------------
    my $version = $help->command(
        -label    => 'Version',
        -compound => 'left',
        -image    => $pic_ueber,
        -command  => \sub {
            gui_info_box();
        },

    );

    $help->pack( -side => 'right' );

    return;
}    # ----------  end of subroutine menu_aktualisieren  ----------

#-------------------------------------------------------------------------------
#   Subroutine: baum_aktualisieren
#
#   Löscht die Einträge der Baumansicht und liest den Pflichtenheftordner noch
#   einmal ein.
#
#-------------------------------------------------------------------------------
sub baum_aktualisieren {
    $tree->delete('all');
    %pfade = ();
    find( \&eintrag, ${$konfiguration}{'aordner'} );

    # Schnelle und dreckige Sortierung ohne grossartig
    # im Code einzugreifen
    # TODO : Muss noch umgeschrieben werden!
    $tree->delete('all');
    foreach my $key ( sort keys %pfade ) {
        if ( (index $key, q{/}) != -1){
            my $name = substr $key, ( index $key, q{/} ) + 1;
            my $name2 = substr $name, 0, ( rindex $name, '.xml' );
            $tree->add(

                # relativen Pfad zur Datei als Anzeige verwenden
                $key,
                -text => $name2    # Name der Datei ohne xml-Endung
            );
        }else{
            $tree->add(

                # relativen Pfad zur Datei als Anzeige verwenden
                $key,
                -text => $key    # Name der Datei ohne xml-Endung
            );
        }
    }
    return;
}    # ----------  end of subroutine baum_aktualisieren  ----------

#---------------------------------------------------------------------------
#   Function : verlauf_fuellen
#
#   Füllt den Verlauf mit Einträgen den übergebenen Einträgen.
#
#   Parameters:
#   $history - Verlaufs-Widget
#   @his_in  - Pfade zu den einzelnen Einträgen
#---------------------------------------------------------------------------
sub verlauf_fuellen {
    my ( $history, @his_in ) = @_;
    foreach my $his (@his_in) {
        foreach my $key ( keys %pfade ) {

            # Zeige nur Einträge an, die in der Baumansicht vorhanden sind
            if ( $his eq $pfade{$key} ) {

                # Macht aus Pheft/Version.xml -> Pheft/Version
                my $bezeichung = substr $key, 0, rindex( $key, '.xml' );

                # Vollständiger Projektpfad, könnte auch $his nehmen
                my $pfad = $pfade{$key};
                $history->command(
                    -label    => "$bezeichung     -> $pfad",
                    -compound => 'left',
                    -command  => \sub {
                        pflichtenheft_laden( $pfade{$key} );
                    }
                );
            }
        }
    }

    return;
}    # ----------  end of subroutine verlauf_fuellen  ----------

#---------------------------------------------------------------------------
#   Subroutine: modal
#
#   Macht Dialog Modal und setzt eine fixe Größe
#
#   Parameters:
#
#   $top_level - Dialog (Toplevel-Wigdet)
#   $BREITE    - gewünschte Breite
#   $HOEHE     - gewünschte Höhe
#---------------------------------------------------------------------------
sub modal {
    my ( $top_level, $BREITE, $HOEHE ) = @_;

    ${$top_level}->geometry( $BREITE . 'x' . $HOEHE );

    # Fenster mittig positionieren
    ${$top_level}->geometry( q{+}
          . int( $SCREEN_WIDTH / 2 - $BREITE / 2 ) . q{+}
          . int( $SCREEN_HEIGHT / 2 - $HOEHE / 2 ) );
    ${$top_level}->raise($mw);
    ${$top_level}->grab();    #macht Fenster modal
    ${$top_level}->resizable( 0, 0 );
    return;
}    # ----------  end of subroutine modal  ----------

#---------------------------------------------------------------------------
#   Subroutine: lade_konfig
#
#   Lade Konfiguration aus moliri.cfg in globalle <$konfiguration> Variable
#---------------------------------------------------------------------------
sub lade_konfig {
    my ($par1) = @_;
    my $moliricfg = MoliriCFG->new();
    $konfiguration = $moliricfg->get_config();
    my $pfad_zur_konfig = ${$konfiguration}{'aordner'};

    if (   not defined $pfad_zur_konfig
        or not -e $pfad_zur_konfig
        or not -w $pfad_zur_konfig )
    {
        my $antw = $mw->Dialog(
            -title => 'Achtung',
            -text =>
"Der Arbeitsordner: \n$pfad_zur_konfig\n ist nicht vorhanden oder beschreibbar.\n"
              . 'Bitte wählen Sie einen anderen Ordner in der Programmkonfiguration aus.',
            -buttons => ['OK'],
            -bitmap  => 'warning'
        )->Show();
        if ($antw) {
            gui_programm_konfig();
        }
    }

    return;
}    # ----------  end of subroutine lade_konfig  ----------

#---------------------------------------------------------------------------
#   Subroutine: eintrag
#
#   Wird in <baum_aktualisieren> als Callback-Funktion von File::find
#   aufgerufen und liest rekursiv den Projektordner ein. Dabei werden nur
#   beschreibbare Dateien mit XML-Suffix berücksichtigt
#
#---------------------------------------------------------------------------
sub eintrag {

    # Wenn .xml-endung, Datei und beschreibbar
    if ( -f $ARG and $ARG =~ /\.xml$/ and -w $ARG ) {

        # Speichere Pfad zur Datei
        my $pfad = $File::Find::dir;

        # Hole nur den Namen des Ordners
        my $ordner = substr $pfad, ( rindex $pfad, q{/} ) + 1;

        my $aordner = ${$konfiguration}{'aordner'};
        $aordner = substr $aordner, ( rindex $aordner, q{/} ) + 1;

        # Namen des Arbeitsordners nicht mit anzeigen
        if ( $ordner eq $aordner ) {
            return;
        }
        if ( not $tree->info( 'exists', $ordner ) )
        {    # Wenn Ordner nicht bereits existiert
            $tree->add( $ordner, -text => $ordner );    # hinzufügen
            $pfade{$ordner} = 'ordner';    # merken, dass es ein Ordner ist
        }

        my $rel_pfad = $ordner . q{/} . $ARG;    # rel. Dateipfad
        $pfade{$rel_pfad} = $File::Find::name;   # Vollständige Pfade einfügen

        $tree->add(

            # relativen Pfad zur Datei als Anzeige verwenden
            $rel_pfad,
            -text => substr $ARG,
            0, ( rindex $ARG, '.xml' )    # Name der Datei ohne xml-Endung
        );

        #        print "\nOrdner: $ordner\n";
        #        print "\nDatei$ARG\n";

    }
    return;
}

#-------------------------------------------------------------------------------
#   Subroutine: trimm
#
#   Es werden führende und abschließende Leerzeichen entfernt.
#
#   Parameters:
#   $par1   -   Enthält den zu trimmenden String
#
#   Returns:
#   Der Rueckgabewert ist der String ohne fuehrende und
#   abschließende Leerzeichen.
#-------------------------------------------------------------------------------
sub trimm {
    my ($par1) = @_;
    if ($par1) {
        $par1 =~ s/^\s+//;    #führende Leerezeichen entfernen
        $par1 =~ s/\s+$//;    #abschließende Leerzeichen entfernen
    }
    else {
        $par1 = $EMPTY;
    }
    return $par1;
}    # ----------  end of subroutine trimm  ----------

#-------------------------------------------------------------------------------
#   Subroutine: umbruch_entfernen
#
#   Enftfernt Zeilenumbrüche aus übergebenen String. Wird in der Vorschau
#   verwendet
#
#   Parameters:
#   $par1   -   Referenz auf String
#-------------------------------------------------------------------------------
sub umbruch_entfernen {
    my ($par1) = @_;
    if ( defined ${$par1} ) {
        ${$par1} =~ s/\n/ /g;
    }
    return;
}    # ----------  end of subroutine umbruch_entfernen  ----------

#-------------------------------------------------------------------------------
#   Subroutine: cut_bei_81
#
#   Schneidet übergebenen String nach 81 Zeichen ab und fügt ' ...' hinten dran
#
#   Parameters:
#   $par1   -   Referenz auf String
#-------------------------------------------------------------------------------
sub cut_bei_81 {
    my ($par1) = @_;
    Readonly my $MAX_BREITE => 81;
    if ( length ${$par1} >= $MAX_BREITE ) {
        ${$par1} = substr( ${$par1}, 0, $MAX_BREITE - 4 ) . ' ...';
    }
    return;
}    # ----------  end of subroutine umbruch_entfernen  ----------

#-------------------------------------------------------------------------------
#   Subroutine: cut_bei_64
#
#   Schneidet übergebenen String nach 64 Zeichen ab und fügt ' ...' hinten dran
#
#   Parameters:
#   $par1   -   Referenz auf String
#-------------------------------------------------------------------------------
sub cut_bei_64 {
    my ($par1) = @_;
    Readonly my $MAX_BREITE => 64;
    if ( length ${$par1} >= $MAX_BREITE ) {
        ${$par1} = substr( ${$par1}, 0, $MAX_BREITE - 4 ) . ' ...';
    }
    return;
}    # ----------  end of subroutine umbruch_entfernen  ----------

#sub gui_web_laden {
#    my	( $par1 )	= @_;
#    $mw->Dialog(
#        -title => 'Achtung',
#        -text  => "Funktion konnte innerhalb der Entwicklungszeit\n"
#          . "nicht implemeniert werden.",
#        -buttons => ['OK'],
#        -bitmap  => 'warning'
#    )->Show();
#    return ;
#}	# ----------  end of subroutine gui_web_laden  ----------
#sub gui_web_laden {
#    my ($par1) = @_;
#    gui_ladebalken(0) if $par1 == 0;
#    my $gui = $mw->Toplevel( -title => 'Pflichtenheft auswählen' );
#
#    $gui->geometry('300x250');
#    $gui->geometry( '+'
#          . int( $screen_width / 2 - 300 / 2 ) . '+'
#          . int( $screen_height / 2 - 100 / 2 ) );
#
#    $gui->raise($mw);
#    $gui->grab();    #macht Fenster modal
#
#    $gui->Label(
#        -text => "Bitte wählen sie das gewünschte\nPflichtenheft aus" )
#      ->pack();
#
#    my $loc_tree = $gui->Scrolled(
#        'Tree',
#        -separator        => '/',
#        -scrollbars       => 'oe',
#        -selectbackground => 'lightblue'
#    );
#
#    #Inhalt vom Projektbaum aus dem Hauptfenster kopieren
#    foreach my $ordner ( $tree->child_entries() ) {
#        $loc_tree->add( $ordner, -text => $ordner );
#        foreach my $datei ( $tree->child_entries($ordner) ) {
#            my $name = substr( $datei, ( index $datei, '/' ) + 1 );
#            $name = substr( $name, 0, ( rindex $name, '.xml' ) );
#            $loc_tree->add( $datei, -text => $name );
#        }
#    }
#
#    $loc_tree->autosetmode();
#    $loc_tree->pack( -fill => 'x' );
#    my $frame_button     = $gui->Frame();
#    my $button_erstellen = $frame_button->Button(
#        -text     => 'Laden',
#        -image    => $pic_ok,
#        -compound => 'left',
#        -command  => \sub {
#            $gui->destroy();
#            gui_ladebalken();
#        },
#    );
#    my $button_abbrechen = $frame_button->Button(
#        -text    => 'Abbrechen',
#        -command => \sub {
#            $gui->destroy();
#        },
#    );
#
#    $frame_button->pack( -fill => 'x', -expand => '1', -side => 'bottom' );
#    $button_erstellen->pack( -side => 'left' );
#    $button_abbrechen->pack( -side => 'right' );
#    return;
#
#}    # ----------  end of subroutine gui_web_laden  ----------

#sub gui_ladebalken {
#    my ($par1) = @_;
#
#    my $gui = $mw->Toplevel( -title => 'Verbindung zum Webserver' );
#    $gui->geometry('300x100');
#    $gui->geometry( '+'
#          . int( $screen_width / 2 - 300 / 2 ) . '+'
#          . int( $screen_height / 2 - 100 / 2 ) );
#
#    $gui->raise($mw);
#    $gui->grab();    #macht Fenster modal
#    my $percent_done;
#
#    #---------------------------------------------------------------------------
#    #  Simulation deiner Verbindung
#    #---------------------------------------------------------------------------
#    $gui->Label( -text => "Verbindung zum Webserver wird aufgebaut.\n"
#          . "Bitte haben sie einen Moment Geduld." )->pack();
#    my $progress = $gui->ProgressBar(
#        -height   => 20,
#        -from     => 0,
#        -to       => 100,
#        -blocks   => 50,
#        -colors   => [ 0, 'lightblue', 100 ],
#        -variable => \$percent_done,
#        -padx     => '3',
#        -pady     => '3',
#        -relief   => 'flat',
#    )->pack( -side => 'bottom', -fill => 'x' );
#    for ( my $i = 0 ; $i <= 1000 ; $i++ ) {
#        $percent_done = $i / 10;
#        $gui->Label( -text => 'Verbindung hergestellt.' )->pack()
#          if ( $i == 1000 );
#        $gui->update;    #Fortschritt anzeigen
#    }
#    sleep(1);
#    $gui->destroy();
#    return;
#}    # ----------  end of subroutine gui_ladebalken  ----------
