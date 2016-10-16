#!/usr/bin/perl

#-------------------------------------------------------------------------------
# FILE: moliri2.pl
#
#    Dies ist die Arbeitsoberfläche des Moliri-Pflichtenheftgenerators. Mann
#    kann Pflichtenhefte bearbeiten und speichern.
#
#  >Autor:       Alexandros Kechagias (Alexandros.Kechagias@gmx.de)
#  >Firma:       Fachhochschule Südwestfalen
#  >Version:     1.0
#  >Erstellt am: 18.10.2010 17:19:05
#  >Revision:    0.2
#-------------------------------------------------------------------------------

use strict;
use warnings;

#use Carp;
use English qw( -no_match_vars );
use utf8;
binmode STDOUT, ':utf8';    # Konsolenausgabe in Unicode

use Tk 804.028;
use Tk::NoteBook 4.011;     # Tabulatoren
use Tk::Table 4.014;        # Tabellen
use Tk::Dialog 4.005;       # Speichern, Laden und Warnhinweise
use Data::Dumper 2.124;     # Debugging
use Tk::JPEG 4.003;
use Tk::PNG 4.004;
use Tk::Balloon 4.011;
use Cwd;
use lib Cwd::cwd() . '/lib';    # /lib-Ordner einbinden
use ComboEntry;                 # Dropdown Menü
use DateEntry;
use MatchEntry;                 # Dropdownmenu mit Auto-Vervollständingung
use MoliriXML;
use threads;
use Readonly;

print "Skriptname:\t$PROGRAM_NAME\n";
print "Perl:\t\t$PERL_VERSION\n";
print "Tk:\t\t$Tk::VERSION\n";


# VARIABLE: %projekt
#
# %projekt ist ein Hash der Referenzen auf Elemente der GUI sowie andere
# für das Projekt wichtige Daten enthält.
# Folgende Elemente sind enthalten :
#
# *Titel*
# - $projekt{titel}   - Titel  
# - $projekt{autor}   - Autor  
# - $projekt{datum}   - Datum  
# - $projekt{version} - Version
# - $projekt{status}  - Titel  
# - $projekt{kommentar} - Referenz auf $text_kom (Tk::Text)
#
# *Produkteinsatz*
# - $projekt{produkteinsatz}   - Referenz auf $txt_einsatz1        (Tk::Text)
# - $projekt{zielgruppen}      - Referenz auf $txt_zgruppen        (Tk::Text)
# - $projekt{arbeitsbereiche}  - Referenz auf $txt_abereiche       (Tk::Text)
# - $projekt{betriebsbedingungen} - Referenz auf $txt_bbedingungen (Tk::Text)
#
# *produktübersicht*
# - $projekt{produktuebersicht} - Referenz auf $txt_produkt_uebersicht (Typ Tk::Text)
# - $projekt{produktuebersicht_bildpfad} - Bildpfad;
# - $projekt{produktuebersicht_bildbeschreibung} - Bildbeschreibung;
# 
# *Qualität*
# - $projekt{qualitaet} - Referenz auf %qualitaet
#
# *Nichtfunktionale Anforderungen*
# - $projekt{anforderungen}   - Referenz auf $text_nichtfunkt (Tk::Text)
#
# *Produktumgebung*
# - $projekt{produktumgebung} - Referenz auf $txt_pumgebung (Tk::Text)
# - $projekt{software}        - Referenz auf $txt_sware     (Tk::Text)
# - $projekt{hardware}        - Referenz auf $txt_hware     (Tk::Text)
# - $projekt{orgware}         - Referenz auf $txt_oware     (Tk::Text)
# - $projekt{schnittstellen}  - Referenz auf $txt_sstellen  (Tk::Text)
#
# *Entwicklungsumgebung*
# - $projekt{e_produktumgebung} - Referenz auf $txt_pumgebung (Tk::Text)
# - $projekt{e_software}        - Referenz auf $txt_sware     (Tk::Text)
# - $projekt{e_schnittstellen}  - Referenz auf $txt_hware     (Tk::Text)
# - $projekt{e_orgware}         - Referenz auf $txt_oware     (Tk::Text)
# - $projekt{e_hardware}        - Referenz auf $txt_sstellen  (Tk::Text)
#
# *Teilprodukte*
# - $projekt{teilprodukte_beschreibung} = Referenz auf $text_beschreibung (Tk::Text)
#
# *Ergänzungen*
# - $projekt{ergaenzungen}    - Referenz auf $txt_ergaenzungen (Tk::Text)
#
# *Tabellen*
# - $projekt{zielbestimmungen} - Referenz auf $nztable          (Tk::Table)
# - $projekt{funktionen}       - Referenz auf $func_table       (Tk::Table)
# - $projekt{daten}            - Referenz auf $daten_table      (Tk::Table)
# - $projekt{leistungen}       - Referenz auf $leistungen_table (Tk::Table)
# - $projekt{teilprodukte}     - Referenz auf $tpr_table        (Tk::Table)
# - $projekt{glossar}        - Referenz auf $table              (Tk::Table)
#
my %projekt;

# VARIABLES: Daten aus den Tabellen Funktionen, Leistungen, Daten, Ziele
# %zielbestimmung - in der Form {ID}->[Zielbestimmung, Beschreibung]
# %funktionen     - in der Form {Nummer}->[Geschäftspr.,Ziel,Vorbedingung,Nachb.Erfolg, Nachb.Fehl,
#                                 Akteure,Ereignis,Beschreibung, Erweiterung,Alternativen]
# %daten          - in der Form {Nummer}->[Bezeichnung, Beschreibung]
# %leistungen     - in der Form {Nummer}->[Bezeichnung, Beschreibung]
# %gui            - in der Form {Nummer}->[Bezeichnung, Bildpfad,
#                                      Bildbeschreibung, Beschreibung,
#                                      {Rollen_ID}-> [Bezeichnung, Rechte]
#                                     ]
# %teilprodukte   - in der Form {ID}->[Bezeichnung,
#                                      {Funktion_ID}->[Bemerkung,Funktion_Nummer,
#                                                      Funktion_Beschreibung]
#                                     ]
# %testfaelle     - in der Form {Nummer}->[Bezeichnung, Vorbedingung,
#                                      Beschreibung, Sollverhalten]
# %glossar        - in der Form {Begriff}->[Erklärung]
my %zielbestimmung;
my %funktionen;
my %daten;
my %leistungen;
my %gui;
my %teilprodukte;
my %testfaelle;
my %glossar;

# VARIABLES: Kapitel
# %funktionen_kapitel - in der Form {Kapitel_ID}{Funktion_Nummer}->Funktion_Nummer
# %daten_kapitel      - in der Form {Kapitel_ID}{Datum_Nummer}->Datum_Nummer
# %leistungen_kapitel - in der Form {Kapitel_ID}{Leistung_Nummer}->Leistung_Nummer
my %funktionen_kapitel;
my %daten_kapitel;
my %leistungen_kapitel;

# VARIABLE: $aktueller_frame
# Nummer des momentan sichtbaren Frames, gebraucht von <switch_frame>
my $aktueller_frame;

# leere Variable, besser als ''
my $EMPTY = q{};

# VARIABLE: $xml_pfad
# entält den Pfad zur momentan bearbeitenden XML-Datei
my ( $xml_pfad, $auto, $minuten ) = @ARGV;

# VARIABLE: $geandert
# Wenn etwas am Pflichtenheft geändert wird ist die Variable auf 1
# ansonsten 0
my $geaendert = 0;

#---------------------------------------------------------------------------
#
#  ABOUT: Hauptfenster
#
# Das Hauptfenster besteht aus $mw (Tk::MainWindow) wovon alle Elementne in der
# GUI abgeleitet sind. Es ist in 4 Hauptbereiche unterteilt
# - dem Menü ($menubar)
# - den algemeinen Informationen über das Plichtenheft wie Name, Autor usw. ($frameoben)
# - dem Arbeitsbereich ($main_frame)
# - den Buttons unten zum wechseln zwischen den Schritten ($framebut)
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
#  VARIABLE: $mw
#  Das Hauptfenster von Typ (Tk::MainWindow)
#---------------------------------------------------------------------------

my $mw = MainWindow->new;
my $icon = $mw->Photo( -file => 'img/mu.png' );
$mw->iconimage($icon);
my $mw_width      = '800';
my $mw_height     = '670';
my $screen_height = $mw->screenheight;
my $screen_width  = $mw->screenwidth;
$mw->geometry( $mw_width . 'x' . $mw_height );
$mw->title('Morili - Pflichtenheftgenerator');
$mw->resizable( 0, 0 );
my $thr;
$mw->protocol(
    'WM_DELETE_WINDOW',
    \sub {

        if ($thr) {
            $thr->kill('KILL')->detach();
        }
        if ($geaendert) {
            my $antwort = $mw->Dialog(
                -title          => 'Hinweis',
                -text           => 'Sollen die Änderungen gespeichert werden?',
                -default_button => 'Ja',
                -buttons        => ['Ja', 'Nein'],
                -bitmap         => 'warning'
            )->Show();
            if ($antwort eq 'Ja'){
                speichern();
            }
        }
        $mw->destroy;
    }
);

#---------------------------------------------------------------------------
#  globalle Widget-optionen setzen
#---------------------------------------------------------------------------
$mw->optionAdd( '*Entry.background',      'snow1' );
$mw->optionAdd( '*Text.background',       'snow1' );
$mw->optionAdd( '*font',                  'Helvetica -12' );
$mw->optionAdd( '*MatchEntry.background', 'snow1' );
$mw->optionAdd( '*borderWidth',           '1' );
$mw->optionAdd( '*Menu.tearOff',          '0' );

#-------------------------------------------------------------------------------
# About: Tastenkürzel
#
# - Strg+n - Leert die GUI <neues_projekt>
# - F1 - Infobox
#
#-------------------------------------------------------------------------------
$mw->bind( '<Control-n>', \&neues_projekt );
$mw->bind( '<Control-s>', \&speichern );
#$mw->bind( '<F1>',        \&info_box );

#--------------------------------------------------------------------------
#  About: Fenster mittig positionieren
#
# $mw->geometry( '+'. breite . '+' . hoehe );
#
#
# Setzt die obere linke Ecke des Programmfesters so,  dass das Programm mittig
# auf dem Desktop erscheint.
# Es wird dazu die Mitte des Desktops in waagerechter und senkrechter Richung
# ermittelt
# - $screen_width / 2 und $screen_height / 2
#
# und anschließend die Mitte der Applikation
# - $mw_width / 2 und $mw_height / 2
#
#--------------------------------------------------------------------------

# Fenster mittig positionieren
$mw->geometry( q{+}
      . int( $screen_width / 2 - $mw_width / 2 ) . q{+}
      . int( $screen_height / 2 - $mw_height / 2 ) );

#---------------------------------------------------------------------------
#  Variables: Icons
# $pic_neu             - Datei -> *Neues Pflichtenheft*
# $pic_neu             - Alle Neu-Buttions
# $pic_oeffne          - Datei -> *Öffne Pflichtenheft*
# $pic_oeffne_datei    - Datei -> Öffne Pflichtenheft -> *Aus Datei ...*
# $pic_oeffne_db       - Datei -> Öffne Pflichtenheft -> *Aus Datenbank*
# $pic_speichern       - Datei -> *Speichere Pflichtenheft*
# $pic_speichern       - Datei -> *Speichern*
# $pic_speichern_datei - Datei -> Speichere Pflichtenheft -> *In Datei ...*
# $pic_speichern_db    - Datei -> Speichere Pflichtenheft -> *In Datenbank ...*
# $pic_exit            - Datei -> *Beenden*
# $pic_ueber           - Hilfe -> *Version*
# $pic_export_txt      - Export -> *in Textdatei ...*
# $pic_edit            - Alle Bearbeiten-Buttons
# $pic_delete          - Alle Löschen-Nuttons
# $pic_ok              - Alle OK-Buttons
# $pic_ok_redo         - Alle Neu-Buttons in Dialogen
# $pic_arrow_left      - Pfeiltasten unten im Programm (links)
# $pic_arrow_right     - Pfieltasten unten im Proigramm (rechts)
# $pic_moliri          - Programmicon und im Menü
# $pic_moliri22x22     - Für Button zum zurückkehren in die Projektansicht
#---------------------------------------------------------------------------
my $pic_neu    = $mw->Photo( -file => 'img/16x16/document-new-5.png' );
my $pic_oeffne = $mw->Photo( -file => 'img/16x16/document-open-folder.png' );
my $pic_oeffne_datei = $mw->Photo( -file => 'img/16x16/document-open-5.png' );
my $pic_oeffne_db = $mw->Photo( -file => 'img/16x16/document-open-remote.png' );
my $pic_speichern = $mw->Photo( -file => 'img/16x16/document-save-3.png' );
my $pic_speichern_datei = $mw->Photo( -file => 'img/16x16/document-new.png' );
my $pic_speichern_db = $mw->Photo( -file => 'img/16x16/server-database.png' );
my $pic_exit        = $mw->Photo( -file => 'img/16x16/application-exit-2.png' );
my $pic_ueber       = $mw->Photo( -file => 'img/16x16/help-about.png' );
my $pic_export_txt  = $mw->Photo( -file => 'img/16x16/document-export-4.png' );
my $pic_edit        = $mw->Photo( -file => 'img/16x16/edit.png' );
my $pic_delete      = $mw->Photo( -file => 'img/16x16/edit-delete-5.png' );
my $pic_ok          = $mw->Photo( -file => 'img/16x16/dialog-ok.png' );
my $pic_ok_redo     = $mw->Photo( -file => 'img/16x16/edit-redo-6.png' );
my $pic_add         = $mw->Photo( -file => 'img/16x16/edit-add.png' );
my $pic_arrow_left  = $mw->Photo( -file => 'img/22x22/arrow-left-2.png' );
my $pic_arrow_right = $mw->Photo( -file => 'img/22x22/arrow-right-2.png' );
my $pic_moliri      = $mw->Photo( -file => 'img/mu_transparent.png' );
my $pic_moliri22x22 = $mw->Photo( -file => 'img/22x22/mu22x22.png' );

#---------------------------------------------------------------------------
#  Variable: $menubar
#
# das Menü hat folgenden Aufbau
#
# -> steht für : ist Elternwidget von
#
# - <$menubar> ->  <$file>
# - <$menubar> ->  <$help>
#
# In der Gui siehr das ganze dann so aus:
#
# - Datei -> *Neues Pflichtenheft*
# - Datei -> *Speichern*
# - Hilfe -> *Version*
#---------------------------------------------------------------------------
my $menubar = $mw->Menu();
$mw->configure( -menu => $menubar );

#---------------------------------------------------------------------------
#  Variable: $file
#  Beinhaltet 2 ausfaltbare Menüs (<$open>, <$save>).
#  Sowie folgende Menüeinträge:
#  - Neues Pflichtenheft
#  - Speichern
#  - Beenden
#---------------------------------------------------------------------------
my $file = $menubar->cascade( -label => '~Datei' );

##---------------------------------------------------------------------------
##  $help
##  Hat folgende Menüeinträge:
##  - Version
##---------------------------------------------------------------------------
#my $help = $menubar->cascade( -label => '~Hilfe' );

$file->command(
    -label       => 'Neues Pflichtenheft',
    -accelerator => 'Strg-n',
    -underline   => 0,
    -compound    => 'left',
    -image       => $pic_neu,
    -command     => \sub {
        neues_projekt();
    }
);

$file->separator;
$file->command(
    -label       => 'Speichern',
    -accelerator => 'Strg-s',
    -underline   => 0,
    -command     => \sub {
        speichern();
    },
    -compound => 'left',
    -image    => $pic_speichern,

);

$file->separator;
$file->command(
    -label       => 'Projektverwaltung',
    -accelerator => 'Strg-q',
    -underline   => 0,
    -command     => \sub {
        if ($thr) {
            $thr->kill('KILL')->detach();
        }
        if ($geaendert) {
            my $antwort = $mw->Dialog(
                -title          => 'Hinweis',
                -text           => 'Sollen die Änderungen gespeichert werden?',
                -default_button => 'Ja',
                -buttons        => ['Ja', 'Nein'],
                -bitmap         => 'warning'
            )->Show();
            if ($antwort eq 'Ja'){
                speichern();
            }
        }
        $mw->destroy;
    },
    -compound => 'left',
    -image    => $pic_moliri,

);

#$help->command(
#    -label    => 'Version',
#    -compound => 'left',
#    -image    => $pic_ueber,
#    -command  => \sub {
#        info_box();
#    },
#
#);

#---------------------------------------------------------------------------
#  about: Die Frames vom Kopf der GUI
#  Hier werden Informationen abgefragt wie Autor, Datum, Version,
#  Status, Kommentar. Zur Formatierung werden Frames verwendet.
#  Die Frames sind wie folgt angeordnet:
#
# > $frameoben
# >+--------------------------------------------------------------------+
# >| $frameobenlinks                 $framekom                          |
# >| +---------------------------+   +--------------------------------+ |
# >| | +-----------------------+ |   |                                | |
# >| | | $frametitel           | |   |                                | |
# >| | +-----------------------+ |   |                                | |
# >| | +-----------------------+ |   |                                | |
# >| | | $frameautor           | |   |                                | |
# >| | +-----------------------+ |   |                                | |
# >| | +-----------------------+ |   |                                | |
# >| | | $framedatum           | |   |                                | |
# >| | +-----------------------+ |   |                                | |
# >| | +-----------------------+ |   |                                | |
# >| | | $framestatus          | |   |                                | |
# >| | +-----------------------+ |   |                                | |
# >| +---------------------------+   +--------------------------------+ |
# >+--------------------------------------------------------------------+
#
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
# VARIABLE: $frameoben
# Gruppiert die Frames
# - <$frameobenlinks>
# - <$framekom>
#---------------------------------------------------------------------------
my $frameoben = $mw->Frame( -borderwidth => 3, -relief => 'groove' );

#---------------------------------------------------------------------------
# VARIABLE: $frameobenlinks
# Gruppiert die Frames
# - <$frametitel>
# - <$frameautor>
# - <$framedatum>
# - <$framestatus>
#---------------------------------------------------------------------------
my $frameobenlinks = $frameoben->Frame();

#---------------------------------------------------------------------------
# VARIABLE: $frametitel
# Gruppert die Widgets
# - <$lab_titel> (Tk::Label)
# - <$ent_titel> (Tk::Entry)
#---------------------------------------------------------------------------
#Pflichtenhefttitel
my $frametitel =
  $frameobenlinks->Frame( -borderwidth => 0, -relief => 'groove' );

#---------------------------------------------------------------------------
# VARIABLES: Eingabefeld für Pflichtenhefttitel
# $lab_titel - Anzeige der Bezeichnung 'Titel'
# $ent_titel - Eingabefeld mit Referenz auf den Hash $projekt{titel}
#---------------------------------------------------------------------------
my $lab_titel = $frametitel->Label( -text => 'Titel    ' );
my $ent_titel = $frametitel->Entry(
    -width        => '37',
    -textvariable => \$projekt{titel},
    -state        => 'disabled',
);

#---------------------------------------------------------------------------
# VARIABLE: $frameautor
# Gruppert die Widgets
# - <$lab_autor> (Tk::Label)
# - <$ent_autor> (Tk::Entry)
#---------------------------------------------------------------------------
my $frameautor =
  $frameobenlinks->Frame( -borderwidth => 0, -relief => 'groove' );

#---------------------------------------------------------------------------
# VARIABLES: Eingabefeld für Autoren
# $lab_autor - Anzeige der Bezeichnung 'Autor'
# $ent_autor - Eingabefeld mit Referenz auf den Hash $projekt{autor}
#---------------------------------------------------------------------------
my $lab_autor = $frameautor->Label( -text => 'Autor  ' );
my $ent_autor = $frameautor->Entry(
    -width        => '37',
    -textvariable => \$projekt{autor}
);
$ent_autor->bind('<KeyPress>' , \&set_aendern);

#---------------------------------------------------------------------------
# VARIABLE: $framedatum
# Gruppert die Widgets
# - <$lab_datum> (Tk::Label)
# - <$ent_datum> (Tk::Entry)
# - <$lab_version> (Tk::Label)
# - <$ent_version> (Tk::Entry)
#---------------------------------------------------------------------------
my $framedatum =
  $frameobenlinks->Frame( -borderwidth => 0, -relief => 'groove' );

#---------------------------------------------------------------------------
#  VARIABLES: Eingabefelder für Version und Datum des Pflichtenheftes
#  $lab_datum   - Anzeige der Bezeichnung 'Datum'
#  $ent_datum   - Eingabefeld mit Referenz auf den Hash $projekt{datum} im Format (yyyy-mm-dd)
#  $lab_version - Anzeige der Bezeichnung 'Version'
#  $ent_version - Eingabefeld mit Referenz auf den Hash $projekt{version} mit Begrenzung auf 8 Zeichen
#---------------------------------------------------------------------------
my $lab_datum = $framedatum->Label( -text => 'Datum' );
my $ent_datum = $framedatum->DateEntry(
    -state      => 'normal',
    -foreground => 'black',
    -parsecmd   => sub {
        my ( $d, $m, $y ) = ( $_[0] =~ m/(\d*)\/(\d*)-(\d*)/ );
        return ( $y, $m, $d );
    },
    -formatcmd => sub {
        sprintf '%d-%d-%d', $_[0], $_[1], $_[2];
    },
    -textvariable => \$projekt{datum}
);
$ent_datum->bind('<KeyPress>' , \&set_aendern);
my $lab_version = $framedatum->Label( -text => 'Version' );
my $ent_version = $framedatum->Entry(
    -width        => '10',
    -validate     => 'key',
    -state        => 'disabled',
    -textvariable => \$projekt{version},
);

#---------------------------------------------------------------------------
# VARIABLE: $framestatus
# Gruppert die Widgets
# - <$lab_status> (Tk::Label)
# - <$rd_inarb> (Tk::Radiobutton)
# - <$rd_akzept> (Tk::Radiobutton)
# - <$rd_frei> (Tk::Radiobutton)
#---------------------------------------------------------------------------
my $framestatus =
  $frameobenlinks->Frame( -borderwidth => 0, -relief => 'groove' );

#---------------------------------------------------------------------------
# VARIABLES: Status des Projektes
# $lab_status - Anzeige der Bezeichnung 'Status'
# $rd_inarb   - Auswahlfeld mit Referenz auf den Hash $projekt{status}
# $rd_akzept  - Auswahlfeld mit Referenz auf den Hash $projekt{status}
# $rd_frei    - Auswahlfeld mit Referenz auf den Hash $projekt{status}
#
# $projekt{status} kann den Zustand 'in Arbeit', 'akzeptiert'
# und 'freigegeben' haben
#---------------------------------------------------------------------------
my $lab_status = $framestatus->Label( -text => 'Status' );
my $rd_inarb = $framestatus->Radiobutton(
    -text        => 'in Arbeit',
    -value       => 'in Arbeit',
    -selectcolor => 'lightblue',
    -variable    => \$projekt{status},
);
my $rd_akzept = $framestatus->Radiobutton(
    -text        => 'akzeptiert',
    -value       => 'akzeptiert',
    -selectcolor => 'lightblue',
    -variable    => \$projekt{status},
);
my $rd_frei = $framestatus->Radiobutton(
    -text        => 'freigegeben',
    -value       => 'freigegeben',
    -selectcolor => 'lightblue',
    -variable    => \$projekt{status},
);

$rd_inarb ->bind('<ButtonPress>' , \&set_aendern);
$rd_akzept->bind('<ButtonPress>' , \&set_aendern);
$rd_frei  ->bind('<ButtonPress>' , \&set_aendern);
#---------------------------------------------------------------------------
# VARIABLE: $framekom
# Gruppiert die Widgets
# - <$lab_kom> (Tk::Label)
# - <$text_kom> (Tk::Text)
#---------------------------------------------------------------------------
my $framekom = $frameoben->Frame( -borderwidth => 0, -relief => 'groove' );

#---------------------------------------------------------------------------
#  VARIABLES: Beschreibung des Pflichtenheftes
#  $lab_kom - Anzeige der Bezeichnung 'Kommentar'
#  $text_kom - Eingebefeld des Kommentars
#---------------------------------------------------------------------------
my $lab_kom = $framekom->Label( -text => 'Kommentar' );
my $text_kom = $framekom->Scrolled( 'Text', -scrollbars => 'oe' );
$text_kom->configure( -height => 5 );
$projekt{kommentar} = $text_kom;
$text_kom ->bind('<KeyPress>' , \&set_aendern);

#---------------------------------------------------------------------------
#  Packs - Fenster oben
#---------------------------------------------------------------------------
$frameoben->pack( -fill => 'both', -pady => 6, -padx => 6 );
$frameobenlinks->pack( -side => 'left', -padx => 5 );
$frametitel->pack( -anchor => 'w' );
$lab_titel->pack( -side => 'left' );
$ent_titel->pack( -side => 'right' );
$frameautor->pack( -anchor => 'w', -fill => 'x' );
$lab_autor->pack( -side => 'left' );
$ent_autor->pack( -side => 'left' );
$framedatum->pack( -anchor => 'w', -fill => 'both', -pady => 6 );
$lab_datum->pack( -side => 'left' );
$ent_datum->pack( -side => 'left' );
$lab_version->pack( -side   => 'right' );
$ent_version->pack( -side   => 'right', -before => $lab_version );
$framestatus->pack( -anchor => 'w' );
$lab_status->pack( -side => 'left' );
$rd_inarb->pack( -side => 'left' );
$rd_akzept->pack( -side => 'left' );
$rd_frei->pack( -side => 'left' );
$framekom->pack( -fill => 'x', -pady => 3, -padx => 3 );
$lab_kom->pack( -side => 'top', -anchor => 'w' );
$text_kom->pack( -fill => 'x' );

#---------------------------------------------------------------------------
#  about: Arbeitsfläche
#  Der <$main_frame> stellt die Hauptarbeitsfläche des Programms da.
#  Der <$button_frame> beinhaltet 15 Widgets vom Typ (Tk::Button). Nach dem
#  Drücken auf die Buttons wird die Funktion <show_frame> aufgerufen die den
#  passenden Frame aus <@frame_stack> in den geometry-manager lädt und
#  alle anderen Frames mit *packForget* aus dem geometry-manager rauswirft
#  aber der Inhalt der rausgeworfenen Widgets bleibt erhalten
#
# > $main_frame
# >+---------------------------------------------------------------------+
# >| $button_frame     $content_frame                                    |
# >| +---------------+ +-----------------------------------------------+ |
# >| |1. Zielbest.   | |+++++++++--------------------------------------| |
# >| |2. Einsatz     | |@frame_stack[15 Elemente vom Typ Tk::Frame]    | |
# >| |3. Übersicht   | ||||||||||                                      | |
# >| |4. Funktionen  | ||||||||||                                      | |
# >| |5. Daten       | ||||||||||                                      | |
# >| |6. Leistungen  | ||||||||||                                      | |
# >| |7. Qualität    | ||||||||||                                      | |
# >| |8. GUI         | ||||||||||                                      | |
# >| |9. techn. Umg. | ||||||||||                                      | |
# >| |10.n. funkt A. | ||||||||||                                      | |
# >| |11.Entw. Umge. | ||||||||||                                      | |
# >| |12.Teilprodukte| ||||||||||                                      | |
# >| |13.Ergänzung   | ||||||||||                                      | |
# >| |14.Testfälle   | ||||||||||                                      | |
# >| |15.Glossar     | ||||||||||                                      | |
# >| +---------------+ ++++++++++--------------------------------------+ |
# >+---------------------------------------------------------------------+

#---------------------------------------------------------------------------
#  VARIABLE: $main_frame
# Gruppiert die Frames
# - <$button_frame>
# - <$content_frame>
#---------------------------------------------------------------------------
my $main_frame = $mw->Frame()->pack( -anchor => 'w', -fill => 'both' );

#---------------------------------------------------------------------------
#  VARIABLE: $button_navi
#  Beinhaltet ein <@button_array> mit 15 Widgets vom Typ (Tk::Button)
#---------------------------------------------------------------------------
my $button_navi =
  $main_frame->Frame()->pack( -side => 'left', -anchor => 'nw' );

#---------------------------------------------------------------------------
# VARIABLE: @button_array
# Beinhaltet 15 Widgets vom Typ (Tk::Button).
#---------------------------------------------------------------------------
my @button_array;

push @button_array, $button_navi->Button(
    -text    => '1.  Zielbestimmung',
    -command => \sub {
        show_frame(0);
    }
);

push @button_array, $button_navi->Button(
    -text    => '2.  Einsatz',
    -command => \sub {
        show_frame(1);
    }
);

push @button_array, $button_navi->Button(
    -text    => '3.  Übersicht',
    -command => \sub {
        show_frame(2);
    }
);

push @button_array, $button_navi->Button(
    -text    => '4.  Funktionen',
    -command => \sub {
        show_frame(3);
    }
);
push @button_array, $button_navi->Button(
    -text    => '5.  Daten',
    -command => \sub {
        show_frame(4);
    }
);
push @button_array, $button_navi->Button(
    -text    => '6.  Leistungen',
    -command => \sub {
        show_frame(5);
    }
);
push @button_array, $button_navi->Button(
    -text    => '7.  Qualität',
    -command => \sub {
        show_frame(6);
    }
);
push @button_array, $button_navi->Button(
    -text    => '8.  GUI',
    -command => \sub {
        show_frame(7);
    }
);
push @button_array, $button_navi->Button(
    -text    => '9. Nichtfunkt. Anford.',
    -command => \sub {
        show_frame(8);
    }
);
push @button_array, $button_navi->Button(
    -text    => '10. Techn. Umgebung',
    -command => \sub {
        show_frame(9);
    }
);

push @button_array, $button_navi->Button(
    -text    => '11. Entw. Umgebung',
    -command => \sub {
        show_frame(10);
    }
);

push @button_array, $button_navi->Button(
    -text    => '12. Teilprodukte',
    -command => \sub {
        show_frame(11);
    }
);

push @button_array, $button_navi->Button(
    -text    => '13. Ergänzungen',
    -command => \sub {
        show_frame(12);
    }
);

push
  @button_array,
  $button_navi->Button(
    -text    => '14. Testfälle',
    -command => [ \&show_frame, 13 ]
  );

push @button_array, $button_navi->Button(
    -text    => '15. Glossar',
    -command => \sub {
        show_frame(14);
    }
);

foreach (@button_array)
{    #Einstellungen für alle Buttons übernehmen und packen
    $_->configure( -relief => 'flat', -anchor => 'w' );
    $_->pack( -anchor => 'w', -fill => 'x' );
}

#---------------------------------------------------------------------------
#  VARIABLE: $content_frame
#  Beinhaltet den <@frame_stack>
#---------------------------------------------------------------------------
my $content_frame = $main_frame->Frame()->pack(
    -side   => 'left',
    -fill   => 'both',
    -expand => '1',
    -padx   => '10'
);

#---------------------------------------------------------------------------
#  VARIABLE: @frame_stack
#  Beinhaltet 15 Elemente vom Typ (Tk::Frame)
#---------------------------------------------------------------------------
my @frame_stack;
foreach ( 0 .. 14 ) {
    push @frame_stack, $content_frame->Frame();
}

#---------------------------------------------------------------------------
#  Oberfläche wird am Anfang geladen und bei Bedarf mittels der Funktion
#  <show_frame> bzw. <switchFrame> aus dem gemometry Manager entfernt oder wieder
#  hinzugefügt
#--------------------------------------------------------------------------

build_frame0();     #Zielbestimmung
build_frame1();     #Einsatz
build_frame2();     #Produktübersicht
build_frame3();     #Produktfunktionen
build_frame4();     #Produktdaten
build_frame5();     #Produktleistungen
build_frame6();     #Qualitätsanforderungen
build_frame7();     #GUI
build_frame8();     #nichtfunkt. anforderungen
build_frame9();     #technische Produktumgebung
build_frame10();    #Entw. Umgebung
build_frame11();    #Teilprodukte
build_frame12();    #Ergänzugen
build_frame13();    #Testfälle
build_frame14();    #Glossar
show_frame(0)
  ;    #Am Anfang ist immer die Oberfläche der Zielbestimmungen aktiviert

#---------------------------------------------------------------------------
#  VARIABLES: Buttons unten
#  $framebut - Frame mit 2 Buttons
#  $but_zur - Button für einen Schritt zurück
#  $but_weiter - Button für einen Schritt vor
#---------------------------------------------------------------------------
my $framebut = $mw->Frame();
$framebut->pack(
    -fill   => 'x',
    -side   => 'bottom',
    -anchor => 's',
    -padx   => 6,
    -pady   => 6
);
my $but_projekt = $framebut->Button(
    -compound => 'left',
    -image    => $pic_moliri22x22,
    -command  => \sub {
        if ($thr) {
            $thr->kill('KILL')->detach();
        }
        if ($geaendert) {
            my $antwort = $mw->Dialog(
                -title          => 'Hinweis',
                -text           => 'Sollen die Änderungen gespeichert werden?',
                -default_button => 'Ja',
                -buttons        => ['Ja', 'Nein'],
                -bitmap         => 'warning'
            )->Show();
            if ($antwort eq 'Ja'){
                speichern();
            }
        }
        $mw->destroy;
    },
    -text => 'Projektansicht',
)->form();
my $but_zur = $framebut->Button(
    -compound => 'left',
    -image    => $pic_arrow_left,
    -text     => ' vorheriger Schritt',
    -command  => [ \&switch_frame, -1 ]
)->form( -left => '%30' );
my $but_weiter = $framebut->Button(
    -compound => 'right',
    -image    => $pic_arrow_right,
    -text     => 'nächster Schritt ',
    -command  => [ \&switch_frame, 1 ]
)->form( -left => $but_zur );

#---------------------------------------------------------------------------
#  Mainloop
#---------------------------------------------------------------------------

laden($xml_pfad);
if ($auto) {
    $thr = threads->create('auto_speichern');
}
MainLoop();

#---------------------------------------------------------------------------
#
# Subroutine: auto_speichern
#
# Wird das Programm mit aktivertem Autospeichern aufgerufen, wird diese 
# Funktion zum Thread und in dem von $minuten angegebenen Interval 
# <speichern> auf.
#
#---------------------------------------------------------------------------

sub auto_speichern {
    print "Thread gestartet\n";
    while (1) {
        my $t = $minuten * 60;
        sleep $t;

        # Thread 'cancellation' signal handler
        local $SIG{'KILL'} = sub { threads->exit(); };
        &speichern;
        print 'Es wurde gespeichert.';
    }

    return;
}    # ----------  end of subroutine auto_speichern  ----------

#---------------------------------------------------------------------------
#
# Subroutine: build_frame0
#
# Baut die Oberfläche von Zielbestimmungen. Diese Besteht aus einer Tabelle
# und drei Buttons.
#
#---------------------------------------------------------------------------

sub build_frame0 {

 #---------------------------------------------------------------------------
 #  Tabellenüberschrift wird erstellt indem man eine Tabelle bestehend
 #  aus einer Zeile gefüllt mit Labels erstellt und diese über die eigentliche
 #  Tabelle stellt
 #---------------------------------------------------------------------------

    my $nztablehead = $frame_stack[0]->Table(
        -columns    => 2,
        -scrollbars => '0'
    );
    my $head1_label = $nztablehead->Label(
        -text   => 'Typ',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 20
    );
    my $head2_label = $nztablehead->Label(
        -text   => 'Beschreibung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 65

    );

    $nztablehead->put( 0, 0, $head1_label );
    $nztablehead->put( 0, 1, $head2_label );

    #---------------------------------------------------------------------------
    #  Tabelle mit 3 Spalten wird erzeugt für die Einträge
    #
    #  Zielbestimmung, Beschreibung, ID
    #
    #  Die ID ist notwendig um die leichter auf Einträge zugreifen
    #  zu können
    #---------------------------------------------------------------------------
    my $nztable = $frame_stack[0]->Table(
        -columns    => 3,
        -rows       => 19,
        -scrollbars => 'oe'
    );

    my $frame_daten_buttons = $frame_stack[0]->Frame();

    #---------------------------------------------------------------------------
    #  3 Buttons für die einzelnen Funktionsaufrufe
    #---------------------------------------------------------------------------

    my $zielneu_but = $frame_daten_buttons->Button(
        -text     => 'Neues Ziel',
        -compound => 'left',
        -image    => $pic_neu,
        -command  => \sub {
            ziel_dialog_neu( \$nztable );
        }
    );
    my $zielbearb_but = $frame_daten_buttons->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            ziel_bearbeiten( \$nztable );
        }
    );
    my $zielloesch_but = $frame_daten_buttons->Button(
        -text     => 'Löschen',
        -compound => 'left',
        -image    => $pic_delete,
        -command  => \sub {
            ziel_loeschen( \$nztable );
            set_aendern();
        }
    );

    $frame_daten_buttons->pack( -anchor => 'w' );
    $zielneu_but->pack( -side => 'left' );
    $zielbearb_but->pack( -side => 'left' );
    $zielloesch_but->pack( -side => 'left' );
    $nztablehead->pack( -anchor => 'w' );
    $nztable->pack( -anchor => 'w', -fill => 'both' );

    $projekt{zielbestimmungen} =
      \$nztable;    #table wird an Hash Projekt übergeben
    return;
}    # ----------  end of subroutine buildframe0  ----------

#---------------------------------------------------------------------------
#
# Subroutine: build_frame1
#
# Baut die Oberfläche für die Einsatzgebiete. Diese besteht aus den Textfeldern
#
# - Produkteinsatz
# - Zielgruppen
# - Arbeitsbereiche
# - Betriebsbedingungen
#
#---------------------------------------------------------------------------
sub build_frame1 {

    #Frame zum gruppieren der Frames von Produkteinsatz und Zielgruppen
    my $frame_einsatz_oben = $frame_stack[1]->Frame();

    #Frame zum gruppieren der Frames von Arbeitsbereiche und Betriebsbedingungen
    my $frame_einsatz_unten = $frame_stack[1]->Frame();

    #Label, Frame und Textblock für Produkteinsatz erstellen
    my $frame_peinsatz = $frame_einsatz_oben->Frame();
    my $lab_peinsatz = $frame_peinsatz->Label( -text => 'Produkteinsatz' );
    my $txt_einsatz1 = $frame_peinsatz->Scrolled( 'Text', -scrollbars => 'oe' );
    $txt_einsatz1->configure( -width => 40, height => 13 );

    #Label, Frame und Textblock für Zielgruppen erstellen
    my $frame_zgruppen = $frame_einsatz_oben->Frame();
    my $lab_zgruppen = $frame_zgruppen->Label( -text => 'Zielgruppen' );
    my $txt_zgruppen = $frame_zgruppen->Scrolled( 'Text', -scrollbars => 'oe' );
    $txt_zgruppen->configure( -width => 40, height => 13 );

    #Label, Frame und Textblock für Arbeitsbereiche erstellen
    my $frame_abereiche = $frame_einsatz_unten->Frame();
    my $lab_abereiche = $frame_abereiche->Label( -text => 'Arbeitsbereiche' );
    my $txt_abereiche =
      $frame_abereiche->Scrolled( 'Text', -scrollbars => 'oe' );
    $txt_abereiche->configure( -width => 40, height => 13 );

    #Label, Frame und Textblock für Arbeitsbereiche erstellen
    my $frame_bbedingungen = $frame_einsatz_unten->Frame();
    my $lab_bbedingungen =
      $frame_bbedingungen->Label( -text => 'Betriebsbedingungen' );
    my $txt_bbedingungen =
      $frame_bbedingungen->Scrolled( 'Text', -scrollbars => 'oe' );
    $txt_bbedingungen->configure( -width => 40, height => 13 );

    $projekt{produkteinsatz} = $txt_einsatz1;
    $projekt{zielgruppen} = $txt_zgruppen;
    $projekt{arbeitsbereiche} = $txt_abereiche;
    $projekt{betriebsbedingungen} = $txt_bbedingungen;

    $txt_einsatz1->bind('<KeyPress>' , \&set_aendern);
    $txt_zgruppen->bind('<KeyPress>' , \&set_aendern);
    $txt_abereiche->bind('<KeyPress>' , \&set_aendern);
    $txt_bbedingungen->bind('<KeyPress>' , \&set_aendern);


    $frame_einsatz_oben->pack();
    $frame_einsatz_unten->pack();

    $frame_peinsatz->pack( -side => 'left' );
    $lab_peinsatz->pack( -anchor => 'w' );
    $txt_einsatz1->pack( -anchor => 'w' );

    $frame_zgruppen->pack( -side => 'left' );
    $lab_zgruppen->pack( -anchor => 'w' );
    $txt_zgruppen->pack( -anchor => 'w' );

    $frame_abereiche->pack( -side => 'left' );
    $lab_abereiche->pack( -anchor => 'w' );
    $txt_abereiche->pack( -anchor => 'w' );

    $frame_bbedingungen->pack( -side => 'left' );
    $lab_bbedingungen->pack( -anchor => 'w' );
    $txt_bbedingungen->pack( -anchor => 'w' );
    return;
}

#---------------------------------------------------------------------------
#
# Subroutine: build_frame2
#
# Baut die Oberfläche für die Übersicht. Diese besteht aus einem
# Textfeld
#
#---------------------------------------------------------------------------

sub build_frame2 {
    my $pfad;

    # Frame um Label "Produktübersicht" und um ein Textfeld erstellen
    my $frame_produkt_uebersicht = $frame_stack[2]->Frame();

    my $frame_bild     = $frame_produkt_uebersicht->Frame();
    my $ent_frame      = $frame_bild->Frame();
    my $lab_frame      = $frame_bild->Frame();
    my $lab_bilddatei  = $lab_frame->Label( -text => 'Bild' );
    my $ent_btn_frame  = $ent_frame->Frame();
    my $lab_bildbeschr = $lab_frame->Label( -text => 'Beschreibung' );
    my $beschreibung;
    my $entry_bildbeschr = $ent_frame->Entry( -textvariable => \$beschreibung );
    my $lab_produkt_uebersicht =
      $frame_produkt_uebersicht->Label( -text => 'Produktübersicht' );
    my $txt_produkt_uebersicht =
      $frame_produkt_uebersicht->Scrolled( 'Text', -scrollbars => 'oe' );

    my $entry_bilddatei = $ent_btn_frame->Entry( -textvariable => \$pfad );
    my $button_bilddatei = $ent_btn_frame->Button(
        -image   => $pic_oeffne,
        -command => sub {
            my $types = [
                [ 'png',          '.png' ],
                [ 'jpeg',         '.jpeg' ],
                [ 'jpg',          '.jpg' ],
                [ 'gif',          '.gif' ],
                [ 'Alle Dateien', q{*} ]
            ];

            #Auswahl der Bilddatei
            $pfad = $ent_btn_frame->getOpenFile( -filetypes => $types, );
        }
    );

    #Wenn $entry_Bilddatei den Focus verliert, wird in Funktion
    #check_bild_bind die Datei auf Gültigkeit überprüft.
    $entry_bilddatei->bind( '<FocusOut>', [ \&check_bild_bind ] );
    my $balloon = $button_bilddatei->Balloon();

    # Wenn Maus über die Buttons gezogen wird, dann kurzen Hilfetext in Form
    # eines Ballons einblenden um dem Benutzer die Funktionalität zu erklären
    $balloon->attach( $button_bilddatei, -msg => 'Dateisystem durchsuchen...' );
    $balloon->attach(
        $entry_bilddatei,
        -msg             => 'Pfad zum Bild',
        -balloonposition => 'mouse'
    );
    $balloon->attach(
        $entry_bildbeschr,
        -msg             => 'Beschreibung zum Bild',
        -balloonposition => 'mouse'
    );

    $entry_bildbeschr       ->bind('<KeyPress>' , \&set_aendern);
    $txt_produkt_uebersicht ->bind('<KeyPress>' , \&set_aendern);
    $entry_bilddatei        ->bind('<KeyPress>' , \&set_aendern);

    #---------------------------------------------------------------------------
    #  Hier werden die einzelnen Inhalte per Referenz einem Hash zugewiesen
    #  TODO: Referenzen noch anpassen, dass nur der Inhalt in den Projekt-Hash
    #  kopiert wird und nicht die Referenz auf das Widget
    #---------------------------------------------------------------------------
    $projekt{produktuebersicht}                  = $txt_produkt_uebersicht;
    $projekt{produktuebersicht_bildpfad}         = \$pfad;
    $projekt{produktuebersicht_bildbeschreibung} = \$beschreibung;

    #---------------------------------------------------------------------------
    #  Pack-Stube
    #---------------------------------------------------------------------------
    $frame_produkt_uebersicht->pack( -expand => '1', -fill => 'both' );
    $frame_bild->pack( -fill => 'both' );
    $lab_frame->pack( -side => 'left' );
    $ent_frame->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $ent_btn_frame->pack( -fill => 'x', -expand => '1' );
    $lab_bilddatei->pack( -anchor => 'w' );
    $lab_bildbeschr->pack( -anchor => 'w' );
    $entry_bilddatei->pack( -fill => 'x', -expand => '1', -side => 'left' );
    $button_bilddatei->pack( -side => 'left' );
    $entry_bildbeschr->pack( -fill => 'x', -expand => '1' );
    $lab_produkt_uebersicht->pack( -anchor => 'w' );
    $txt_produkt_uebersicht->pack(
        -anchor => 'w',
        -fill   => 'both',
        -expand => '1'
    );

    return;
}

#---------------------------------------------------------------------------
#
#  Subroutine: build_frame3
#
#  Baut die Oberfläche für die Funktionen. Diese besteht aus einer Tabelle
#  und 3 Buttons
#
#---------------------------------------------------------------------------
sub build_frame3 {
    $frame_stack[3]->configure();

 #---------------------------------------------------------------------------
 #  Tabellenüberschrift wird erstellt indem man eine Tabelle bestehend
 #  aus einer Zeile gefüllt mit Labels erstellt und diese über die eigentliche
 #  Tabelle stellt
 #---------------------------------------------------------------------------
    my $func_table_head = $frame_stack[3]->Table(
        -columns    => 4,
        -rows       => 1,
        -scrollbars => '0',
        -relief     => 'raised'
    );

    my $tf_head1_label = $func_table_head->Label(
        -text   => 'Num.',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 5
    );
    my $tf_head2_label = $func_table_head->Label(
        -text   => 'Geschäftspr.',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 11
    );

    my $tf_head3_label = $func_table_head->Label(
        -text   => 'Akteure',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 15

    );

    my $tf_head4_label = $func_table_head->Label(
        -text   => 'Beschreibung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 50

    );

    #Erstellt den Tabellenkopf
    $func_table_head->put( 0, 1, $tf_head1_label );
    $func_table_head->put( 0, 2, $tf_head2_label );
    $func_table_head->put( 0, 3, $tf_head3_label );
    $func_table_head->put( 0, 4, $tf_head4_label );

    #---------------------------------------------------------------------------
    #  Tabelle mit 5 Spalten wird erzeugt für die Einträge
    #
    #  Nummer, Geschäftsprozess, Akteure, Beschreibung, ID
    #
    #  Die ID ist notwendig um leichter auf Einträge zugreifen
    #  zu können, ist im Programm aber nicht sichtbar.
    #---------------------------------------------------------------------------

    #Erstellt die Tabelle die die Funktionen enthält
    my $func_table = $frame_stack[3]->Table(
        -columns    => 5,
        -rows       => 17,
        -scrollbars => 'oe',
        -relief     => 'raised'
    );

    # Erstellt einen Frame mit den Buttons "Neu", "Bearbeiten" und "Löschen"
    my $frame_buttons   = $frame_stack[3]->Frame();
    my $funk_button_neu = $frame_buttons->Button(
        -text     => 'Neue Funktion',
        -compound => 'left',
        -image    => $pic_neu,
        -command  => \sub {
            funktion_dialog_neu( \$func_table );
        }
    );
    my $funk_button_loesch = $frame_buttons->Button(
        -text     => 'Löschen',
        -compound => 'left',
        -image    => $pic_delete,
        -command  => \sub {
            funktion_loeschen( \$func_table );
            set_aendern();
        }
    );
    my $funk_button_bearb = $frame_buttons->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            funktion_bearbeiten( \$func_table );
        }
    );

    #----------------------------------------------------------------
    #  Funktionen -- packs
    #----------------------------------------------------------------
    $frame_buttons->pack( -fill => 'x', -side => 'top', -anchor => 'nw' );
    $funk_button_neu->pack( -side => 'left' );
    $funk_button_bearb->pack( -side => 'left' );
    $funk_button_loesch->pack( -side => 'left' );
    $func_table_head->pack( -anchor => 'w' );
    $func_table->pack( -anchor => 'w' );
    $projekt{funktionen} = \$func_table;
    return;
}

#---------------------------------------------------------------------------
#
# Subroutine: build_frame4
#
#  Baut die Oberfläche für die Daten. Diese besteht aus einer Tabelle und
#  3 Buttons
#
#---------------------------------------------------------------------------
sub build_frame4 {

    #Tabellenüberschriften
    my $daten_table_head = $frame_stack[4]->Table(
        -columns    => 3,
        -relief     => 'raised',
        -scrollbars => '0',
    );

    my $head1_label = $daten_table_head->Label(
        -text   => 'Nummer',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 6
    );

    my $head2_label = $daten_table_head->Label(
        -text   => 'Bezeichnung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 35
    );
    my $head3_label = $daten_table_head->Label(
        -text   => 'Beschreibung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 41
    );

    $daten_table_head->put( 0, 1, $head1_label );
    $daten_table_head->put( 0, 2, $head2_label );
    $daten_table_head->put( 0, 3, $head3_label );

    #---------------------------------------------------------------------------
    #  Tabelle mit 4 Spalten wird erzeugt für die Einträge
    #
    #  Nummer, Bezeichnung, Beschreibung, ID
    #
    #  Die ID ist notwendig um leichter auf Einträge zugreifen
    #  zu können, ist im Programm aber nicht sichtbar.
    #---------------------------------------------------------------------------
    my $daten_table = $frame_stack[4]->Table(
        -columns    => 4,
        -rows       => 17,
        -scrollbars => 'oe',
        -relief     => 'raised'
    );

    my $frame_daten_buttons = $frame_stack[4]->Frame();

    my $but_neu = $frame_daten_buttons->Button(
        -text     => 'Neues Datum',
        -compound => 'left',
        -image    => $pic_neu,
        -command  => \sub {
            datum_dialog_neu( \$daten_table );
        }
    );

    my $but_bearb = $frame_daten_buttons->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            datum_bearbeiten( \$daten_table );
        }
    );

    my $but_loesch = $frame_daten_buttons->Button(
        -text     => 'Löschen',
        -compound => 'left',
        -image    => $pic_delete,
        -command  => \sub {
            datum_loeschen( \$daten_table );
            set_aendern();
          }

    );

    $frame_daten_buttons->pack( -anchor => 'w' );
    $but_neu->pack( -side => 'left' );
    $but_bearb->pack( -side => 'left' );
    $but_loesch->pack( -side => 'left' );
    $daten_table_head->pack( -anchor => 'w' );
    $daten_table->pack( -anchor => 'w' );

    $projekt{daten} = \$daten_table;
    return;
}

#---------------------------------------------------------------------------
#
# Subroutine: build_frame5
#
#  Baut die Oberfläche für die Leistungen. Diese besteht aus einer Tabelle und
#  3 Buttons
#
#---------------------------------------------------------------------------
sub build_frame5 {

    #Tabellenüberschriften
    my $leistungen_table_head = $frame_stack[5]->Table(
        -columns    => 3,
        -relief     => 'raised',
        -scrollbars => '0',
    );

    my $head1_label = $leistungen_table_head->Label(
        -text   => 'Nummer',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 6
    );

    my $head2_label = $leistungen_table_head->Label(
        -text   => 'Bezeichnung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 35
    );
    my $head3_label = $leistungen_table_head->Label(
        -text   => 'Beschreibung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 41
    );

    $leistungen_table_head->put( 0, 1, $head1_label );
    $leistungen_table_head->put( 0, 2, $head2_label );
    $leistungen_table_head->put( 0, 3, $head3_label );

    #Erstellt die Tabelle die die Leistungen enthält
    my $leistungen_table = $frame_stack[5]->Table(

        #        -columns    => 4,
        -columns    => 3,
        -rows       => 17,
        -scrollbars => 'oe',
        -relief     => 'raised'
    );

    my $frame_leistungen_buttons = $frame_stack[5]->Frame();

    my $but_neu = $frame_leistungen_buttons->Button(
        -text     => 'Neue Leistung',
        -compound => 'left',
        -image    => $pic_neu,
        -command  => \sub {
            leistung_dialog_neu( \$leistungen_table );
        }
    );

    my $but_bearb = $frame_leistungen_buttons->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            leistung_bearbeiten( \$leistungen_table );
        }
    );

    my $but_loesch = $frame_leistungen_buttons->Button(
        -text     => 'Löschen',
        -compound => 'left',
        -image    => $pic_delete,
        -command  => \sub {
            leistung_loeschen( \$leistungen_table );
            set_aendern();
          }

    );

    $frame_leistungen_buttons->pack( -anchor => 'w' );
    $but_neu->pack( -side => 'left' );
    $but_bearb->pack( -side => 'left' );
    $but_loesch->pack( -side => 'left' );
    $leistungen_table_head->pack( -anchor => 'w' );
    $leistungen_table->pack( -anchor => 'w' );

    $projekt{leistungen} = \$leistungen_table;
    return;

}

#---------------------------------------------------------------------------
#
#  Subroutine: build_frame6
#
#  Baut die Oberfläche für die Qualitätanforderungen. Diese besteht aus 21
#  Elementen von Typ Tk::ComboEntry.
#  Folgende Qualitätsanforderungen werden dabei berücksichtigt:
#
# - Funktionalität : Angemessenheit, Richtigkeit, Interoperabilität, Ordnungsmäkeit, Sicherheit
#
# - Zuverlässigkeit : Reife, Fehlertoleranz, Wiederherstellbarkeit
#
# - Benutzbarkeit : Verständlichkeit, Erlernbarkeit, Bedienbarkeit
#
# - Effizienz : Zeitverhalten, Verbrauchsverhalten
#
# - Änderbarkeit : Analysierbarkeit, Modifizierbarkeit, Stabilität, Prüfbarkeit
#
# - Übertragbarkeit : Anpassbarkeit, Installierbarkeit, Konformität, Austauschbarkeit
#
#---------------------------------------------------------------------------
sub build_frame6 {
    my @ilist = ( 'sehr gut', 'gut', 'normal', 'nicht relevant' );
    my %qualitaet = ();

    #----Funktionalität----
    #Frame links
    my $frame_q_links =
      $frame_stack[6]->Frame()->pack( -side => 'left', -anchor => 'n' );

    #Frame Funktionalität mit Überschrift erstellen
    my $frame_q_funkt = $frame_q_links->Frame(
        -label       => 'Funktionalität',
        -borderwidth => 2,
        -relief      => 'groove'
    )->pack( -fill => 'x', -pady => 4 );

    #Angemessenheit
    $frame_q_funkt->ComboEntry(
        -textvariable => \$qualitaet{angemessenheit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Angemessenheit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Richtigkeit
    $frame_q_funkt->ComboEntry(
        -textvariable => \$qualitaet{richtigkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Richtigkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Interoperabilität
    $frame_q_funkt->ComboEntry(
        -textvariable => \$qualitaet{interoperabilitaet},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Interoperabilität',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #OrdnungsmäÃigkeit
    $frame_q_funkt->ComboEntry(
        -textvariable => \$qualitaet{ordnungsmaessigkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Ordnungsmäßigkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Sicherheit
    $frame_q_funkt->ComboEntry(
        -textvariable => \$qualitaet{sicherheit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Sicherheit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #----Zuverlässigkeit----
    #Frame Zuverlässigkeit mit Überschrift erstellen
    my $frame_q_zuverl = $frame_q_links->Frame(
        -label       => 'Zuverlässigkeit',
        -borderwidth => 2,
        -relief      => 'groove'
    )->pack( -fill => 'x', -pady => 4 );

    #Reife
    $frame_q_zuverl->ComboEntry(
        -textvariable => \$qualitaet{reife},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Reife',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Fehlertoleranz
    $frame_q_zuverl->ComboEntry(
        -textvariable => \$qualitaet{fehlertoleranz},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Fehlertoleranz',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Wiederherstellbarkeit
    $frame_q_zuverl->ComboEntry(
        -textvariable => \$qualitaet{wiederherstellbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Wiederherstellbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #----Benutzbarkeit----
    #Frame Benutzbarkeit mit Überschrift erstellen
    my $frame_q_benutz = $frame_q_links->Frame(
        -label       => 'Benutzbarkeit',
        -borderwidth => 2,
        -relief      => 'groove'
    )->pack( -fill => 'x', -pady => 4 );

    #Verständlichkeit
    $frame_q_benutz->ComboEntry(
        -textvariable => \$qualitaet{verstaendlichkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Verstandlichkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Erlernbarkeit
    $frame_q_benutz->ComboEntry(
        -textvariable => \$qualitaet{erlernbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Erlernbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Bedienbarkeit
    $frame_q_benutz->ComboEntry(
        -textvariable => \$qualitaet{bedienbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Bedienbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Frame rechts
    my $frame_q_rechts =
      $frame_stack[6]->Frame()->pack( -side => 'left', -anchor => 'n' );

    #----Effizienz----
    #Frame Effizienz mit Überschrift erstellen
    my $frame_q_effi = $frame_q_rechts->Frame(
        -label       => 'Effizienz',
        -borderwidth => 2,
        -relief      => 'groove'
    )->pack( -fill => 'x', -pady => 4 );

    #Zeitverhalten
    $frame_q_effi->ComboEntry(
        -textvariable => \$qualitaet{zeitverhalten},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Zeitverhalten',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Verbrauchsverhalten
    $frame_q_effi->ComboEntry(
        -textvariable => \$qualitaet{verbrauchsverhalten},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Verbrauchsverhalten',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #----Änderbarkeit----
    #Frame Effizienz mit Überschrift erstellen
    my $frame_q_ande = $frame_q_rechts->Frame(
        -label       => 'Änderbarkeit',
        -borderwidth => 2,
        -relief      => 'groove'
    )->pack( -fill => 'x', -pady => 4 );

    #Analysierbarkeit
    $frame_q_ande->ComboEntry(
        -textvariable => \$qualitaet{analysierbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Analysierbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Modifizierbarkeit
    $frame_q_ande->ComboEntry(
        -textvariable => \$qualitaet{modifizierbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Modifizierbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Stabilität
    $frame_q_ande->ComboEntry(
        -textvariable => \$qualitaet{stabilitaet},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Stabilität',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Prüfbarkeit
    $frame_q_ande->ComboEntry(
        -textvariable => \$qualitaet{pruefbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Prüfbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #----Übertragbarkeit----
    #Frame Übertragbarkeit mit Überschrift erstellen
    my $frame_q_ubert = $frame_q_rechts->Frame(
        -label       => 'Übertragbarkeit',
        -borderwidth => 2,
        -relief      => 'groove'
    )->pack( -fill => 'x', -pady => 4 );

    #Anpassbarkeit
    $frame_q_ubert->ComboEntry(
        -textvariable => \$qualitaet{anpassbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Anpassbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Installierbarkeit
    $frame_q_ubert->ComboEntry(
        -textvariable => \$qualitaet{installierbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Installierbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Konformität
    $frame_q_ubert->ComboEntry(
        -textvariable => \$qualitaet{konformitaet},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Konformität',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );

    #Austauschbarkeit
    $frame_q_ubert->ComboEntry(
        -textvariable => \$qualitaet{austauschbarkeit},
        -itemlist     => [@ilist],
        -width        => 20,
        -label        => 'Austauschbarkeit',
        -labelPack    => [ -side => 'left' ],
        -borderwidth  => '0'
    )->pack( -anchor => 'e', -pady => 2 );
    $projekt{qualitaet} = \%qualitaet;

#---------------------------------------------------------------------------
#  Jedes einzelne ComboEntry-Widget mit binding versehen
#---------------------------------------------------------------------------
    foreach($frame_q_links->packSlaves()){
        foreach my $cb ($ARG->packSlaves()){
            foreach my $element ($cb->packSlaves()){
                $element->bind ('<ButtonPress>', [\&set_aendern]);
            }
        }
    }
    foreach($frame_q_rechts->packSlaves()){
        foreach my $cb ($ARG->packSlaves()){
            foreach my $element ($cb->packSlaves()){
                $element->bind ('<ButtonPress>', [\&set_aendern]);
            }
        }
    }
    return;
}

#---------------------------------------------------------------------------
#
# Subroutine: build_frame7
#
#  Baut die Oberfläche für die GUI.
#
#
#---------------------------------------------------------------------------
sub build_frame7 {
    $frame_stack[7]->configure();

 #---------------------------------------------------------------------------
 #  Tabellenüberschrift wird erstellt indem man eine Tabelle bestehend
 #  aus einer Zeile gefüllt mit Labels erstellt und diese über die eigentliche
 #  Tabelle stellt
 #---------------------------------------------------------------------------
    my $gui_table_head = $frame_stack[7]->Table(
        -columns    => 4,
        -rows       => 1,
        -scrollbars => '0',
        -relief     => 'raised'
    );

    my $lab_table_kopf1 = $gui_table_head->Label(
        -text   => 'Num.',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 5
    );
    my $lab_table_kopf2 = $gui_table_head->Label(
        -text   => 'Bezeichnung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 11
    );

    my $tf_head3_label = $gui_table_head->Label(
        -text   => 'Akteure',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 15

    );

    my $tf_head4_label = $gui_table_head->Label(
        -text   => 'Beschreibung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 50

    );

    #Erstellt den Tabellenkopf
    $gui_table_head->put( 0, 1, $lab_table_kopf1 );
    $gui_table_head->put( 0, 2, $lab_table_kopf2 );
    $gui_table_head->put( 0, 3, $tf_head3_label );
    $gui_table_head->put( 0, 4, $tf_head4_label );

    #---------------------------------------------------------------------------
    #  Tabelle mit 5 Spalten wird erzeugt für die Einträge
    #
    #  Nummer, Geschäftsprozess, Akteure, Beschreibung, ID
    #
    #  Die ID ist notwendig um die einzelnen Einträge in der
    #  Datenbank wiederzufinden und leichter auf Einträge zugreifen
    #  zu können, ist im Programm aber nicht sichtbar.
    #---------------------------------------------------------------------------

    #Erstellt die Tabelle die die Funktionen enthält
    my $gui_table = $frame_stack[7]->Table(
        -columns    => 5,
        -rows       => 17,
        -scrollbars => 'oe',
        -relief     => 'raised'
    );

    # Erstellt einen Frame mit den Buttons "Neu", "Bearbeiten" und "Löschen"
    my $frame_buttons  = $frame_stack[7]->Frame();
    my $gui_button_neu = $frame_buttons->Button(
        -text     => 'Neue GUI',
        -compound => 'left',
        -image    => $pic_neu,
        -command  => \sub {
            gui_dialog_neu( \$gui_table );
        }
    );
    my $gui_button_loesch = $frame_buttons->Button(
        -text     => 'Löschen',
        -compound => 'left',
        -image    => $pic_delete,
        -command  => \sub {
            gui_loeschen( \$gui_table );
            set_aendern();
        }
    );
    my $gui_button_bearb = $frame_buttons->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            gui_bearbeiten( \$gui_table );
        }
    );

    #----------------------------------------------------------------
    #  Funktionen -- packs
    #----------------------------------------------------------------
    $frame_buttons->pack( -fill => 'x', -side => 'top', -anchor => 'nw' );
    $gui_button_neu->pack( -side => 'left' );
    $gui_button_bearb->pack( -side => 'left' );
    $gui_button_loesch->pack( -side => 'left' );
    $gui_table_head->pack( -anchor => 'w' );
    $gui_table->pack( -anchor => 'w' );
    $projekt{gui} = \$gui_table;
    return;
}

#---------------------------------------------------------------------------
#
# Subroutine: build_frame8
#
#  Baut die Oberfläche für die nichtfuntkionale Anforderungen. Diese besteht
#  aus einem Element vom Typ Tk::Text.
#
#---------------------------------------------------------------------------

sub build_frame8 {
    $frame_stack[8]->Label( -text => 'Nichtfunktionale Anforderungen' )
      ->pack( -anchor => 'nw' );
    my $text_nichtfunkt =
      $frame_stack[8]->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $text_nichtfunkt->bind('<KeyPress>' , \&set_aendern);
    $text_nichtfunkt->configure( -width => '87', height => '28' );
    $projekt{anforderungen} = $text_nichtfunkt;
    return;
}

#------------------------------------------------------------------------
#
# Subroutine: build_frame9
#
# Baut die Oberfläche für die technische Umbebung. Diese besteht aus den
# Textfeldern:
# - Produktumgebung
# - Software
# - Hardware
# - Orgware
# - Schnittstellen
#
#---------------------------------------------------------------------------
sub build_frame9 {

    #Frame zum gruppieren von Produktumgebung und Software erstellen
    my $frame_techn_links = $frame_stack[9]->Frame()->pack( -side => 'left' );

    #Frame zum gruppieren von Hardware, Orgware und Schnittstellen erstellen
    my $frame_techn_rechts = $frame_stack[9]->Frame()->pack( -side => 'left' );

    #Label, Frame und Textblock für Produkumgebung erstellen
    my $frame_pumgebung = $frame_techn_links->Frame()->pack();
    $frame_pumgebung->Label( -text => 'Produktumgebung' )
      ->pack( -anchor => 'w' );
    my $txt_pumgebung =
      $frame_pumgebung->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_pumgebung->configure( -width => '40', height => '13' );

    #Label, Frame und Textblock für Software erstellen
    my $frame_sware = $frame_techn_links->Frame()->pack();
    $frame_pumgebung->Label( -text => 'Software' )->pack( -anchor => 'w' );
    my $txt_sware =
      $frame_sware->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_sware->configure( -width => '40', height => '13' );

    #Label, Frame und Textblock für Hardware erstellen
    my $frame_hware = $frame_techn_rechts->Frame()->pack();
    $frame_hware->Label( -text => 'Hardware' )->pack( -anchor => 'w' );
    my $txt_hware =
      $frame_hware->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_hware->configure( -width => '40', height => '8' );

    #Label, Frame und Textblock für Orgware erstellen
    my $frame_oware = $frame_techn_rechts->Frame()->pack();
    $frame_oware->Label( -text => 'Orgware' )->pack( -anchor => 'w' );
    my $txt_oware =
      $frame_oware->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_oware->configure( -width => '40', height => '8' );

    #Label, Frame und Textblock für Schnittstellen erstellen
    my $frame_sstellen = $frame_techn_rechts->Frame()->pack();
    $frame_sstellen->Label( -text => 'Schnittstellen' )->pack( -anchor => 'w' );
    my $txt_sstellen =
      $frame_sstellen->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_sstellen->configure( -width => '40', height => '8' );

    $txt_pumgebung->bind( '<KeyPress>', \&set_aendern );
    $txt_sware->bind( '<KeyPress>', \&set_aendern );
    $txt_hware->bind( '<KeyPress>', \&set_aendern );
    $txt_oware->bind( '<KeyPress>', \&set_aendern );
    $txt_sstellen->bind( '<KeyPress>', \&set_aendern );

    $projekt{produktumgebung} = $txt_pumgebung;
    $projekt{software}        = $txt_sware;
    $projekt{hardware}        = $txt_hware;
    $projekt{orgware}         = $txt_oware;
    $projekt{schnittstellen}  = $txt_sstellen;
    return;

}

#-------------------------------------------------------------------------------
#     Subroutine:  build_frame10
#
# Baut die Oberfläche für die Entwicklungsumbebung. Diese besteht aus den
# Textfeldern:
# - Entwicklungsumbebung
# - Software
# - Hardware
# - Orgware
# - Schnittstellen
#-------------------------------------------------------------------------------
sub build_frame10 {

    #Frame zum gruppieren von Produktumgebung und Software erstellen
    my $frame_techn_links = $frame_stack[10]->Frame()->pack( -side => 'left' );

    #Frame zum gruppieren von Hardware, Orgware und Schnittstellen erstellen
    my $frame_techn_rechts = $frame_stack[10]->Frame()->pack( -side => 'left' );

    #Label, Frame und Textblock für Entwicklungsumgebung erstellen
    my $frame_pumgebung = $frame_techn_links->Frame()->pack();
    $frame_pumgebung->Label( -text => 'Entwicklungsumgebung' )
      ->pack( -anchor => 'w' );
    my $txt_pumgebung =
      $frame_pumgebung->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_pumgebung->configure( -width => '40', height => '13' );

    #Label, Frame und Textblock für Software erstellen
    my $frame_sware = $frame_techn_links->Frame()->pack();
    $frame_pumgebung->Label( -text => 'Software' )->pack( -anchor => 'w' );
    my $txt_sware =
      $frame_sware->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_sware->configure( -width => '40', height => '13' );

    #Label, Frame und Textblock für Hardware erstellen
    my $frame_hware = $frame_techn_rechts->Frame()->pack();
    $frame_hware->Label( -text => 'Hardware' )->pack( -anchor => 'w' );
    my $txt_hware =
      $frame_hware->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_hware->configure( -width => '40', height => '8' );

    #Label, Frame und Textblock für Orgware erstellen
    my $frame_oware = $frame_techn_rechts->Frame()->pack();
    $frame_oware->Label( -text => 'Orgware' )->pack( -anchor => 'w' );
    my $txt_oware =
      $frame_oware->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_oware->configure( -width => '40', height => '8' );

    #Label, Frame und Textblock für Schnittstellen erstellen
    my $frame_sstellen = $frame_techn_rechts->Frame()->pack();
    $frame_sstellen->Label( -text => 'Schnittstellen' )->pack( -anchor => 'w' );
    my $txt_sstellen =
      $frame_sstellen->Scrolled( 'Text', -scrollbars => 'oe' )
      ->pack( -anchor => 'w' );
    $txt_sstellen->configure( -width => '40', height => '8' );

    $txt_pumgebung ->bind('<KeyPress>' , \&set_aendern);
    $txt_sware     ->bind('<KeyPress>' , \&set_aendern);
    $txt_sstellen  ->bind('<KeyPress>' , \&set_aendern);
    $txt_oware     ->bind('<KeyPress>' , \&set_aendern);
    $txt_hware     ->bind('<KeyPress>' , \&set_aendern);
    $projekt{e_produktumgebung} = $txt_pumgebung;
    $projekt{e_software}        = $txt_sware;
    $projekt{e_schnittstellen}  = $txt_sstellen;
    $projekt{e_orgware}         = $txt_oware;
    $projekt{e_hardware}        = $txt_hware;
    return;
}    # ----------  end of subroutine build_frame10  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  build_frame11
#
#     Baut die Oberfläche für die Teilprodukte
#-------------------------------------------------------------------------------
sub build_frame11 {

    my $text_beschreibung = $frame_stack[11]->Scrolled(
        'Text',
        -scrollbars => 'oe',
        -height     => '16',
    );
    $text_beschreibung ->bind('<KeyPress>' , \&set_aendern);

    my $tpr_table_head = $frame_stack[11]->Table(
        -columns    => 4,
        -rows       => 1,
        -scrollbars => '0',
        -relief     => 'raised',
    );

    my $lab_table_kopf1 = $tpr_table_head->Label(
        -text   => 'Teilprodukte',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 84,
    );

    #Erstellt den Tabellenkopf
    $tpr_table_head->put( 0, 1, $lab_table_kopf1 );

    #---------------------------------------------------------------------------
    #  Tabelle mit 2 Spalten wird erzeugt für die Einträge
    #
    #  Bezeichnung, ID
    #
    #  Die ID ist notwendig um die einzelnen Einträge in der
    #  Datenbank wiederzufinden und leichter auf Einträge zugreifen
    #  zu können, ist im Programm aber nicht sichtbar.
    #---------------------------------------------------------------------------

    #Erstellt die Tabelle die die Funktionen enthält
    my $tpr_table = $frame_stack[11]->Table(
        -columns    => 2,
        -rows       => 7,
        -scrollbars => 'oe',
        -relief     => 'raised',
    );
    my $frame_button = $frame_stack[11]->Frame();

    my $button_neu = $frame_button->Button(
        -text     => 'Neues Teilprodukt',
        -image    => $pic_neu,
        -compound => 'left',
        -command  => sub {
            teilprodukt_dialog_neu( \$tpr_table );
        }
    );
    my $button_bearbeiten = $frame_button->Button(
        -text     => 'Bearbeiten',
        -image    => $pic_edit,
        -compound => 'left',
        -command  => sub {
            teilprodukt_bearbeiten( \$tpr_table );
        }
    );
    my $button_loeschen = $frame_button->Button(
        -text     => 'Löschen',
        -image    => $pic_delete,
        -compound => 'left',
        -command  => sub {
            teilprodukt_loeschen( \$tpr_table );
            set_aendern();
          }

    );
    $text_beschreibung->pack( -anchor => 'w', -fill => 'x' );
    $frame_button->pack( -fill => 'x' );
    $button_neu->pack( -side => 'left' );
    $button_bearbeiten->pack( -side => 'left' );
    $button_loeschen->pack( -side => 'left' );
    $tpr_table_head->pack( -anchor => 'w', -fill => 'x' );
    $tpr_table->pack( -anchor => 'w', -fill => 'x' );

    $projekt{teilprodukte_beschreibung} = $text_beschreibung;
    $projekt{teilprodukte}              = \$tpr_table;
    return;
}    # ----------  end of subroutine build_frame11  ----------

#---------------------------------------------------------------------------
#
# Subroutine: build_frame12
#
# Baut die Oberfläche für die Ergänzungen. Diese besteht aus einem
# Element vom Typ Tk::Text.
#
#---------------------------------------------------------------------------
sub build_frame12 {
    $frame_stack[12]->configure( -relief => 'flat' );

    my $pfad;
    my $frame_ergaenzungen =
      $frame_stack[12]->Frame( -height => 2 )->pack( -fill => 'x' );
    my $frame_bild     = $frame_ergaenzungen->Frame();
    my $ent_frame      = $frame_bild->Frame();
    my $lab_frame      = $frame_bild->Frame();
    my $lab_bilddatei  = $lab_frame->Label( -text => 'Bild' );
    my $ent_btn_frame  = $ent_frame->Frame();
    my $lab_bildbeschr = $lab_frame->Label( -text => 'Beschreibung' );
    my $beschreibung;
    my $entry_bildbeschr = $ent_frame->Entry( -textvariable => \$beschreibung );
    my $lab_ergaenzungen =
      $frame_ergaenzungen->Label( -text => 'Ergänzungen' );
    my $txt_ergaenzungen =
      $frame_ergaenzungen->Scrolled( 'Text', -scrollbars => 'oe' );
    my $entry_bilddatei = $ent_btn_frame->Entry( -textvariable => \$pfad );
    my $button_bilddatei = $ent_btn_frame->Button(
        -image   => $pic_oeffne,
        -command => sub {
            my $types = [
                [ 'png',          '.png' ],
                [ 'jpeg',         '.jpeg' ],
                [ 'jpg',          '.jpg' ],
                [ 'gif',          '.gif' ],
                [ 'Alle Dateien', q{*} ]
            ];
            my $r_pfad = $ent_btn_frame->getOpenFile( -filetypes => $types, );
            if ( !check_bild($r_pfad) ) { $pfad = $r_pfad }
        }
    );

    #Wenn $entry_Bilddatei den Focus verliert, wird in Funktion
    #check_bild_bind die Datei auf Gültigkeit überprüft.
    $entry_bilddatei->bind( '<FocusOut>', [ \&check_bild_bind ] );
    my $balloon = $button_bilddatei->Balloon();

    $projekt{'Ergaenzungen_Bild_Beschreibung'} = \$entry_bildbeschr;

    # Wenn Maus über die Buttons gezogen wird, dann kurzen Hilfetext in Form
    # eines Ballons einblenden um dem Benutzer die Funktionalität zu erklären
    $balloon->attach( $button_bilddatei, -msg => 'Dateisystem durchsuchen...' );
    $balloon->attach(
        $entry_bilddatei,
        -msg             => 'Pfad zum Bild',
        -balloonposition => 'mouse'
    );
    $balloon->attach(
        $entry_bildbeschr,
        -msg             => 'Beschreibung zum Bild',
        -balloonposition => 'mouse'
    );

    $entry_bilddatei->bind('<KeyPress>' , \&set_aendern);
    $entry_bildbeschr->bind('<KeyPress>' , \&set_aendern);
    $txt_ergaenzungen->bind('<KeyPress>' , \&set_aendern);
    #---------------------------------------------------------------------------
    #  Pack-Stube
    #---------------------------------------------------------------------------
    $frame_ergaenzungen->pack( -expand => '1', -fill => 'both' );
    $frame_bild->pack( -fill => 'both' );
    $lab_frame->pack( -side => 'left' );
    $ent_frame->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $ent_btn_frame->pack( -fill => 'x', -expand => '1' );
    $lab_bilddatei->pack( -anchor => 'w' );
    $lab_bildbeschr->pack( -anchor => 'w' );
    $entry_bilddatei->pack( -fill => 'x', -expand => '1', -side => 'left' );
    $button_bilddatei->pack( -side   => 'left' );
    $entry_bildbeschr->pack( -fill   => 'x', -expand => '1' );
    $lab_ergaenzungen->pack( -anchor => 'w' );
    $txt_ergaenzungen->pack(
        -anchor => 'w',
        -fill   => 'both',
        -expand => '1'
    );

    $projekt{'Ergaenzungen_Bild'} = \$pfad;
    $projekt{'Ergaenzungen_bes'}  = \$beschreibung;
    $projekt{'Ergaenzungen_txt'}  = $txt_ergaenzungen;
    return;
}

#-------------------------------------------------------------------------------
# Subroutine: build_frame13
#
# Baut die Oberfläche für die Testfälle. Diese besteht aus einem
# Element vom Typ Tk::Text und einer Tabelle.
#-------------------------------------------------------------------------------
sub build_frame13 {

    #Tabellenüberschriften
    my $table_head = $frame_stack[13]->Table(
        -columns    => 3,
        -relief     => 'raised',
        -scrollbars => '0',
    );

    my $head1_label = $table_head->Label(
        -text   => 'Nummer',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 6
    );

    my $head2_label = $table_head->Label(
        -text   => 'Bezeichnung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 35
    );
    my $head3_label = $table_head->Label(
        -text   => 'Beschreibung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 41
    );

    $table_head->put( 0, 1, $head1_label );
    $table_head->put( 0, 2, $head2_label );
    $table_head->put( 0, 3, $head3_label );

    #Erstellt die Tabelle die die Testfälle enthält
    my $table = $frame_stack[13]->Table(
        -columns    => 4,
        -rows       => 17,
        -scrollbars => 'oe',
        -relief     => 'raised'
    );

    my $frame_buttons = $frame_stack[13]->Frame();

    my $but_neu = $frame_buttons->Button(
        -text     => 'Neuer Testfall',
        -compound => 'left',
        -image    => $pic_neu,
        -command  => \sub {
            testfall_dialog_neu( \$table );
        }
    );

    my $but_bearb = $frame_buttons->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            testfall_bearbeiten( \$table );
        }
    );

    my $but_loesch = $frame_buttons->Button(
        -text     => 'Löschen',
        -compound => 'left',
        -image    => $pic_delete,
        -command  => \sub {
            testfall_loeschen( \$table );
            set_aendern();
          }

    );

    $frame_buttons->pack( -anchor => 'w' );
    $but_neu->pack( -side => 'left' );
    $but_bearb->pack( -side => 'left' );
    $but_loesch->pack( -side   => 'left' );
    $table_head->pack( -anchor => 'w' );
    $table->pack( -anchor => 'w' );

    $projekt{testfaelle} = \$table;

    return;
}    # ----------  end of subroutine build_frame13  ----------

#-------------------------------------------------------------------------------
# Subroutine: build_frame14
#
# Baut die Oberfläche für das Glossar
#-------------------------------------------------------------------------------
sub build_frame14 {

    #Tabellenüberschriften
    my $table_head = $frame_stack[14]->Table(
        -columns    => 2,
        -relief     => 'raised',
        -scrollbars => '0',
    );

    my $head1_label = $table_head->Label(
        -text   => 'Begriff',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 20,
    );

    my $head2_label = $table_head->Label(
        -text   => 'Erklärung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 63,
    );

    $table_head->put( 0, 1, $head1_label );
    $table_head->put( 0, 2, $head2_label );

    #Erstellt die Tabelle die die Testfälle enthält
    my $table = $frame_stack[14]->Table(
        -columns    => 3,
        -rows       => 17,
        -scrollbars => 'oe',
        -relief     => 'raised'
    );

    my $frame_buttons = $frame_stack[14]->Frame();

    my $but_neu = $frame_buttons->Button(
        -text     => 'Neuer Begriff',
        -compound => 'left',
        -image    => $pic_neu,
        -command  => \sub {
            glossar_dialog_neu( \$table );
        }
    );

    my $but_bearb = $frame_buttons->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            glossar_bearbeiten( \$table );
        }
    );
    my $but_loesch = $frame_buttons->Button(
        -text     => 'Löschen',
        -compound => 'left',
        -image    => $pic_delete,
        -command  => \sub {
            glossar_loeschen( \$table );
            set_aendern();
          }

    );

    $frame_buttons->pack( -anchor => 'w' );
    $but_neu->pack( -side => 'left' );
    $but_bearb->pack( -side => 'left' );
    $but_loesch->pack( -side   => 'left' );
    $table_head->pack( -anchor => 'w' );
    $table->pack( -anchor => 'w' );

    $projekt{'glossar'} = \$table;
    return;
}    # ----------  end of subroutine build_frame14  ----------

#---------------------------------------------------------------------------
#  Subroutine: funk_bind_nummer_type
#  
#      Dem Binding werden alle Eingadbefelder übergeben und es überprüft nach jedem
#      Tastenschlag ob die eingegebene Nummer bereits vorhanden ist. Dabei wird
#      anhand des Modus indem sich der Dialog befindet entschieden ob ein Button
#      aktiviert oder deaktiviert wird. Durch die ismapped-Funktion von Tk findet
#      das Binding heraus ob der OK- (neu anlegen-Modus) oder der Übernehmen-Button
#      (Bearbeitungs-Modus) aktiv ist. Unabhängig vom Modus werden bei Existenz
#      der Nummer die Eingabefelder mit den dazugehörigen Daten gefüllt.
#
#      *Übernehmen Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - Nummernfeld weiss färben
#
#      *Neu anlegen-Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - deaktiviere Neu-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - aktiviere Neu-Button
#      - Nummernfeld weiss farben
#
# Parameters: 
#
#    $w                 - aufrufendes Widget 
#    $parameter_ref     - Folgende Parameter werden per Hashreferenz übergeben:
#    nummer             - Nummer, kein Widget
#    kapitel            - Entry-Widget
#    geschaeft          - Entry-Widget
#    ziel               - Entry-Widget
#    vorbedingung       - Entry-Widget
#    nach_erfolg        - Entry-Widget
#    nach_fehl          - Entry-Widget
#    akteure            - Entry-Widget
#    text_ereignis      - Text-Widget
#    text_beschreibung  - Text-Widget
#    text_erweiterung   - Text-Widget
#    text_alternativen  - Text-Widget
#    button_ok          - Button-Widget
#    button_neu         - Button-Widget
#    button_uebernehmen - Button-Widget
#
#---------------------------------------------------------------------------
sub funk_bind_nummer_type {

    my ( $w, $parameter_ref ) = @_;
    my $num                = ${$parameter_ref}{'nummer'};
    my $kapitel            = ${$parameter_ref}{'kapitel'};
    my $geschaeft          = ${$parameter_ref}{'geschaeft'};
    my $ziel               = ${$parameter_ref}{'ziel'};
    my $vorbedingung       = ${$parameter_ref}{'vorbedingung'};
    my $nach_erfolg        = ${$parameter_ref}{'nach_erfolg'};
    my $nach_fehl          = ${$parameter_ref}{'nach_fehl'};
    my $akteure            = ${$parameter_ref}{'akteure'};
    my $text_ereignis      = ${$parameter_ref}{'text_ereignis'};
    my $text_beschreibung  = ${$parameter_ref}{'text_beschreibung'};
    my $text_erweiterung   = ${$parameter_ref}{'text_erweiterung'};
    my $text_alternativen  = ${$parameter_ref}{'text_alternativen'};
    my $button_ok          = ${$parameter_ref}{'button_ok'};
    my $button_neu         = ${$parameter_ref}{'button_neu'};
    my $button_uebernehmen = ${$parameter_ref}{'button_uebernehmen'};

    my $nummer = ${$num};

    if ($nummer) {
        if ( $funktionen{$nummer} ) {

            # wenn Eintrag im Hash dann auf jeden Fall Einträge laden
            ${$geschaeft}    = $funktionen{$nummer}[0];
            ${$ziel}         = $funktionen{$nummer}[1];
            ${$vorbedingung} = $funktionen{$nummer}[2];
            ${$nach_erfolg}  = $funktionen{$nummer}[3];
            ${$nach_fehl}    = $funktionen{$nummer}[4];
            ${$akteure}      = $funktionen{$nummer}[5];
            ${$text_ereignis}->Contents( $funktionen{$nummer}[6] );
            ${$text_beschreibung}->Contents( $funktionen{$nummer}[7] );
            ${$text_erweiterung}->Contents( $funktionen{$nummer}[8] );
            ${$text_alternativen}->Contents( $funktionen{$nummer}[9] );
            ${$kapitel} = suche_id( $nummer, \%funktionen_kapitel );
            ${$button_uebernehmen}->configure( -state => 'normal' );

            # Wenn OK-Button gemapped dann befindet man sich im
            # "Neu anlegen"-Modus. Die Buttons deaktivieren um zu 
            # verdeutlichen, dass die Zahl bereits vergeben ist.
            if ( ${$button_ok}->ismapped() ) {
                $w->configure( -background => '#ff9696' );
                ${$button_ok}->configure( -state => 'disabled' );
                ${$button_neu}->configure( -state => 'disabled' );
            }
        }
        else {

            #Ansonsten alle Felder leeren, aktivieren und
            #Ok/Neu Buttons auswählbar machen
            undef ${$geschaeft};
            undef ${$ziel};
            undef ${$vorbedingung};
            undef ${$nach_erfolg};
            undef ${$nach_fehl};
            undef ${$akteure};
            ${$text_ereignis}->Contents($EMPTY);
            ${$text_beschreibung}->Contents($EMPTY);
            ${$text_erweiterung}->Contents($EMPTY);
            ${$text_alternativen}->Contents($EMPTY);
            ${$kapitel} = $EMPTY;
            $w->configure( -background => 'snow1' );
            ${$button_ok}->configure( -state => 'normal' );
            ${$button_neu}->configure( -state => 'normal' );

            #Übernehmen-Button deaktivieren, da im Bearbeitungs-Modus
            #nur vorhandene Einträge bearbeite werden. Rein Theoretisch
            #könnte man auch mit dem Bearbeiten-Button Einträge anlegen,
            #jedoch würde as nur unnötig für Verwirrung sorgen.
            ${$button_uebernehmen}->configure( -state => 'disabled' );
        }
    }
    else {

        #Wenn keine Nummer angegeben, Alle Buttons deaktivieren.
        ${$button_ok}->configure( -state => 'disabled' );
        ${$button_neu}->configure( -state => 'disabled' );
        ${$button_uebernehmen}->configure( -state => 'disabled' );
    }
    return;
}

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
          . int( $screen_width / 2 - $BREITE / 2 ) . q{+}
          . int( $screen_height / 2 - $HOEHE / 2 ) );
    ${$top_level}->raise($mw);
    ${$top_level}->grab();    #macht Fenster modal
    ${$top_level}->resizable( 0, 0 );
    return;
}    # ----------  end of subroutine modal  ----------

#---------------------------------------------------------------------------
# Subroutine:  funktion_dialog_neu
#  Baut den Dialog zur Erstellung einer Funktion.
#  Dieser hat zwei Modi die über den Parameter $id angesteuert werden.
#
#  - *normaler Modus*
#  Wird die Funktion ohne den Parameter $id aufgerufen, erscheint die GUI
#  im normalen Modus. Das heisst, die Elemente sind alle leer und es können
#  neue Einträge in die Tabelle vorgenommen werden. Dazu werden unten links
#  die Buttons *OK* und *NEU* eingeblendet.
#
#  $button_ok - legt einen Eintrag an und schliesst danach den Dialog
#
#  $button_neu - ist wie OK, nur Dialog schliesst nicht, sondert es leeren sich
#  alle Eingabefelder und es kann ein weiterer Eintrag vorgenommen werden.
#
# - *bearbeitender Modus*
#  Wird die Funktion mit den Parameter $id aufgerufen, erscheint die GUI im
#  bearbeitenden Modus. Das heisst, die Elemente werden alle gefüllt mit dem
#  zu bearbeitenden Eintrag. Unten links im Dialog werden die Buttons
#  vom normalen Modus ausgeblendet und stattdesen der Übernehmen Button eingeblendet
#
#  $button_uebernehmen - Speichert die vorgenommenen Änderungen und schliesst den Dialog
#
# PARAMETERS:
#  $table - Referenz auf func_table vom Typ Tk::Table
#  $id -  ID des zu bearbeitenden Eintrages im Hash und in der Tabelle
#---------------------------------------------------------------------------
sub funktion_dialog_neu {
    my ( $table, $nummer ) = @_;

    # Erstellt ein neues Toplevel-Widget
    my $toplevel_funktion =
      $frame_stack[3]->Toplevel( -title => 'neue Funktion anlegen' );
    Readonly my $BREITE => 650;
    Readonly my $HOEHE  => 490;
    modal( \$toplevel_funktion, $BREITE, $HOEHE );

    # Oberer Frame mit den Elementen oberhalb der Tabs
    my $frame_oben = $toplevel_funktion->Frame( -height => 8 );
    my $frame_label = $frame_oben->Frame( -height => 2 );
    my $lab_kapitel   = $frame_label->Label( -text => 'Kapitel' );
    my $lab_nummer    = $frame_label->Label( -text => 'Nummer' );
    my $lab_geschaeft = $frame_label->Label( -text => 'Geschäftsprozess' );
    my $frame_entry = $frame_oben->Frame( -height => 2 );
    my $geschaeft;
    my $entry_geschaeft =
      $frame_entry->Entry( -width => 75, -textvariable => \$geschaeft );


    my @klist = keys %funktionen_kapitel;    #alle Funktionskapitel holen
    my $kapitel;
    my $combo_entry = $frame_entry->ComboEntry(
        -textvariable => \$kapitel,
        -itemlist     => [@klist],
        -width        => 28,
        -borderwidth  => '0',
    );

    # Unteres Frame mit den drei Tabs Bedingungen Beschreibung und Ergänzung
    my $frame_unten = $toplevel_funktion->Frame( -height => 2 );

    # Dieses Feld dient zum einfacheren Zugriff auf die Tabs
    my @tab;

    # Diese Variable enthält die Tabs Bedingungen, Beschreibung und Ergänzung
    my $book = $frame_unten->NoteBook();
    push @tab, $book->add( 1, -label => 'Bedingungen' );
    push @tab, $book->add( 2, -label => 'Beschreibung' );
    push @tab, $book->add( 3, -label => 'Ergänzung' );

    # Inhalt des ersten Tabs "Bedingung"
    my $frame_ziel = $tab[0]->Frame( -height => 2 );
    my $lab_ziel =
      $frame_ziel->Label( -text => 'Ziel', -width => 25, -anchor => 'e' );
    my $ziel;
    my $entry_ziel =
      $frame_ziel->Entry( -width => 65, -textvariable => \$ziel );
    my $frame_vorbedingung = $tab[0]->Frame( -height => 2 );
    my $lab_vorbedingung = $frame_vorbedingung->Label(
        -text    => 'Vorbedingung',
        -width   => 25,
        -anchor  => 'e',
        -justify => 'left'
    );
    my $vorbedingung;
    my $entry_vorbedingung = $frame_vorbedingung->Entry(
        -width        => 65,
        -textvariable => \$vorbedingung
    );

    my $frame_nach_erfolg = $tab[0]->Frame( -height => 2 );
    my $lab_nach_erfolg = $frame_nach_erfolg->Label(
        -text   => 'Nachbedingung Erfolg',
        -width  => 25,
        -anchor => 'e'
    );
    my $nach_erfolg;
    my $entry_nach_erfolg =
      $frame_nach_erfolg->Entry( -width => 65, -textvariable => \$nach_erfolg );

    my $frame_nach_fehl = $tab[0]->Frame( -height => 2 );
    my $lab_nach_fehl = $frame_nach_fehl->Label(
        -text   => 'Nachbedingung Fehlschlag',
        -width  => 25,
        -anchor => 'e'
    );
    my $nach_fehl;
    my $entry_nach_fehl =
      $frame_nach_fehl->Entry( -width => 65, -textvariable => \$nach_fehl );

    my $frame_akteure = $tab[0]->Frame( -height => 2 );
    my $lab_akteure =
      $frame_akteure->Label( -text => 'Akteure', -width => 25, -anchor => 'e' );
    my $akteure;
    my $entry_akteure =
      $frame_akteure->Entry( -width => 65, -textvariable => \$akteure );

    my $frame_ereignis = $tab[0]->Frame( -height => 2 );
    my $lab_ereignis = $frame_ereignis->Label(
        -text   => 'Auslösendes Ereignis',
        -width  => 25,
        -anchor => 'e'
    );
    my $text_ereignis =
      $frame_ereignis->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_ereignis->configure( height => '12', -width => '65' );

    # Inhalt des zweiten Tabs "Beschreibung"
    my $text_beschreibung = $tab[1]->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_beschreibung->configure( -width => '90', height => '21' );

    # Inhalt des dritten Tabs "Ergänzung"
    my $frame_erweiterung = $tab[2]->Frame();
    my $lab_erweiterung = $frame_erweiterung->Label( -text => 'Erweiterung' );
    my $text_erweiterung =
      $frame_erweiterung->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_erweiterung->configure( -width => '90', height => '9' );
    my $frame_alternativen = $tab[2]->Frame();
    my $lab_alternativen =
      $frame_alternativen->Label( -text => 'Alternativen' );
    my $text_alternativen =
      $frame_alternativen->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_alternativen->configure( -width => 90, -height => 9 );

    # Wenn $id angegeben wurde, holle alle Hash-Keys aus dem Funktionen-Hash 
    # und nutze diese für die Autovervollständigung (MatchEntry-Widget)
    my @choices = keys %funktionen;

    my $entry_nummer = $frame_entry->MatchEntry(
        -choices      => \@choices,
        -fixedwidth   => 1,
        -ignorecase   => 1,
        -maxheight    => 5,
        -width        => 10,
        -textvariable => \$nummer,
    );

    # Frame mit "OK"- und "Abbrechen"-Button
    my $frame_ok_cancel = $toplevel_funktion->Frame();

    # Neu-Button
    my $button_neu = $toplevel_funktion->Button(
        -state    => 'disabled',
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -command  => \sub {
            funktion_tabelle_einfuegen(
                {
                    table       => $table,
                    nummer      => $nummer,
                    geschaeft   => $geschaeft,
                    ziel        => $ziel,
                    vor         => $vorbedingung,
                    nach_erfolg => $nach_erfolg,
                    nach_fehl   => $nach_fehl,
                    akteure     => $akteure,
                    ereignis    => $text_ereignis->get( '1.0', 'end -1 chars' ),
                    beschreibung =>
                      $text_beschreibung->get( '1.0', 'end -1 chars' ),
                    erweiterung =>
                      $text_erweiterung->get( '1.0', 'end -1 chars' ),
                    alternativen =>
                      $text_alternativen->get( '1.0', 'end -1 chars' ),
                    kapitel => $kapitel,
                }
            );

            #alle Einträge leeren
            undef $nummer;
            undef $geschaeft;
            undef $ziel;
            undef $vorbedingung;
            undef $nach_erfolg;
            undef $nach_fehl;
            undef $akteure;
            $text_ereignis->Contents($EMPTY);
            $text_beschreibung->Contents($EMPTY);
            $text_erweiterung->Contents($EMPTY);
            $text_alternativen->Contents($EMPTY);
            undef $kapitel;
            # Da der Neu-Button den Dialog nicht neu aufbaut, müssen Kapitel
            # und eventuell neue Funktionsnummern manuel neu zugewiesen werden.
            @klist = keys %funktionen_kapitel;
            $combo_entry->configure( -list => \@klist );
            @choices = keys %funktionen;
            $entry_nummer->configure( -choices => \@choices );
            $entry_nummer->focus();
        }
    );

    #OK-Button
    my $button_ok = $toplevel_funktion->Button(
        -state    => 'disabled',
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            funktion_tabelle_einfuegen(
                {
                    table       => $table,
                    nummer      => $nummer,
                    geschaeft   => $geschaeft,
                    ziel        => $ziel,
                    vor         => $vorbedingung,
                    nach_erfolg => $nach_erfolg,
                    nach_fehl   => $nach_fehl,
                    akteure     => $akteure,
                    ereignis    => $text_ereignis->get( '1.0', 'end -1 chars' ),
                    beschreibung =>
                      $text_beschreibung->get( '1.0', 'end -1 chars' ),
                    erweiterung =>
                      $text_erweiterung->get( '1.0', 'end -1 chars' ),
                    alternativen =>
                      $text_alternativen->get( '1.0', 'end -1 chars' ),
                    kapitel => $kapitel,
                }
            );
            set_aendern();
            $toplevel_funktion->destroy;    #Dialog schliessen

        }
    );
    my $button_cancel = $toplevel_funktion->Button(
        -image    => $pic_exit,
        -compound => 'left',
        -text    => 'Abbrechen',
        -command => \sub {
            $toplevel_funktion->destroy();
        }
    );

    #Übernehmen-Button
    my $button_uebernehmen = $toplevel_funktion->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            funktion_tabelle_aendern(
                {
                    table       => $table,
                    nummer      => $nummer,
                    geschaeft   => $geschaeft,
                    ziel        => $ziel,
                    vor         => $vorbedingung,
                    nach_erfolg => $nach_erfolg,
                    nach_fehl   => $nach_fehl,
                    akteure     => $akteure,
                    ereignis    => $text_ereignis->get( '1.0', 'end -1 chars' ),
                    beschreibung =>
                      $text_beschreibung->get( '1.0', 'end -1 chars' ),
                    erweiterung =>
                      $text_erweiterung->get( '1.0', 'end -1 chars' ),
                    alternativen =>
                      $text_alternativen->get( '1.0', 'end -1 chars' ),
                    kapitel => $kapitel,
                }
            );
            set_aendern();
            $toplevel_funktion->destroy;    #Dialog schliessen
        }
    );

    $entry_nummer->bind(
        '<KeyRelease>',
        [
            \&funk_bind_nummer_type,
            {
                nummer             => \$nummer,
                kapitel            => \$kapitel,
                geschaeft          => \$geschaeft,
                ziel               => \$ziel,
                vorbedingung       => \$vorbedingung,
                nach_erfolg        => \$nach_erfolg,
                nach_fehl          => \$nach_fehl,
                akteure            => \$akteure,
                text_ereignis      => \$text_ereignis,
                text_beschreibung  => \$text_beschreibung,
                text_erweiterung   => \$text_erweiterung,
                text_alternativen  => \$text_alternativen,
                button_ok          => \$button_ok,
                button_neu         => \$button_neu,
                button_uebernehmen => \$button_uebernehmen,
            }
        ]
    );

    $entry_nummer->bind(
        '<FocusIn>',
        [
            \&bind_nummer_in, \$nummer, \$button_ok,
            \$button_neu,     \$button_uebernehmen
        ]
    );
    if ( defined $nummer ) {
        $toplevel_funktion->configure( -title => 'Funktion bearbeiten' );

        #        $nummer      =  ->insert($nummer);
        $geschaeft    = $funktionen{$nummer}[0];
        $ziel         = $funktionen{$nummer}[1];
        $vorbedingung = $funktionen{$nummer}[2];
        $nach_erfolg  = $funktionen{$nummer}[3];
        $nach_fehl    = $funktionen{$nummer}[4];
        $akteure      = $funktionen{$nummer}[5];
        $text_ereignis->Contents( $funktionen{$nummer}[6] );
        $text_beschreibung->Contents( $funktionen{$nummer}[7] );
        $text_erweiterung->Contents( $funktionen{$nummer}[8] );
        $text_alternativen->Contents( $funktionen{$nummer}[9] );
        $kapitel = suche_id( $nummer, \%funktionen_kapitel )
          ;    # suche, wenn zugeordnet, das Kapitel
    }

    #---------------------------------------------------------------------------
    #  Packstube
    #---------------------------------------------------------------------------
    $frame_oben->pack( -fill => 'x' );
    $frame_label->pack( -side => 'left' );
    $lab_nummer->pack( -anchor => 'w' );
    $lab_geschaeft->pack();
    $lab_kapitel->pack( -anchor => 'w' );
    $frame_entry->pack( -side   => 'left' );
    $entry_nummer->pack( -anchor => 'w' );
    $entry_geschaeft->pack();
    $combo_entry->pack( -anchor => 'w', -pady => 2, -fill => 'x' );
    $frame_unten->pack( -fill => 'x' );

    $book->pack( -fill => 'x', -side => 'left' );

    $frame_ziel->pack( -fill => 'x' );
    $lab_ziel->pack( -side => 'left' );
    $entry_ziel->pack( -side => 'left' );

    $frame_vorbedingung->pack( -fill => 'x' );
    $lab_vorbedingung->pack( -side => 'left' );
    $entry_vorbedingung->pack( -side => 'left' );

    $frame_nach_erfolg->pack( -fill => 'x' );
    $lab_nach_erfolg->pack( -side => 'left' );
    $entry_nach_erfolg->pack( -side => 'left' );

    $frame_nach_fehl->pack( -fill => 'x' );
    $lab_nach_fehl->pack( -side => 'left' );
    $entry_nach_fehl->pack( -side => 'left' );

    $frame_akteure->pack( -fill => 'x' );
    $lab_akteure->pack( -side => 'left' );
    $entry_akteure->pack( -side => 'left' );
    $frame_ereignis->pack( -fill => 'x' );
    $lab_ereignis->pack( -side => 'left' );
    $text_ereignis->pack( -side => 'left' );

    $text_beschreibung->pack( -side => 'left' );

    $frame_erweiterung->pack( -fill => 'x', -side => 'top', -anchor => 'nw' );
    $lab_erweiterung->pack( -side => 'top', -anchor => 'nw' );
    $text_erweiterung->pack( -fill => 'x', -side => 'left' );

    $frame_alternativen->pack( -fill => 'x', -side => 'top', -anchor => 'nw' );
    $lab_alternativen->pack( -side => 'top', -anchor => 'nw' );
    $text_alternativen->pack( -side => 'left' );

    $frame_ok_cancel->pack( -fill => 'x', -side => 'bottom' );

    if ( defined $nummer )
    {    # Wenn $id definiert nur Speichern-Button einblenden
        $button_uebernehmen->pack( -side => 'left' );
    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_cancel->pack( -side => 'right' );
    return;
}

#---------------------------------------------------------------------------
# Subroutine:  funktion_tabelle_einfuegen
# Dient zum neu anlegen von Einträgen in der Tabelle und dem
# Hash der Funktionen.
#
# <funktion_hash_einfuegen> wird aufgerufen, die Daten übergeben und dieser
# gibt die eine neue $id zurück die mit dem Eintrag verbunden ist. Diese $id ist auch
# der Key unter dem auf den Eintrag in dem Hash <%funktionen> zugegriffen wird.
#
# Labels werden für die einzelenen Einträge der Tabelle erzeugt. Wenn ein
# Label aktiv ist wird der Hintergrund auf LightSkyBlue gesetzt
# und somit so eine Art Markiereung erzeugt. Dies ist notwendig, da Tk::Table
# kein markieren von Einträgen unterstützt.
#
# Es werden den Labels bindings zugewiesen, <mark_umschalten> dient
# zum markieren eines Elements und ändert den Zustand von aktiv auf normal
# oder umgekehrt wenn angeklickt.
#
# PARAMETERS:
# $table        - Referenz auf func_table vom Typ Tk::Table
# $nummer       - Nummer
# $geschaeft    - Geschäftsprozess
# $ziel         - Ziel
# $vor          - Vorbedingung
# $nach_erfolg  - Nachbedingung bei Erfolg
# $nach_fehl    - Nachbedingung bei Fehlschlag
# $akteure      - Akteure
# $ereignis     - auslösendes Ereignis
# $beschreibung - Beschreibung
# $erweiterung  - Erweiterungen
# $alternativen - Alternativen
# $kapitel      - Kapitel
# $id           - ID des zu bearbeitenden Eintrages im Hash und in der Tabelle
#---------------------------------------------------------------------------
sub funktion_tabelle_einfuegen {
    my ($parameter_ref) = @_;
    my $table           = ${$parameter_ref}{'table'};
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $geschaeft       = ${$parameter_ref}{'geschaeft'};
    my $ziel            = ${$parameter_ref}{'ziel'};
    my $vor             = ${$parameter_ref}{'vor'};
    my $nach_erfolg     = ${$parameter_ref}{'nach_erfolg'};
    my $nach_fehl       = ${$parameter_ref}{'nach_fehl'};
    my $akteure         = ${$parameter_ref}{'akteure'};
    my $ereignis        = ${$parameter_ref}{'ereignis'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $erweiterung     = ${$parameter_ref}{'erweiterung'};
    my $alternativen    = ${$parameter_ref}{'alternativen'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    if ( defined $nummer ) {
        funktion_hash_aendern(
            {
                nummer       => $nummer,
                geschaeft    => $geschaeft,
                ziel         => $ziel,
                vor          => $vor,
                nach_erfolg  => $nach_erfolg,
                nach_fehl    => $nach_fehl,
                akteure      => $akteure,
                ereignis     => $ereignis,
                beschreibung => $beschreibung,
                erweiterung  => $erweiterung,
                alternativen => $alternativen,
                kapitel      => $kapitel,
            }
        );

    }
    else {
        funktion_hash_einfuegen(
            {
                nummer       => $nummer,
                geschaeft    => $geschaeft,
                ziel         => $ziel,
                vor          => $vor,
                nach_erfolg  => $nach_erfolg,
                nach_fehl    => $nach_fehl,
                akteure      => $akteure,
                ereignis     => $ereignis,
                beschreibung => $beschreibung,
                erweiterung  => $erweiterung,
                alternativen => $alternativen,
                kapitel      => $kapitel,
            }
        );
    }

    #Labels werden erzeugt
    my $lab_num = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $nummer,
        -width            => '5',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_gesch = ${$table}->Label(
        -background => 'snow1',
        -relief     => 'groove',
        -text       => $geschaeft,
        -width      => '11',
        -padx       => '2',
        -anchor     => 'w',
        -activebackground =>
          'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
    );

    my $lab_akt = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $akteure,
        -width            => '15',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );

    # Zeilenumbrüche werden entfernt, damit Text in eine Zeile passt
    umbruch_entfernen( \$beschreibung );
    my $lab_besch = ${$table}->Label(
        -background => 'snow1',
        -relief     => 'groove',
        -text       => $beschreibung,
        -width      => '50',
        -padx       => '2',
        -anchor     => 'w',
        -activebackground =>
          'LightSkyBlue'    #wenn aktiviert bzw markiert auf blau setzen
    );

#    my $lab_id = ${$table}->Label(
#        -foreground =>
#          ''snow1'',        #gleiche farbe wie hintergrund,  damit ID unsichtbar
#        -text  => $id,
#        -width => '0'
#    );
    my $akt_zeile = ${$table}->totalRows;

    $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_gesch->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_akt->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_besch->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $lab_num );
    ${$table}->put( $akt_zeile, 1, $lab_gesch );
    ${$table}->put( $akt_zeile, 2, $lab_akt );
    ${$table}->put( $akt_zeile, 3, $lab_besch );

    #    ${$table}->put( $akt_zeile, 4, $lab_id );
    return;

}    # ----------  end of subroutine funktion_tabelle_einfuegen_funkt  ----------

#-------------------------------------------------------------------------------
# Subroutine:  funktion_tabelle_aendern
# Dient zum ändern von Einträgen in der Tabelle und dem Hash der Funktionen.
#
# <funktion_hash_aendern> wird aufgerufen und überschreibt den zur $id
# gehörenden Eintrag im Hash <%funktionen>.
#
# Nun wird die Tabellenzeile herausgesucht unter der die ID zu finden ist und
# das text-Attribut der jeweiligen Labels auf den neuen Wert gesetzt.
#
# PARAMETERS:
# $table        - Referenz auf func_table vom Typ Tk::Table
# $nummer       - Nummer
# $geschaeft    - Geschäftsprozess
# $ziel         - Ziel
# $vor          - Vorbedingung
# $nach_erfolg  - Nachbedingung bei Erfolg
# $nach_fehl    - Nachbedingung bei Fehlschlag
# $akteure      - Akteure
# $ereignis     - auslösendes Ereignis
# $beschreibung - Beschreibung
# $erweiterung  - Erweiterungen
# $alternativen - Alternativen
# $kapitel      - Kapitel
# $id           - ID des zu bearbeitenden Eintrages im Hash und in der Tabelle
#-------------------------------------------------------------------------------
sub funktion_tabelle_aendern {
    my ($parameter_ref) = @_;
    my $table           = ${$parameter_ref}{'table'};
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $geschaeft       = ${$parameter_ref}{'geschaeft'};
    my $ziel            = ${$parameter_ref}{'ziel'};
    my $vor             = ${$parameter_ref}{'vor'};
    my $nach_erfolg     = ${$parameter_ref}{'nach_erfolg'};
    my $nach_fehl       = ${$parameter_ref}{'nach_fehl'};
    my $akteure         = ${$parameter_ref}{'akteure'};
    my $ereignis        = ${$parameter_ref}{'ereignis'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $erweiterung     = ${$parameter_ref}{'erweiterung'};
    my $alternativen    = ${$parameter_ref}{'alternativen'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    #    my $id              = ${$parameter_ref}{'id'};

    funktion_hash_aendern(
        {
            nummer       => $nummer,
            geschaeft    => $geschaeft,
            ziel         => $ziel,
            vor          => $vor,
            nach_erfolg  => $nach_erfolg,
            nach_fehl    => $nach_fehl,
            akteure      => $akteure,
            ereignis     => $ereignis,
            beschreibung => $beschreibung,
            erweiterung  => $erweiterung,
            alternativen => $alternativen,
            kapitel      => $kapitel,

            #            id           => $id,
        }
    );
    my $row;

    #herausfinden in welcher Zeile sich die ID befindet und in $row abspeichern
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) eq $nummer ) {
            $row = $i;
        }
    }

    umbruch_entfernen( \$beschreibung );    #Zeilenumbrüche entfernen
    ${$table}->get( $row, 0 )->configure( -text => $nummer );
    ${$table}->get( $row, 1 )->configure( -text => $geschaeft );
    ${$table}->get( $row, 2 )->configure( -text => $akteure );
    ${$table}->get( $row, 3 )->configure( -text => $beschreibung );

    return;
}    # ----------  end of subroutine funktion_tabelle_aendernion  ----------

#-------------------------------------------------------------------------------
# Subroutine:  funktion_tabelle_sync
# Hier werden die Einträge in der von @folge bestimmten Reihenfolge aus
# <%funktionen> geholt und wie in <funktion_tabelle_einfuegen> in die Tabelle
# eingetragen.
# @folge ist notwendig, damit nicht nach jedem Löschvorgang, die Einträge
# in anderer Reihenfolfe in der Tabelle stehen.
#
# Dabei werden den Labels auch bindings auf <mark_umschalten> zugewiesen.
#
# PARAMETERS:
#  $table - Referenz auf func_table vom Typ Tk::Table
#  @folge - alte Reihenfolge der IDs von der Tabelle ohne die zu löschende Zeile
#-------------------------------------------------------------------------------
sub funktion_tabelle_sync {
    my ( $table, @folge ) = @_;
    my ( $nummer, $gesch, $akt, $besch, $id );

    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {

        $nummer = $folge[$i];
        $gesch  = $funktionen{ $folge[$i] }[0];
        $akt    = $funktionen{ $folge[$i] }[5];
        $besch  = $funktionen{ $folge[$i] }[7];

        #        $id     = $folge[$i];
        my $lab_num = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $nummer,
            -width            => '5',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        my $lab_gesch = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $gesch,
            -width      => '11',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );

        my $lab_akt = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $akt,
            -width            => '15',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        umbruch_entfernen( \$besch );
        my $lab_besch = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $besch,
            -width      => '50',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );

        $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_gesch->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_akt->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_besch->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_num );
        ${$table}->put( $i, 1, $lab_gesch );
        ${$table}->put( $i, 2, $lab_akt );
        ${$table}->put( $i, 3, $lab_besch );

        #        ${$table}->put( $i, 4, $lab_id );
    }

    return;
}    # ----------  end of subroutine funktion_tabelle_sync  ----------

#-------------------------------------------------------------------------------
# Subroutine:  funktion_loeschen
# Dient zum löschen von markierten Einträgen in der Tabelle
# Diese Einträge werden in der Tabelle und dem Hash der Funktionen gelöscht.
#
# Es wird die markierte Tabellenzeile herausgesucht un deren ID in die Variable
# $id kopiert
#
# Wenn keine $id gefunden, wurde keine Zeile markiert und es wird eine
# Fehlermeldung ausgegeben.
#
# <funktion_hash_loeschen> wird aufgerufen und löscht den zur $id
# gehörenden Eintrag im Hash <%funktionen>.
#
# Tabelle wird geleert
#
# Nun wird die alte Reihenfolge der IDs der Tabelle in einem Feld gespeichert
# und zwar ohne die zu löschende Zeile. Diese Einträge werden nun wieder
# _in der selben Reihenfolge_ über <funktion_tabelle_sync> in
# die Tabelle eingelesen. Dies war notwendig, weil die Einträge in einem Hash
# keine feste Reihenfolge haben wie in einem Feld. Dies hatte zufolge,  dass
# nach jedem löschen die Reihenfolge der Einträge in der Tabelle sich änderte.
#
# Tabelle wird geleert.
#
#<funktion_tabelle_sync> wird aufgerufen damit die Einträge in der Tabelle
# aktualisiert werden
#
# PARAMETERS:
#  $table - Referenz auf func_table vom Typ Tk::Table
#-------------------------------------------------------------------------------
sub funktion_loeschen {
    my ($table) = @_;

    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }

    if ( !defined $nummer ) {    #Fehlermeldung wenn keine Zeile markiert wurde
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    funktion_hash_loeschen($nummer);

    # alte Reihenfolge der Tabelleneinträge über die
    # IDs speichern ohne die gelöschte Zeile
    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) ne $nummer )
        {    #gelöschte Zeile
            push @folge, ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    ${$table}->clear();
    funktion_tabelle_sync( $table, @folge );

    return;
}    # ----------  end of subroutine funktion_loeschen  ----------

#-------------------------------------------------------------------------------
# Subroutine: funktion_bearbeiten
# Findet heraus welche Zeile markiert wurde über das Attribut des Labels "state"
#
# Wenn keine Zeile markiert wurde folgt eine Fehlermeldung
#
# Anschließend wird der Dialog zum Anlegen neuer Datenbankeinträge <funktion_dialog_neu>
# im bearbeitenden Modus aufgerufen durch das angeben einer ID.
#
# PARAMETERS:
#  $table - Referenz auf func_table vom Typ Tk::Table
#-------------------------------------------------------------------------------
sub funktion_bearbeiten {
    my ($table) = @_;
    my $nummer;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return;
    }
    funktion_dialog_neu( $table, $nummer );
    return;
}    # ----------  end of subroutine funktion_bearbeiten  ----------

#-------------------------------------------------------------------------------
# Subroutine:  funktion_hash_einfuegen
# Die übergebenen Einträge werden in <%funktionen> eingefügt und die ID über die
# diese zu finden sind wieder zurückgegeben
#
# Erste nicht benutzte ID wird in <%funktionen> gesucht
#
# Füge Eintrag in <%funktionen> ein
#
# <einfuegen_id> fügt die ID der Funktion in das ausgewählte Kapitel in
# <%funktionen_kapitel> ein.
#
# PARAMETERS:
#
# $nummer       - Nummer
# $geschaeft    - Geschäftsprozess
# $ziel         - Ziel
# $vor          - Vorbedingung
# $nach_erfolg  - Nachbedingung bei Erfolg
# $nach_fehl    - Nachbedingung bei Fehlschlag
# $akteure      - Akteure
# $ereignis     - auslösendes Ereignis
# $beschreibung - Beschreibung
# $erweiterung  - Erweiterungen
# $alternativen - Alternativen
# $kapitel      - Kapitel
#
# RETURNS:
#  $id                      - ID des Eintrages im Hash
#-------------------------------------------------------------------------------
sub funktion_hash_einfuegen {
    my ($parameter_ref) = @_;
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $geschaeft       = ${$parameter_ref}{'geschaeft'};
    my $ziel            = ${$parameter_ref}{'ziel'};
    my $vor             = ${$parameter_ref}{'vor'};
    my $nach_erfolg     = ${$parameter_ref}{'nach_erfolg'};
    my $nach_fehl       = ${$parameter_ref}{'nach_fehl'};
    my $akteure         = ${$parameter_ref}{'akteure'};
    my $ereignis        = ${$parameter_ref}{'ereignis'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $erweiterung     = ${$parameter_ref}{'erweiterung'};
    my $alternativen    = ${$parameter_ref}{'alternativen'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    einfuegen_id( $nummer, $kapitel, \%funktionen_kapitel );

    $funktionen{$nummer} = [
        $geschaeft,   $ziel,    $vor,      $nach_erfolg,
        $nach_fehl,   $akteure, $ereignis, $beschreibung,
        $erweiterung, $alternativen
    ];

    return ();
}    # ----------  end of subroutine funktion_hash_einfuegen  ----------

#-------------------------------------------------------------------------------
# Subroutine:  funktion_hash_loeschen
#
# Die übergebene Id wird aus <%funktionen> gelöscht
#
# <loesche_id> löscht die ID der Funktion aus dem ausgewählten Kapitel in
# <%funktionen_kapitel>
#
# PARAMETERS:
#  $id - zu löschende ID
#
# RETURNS:
#  $id                      - ID des Eintrages im Hash
#-------------------------------------------------------------------------------

sub funktion_hash_loeschen {
    my ($nummer) = @_;

    delete $funktionen{$nummer};
    loesche_id( $nummer, \%funktionen_kapitel );
    return;
}    # ----------  end of subroutine funktion_hash_loeschen  ----------

#-------------------------------------------------------------------------------
# Subroutine: funktion_hash_aendern
# Die übergebenen Einträge werden in <%funktionen> geändert.
#
# <einfuegen_id> fügt die ID der Funktion in das ausgewählte Kapitel in
# <%funktionen_kapitel> ein.
#
# PARAMETERS:
#  $nummer      - Nummer
#  $geschaeft   - Geschäftsprozess
#  $ziel        - Ziel
#  $vor         - Vorbedingung
#  $nach_erfolg - Nachbedingung bei Erfolg
#  $nach_fehl   - Nachbedingung bei Fehlschlag
#  $akteure     - Akteure
#  $ereignis    - auslösendes Ereignis
#  $beschreibung- Beschreibung
#  $erweiterung - Erweiterungen
#  $alternativen- Alternativen
#  $kapitel     - Kapitel
#  $id          - ID des Eintrages im Hash
#-------------------------------------------------------------------------------
sub funktion_hash_aendern {
    my ($parameter_ref) = @_;
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $geschaeft       = ${$parameter_ref}{'geschaeft'};
    my $ziel            = ${$parameter_ref}{'ziel'};
    my $vor             = ${$parameter_ref}{'vor'};
    my $nach_erfolg     = ${$parameter_ref}{'nach_erfolg'};
    my $nach_fehl       = ${$parameter_ref}{'nach_fehl'};
    my $akteure         = ${$parameter_ref}{'akteure'};
    my $ereignis        = ${$parameter_ref}{'ereignis'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $erweiterung     = ${$parameter_ref}{'erweiterung'};
    my $alternativen    = ${$parameter_ref}{'alternativen'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    $funktionen{$nummer} = [
        $geschaeft,   $ziel,    $vor,      $nach_erfolg,
        $nach_fehl,   $akteure, $ereignis, $beschreibung,
        $erweiterung, $alternativen
    ];
    einfuegen_id( $nummer, $kapitel, \%funktionen_kapitel )
      ;    #ID in gewünschtes Kapitel einfügen
    return;
}    # ----------  end of subroutine funktion_hash_aendern ----------

#---------------------------------------------------------------------------
#  Subroutine: gui_bind_nummer_type
#  
#      Dem Binding werden alle Eingadbefelder übergeben und es überprüft nach jedem
#      Tastenschlag ob die eingegebene Nummer bereits vorhanden ist. Dabei wird
#      anhand des Modus indem sich der Dialog befindet entschieden ob ein Button
#      aktiviert oder deaktiviert wird. Durch die ismapped-Funktion von Tk findet
#      das Binding heraus ob der OK- (neu anlegen-Modus) oder der Übernehmen-Button
#      (Bearbeitungs-Modus) aktiv ist. Unabhängig vom Modus werden bei Existenz
#      der Nummer die Eingabefelder den dazugehörigen Daten gefüllt.
#
#      *Übernehmen Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - Nummernfeld weiss färben
#
#      *Neu anlegen-Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - deaktiviere Neu-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - aktiviere Neu-Button
#      - Nummernfeld weiss farben
#
# Parameters: 
#
#    $w                 - aufrufendes Widget 
#    $parameter_ref     - Folgende Parameter werden per Hashreferenz übergeben:
#    num                - Nummer
#    text_bezeic        - Text-Widget
#    bilddatei          - Entry-Widget
#    bildbeschr         - Entry-Widget
#    text_beschr        - Text-Widget
#    table_rollen       - Table-Widget
#    rollen             - Hashreferenz
#    button_ok          - Button-Widget
#    button_neu         - Button-Widget
#    button_uebernehmen - Button-Widget
#
#---------------------------------------------------------------------------
sub gui_bind_nummer_type {
    my ( $w, $parameter_ref ) = @_;
    my $num                = ${$parameter_ref}{'nummer'};
    my $text_bezeic        = ${$parameter_ref}{'text_bezeic'};
    my $bilddatei          = ${$parameter_ref}{'pfad'};
    my $bildbeschr         = ${$parameter_ref}{'bildbeschr'};
    my $text_beschr        = ${$parameter_ref}{'text_beschr'};
    my $table_rollen       = ${$parameter_ref}{'table_rollen'};
    my $rollen             = ${$parameter_ref}{'rollen'};
    my $button_ok          = ${$parameter_ref}{'button_ok'};
    my $button_neu         = ${$parameter_ref}{'button_neu'};
    my $button_uebernehmen = ${$parameter_ref}{'button_uebernehmen'};
    my $nummer             = ${$num};

    if ($nummer) {
        if ( $gui{$nummer} ) {

            # wenn Eintrag im Hash dann auf jeden Fall Einträge laden
            ${$text_bezeic}->Contents( $gui{$nummer}[0] );
            ${$bilddatei}  = $gui{$nummer}[1];
            ${$bildbeschr} = $gui{$nummer}[2];
            ${$text_beschr}->Contents( $gui{$nummer}[3] );

        #            gui_rolle_tabelle_sync( \$table_rollen, $gui{$nummer}[4] );
        #            %rollen = %{ $gui{$nummer}[4] };

            ${$table_rollen}->clear();
            gui_rolle_tabelle_sync( $table_rollen, $gui{$nummer}[4] );
            %{$rollen} = %{ $gui{$nummer}[4] };
            ${$button_uebernehmen}->configure( -state => 'normal' );

            # Wenn OK-Button gemapped dann befindet man sich im
            # "Neu anlegen"-Modus und die Buttons und Eingaben
            # deaktivieren um zu verdeutlichen, dass die Zahl bereits
            # vergeben ist.
            if ( ${$button_ok}->ismapped() ) {
                $w->configure( -background => '#ff9696' );
                ${$button_ok}->configure( -state => 'disabled' );
                ${$button_neu}->configure( -state => 'disabled' );
            }

        }

        else {

            #Ansonsten alle Felder leeren und
            #Ok/Neu Buttons auswählbar machen
            ${$text_bezeic}->Contents($EMPTY);
            ${$bilddatei} = $EMPTY;
            undef ${$bildbeschr};
            ${$text_beschr}->Contents($EMPTY);
            undef %{$rollen};
            ${$table_rollen}->clear();
            $w->configure( -background => 'snow1' );
            ${$button_ok}->configure( -state => 'normal' );
            ${$button_neu}->configure( -state => 'normal' );

            #Übernehmen-Button deaktivieren, da im Bearbeitungs-Modus
            #nur vorhandene Einträge bearbeite werden. Rein Theoretisch
            #könnte man auch mit dem Bearbeiten-Button Einträge anlegen,
            #jedoch würde as nur unnötig für Verwirrung sorgen.
            ${$button_uebernehmen}->configure( -state => 'disabled' );
        }
    }
    else {
        ${$button_ok}->configure( -state => 'disabled' );
        ${$button_neu}->configure( -state => 'disabled' );
        ${$button_uebernehmen}->configure( -state => 'disabled' );
    }
    return;
}    # ----------  end of subroutine gui_bind_nummer_type   ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_dialog_neu
#
#                Erstellt einen Dialog um dem Pflichtenheft eine neue GUI hinzuzufügen.
#                Der Dialog wird auch zum Bearbeiten einer GUI benutzt und muss zu
#                diesem Zweck eine ID mit übergeben bekommen.
#
#                Der Unterschied zu <funktion_dialog_neu> ist der, dass wir hier
#                noch bei Bedarf den Unterdialog <gui_rolle_dialog_neu> aufrufen,
#                der unserer GUI noch Rollen zuweist. Diese werden in dem Variable
#                <%rollen> abgespeichert, die innerhalb von <gui_hash_einfuegen>
#                dann <%gui> zugewiesen wird.
#
#
#   Parameters:
#				 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 $id - Die ID des Datensatzes
#
#     See Also:
#     			 <funktion_dialog_neu> ist funktionsgleich
#
#-------------------------------------------------------------------------------
sub gui_dialog_neu {
    my ( $table, $nummer ) = @_;
    my $toplevel_gui =
      $frame_stack[7]->Toplevel( -title => 'neue GUI anlegen' );
    my %rollen;
    Readonly my $BREITE => 350;
    Readonly my $HOEHE  => 640;
    modal( \$toplevel_gui, $BREITE, $HOEHE );

    #Nummer
    my $frame_nummer = $toplevel_gui->Frame();
    my $lab_nummer =
      $frame_nummer->Label( -text => 'Nummer', -width => '8', -anchor => 'w' );

    #Bezeichnung
    my $frame_bezeichnung = $toplevel_gui->Frame();
    my $lab_bezeichnung = $frame_bezeichnung->Label( -text => 'Bezeichnung' );
    my $text_bezeic =
      $frame_bezeichnung->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_bezeic->configure( -width => '40', height => '9' );

    #Bilddatei einfügen

    my $frame_bild        = $toplevel_gui->Frame();
    my $frame_bild_labels = $frame_bild->Frame();
    $frame_bild_labels->Label( -text => 'Bildpfad',    -anchor => 'w' )->pack();
    $frame_bild_labels->Label( -text => 'Bildbeschr.', -anchor => 'w' )->pack();
    my $frame_bild_entry  = $frame_bild->Frame();
    my $frame_bild_entry1 = $frame_bild_entry->Frame();
    my $bildbeschr;
    my $entry_bildbeschr =
      $frame_bild_entry->Entry( -textvariable => \$bildbeschr );
    my $pfad;
    my $entry_bilddatei = $frame_bild_entry1->Entry( -textvariable => \$pfad );
    my $button_bilddatei = $frame_bild_entry1->Button(
        -image   => $pic_oeffne,
        -command => sub {
            my $types = [
                [ 'png',          '.png' ],
                [ 'jpeg',         '.jpeg' ],
                [ 'jpg',          '.jpg' ],
                [ 'gif',          '.gif' ],
                [ 'Alle Dateien', q{*} ]
            ];
            $pfad = $entry_bilddatei->getOpenFile( -filetypes => $types );
        }
    );
    $entry_bilddatei->bind( '<FocusOut>', [ \&check_bild_bind ] );
    my $balloon = $button_bilddatei->Balloon();
    $balloon->attach( $button_bilddatei, -msg => 'Dateisystem durchsuchen...' );
    $balloon->attach(
        $entry_bilddatei,
        -msg             => 'Pfad zum Bild',
        -balloonposition => 'mouse'
    );
    $balloon->attach(
        $entry_bildbeschr,
        -msg             => 'Beschreibung zum Bild',
        -balloonposition => 'mouse'
    );

    #Beschreibung
    my $frame_beschr = $toplevel_gui->Frame();
    my $lab_beschr   = $frame_beschr->Label( -text => 'Beschreibung' );
    my $text_beschr  = $frame_beschr->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_beschr->configure( -width => '40', height => '9' );

    #Rollen
    my $frame_rollen = $toplevel_gui->Frame();

    #Rollen - Tabelle
    #Tabellenkopf ist eine eigene Tabelle
    my $table_rollen_kopf = $frame_rollen->Table(
        -columns    => 2,
        -rows       => 1,
        -scrollbars => '0',
        -relief     => 'raised'
    );

    #Tabellenüberschriften sind Labels
    my $lab_table_kopf1 = $table_rollen_kopf->Label(
        -text   => 'Bezeichnung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 18
    );
    my $lab_table_kopf2 = $table_rollen_kopf->Label(
        -text   => 'Rechte',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 26,
    );

    #Labels dem Tabellenkopf hinzufügen als Tabellenüberschriften
    $table_rollen_kopf->put( 0, 1, $lab_table_kopf1 );
    $table_rollen_kopf->put( 0, 2, $lab_table_kopf2 );

    #---------------------------------------------------------------------------
    #  Tabelle mit 2 Spalten wird erzeugt für die Einträge
    #
    #  Bezeichnung, Rechte, ID
    #
    #  Die ID ist notwendig um die einzelnen Einträge in der
    #  Datenbank wiederzufinden und leichter auf Einträge zugreifen
    #  zu können, ist im Programm aber nicht sichtbar.
    #---------------------------------------------------------------------------

    #Erstellt die Tabelle die die GUI-Elemente enthält
    my $table_rollen = $frame_rollen->Table(
        -columns    => 3,
        -rows       => 5,
        -scrollbars => 'oe',
        -relief     => 'raised'
    );

    my $frame_rollen_button = $frame_rollen->Frame();
    my $button_rollen_neu   = $frame_rollen_button->Button(
        -text     => 'Neue Rolle',
        -compound => 'left',
        -image    => $pic_neu,
        -command  => \sub {
            gui_rolle_dialog_neu( $toplevel_gui, \%rollen, \$table_rollen );
        }
    );
    my $button_rollen_bearbeiten = $frame_rollen_button->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            gui_rolle_bearbeiten( $toplevel_gui, \%rollen, \$table_rollen );
        },
    );
    my $button_rollen_loeschen = $frame_rollen_button->Button(
        -text     => 'Löschen',
        -compound => 'left',
        -image    => $pic_delete,
        -command  => \sub {
            gui_rolle_loeschen( $toplevel_gui, \%rollen, \$table_rollen );
        },
    );

    my @choices      = keys %gui;
    my $entry_nummer = $frame_nummer->MatchEntry(
        -choices      => \@choices,
        -fixedwidth   => 1,
        -ignorecase   => 1,
        -maxheight    => 5,
        -textvariable => \$nummer,
    );
    if ( defined $nummer ) {
        $toplevel_gui->configure( -title => 'GUI bearbeiten' );
        $text_bezeic->Contents( $gui{$nummer}[0] );
        $pfad       = $gui{$nummer}[1];
        $bildbeschr = $gui{$nummer}[2];
        $text_beschr->Contents( $gui{$nummer}[3] );
        gui_rolle_tabelle_sync( \$table_rollen, $gui{$nummer}[4] );
        %rollen = %{ $gui{$nummer}[4] };
    }

    my $button_frame = $toplevel_gui->Frame();
    my $button_ok    = $button_frame->Button(
        -state    => 'disabled',
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            gui_tabelle_einfuegen(
                {
                    table       => $table,
                    nummer      => $nummer,
                    bezeichnung => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    bildpfad    => $pfad,
                    bildbeschreibung => $bildbeschr,
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    rollen       => \%rollen,
                    rollen_table => \$table_rollen,
                }
            );
            set_aendern();
            $toplevel_gui->destroy();
        }
    );

    my $button_uebernehmen = $button_frame->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            gui_tabelle_aendern(
                {
                    table       => $table,
                    nummer      => $nummer,
                    bezeichnung => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    bildpfad    => $entry_bilddatei->get(),
                    bildbeschreibung => $entry_bildbeschr->get(),
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    rollen       => \%rollen,
                }
            );
            set_aendern();
            $toplevel_gui->destroy();
        }
    );
    my $button_neu = $button_frame->Button(
        -state    => 'disabled',
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -command  => \sub {
            gui_tabelle_einfuegen(
                {
                    table       => $table,
                    nummer      => $nummer,
                    bezeichnung => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    bildpfad    => $pfad,
                    bildbeschreibung => $bildbeschr,
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    rollen       => \%rollen,
                    rollen_table => \$table_rollen,
                }
            );
            undef $nummer;
            $text_bezeic->Contents($EMPTY);
            undef $pfad;
            undef $bildbeschr;
            $text_beschr->Contents($EMPTY);
            undef %rollen;
            $table_rollen->clear();
            @choices = keys %gui;
            $entry_nummer->configure( -choices => \@choices );
            $entry_nummer->focus();
        }
    );

    my $button_abbrechen = $button_frame->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text    => 'Abbrechen',
        -command => \sub {
            $toplevel_gui->destroy();
        }
    );

    $entry_nummer->bind(
        '<KeyRelease>',
        [
            \&gui_bind_nummer_type,
            {
                nummer             => \$nummer,
                text_bezeic        => \$text_bezeic,
                pfad               => \$pfad,
                bildbeschr         => \$bildbeschr,
                text_beschr        => \$text_beschr,
                table_rollen       => \$table_rollen,
                rollen             => \%rollen,
                button_ok          => \$button_ok,
                button_neu         => \$button_neu,
                button_uebernehmen => \$button_uebernehmen,
            }
        ]
    );

    #    $entry_nummer->bind(
    #        '<FocusOut>',
    #        [
    #            \&bind_nummer_out, \$nummer,             \$button_ok,
    #            \$button_neu,      \$button_uebernehmen, \$toplevel_gui,
    #            \%gui
    #        ]
    #    );

    $entry_nummer->bind(
        '<FocusIn>',
        [
            \&bind_nummer_in, \$nummer, \$button_ok,
            \$button_neu,     \$button_uebernehmen
        ]
    );

    #---------------------------------------------------------------------------
    #  neue gui packs
    #---------------------------------------------------------------------------

    # Nummer
    $frame_nummer->pack( -anchor => 'w' );
    $lab_nummer->pack( -side => 'left' );
    $entry_nummer->pack( -side => 'left' );

    #Bezeichnung
    $frame_bezeichnung->pack( -fill => 'x' );
    $lab_bezeichnung->pack( -anchor => 'w', );
    $text_bezeic->pack( -anchor => 'w', -fill => 'x' );

    #Bildauswahl
    $frame_bild->pack( -fill => 'x' );
    $frame_bild_labels->pack( -side => 'left' );
    $frame_bild_entry->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $frame_bild_entry1->pack( -fill => 'x' );
    $entry_bilddatei->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $button_bilddatei->pack( -side => 'left' );
    $entry_bildbeschr->pack( -fill => 'x' );

    #Beschreibung
    $frame_beschr->pack( -fill => 'x' );
    $lab_beschr->pack( -anchor => 'w' );
    $text_beschr->pack( -anchor => 'w', -fill => 'x' );

    #Rollen einfügen
    $frame_rollen->pack( -fill => 'x' );
    $frame_rollen_button->pack( -fill => 'x' );
    $button_rollen_neu->pack( -side => 'left' );
    $button_rollen_bearbeiten->pack( -side => 'left' );
    $button_rollen_loeschen->pack( -side => 'right' );
    $table_rollen_kopf->pack( -fill => 'x' );
    $table_rollen->pack( -fill => 'x', -expand => '1' );

    #Buttons
    $button_frame->pack( -fill => 'x', -side => 'bottom' );
    if ( defined $nummer ) {
        $button_uebernehmen->pack( -side => 'left' );
    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );

    #---------------------------------------------------------------------------
    #  zwischen bearbeitungs und editier oberfläche umschalten
    #---------------------------------------------------------------------------
    return;
}

#-------------------------------------------------------------------------------
#     Subroutine:  gui_tabelle_einfuegen
#
#				 Diese Funktion fügt einen Eintrag in den Hash %gui und
#				 in die Tabelle im Frame <build_frame7> '8.GUI' hinzu.
#
#   PARAMETERS:
#
#    $table            - Tabelle aus <build_frame7>
#    $nummer           - Nummer der GUI
#    $bezeichnung      - Bezeichung der GUI
#    $bildpfad         - Der Pfad des eingefügten Bildes
#    $bildbeschreibung - Die Beschreibung des eingefügten Bildes
#    $beschreibung     - Beschreibung der GUI
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#    $rollen_table     - Referenz auf Tabelle mit Rollen der GUI
#    $id               - ID der GUI
#
#     See Also:
#     		<funktion_tabelle_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_tabelle_einfuegen {
    my ($parameter_ref)  = @_;
    my $table            = ${$parameter_ref}{'table'};
    my $nummer           = ${$parameter_ref}{'nummer'};
    my $bezeichnung      = ${$parameter_ref}{'bezeichnung'};
    my $bildpfad         = ${$parameter_ref}{'bildpfad'};
    my $bildbeschreibung = ${$parameter_ref}{'bildbeschreibung'};
    my $beschreibung     = ${$parameter_ref}{'beschreibung'};
    my $rollen           = ${$parameter_ref}{'rollen'};
    gui_hash_einfuegen(
        {
            nummer           => $nummer,
            bezeichnung      => $bezeichnung,
            bildpfad         => $bildpfad,
            bildbeschreibung => $bildbeschreibung,
            beschreibung     => $beschreibung,
            rollen           => $rollen,
        }
    );

    umbruch_entfernen( \$bezeichnung );
    umbruch_entfernen( \$beschreibung );

    my $lab_num = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $nummer,
        -width            => '5',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_bez = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $bezeichnung,
        -width            => '11',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_akt = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => rollen_holen($rollen),
        -width            => '15',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_bes = ${$table}->Label(
        -background => 'snow1',
        -relief     => 'groove',
        -text       => $beschreibung,
        -width      => '50',
        -padx       => '2',
        -anchor     => 'w',
        -activebackground =>
          'LightSkyBlue'    #wenn aktiviert bzw markiert auf blau setzen
    );

    my $akt_zeile = ${$table}->totalRows;

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bez->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_akt->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bes->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $lab_num );
    ${$table}->put( $akt_zeile, 1, $lab_bez );
    ${$table}->put( $akt_zeile, 2, $lab_akt );
    ${$table}->put( $akt_zeile, 3, $lab_bes );

    #    ${$table}->put( $akt_zeile, 4, $lab_id );    #id des Eintrages

    return;
}    # ----------  end of subroutine leistung_tabelle_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  rollen_holen
#
#                Fügt alle Rollen einer GUI, mit Komma voneinander getrennt in einen
#                String ein. Dies dient zur Darstellung in der Tabelle von GUI
#                in <gui_tabelle_einfuegen> und <gui_tabelle_sync>
#
#   PARAMETERS:
#
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#
#   RETURNS:
#
#    anonymer_string  - Alle Rollen mit Komma voneinander getrennt
#
#-------------------------------------------------------------------------------
sub rollen_holen {
    my ($rollen) = @_;
    my @rol;
    for my $key ( keys %{$rollen} ) {
        push @rol, ${$rollen}{$key}[0];
    }
    return ( join q{,}, @rol );
}    # ----------  end of subroutine rollen_holen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_bearbeiten
#
#                Sucht die markierte ID aus der Tabelle und übergibt diese an
#                <gui_dialog_neu> zum bearbeiten.
#
#
#     PARAMETERS:
#
#    $table           - Referenz auf Tabelle mit markiertem Eintrag
#
#     See Also:
#     			 <funktion_bearbeiten> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_bearbeiten {
    my ( $table, ) = @_;
    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();

        return;
    }
    gui_dialog_neu( $table, $nummer );
    return;

}    # ----------  end of subroutine gui_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_hash_einfuegen
#
#				 Diese Funktion fügt einen Eintrag in den Hash %gui hinzu und
#				 sucht nach der ersten freien ID.
#
#   PARAMETERS:
#
#    $nummer           - Nummer der GUI
#    $bezeichnung      - Bezeichung der GUI
#    $bildpfad         - Der Pfad des eingefügten Bildes
#    $bildbeschreibung - Die Beschreibung des eingefügten Bildes
#    $beschreibung     - Beschreibung der GUI
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#
#   RETURNS:
#
#    $id               - ID der GUI
#
#     See Also:
#     		<funktion_tabelle_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_hash_einfuegen {
    my ($parameter_ref)  = @_;
    my $nummer           = ${$parameter_ref}{'nummer'};
    my $bezeichnung      = ${$parameter_ref}{'bezeichnung'};
    my $bildpfad         = ${$parameter_ref}{'bildpfad'};
    my $bildbeschreibung = ${$parameter_ref}{'bildbeschreibung'};
    my $beschreibung     = ${$parameter_ref}{'beschreibung'};
    my $rollen           = ${$parameter_ref}{'rollen'};

    my %copycat = %{$rollen};
    $gui{$nummer} =
      [ $bezeichnung, $bildpfad, $bildbeschreibung, $beschreibung, \%copycat ];

    return ();
}    # ----------  end of subroutine gui_hash_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_tabelle_aendern
#
#				 Ändert einen bestimmten Eintrag im Hash <%gui> und die entsprechende Zeile
#				 in der Tabelle im Frame '6.Leistungen'.
#
#   PARAMETERS:
#    $table            - Tabelle aus <build_frame7>
#    $nummer           - Nummer der GUI
#    $bezeichnung      - Bezeichung der GUI
#    $bildpfad         - Der Pfad des eingefügten Bildes
#    $bildbeschreibung - Die Beschreibung des eingefügten Bildes
#    $beschreibung     - Beschreibung der GUI
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#    $id               - ID der GUI
#
#     See Also:
#     			 <funktion_tabelle_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_tabelle_aendern {
    my ($parameter_ref)  = @_;
    my $table            = ${$parameter_ref}{'table'};
    my $nummer           = ${$parameter_ref}{'nummer'};
    my $bezeichnung      = ${$parameter_ref}{'bezeichnung'};
    my $bildpfad         = ${$parameter_ref}{'bildpfad'};
    my $bildbeschreibung = ${$parameter_ref}{'bildbeschreibung'};
    my $beschreibung     = ${$parameter_ref}{'beschreibung'};
    my $rollen           = ${$parameter_ref}{'rollen'};

    my $row;
    gui_hash_aendern(
        {
            nummer           => $nummer,
            bezeichnung      => $bezeichnung,
            bildpfad         => $bildpfad,
            bildbeschreibung => $bildbeschreibung,
            beschreibung     => $beschreibung,
            rollen           => $rollen,
        }
    );

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) eq $nummer ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$beschreibung );
    umbruch_entfernen( \$bezeichnung );

    ${$table}->get( $row, 0 )->configure( -text => $nummer );
    ${$table}->get( $row, 1 )->configure( -text => $bezeichnung );
    ${$table}->get( $row, 2 )->configure( -text => rollen_holen($rollen) );
    ${$table}->get( $row, 3 )->configure( -text => $beschreibung );

    return;
}    # ----------  end of subroutine gui_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_loeschen
#
#        Löscht die markierte Zeile aus der Tabelle und benutzt die
#        Funktion <gui_hash_loeschen> um den entsprechenden Eintrag aus dem Hash
#        <%gui> zu löschen. Anschließend wird die Tabelle neu geladen.
#
#   PARAMETERS:
#    $table            - Tabelle aus <build_frame7>
#
#     See Also:
#     			 <funktion_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_loeschen {
    my ($table) = @_;
    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }

    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    gui_hash_loeschen($nummer);

    # alte Reihenfolge der Tabelleneinträge über die
    # IDs speichern ohne die gelöschte Zeile
    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) ne $nummer )
        {    #gelöschte Zeile
            push @folge, ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    ${$table}->clear();

    gui_tabelle_sync( $table, @folge );

    return;

}    # ----------  end of subroutine gui_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_tabelle_sync
#
#        Löscht die markierte Zeile aus der Tabelle und benutzt die
#        Funktion <gui_hash_loeschen> um den entsprechenden Eintrag aus dem Hash
#        <%gui> zu löschen.
#
#   PARAMETERS:
#    $table      - Tabelle aus <build_frame7>
#    @folge      - IDs in einer bestimmten Reihenfolge
#
#     See Also:
#     			 <funktion_tabelle_sync> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_tabelle_sync {
    my ( $table, @folge ) = @_;
    my ( $nummer, $bezeichnung, $beschreibung, $akteure );
    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {

        $nummer       = $folge[$i];
        $bezeichnung  = $gui{ $folge[$i] }[0];
        $akteure      = rollen_holen( $gui{ $folge[$i] }[4] );
        $beschreibung = $gui{ $folge[$i] }[3];
        umbruch_entfernen( \$bezeichnung );
        umbruch_entfernen( \$beschreibung );
        my $lab_num = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $nummer,
            -width            => '5',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );
        my $lab_bez = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $bezeichnung,
            -width            => '11',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        my $lab_akt = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $akteure,
            -width            => '15',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );
        my $lab_bes = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $beschreibung,
            -width      => '50',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf blau setzen
        );

        $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_bez->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_bes->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_akt->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_num );
        ${$table}->put( $i, 1, $lab_bez );
        ${$table}->put( $i, 2, $lab_akt );
        ${$table}->put( $i, 3, $lab_bes );

        #        ${$table}->put( $i, 4, $lab_id );
    }

    return;

}    # ----------  end of subroutine gui_tabelle_sync  ----------

#-------------------------------------------------------------------------------
# Subroutine:  gui_hash_loeschen
#
# Die übergebene Id wird aus <%gui> gelöscht
#
# PARAMETERS:
#  $id - zu löschende ID
#-------------------------------------------------------------------------------
sub gui_hash_loeschen {
    my ($nummer) = @_;
    delete $gui{$nummer};
    return;

}    # ----------  end of subroutine gui_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_hash_aendern
#
#				 Ändert einen bestimmten Eintrag mit der übergebenen ID
#				 im Hash <%gui>
#
#   PARAMETERS:
#    $nummer           - Nummer der GUI
#    $bezeichnung      - Bezeichung der GUI
#    $bildpfad         - Der Pfad des eingefügten Bildes
#    $bildbeschreibung - Die Beschreibung des eingefügten Bildes
#    $beschreibung     - Beschreibung der GUI
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#    $id               - ID der GUI
#
#     See Also:
#     			 <funktion_hash_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_hash_aendern {
    my ($parameter_ref)  = @_;
    my $nummer           = ${$parameter_ref}{'nummer'};
    my $bezeichnung      = ${$parameter_ref}{'bezeichnung'};
    my $bildpfad         = ${$parameter_ref}{'bildpfad'};
    my $bildbeschreibung = ${$parameter_ref}{'bildbeschreibung'};
    my $beschreibung     = ${$parameter_ref}{'beschreibung'};
    my $rollen           = ${$parameter_ref}{'rollen'};

    $gui{$nummer} =
      [ $bezeichnung, $bildpfad, $bildbeschreibung, $beschreibung, $rollen ];

    return;
}    # ----------  end of subroutine gui_hash_aendern  ----------

sub gui_rolle_bind {
    my ($par1) = @_;
    return;
}    # ----------  end of subroutine gui_rolle_bind  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  gui_rolle_dialog_neu
#
#    Wird aus <gui_dialog_neu> aufgerufen und fügt der GUI Rollen hinzu.
#    Diese Oberfläche hat auch, ähnlich wie in <funktion_dialog_neu> beschrieben
#    zwei Modi die abhängig von der $id aktiviert werden.
#
#   PARAMETERS:
#
#    $toplevel_gui     - Toplevel-Widget aus <gui_dialog_neu>
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#    $table_rollen     - Referenz auf Tabelle mit Rollen
#    $id               - ID der Rolle
#
#   See Also:
#   <funktion_dialog_neu> ist nahezu funktionsgleich
#
#-------------------------------------------------------------------------------
sub gui_rolle_dialog_neu {
    my ( $toplevel_gui, $rollen, $table_rollen, $id ) = @_;

    my $neue_rolle = $toplevel_gui->Toplevel( -title => 'Neue Rolle' );

    #Fenster mittig positionieren
    $neue_rolle->geometry('400x200');
    $neue_rolle->geometry( q{+}
          . int( $screen_width / 2 - 400 / 2 ) . q{+}
          . int( $screen_height / 2 - 200 / 2 ) );
    my $frame_bezeichnung = $neue_rolle->Frame();
    my $frame_rechte      = $neue_rolle->Frame();

    $neue_rolle->raise($toplevel_gui);
    $neue_rolle->grab();    #macht Fenster modal
    $neue_rolle->resizable( 0, 0 );

    my $bezeichnung;
    my $label_bezeichnung = $frame_bezeichnung->Label( -text => 'Bezeichnung' );
    my $entry_bezeichnung =
      $frame_bezeichnung->Entry( -textvariable => \$bezeichnung );
    my $label_rechte = $frame_rechte->Label( -text => 'Rechte' );
    my $box_rechte =
      $frame_rechte->Scrolled( 'Text', -scrollbars => 'oe', -height => '7' );

    if ( defined $id ) {
        $bezeichnung = ${$rollen}{$id}[0];
        $box_rechte->Contents( ${$rollen}{$id}[1] );
    }
    my $frame_buttons = $neue_rolle->Frame();
    my $button_ok     = $frame_buttons->Button(
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {

            gui_rolle_tabelle_einfuegen( $table_rollen, $rollen, $bezeichnung,
                $box_rechte->get( '1.0', 'end -1 chars' ),
            );
            set_aendern();
            $neue_rolle->destroy();
        }
    );
    my $button_neu = $frame_buttons->Button(
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -command  => \sub {
            gui_rolle_tabelle_einfuegen( $table_rollen, $rollen, $bezeichnung,
                $box_rechte->get( '1.0', 'end -1 chars' ),
            );
            undef $bezeichnung;
            $box_rechte->Contents($EMPTY);
            set_aendern();
        },
    );
    my $button_abbrechen = $frame_buttons->Button(
        -text     => 'Abbrechen',
        -compound => 'left',
        -image    => $pic_exit,
        -command  => \sub {
            $neue_rolle->destroy();
        }
    );

    my $button_uebernehmen = $frame_buttons->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            gui_rolle_tabelle_aendern( $table_rollen, $rollen, $bezeichnung,
                $box_rechte->get( '1.0', 'end -1 chars' ), $id );
            set_aendern();
            $neue_rolle->destroy();
        },

    );

    #---------------------------------------------------------------------------
    #  neue_rolle packs
    #---------------------------------------------------------------------------
    $frame_bezeichnung->pack( -fill => 'x' );
    $label_bezeichnung->pack( -side => 'left' );
    $entry_bezeichnung->pack( -side => 'left', -expand => '1', -fill => 'x' );
    $frame_rechte->pack( -fill   => 'x' );
    $label_rechte->pack( -anchor => 'w' );
    $box_rechte->pack();
    $frame_buttons->pack( -fill => 'x' );

    if ( defined $id ) {
        $button_uebernehmen->pack( -side => 'left' );
    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );

    return;
}    # ----------  end of subroutine gui_rolle_dialog_neu  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  gui_rolle_tabelle_einfuegen
#
#    Fügt der Tabelle aus <gui_dialog_neu> einen Eintrag hinzu.
#
#   PARAMETERS:
#
#    $table            - Tabelle aus <gui_dialog_neu>
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#    $bezeichnung      - Bezeichnung der Rolle
#    $box              - Beschreibung der Rolle
#    $id               - ID der Rolle
#
#   See Also:
#
#    <funktion_tabelle_einfuegen>   hat nahezu gleiche Funktionalität
#
#
#-------------------------------------------------------------------------------
sub gui_rolle_tabelle_einfuegen {
    my ( $table, $rollen, $bezeichnung, $box, $id ) = @_;

    $id = gui_rolle_hash_einfuegen( $bezeichnung, $box, $rollen );

    umbruch_entfernen( \$box );

    my $rolle_lab = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $bezeichnung,
        -width            => '18',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_bez = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $box,
        -width            => '26',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );

    my $lab_id = ${$table}->Label(
        -foreground       => 'snow1',    #gleiche farbe wie hintergrund
        -text             => $id,
        -width            => '0',
        -activebackground => 'snow1'
    );
    my $akt_zeile = ${$table}->totalRows;

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $rolle_lab->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bez->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $rolle_lab );
    ${$table}->put( $akt_zeile, 1, $lab_bez );
    ${$table}->put( $akt_zeile, 2, $lab_id );      #id des Eintrages

    return;
}    # ----------  end of subroutine gui_rolle_tabelle_einfuegen  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  gui_rolle_tabelle_aendern
#
#    Ändert in der Tabelle aus <gui_dialog_neu> einen Eintrag.
#
#   PARAMETERS:
#
#    $table            - Referenz auf Tabelle mit Rollen
#    $rollen           - Referenz auf Hash mit den Rollen
#    $bezeichnung      - Bezeichnung der Rolle
#    $box              - Beschreibung der Rolle
#    $id               - ID der Rolle
#
#   See Also:
#
#    <funktion_tabelle_aendern>   hat nahezu gleiche Funktionalität
#
#
#-------------------------------------------------------------------------------
sub gui_rolle_tabelle_aendern {
    my ( $table, $rollen, $bezeichnung, $box, $id ) = @_;
    my $row;
    gui_rolle_hash_aendern( $rollen, $bezeichnung, $box, $id );
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 2 )->cget( -text ) == $id ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$box );

    ${$table}->get( $row, 0 )->configure( -text => $bezeichnung );
    ${$table}->get( $row, 1 )->configure( -text => $box );

    return;
}    # ----------  end of subroutine gui_rolle_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  gui_rolle_hash_aendern
#
#    Ändert einen Eintrag in dem Hash %rollen
#
#   PARAMETERS:
#
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#    $bezeichnung      - Bezeichnung der Rolle
#    $box              - Beschreibung der Rolle
#    $id               - Zu ändernde ID im Hash
#
#   See Also:
#
#    <funktion_hash_aendern>   hat nahezu gleiche Funktionalität
#
#
#-------------------------------------------------------------------------------
sub gui_rolle_hash_aendern {
    my ( $rollen, $bezeichnung, $box, $id ) = @_;
    ${$rollen}{$id} = [ $bezeichnung, $box ];

    return;
}    # ----------  end of subroutine gui_rolle_hash_aendern  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  gui_rolle_bearbeiten
#
#   Findet markierte Zeile heraus und ruft <gui_rolle_dialog_neu> mit der zu
#   editierenden ID auf.
#
#   PARAMETERS:
#
#    $toplevel_gui     - aufrufendes Toplevel-Widget
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#    $table            - Referenz auf Tabelle mit Rollen
#
#   See Also:
#
#    <funktion_bearbeiten>   hat nahezu gleiche Funktionalität
#
#
#-------------------------------------------------------------------------------
sub gui_rolle_bearbeiten {
    my ( $toplevel_gui, $rollen, $table ) = @_;
    my $id;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $id = ${$table}->get( $i, 2 )->cget( -text );
        }
    }
    if ( !defined $id ) {
        $toplevel_gui->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();

        return;
    }
    gui_rolle_dialog_neu( $toplevel_gui, $rollen, $table, $id );
    return;

}    # ----------  end of subroutine gui_rolle_bearbeiten  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  gui_rolle_loeschen
#
#
#
#   PARAMETERS:
#
#    $toplevel_gui     - aufrufendes Toplevel-Widget
#    $rollen           - Referenz auf Hash mit den Rollen der GUI
#    $table            - Referenz auf Tabelle mit Rollen
#
#   See Also:
#
#    <funktion_loeschen>   hat nahezu gleiche Funktionalität
#
#-------------------------------------------------------------------------------
sub gui_rolle_loeschen {
    my ( $toplevel_gui, $rollen, $table ) = @_;

    my $id;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $id = ${$table}->get( $i, 2 )->cget( -text );
        }
    }

    if ( !defined $id ) {    #Fehlermeldung wenn keine Zeile markiert wurde
        $toplevel_gui->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    gui_rolle_hash_loeschen( $id, $rollen );

    # alte Reihenfolge der Tabelleneinträge über die
    # IDs speichern ohne die gelöschte Zeile
    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 2 )->cget( -text ) != $id ) { #gelöschte Zeile
            push @folge, ${$table}->get( $i, 2 )->cget( -text );
        }
    }
    ${$table}->clear();

    gui_rolle_tabelle_sync( $table, $rollen, @folge );

    return;

}    # ----------  end of subroutine gui_rolle_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_rolle_tabelle_sync
#
#				 Diese Funktion synchronisiert die Tabelle mit dem Hash %rolle und fügt
#				 die Zeilen in einer bestimmten Reihenfolge in die Tabelle.
#
#   PARAMETERS:
#   			 $table	 - Enthält die Referenz auf die zu bearbeitende Tabelle
#   			 $rollen - Enthält die Referenz auf hash %rollen
#				 @folge	 - Enthält die Reihenfolge in welcher die Datensätze in
#				           die Tabelle eingepflegt werden sollen.
#
#     See Also:
#     			 <funktion_tabelle_sync> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_rolle_tabelle_sync {
    my ( $table, $rollen, @folge ) = @_;
    my ( $box, $beschreibung, $id );
    if ( not @folge ) {
        @folge = keys %{$rollen};
    }

    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {
        $beschreibung = ${$rollen}{ $folge[$i] }[0];
        $box          = ${$rollen}{ $folge[$i] }[1];
        umbruch_entfernen( \$box );
        $id = $folge[$i];
        my $beschreibung_lab = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $beschreibung,
            -width            => '18',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        my $box_lab = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $box,
            -width      => '26',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );
        my $lab_id = ${$table}->Label(
            -foreground => 'snow1',    #gleiche farbe wie hintergrund
            -text       => $id,
            -width      => '0'
        );

        $box_lab->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $beschreibung_lab->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $beschreibung_lab );
        ${$table}->put( $i, 1, $box_lab );
        ${$table}->put( $i, 2, $lab_id );
    }

    return;
}    # ----------  end of subroutine gui_rolle_tabelle_sync  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_rollen_hash_loeschen
#
#				 Löscht das Key/Value-Paar mit der entsprechenden ID im Hash %rollen.
#
#   PARAMETERS:
#   			 $id     - Die ID des zu löschenden Eintrages
#   			 $rollen - Enthält die Referenz auf hash %rollen
#
#     See Also:
#     			 <funktion_hash_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_rolle_hash_loeschen {
    my ( $id, $rollen ) = @_;
    delete ${$rollen}{$id};
    return;
}    # ----------  end of subroutine gui_rolle_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  gui_rolle_hash_einfuegen
#
#                Fügt einen neuen Eintrag in den Hash %rollen hinzu.
#
#   Parameters:
#   			 $bezeichnung - Die Bezeichnung der Rolle
#   			 $box         - Die Beschreibung der Rolle
#   			 $rollen      - Enthält die Referenz auf hash %rollen
#
#      Returns:
#                $id 		- ID des Eintrages
#
#     See Also:
#     			 <funktion_hash_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub gui_rolle_hash_einfuegen {
    my ( $bezeichnung, $box, $rollen ) = @_;
    my $id;
    for my $i ( 0 .. keys %{$rollen} ) {    #finde unbenutzte IDS heraus
        if ( !exists ${$rollen}{$i} ) {
            $id = $i;
        }
    }

    ${$rollen}{$id} = [ $bezeichnung, $box ];

    return $id;
}    # ----------  end of subroutine gui_rolle_hash_einfuegen  ----------

#---------------------------------------------------------------------------
#   Subroutine: bind_nummer_in
#
#   Unabhängig vom Modus wird in diesem Binding nach jedem Tastenanschlag 
#   überprüft ob das Nummern-Entry leer ist.
#
#   *Entry leer*
#   - Ok-Button deaktivieren
#   - Neu-Button deaktivieren
#   - Übernehmen-Button deaktivieren
#   
#   Parameters: 
#   $w                  - aufrufendes Widget
#   $num                - Nummer
#   $button_ok          - Button-Widget
#   $button_neu         - Button-Widget
#   $button_uebernehmen - Button-Widget
#---------------------------------------------------------------------------
sub bind_nummer_in {
    my ( $w, $num, $button_ok, $button_neu, $button_uebernehmen ) = @_;
    if ( not ${$num} ) {
        ${$button_ok}->configure( -state => 'disabled' );
        ${$button_neu}->configure( -state => 'disabled' );
        ${$button_uebernehmen}->configure( -state => 'disabled' );
    }
    return;
}

#---------------------------------------------------------------------------
#  Subroutine: lei_bind_nummer_type
#  
#      Dem Binding werden alle Eingadbefelder übergeben und es überprüft nach jedem
#      Tastenschlag ob die eingegebene Nummer bereits vorhanden ist. Dabei wird
#      anhand des Modus indem sich der Dialog befindet entschieden ob ein Button
#      aktiviert oder deaktiviert wird. Durch die ismapped-Funktion von Tk findet
#      das Binding heraus ob der OK- (neu anlegen-Modus) oder der Übernehmen-Button
#      (Bearbeitungs-Modus) aktiv ist. Unabhängig vom Modus werden bei Existenz
#      der Nummer die Eingabefelder den dazugehörigen Daten gefüllt.
#
#      *Übernehmen Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - Nummernfeld weiss färben
#
#      *Neu anlegen-Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - deaktiviere Neu-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - aktiviere Neu-Button
#      - Nummernfeld weiss farben
#
# Parameters: 
#
#    $w                 - aufrufendes Widget 
#    $parameter_ref     - Folgende Parameter werden per Hashreferenz übergeben:
#    num                - Nummer
#    text_bezeic        - Text-Widget
#    text_beschr        - Text-Widget
#    kapitel            - Entry-Widget
#    button_ok          - Button-Widget
#    button_neu         - Button-Widget
#    button_uebernehmen - Button-Widget
#
#---------------------------------------------------------------------------
sub lei_bind_nummer_type {
    my ( $w, $parameter_ref ) = @_;

    my $num                = ${$parameter_ref}{'nummer'};
    my $text_bezeic        = ${$parameter_ref}{'text_bezeic'};
    my $text_beschr        = ${$parameter_ref}{'text_beschr'};
    my $kapitel            = ${$parameter_ref}{'kapitel'};
    my $button_ok          = ${$parameter_ref}{'button_ok'};
    my $button_neu         = ${$parameter_ref}{'button_neu'};
    my $button_uebernehmen = ${$parameter_ref}{'button_uebernehmen'};

    my $nummer = ${$num};
    if ($nummer) {
        if ( $leistungen{$nummer} ) {

            # wenn Eintrag im Hash dann auf jeden Fall Einträge laden
            ${$text_bezeic}->Contents( $leistungen{$nummer}[0] );
            ${$text_beschr}->Contents( $leistungen{$nummer}[1] );
            ${$kapitel} = suche_id( $nummer, \%leistungen_kapitel );
            ${$button_uebernehmen}->configure( -state => 'normal' );

            # Wenn OK-Button gemapped dann befindet man sich im
            # "Neu anlegen"-Modus und die Buttons und Eingaben
            # deaktivieren um zu verdeutlichen, dass die Zahl bereits
            # vergeben ist.
            if ( ${$button_ok}->ismapped() ) {
                $w->configure( -background => '#ff9696' );
                ${$button_ok}->configure( -state => 'disabled' );
                ${$button_neu}->configure( -state => 'disabled' );
            }
        }
        else {

            #Ansonsten alle Felder leeren, aktivieren und
            #Ok/Neu Buttons auswählbar machen
            ${$text_bezeic}->Contents($EMPTY);
            ${$text_beschr}->Contents($EMPTY);
            ${$kapitel} = $EMPTY;
            $w->configure( -background => 'snow1' );
            ${$button_ok}->configure( -state => 'normal' );
            ${$button_neu}->configure( -state => 'normal' );

            #Übernehmen-Button deaktivieren, da im Bearbeitungs-Modus
            #nur vorhandene Einträge bearbeite werden. Rein Theoretisch
            #könnte man auch mit dem Bearbeiten-Button Einträge anlegen,
            #jedoch würde as nur unnötig für Verwirrung sorgen.
            ${$button_uebernehmen}->configure( -state => 'disabled' );
        }
    }
    else {

        #Wenn keine Nummer angegeben, Alle Buttons deaktivieren.
        ${$button_ok}->configure( -state => 'disabled' );
        ${$button_neu}->configure( -state => 'disabled' );
        ${$button_uebernehmen}->configure( -state => 'disabled' );
    }

    return;
}    # ----------  end of subroutine lei_bind_nummer_type  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  leistung_dialog_neu
#
#                Erstellt einen Dialog um eine neue Leistung dem Pflichtenheft hinzuzufügen.
#                Der Dialog wird auch zum Bearbeiten einer Leistung benutzt und muss zum
#                diesem Zweck eine ID mit übergeben bekommen.
#
#   Parameters:
#				 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 $id    - Die ID des Datensatzes
#
#     See Also:
#     			 <funktion_dialog_neu> ist funktionsgleich

#-------------------------------------------------------------------------------
sub leistung_dialog_neu {
    my ( $table, $nummer ) = @_;
    my $toplevel_leistung =
      $frame_stack[4]->Toplevel( -title => 'neue Leistung anlegen' );

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 435;
    modal( \$toplevel_leistung, $BREITE, $HOEHE );
    my $eingabe =
      $toplevel_leistung->Frame( -borderwidth => '2', -relief => 'groove' );
    my $frame_nummer = $eingabe->Frame();
    my $lab_nummer =
      $frame_nummer->Label( -text => 'Nummer', -width => '8', -anchor => 'w' );

    my @choices = keys %leistungen;

    my $frame_kapitel = $eingabe->Frame();
    my $label_kapitel = $frame_kapitel->Label(
        -text   => 'Kapitel',
        -width  => '8',
        -anchor => 'w'
    );
    my @klist = keys %leistungen_kapitel;    #alle Leistungskapitel holen
    my $kapitel;
    my $combo_kapitel = $frame_kapitel->ComboEntry(
        -textvariable => \$kapitel,
        -itemlist     => [@klist],
        -width        => 28,
        -borderwidth  => '0'
    );

    my $lab_bezeichnung = $eingabe->Label( -text => 'Bezeichnung' );
    my $text_bezeic = $eingabe->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_bezeic->configure( -width => '40', height => '9' );
    my $lab_beschr = $eingabe->Label( -text => 'Beschreibung' );
    my $text_beschr = $eingabe->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_beschr->configure( -width => '40', height => '9' );
    my $buttons = $toplevel_leistung->Frame();

    my $entry_nummer = $frame_nummer->MatchEntry(
        -choices      => \@choices,
        -fixedwidth   => 1,
        -ignorecase   => 1,
        -maxheight    => 5,
        -textvariable => \$nummer,
    );

    my $button_ok = $buttons->Button(
        -state    => 'disabled',
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -state    => 'disabled',
        -command  => \sub {
            leistung_tabelle_einfuegen(
                {
                    table        => $table,
                    nummer       => $nummer,
                    bezeichnung  => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    kapitel      => $kapitel,
                }
            );
            set_aendern();
            $toplevel_leistung->destroy();
        }
    );

    my $button_uebernehmen = $buttons->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            leistung_tabelle_aendern(
                {
                    table        => $table,
                    nummer       => $nummer,
                    bezeichnung  => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    kapitel      => $kapitel,
                }
            );
            set_aendern();
            $toplevel_leistung->destroy();
        }
    );

    my $button_neu = $buttons->Button(
        -state    => 'disabled',
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -state    => 'disabled',
        -command  => \sub {
            leistung_tabelle_einfuegen(
                {
                    table        => $table,
                    nummer       => $nummer,
                    bezeichnung  => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    kapitel      => $kapitel,
                }
            );
            undef $nummer;
            $text_bezeic->Contents($EMPTY);
            $text_beschr->Contents($EMPTY);
            undef $kapitel;
            @klist = keys %leistungen_kapitel;
            $combo_kapitel->configure( -list => \@klist );
            @choices = keys %leistungen;
            $entry_nummer->configure( -choices => \@choices );
            $entry_nummer->focus();
            set_aendern();
        }
    );

    my $button_abbrechen = $buttons->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text    => 'Abbrechen',
        -command => \sub {
            $toplevel_leistung->destroy();
          }

    );

    $entry_nummer->bind(
        '<KeyRelease>',
        [
            \&lei_bind_nummer_type,
            {
                nummer             => \$nummer,
                text_bezeic        => \$text_bezeic,
                text_beschr        => \$text_beschr,
                kapitel            => \$kapitel,
                button_ok          => \$button_ok,
                button_neu         => \$button_neu,
                button_uebernehmen => \$button_uebernehmen,
            }
        ]
    );

    $entry_nummer->bind(
        '<FocusIn>',
        [
            \&bind_nummer_in, \$nummer, \$button_ok,
            \$button_neu,     \$button_uebernehmen
        ]
    );

    if ( defined $nummer ) {
        $toplevel_leistung->configure( -title => 'Leistung bearbeiten' );
        $text_bezeic->Contents( $leistungen{$nummer}[0] );
        $text_beschr->Contents( $leistungen{$nummer}[1] );
        $kapitel = suche_id( $nummer, \%leistungen_kapitel );
        $entry_nummer->focus();
    }

    #---------------------------------------------------------------------------
    #  neue Leistung packs
    #---------------------------------------------------------------------------

    $eingabe->pack( -pady => '2' );
    $frame_nummer->pack( -anchor => 'w' );
    $lab_nummer->pack( -side => 'left' );
    $entry_nummer->pack( -side => 'left' );
    $frame_kapitel->pack( -anchor => 'w', -fill => 'x' );
    $label_kapitel->pack( -side   => 'left' );
    $combo_kapitel->pack( -side   => 'left' );
    $lab_bezeichnung->pack( -anchor => 'w' );
    $text_bezeic->pack( -anchor => 'w' );
    $lab_beschr->pack( -anchor => 'w' );
    $text_beschr->pack( -anchor => 'w' );
    $buttons->pack( -fill => 'x' );

    if ( defined $nummer ) {
        $button_uebernehmen->pack( -side => 'left' );
    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );
    return;
}

#-------------------------------------------------------------------------------
#     Subroutine:  leistung_tabelle_einfuegen
#
#				 Diese Funktion fügt einen Eintrag in den Hash %leistungen und
#				 in die Tabelle im Frame '6.Leistungen' hinzu.
#
#   PARAMETERS:
#   			 $table         - Enthält die Referenz auf die zu bearbeitende Tabelle
#				 $nummer        - Die Nummer der Leistung
#				 $bezeichnung   - Die Bezeichnung der Leistung
#				 $beschreibung  - Die Beschreibung der Leistung
#				 $kapitel       - Kapitel der Leistung
#				 $id            - Die eindeutige ID des zu bearbeitenden Datensatzes
#
#     See Also:
#     			 <funktion_tabelle_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub leistung_tabelle_einfuegen {
    my ($parameter_ref) = @_;
    my $table           = ${$parameter_ref}{'table'};
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    leistung_hash_einfuegen(
        {
            nummer       => $nummer,
            bezeichnung  => $bezeichnung,
            beschreibung => $beschreibung,
            kapitel      => $kapitel,
        }
    );

    umbruch_entfernen( \$bezeichnung );
    umbruch_entfernen( \$beschreibung );

    my $lab_num = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $nummer,
        -width            => '6',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_bez = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $bezeichnung,
        -width            => '35',
        -padx             => '2',
        -anchor           => 'w',
        -activebackground => 'LightSkyBlue'
    );

    my $lab_bes = ${$table}->Label(
        -background => 'snow1',
        -relief     => 'groove',
        -text       => $beschreibung,
        -width      => '41',
        -padx       => '2',
        -anchor     => 'w',
        -activebackground =>
          'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
    );

    my $akt_zeile = ${$table}->totalRows;

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bez->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bes->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $lab_num );
    ${$table}->put( $akt_zeile, 1, $lab_bez );
    ${$table}->put( $akt_zeile, 2, $lab_bes );

    #    ${$table}->put( $akt_zeile, 3, $lab_id );    #id des Eintrages

    return;
}    # ----------  end of subroutine leistung_tabelle_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  leistung_tabelle_aendern
#
#           Ändert einen bestimmten Eintrag im Hash %leistungen und die entsprechende Zeile
#           in der Tabelle im Frame '6.Leistungen'.
#
#   PARAMETERS:
#           $table        - Enthält die Referenz auf die zu bearbeitende Tabelle
#           $nummer       - Die Nummer der Leistung
#           $bezeichnung  - Die Bezeichnung der Leistung
#           $beschreibung - Die Beschreibung der Leistung
#           $kapitel      - Kapitel der Leistung
#           $id           - Die eindeutige ID des zu bearbeitenden Datensatzes
#
#     See Also:
#     			 <funktion_tabelle_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub leistung_tabelle_aendern {
    my ($parameter_ref) = @_;
    my $table           = ${$parameter_ref}{'table'};
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    my $row;
    leistung_hash_aendern(
        {
            nummer       => $nummer,
            bezeichnung  => $bezeichnung,
            beschreibung => $beschreibung,
            kapitel      => $kapitel,
        }
    );

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) eq $nummer ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$beschreibung );
    umbruch_entfernen( \$bezeichnung );

    ${$table}->get( $row, 0 )->configure( -text => $nummer );
    ${$table}->get( $row, 1 )->configure( -text => $bezeichnung );
    ${$table}->get( $row, 2 )->configure( -text => $beschreibung );

    return;
}    # ----------  end of subroutine leistung_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  leistung_tabelle_sync
#
#				 Diese Funktion synchronisiert die Tabelle mit dem Hash %leistungen und fügt
#				 die Zeilen in einer bestimmten Reihenfolge in die Tabelle.
#
#   PARAMETERS:
#   			 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 @folge	- Enthält die Reihenfolge in welcher die Datensätze in
#				          die Tabelle eingepflegt werden sollen.
#
#     See Also:
#     			 <funktion_tabelle_sync> ist funktionsgleich
#-------------------------------------------------------------------------------
sub leistung_tabelle_sync {
    my ( $table, @folge ) = @_;

    my ( $nummer, $bezeichnung, $beschreibung );
    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {
        $nummer       = $folge[$i];
        $bezeichnung  = $leistungen{ $folge[$i] }[0];
        $beschreibung = $leistungen{ $folge[$i] }[1];

        my $lab_num = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $nummer,
            -width            => '6',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        umbruch_entfernen( \$bezeichnung );
        my $lab_bezeichnung = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $bezeichnung,
            -width      => '35',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );

        umbruch_entfernen( \$beschreibung );
        my $lab_beschreibung = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $beschreibung,
            -width            => '41',
            -padx             => '2',
            -anchor           => 'w',
            -activebackground => 'LightSkyBlue'
        );

        $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_bezeichnung->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_beschreibung->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_num );
        ${$table}->put( $i, 1, $lab_bezeichnung );
        ${$table}->put( $i, 2, $lab_beschreibung );

    }

    return;
}    # ----------  end of subroutine datum_tabelle_sync  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  leistung_bearbeiten
#
#				 Diese Funktion holt die ID des markierten Datensatzes und ermöglicht mit Hilfe
#				 der Funktion 'leistung_dialog_neu' die Bearbeitung des Datensatzes.
#
#   PARAMETERS:
#   			 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#
#     See Also:
#     			 <funktion_bearbeiten> ist funktionsgleich
#-------------------------------------------------------------------------------
sub leistung_bearbeiten {
    my ($table) = @_;
    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();

        return;
    }
    leistung_dialog_neu( $table, $nummer );
    return;
}    # ----------  end of subroutine leistung_bearbeiten  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  leistung_loeschen
#
#				 Die Funktion löscht die markierte Zeile aus der Tabelle und benutzt die
#      			 Funktion leistung_hash_loeschen um den entsprechenden Eintrag aus dem Hash
#      			 %leistungen zu löschen.
#
#   Parameters:
#   			 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#
#     See Also:
#     			 <funktion_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub leistung_loeschen {
    my ($table) = @_;
    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden

            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }

    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    leistung_hash_loeschen($nummer);

    # alte Reihenfolge der Tabelleneinträge über die
    # IDs speichern ohne die gelöschte Zeile
    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {

        if ( ${$table}->get( $i, 0 )->cget( -text ) ne $nummer )
        {    #gelöschte Zeile
            push @folge, ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    ${$table}->clear();

    leistung_tabelle_sync( $table, @folge );

    return;
}    # ----------  end of subroutine datum_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  leistung_hash_einfuegen
#
#                Fügt einen neuen Eintrag in den Hash %leistungen hinzu.
#
#   Parameters:
#   			 $nummer	    - Die Nummer der Leistung
#   			 $bezeic	    - Die Art des Kriteriums
#   			 $beschreibung	- Die Beschreibung der Leistung
#                $kapitel       - Kapitel der Leistung
#
#      Returns:
#                $id 		- ID des Eintrages
#
#     See Also:
#     			 <funktion_hash_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub leistung_hash_einfuegen {
    my ($parameter_ref) = @_;
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    my $id;
    for my $i ( 0 .. keys %leistungen ) {    #finde unbenutzte IDS heraus
        if ( !exists $leistungen{$i} ) {
            $id = $i;
        }
    }

    einfuegen_id( $nummer, $kapitel, \%leistungen_kapitel );

    $leistungen{$nummer} = [ $bezeichnung, $beschreibung ];

    return ();
}    # ----------  end of subroutine leistung_hash_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  leistung_hash_loeschen
#
#				 Löscht das Key/Value-Paar mit der entsprechenden ID im Hash %leistungen.
#
#   PARAMETERS:
#   			 $id - Die ID des zu löschenden Eintrages
#
#     See Also:
#     			 <funktion_hash_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub leistung_hash_loeschen {
    my ($nummer) = @_;
    delete $leistungen{$nummer};
    return;
}    # ----------  end of subroutine datum_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  leistungn_hash_aendern
#
#				 Ändert ein Key/Value-Paar mit der entsprechenden ID im Hash %leistungen.
#   PARAMETERS:
#   			 $nummer - Die Nummer des Datensatzes
#   			 $bezeic - Die Bezeichnung des Produktdaten-Datensatzes
#   			 $beschreibung - Die Beschreibung des Datensatzes
#   			 $id	 - Die eindeutige ID des Datensatzes
#                $kapitel      - Kapitel der Leistung
#
#      RETURNS:
#      			 -
#-------------------------------------------------------------------------------
sub leistung_hash_aendern {
    my ($parameter_ref) = @_;
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    $leistungen{$nummer} = [ $bezeichnung, $beschreibung ];
    einfuegen_id( $nummer, $kapitel, \%leistungen_kapitel );
    return;
}    # ----------  end of subroutine leistungen_hash_aendern ----------

#-------------------------------------------------------------------------------
#     Subroutine:  ziel_dialog_neu
#
#     Erstellt einen Dialog um einen neue Zielbestimmung der Datenbank
#     hinzuzufügen.Der Dialog wird auch zum Bearbeiten einer Zielbestimmung
#     benutzt und muss zu diesem Zweck eine ID mit übergeben bekommen.
#
#   PARAMETERS:
#				 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 $id - Die ID des Datensatzes
#
#     See Also:
#     			 <funktion_dialog_neu> ist funktionsgleich
#-------------------------------------------------------------------------------
sub ziel_dialog_neu {
    my ( $table, $id ) = @_;
    my ( $typ, $eingabe );

    my $toplevel_ziel =
      $frame_stack[0]->Toplevel( -title => 'neues Ziel anlegen' );

    $toplevel_ziel->geometry('300x380');

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 375;
    modal( \$toplevel_ziel, $BREITE, $HOEHE );
    my $frame_eingabe = $toplevel_ziel->Frame();

    # Combobox mit 3 Auswahlmöglichkeiten erzeugen
    my $combo_entry = $frame_eingabe->ComboEntry(
        -textvariable => \$typ,
        -itemlist =>
          [ 'Wunschkriterium', 'Musskriterium', 'Abgrenzungskriterium' ],
        -width     => 20,
        -label     => 'Typ',
        -labelPack => [ -side => 'left' ]
    );

    my $lab_eingabe = $frame_eingabe->Label( -text => 'Beschreibung' );
    my $text_eingabe =
      $frame_eingabe->Scrolled(    #Textbox für Beschreibung einfügen
        'Text',
        -scrollbars => 'oe'
      );
    $text_eingabe->configure( -width => '40', height => '18' );

    my $frame_buttons = $toplevel_ziel->Frame();
    my $button_ok     = $frame_buttons->Button(    # OK-Button
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            $eingabe = $text_eingabe->get( '1.0', 'end -1 chars' );
            ziel_tabelle_einfuegen( $table, $typ, $eingabe )
              ;                                    #Daten und Tabelle übergeben
            $toplevel_ziel->destroy();             # Fenster "zerstören"
        }
    );

    if ( defined $id ) {
        $typ = $zielbestimmung{$id}[0];
        $text_eingabe->Contents( $zielbestimmung{$id}[1] );
    }

    my $button_uebernehmen = $frame_buttons->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            $eingabe = $text_eingabe->get( '1.0', 'end -1 chars' );
            ziel_tabelle_aendern( $table, $typ, $eingabe, $id );
            $toplevel_ziel->destroy();    # Fenster "zerstören"
            set_aendern();
        }
    );

    my $button_neu = $frame_buttons->Button(
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -command  => \sub {
            $eingabe = $text_eingabe->get( '1.0', 'end -1 chars' );
            ziel_tabelle_einfuegen( $table, $typ, $eingabe );
            $text_eingabe->Contents($EMPTY)
              ;    #Nach dem einfügen in Tabelle Textfeld leeren
            set_aendern();
          }

    );

    my $button_abbrechen = $frame_buttons->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text    => 'Abbrechen',
        -command => \sub {
            $toplevel_ziel->destroy();
        }
    );

    $frame_eingabe->pack( -anchor => 'w' );
    $combo_entry->pack( -anchor => 'w' );
    $lab_eingabe->pack( -anchor => 'w' );
    $text_eingabe->pack( -anchor => 'w' );
    $frame_buttons->pack( -fill => 'x' );
    if ( defined $id ) {    #wenn bearbeitet wird OK und Neu-Buttons ausblenden
        $button_uebernehmen->pack( -side => 'left' );
        $toplevel_ziel->configure( -title => 'Ziel bearbeiten' );
    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine neuesZiel  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  ziel_tabelle_einfuegen
#
#				 Die Funktion fügt dem Hash %zielbestimmung einen neuen Datensatz hinzu
#				 bzw. bearbeitet ihn mittels der Funktion 'ziel_hash_aendern' und
#				 bearbeitet die Tabelle im Frame '1.Zielbestimmungen'.
#
#   PARAMETERS:
#   			 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 $typ - Art des Kriteriums
#				 $eingabe - Die Beschreibung der Zielbestimmung
#				 $id - Die ID wird nicht immer übergeben, da die XML-Datei
#				       nicht die IDs enthalten.
#
#     See Also:
#     			 <funktion_tabelle_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub ziel_tabelle_einfuegen {
    my ( $table, $typ, $eingabe, $id ) = @_;
    if ( defined $id ) {
        ziel_hash_aendern( $typ, $eingabe, $id );
    }
    else {
        $id = ziel_hash_einfuegen( $typ, $eingabe );
    }

    umbruch_entfernen( \$eingabe );

    my $lab_typ = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $typ,
        -width            => '20',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );

    my $lab_eingabe = ${$table}->Label(
        -background => 'snow1',
        -relief     => 'groove',
        -text       => $eingabe,
        -width      => '63',
        -padx       => '2',
        -anchor     => 'w',
        -activebackground =>
          'LightSkyBlue'    #wenn aktiviert bzw markiert auf Blau setzen
    );
    my $lab_id = ${$table}->Label(
        -foreground => 'snow1',    #gleiche farbe wie hintergrund
        -text       => $id
    );

    my $akt_zeile = ${$table}->totalRows;

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $lab_typ->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_eingabe->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $lab_typ );
    ${$table}->put( $akt_zeile, 1, $lab_eingabe );
    ${$table}->put( $akt_zeile, 2, $lab_id );        #id des Eintrages

    return;
}    # ----------  end of subroutine tabelle_einfuegen  ----------

#-------------------------------------------------------------------------------
#  Subroutine:  ziel_tabelle_aendern
#
#  Ändert einen bestimmten Datensatz in der Tabelle des Frames '1.Zielbestimmung'
#  und im Hash %zielbestimmung.
#
#   PARAMETERS:
#   $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#   $typ - Art des Kriteriums
#   $eingabe - Die Beschreibung der Zielbestimmung
#   $id - Die eindeutige ID des zu bearbeitenden Datensatzes
#
#     See Also:
#   <funktion_tabelle_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub ziel_tabelle_aendern {
    my ( $table, $typ, $eingabe, $id ) = @_;
    my $row;
    ziel_hash_aendern( $typ, $eingabe, $id );
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 2 )->cget( -text ) == $id ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$eingabe );
    ${$table}->get( $row, 0 )->configure( -text => $typ );
    ${$table}->get( $row, 1 )->configure( -text => $eingabe );
    return;
}    # ----------  end of subroutine ziel_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
#   NAME:  ziel_tabelle_sync
# Hier werden die Einträge in der von @folge bestimmten Reihenfolge aus
# <%zielbestimmung> geholt und wie in <ziel_tabelle_einfuegen> in die Tabelle
# eingetragen
#
#   Parameters:
#   			 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 @folge	- Enthält die Reihenfolge in welcher die Datensätze in die Tabelle eingepflegt werden sollen.
#     See Also:
#     			 <funktion_tabelle_sync> ist funktionsgleich
#
#-------------------------------------------------------------------------------
sub ziel_tabelle_sync {
    my ( $table, @folge ) = @_;
    my $typ;
    my $eingabe;
    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {

        $typ     = $zielbestimmung{ $folge[$i] }[0];
        $eingabe = $zielbestimmung{ $folge[$i] }[1];

        umbruch_entfernen( \$eingabe );

        my $lab_typ = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $typ,
            -width            => '20',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        my $lab_eingabe = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $eingabe,
            -width      => '63',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );
        my $lab_id = ${$table}->Label(
            -foreground => 'snow1',
            -text       => $folge[$i]
        );

        $lab_typ->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_eingabe->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_typ );
        ${$table}->put( $i, 1, $lab_eingabe );
        ${$table}->put( $i, 2, $lab_id );        #id des Eintrages

    }

    return;
}    # ----------  end of subroutine sync_table_hash  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  ziel_bearbeiten
#
#				 Diese Funktion holt die ID des markierten Datensatzes und
#				 ermöglicht mit Hilfe der Funktion <ziel_dialog_neu> die
#				 Bearbeitung des Datensatzes.
#
#   PARAMETERS:
#   			 $table	- Enthaelt die Referenz auf die zu bearbeitende Tabelle
#
#      RETURNS:
#      			 -
#
#     See Also:
#     			 <funktion_bearbeiten> ist funktionsgleich
#-------------------------------------------------------------------------------
sub ziel_bearbeiten {
    my ($table) = @_;
    my $id;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $id = ${$table}->get( $i, 2 )->cget( -text );
        }
    }

    if ( !defined $id ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();

        return;

    }

    ziel_dialog_neu( $table, $id );
    return;
}    # ----------  end of subroutine ziel_bearbeiten  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  ziel_loeschen
#
#     Die Funktion löscht die markierte Zeile aus der Tabelle und benutzt die
#     Funktion ziel_hash_loeschen um den entsprechenden Eintrag aus dem Hash
#     <%zielbestimmung> zu löschen.
#
#   PARAMETERS:
#   			 $table	- Enthaelt die Referenz auf die zu bearbeitende Tabelle
#   See also:
#     			 <funktion_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------

sub ziel_loeschen {
    my ($table) = @_;
    my $id;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $id = ${$table}->get( $i, 2 )->cget( -text );
        }
    }

    if ( !defined $id ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    ziel_hash_loeschen($id);

    # alte Reihenfolge der Tabelleneinträge über die
    # IDs speichern ohne die gelöschte Zeile
    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 2 )->cget( -text ) != $id ) { #gelöschte Zeile
            push @folge, ${$table}->get( $i, 2 )->cget( -text );
        }
    }
    ${$table}->clear();
    ziel_tabelle_sync( $table, @folge );

    return;
}    # ----------  end of subroutine ziel_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  ziel_hash_einfuegen
#
#      		     Eintrag in den Hash der Zielbestimmungesn einfügen
#
#   PARAMETERS:
#   			 $typ		- Art des Kriteriums
#   			 $eingabe	- Die Beschreibung der Zielbestimmung
#
#      RETURNS:
#      			 $id 		- ID des Eintrages
#
#     See Also:
#     			 <funktion_hash_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub ziel_hash_einfuegen {
    my ( $typ, $eingabe ) = @_;

    my $id;

    for my $i ( 0 .. keys %zielbestimmung ) {    #finde unbenutzte IDS heraus
        if ( !exists $zielbestimmung{$i} ) {
            $id = $i;
        }
    }

    $zielbestimmung{$id} = [ $typ, $eingabe ];

    return ($id);
}    # ----------  end of subroutine hash_rein_ziel  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  ziel_hash_loeschen
#
#   PARAMETERS:
#   			 $id	- Die eindeutige ID des zu löschenden Datensatzes
#     See Also:
#     			 <funktion_hash_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub ziel_hash_loeschen {
    my ($id) = @_;

    delete $zielbestimmung{$id};
    return;
}    # ----------  end of subroutine ziel_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  ziel_hash_aendern
#
#     			 Ändert das Key/Value-Paar im Hash %zielbestimmungen,
#     			 bei dem Key mit $id übereinstimmt.
#
#   PARAMETERS:
#   			 $typ		- Die Art des Kriteriums
#   			 $eingabe	- Die neue Beschreibung der Zielbestimmung
#   			 $id		- Die ID der Zielbestimmung
#
#      RETURNS:
#      			 -
#
#     See Also:
#     			 <funktion_hash_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub ziel_hash_aendern {
    my ( $typ, $eingabe, $id ) = @_;

    $zielbestimmung{$id} = [ $typ, $eingabe ];
    return;
}

#---------------------------------------------------------------------------
#  Subroutine: dat_bind_nummer_type
#  
#      Dem Binding werden alle Eingadbefelder übergeben und es überprüft nach jedem
#      Tastenschlag ob die eingegebene Nummer bereits vorhanden ist. Dabei wird
#      anhand des Modus indem sich der Dialog befindet entschieden ob ein Button
#      aktiviert oder deaktiviert wird. Durch die ismapped-Funktion von Tk findet
#      das Binding heraus ob der OK- (neu anlegen-Modus) oder der Übernehmen-Button
#      (Bearbeitungs-Modus) aktiv ist. Unabhängig vom Modus werden bei Existenz
#      der Nummer die Eingabefelder den dazugehörigen Daten gefüllt.
#
#      *Übernehmen Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - Nummernfeld weiss färben
#
#      *Neu anlegen-Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - deaktiviere Neu-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - aktiviere Neu-Button
#      - Nummernfeld weiss farben
#
# Parameters: 
#
#    $w                 - aufrufendes Widget 
#    $parameter_ref     - Folgende Parameter werden per Hashreferenz übergeben:
#    num                - Nummer
#    text_bezeic        - Text-Widget
#    text_beschr        - Text-Widget
#    kapitel            - Entry-Widget
#    button_ok          - Button-Widget
#    button_neu         - Button-Widget
#    button_uebernehmen - Button-Widget
#
#---------------------------------------------------------------------------
sub dat_bind_nummer_type {
    my ( $w, $parameter_ref ) = @_;
    my $num                = ${$parameter_ref}{'nummer'};
    my $text_bezeic        = ${$parameter_ref}{'text_bezeic'};
    my $text_beschr        = ${$parameter_ref}{'text_beschr'};
    my $kapitel            = ${$parameter_ref}{'kapitel'};
    my $button_ok          = ${$parameter_ref}{'button_ok'};
    my $button_neu         = ${$parameter_ref}{'button_neu'};
    my $button_uebernehmen = ${$parameter_ref}{'button_uebernehmen'};

    my $nummer = ${$num};

    if ($nummer) {
        if ( $daten{$nummer} ) {

            # wenn Eintrag im Hash dann auf jeden Fall Einträge laden
            ${$text_bezeic}->Contents( $daten{$nummer}[0] );
            ${$text_beschr}->Contents( $daten{$nummer}[1] );
            ${$kapitel} = suche_id( $nummer, \%daten_kapitel );
            ${$button_uebernehmen}->configure( -state => 'normal' );

            # Wenn OK-Button gemapped dann befindet man sich im
            # "Neu anlegen"-Modus und die Buttons und Eingaben
            # deaktivieren um zu verdeutlichen, dass die Zahl bereits
            # vergeben ist.
            if ( ${$button_ok}->ismapped() ) {
                $w->configure( -background => '#ff9696' );
                ${$button_ok}->configure( -state => 'disabled' );
                ${$button_neu}->configure( -state => 'disabled' );
            }
        }
        else {

            #Ansonsten alle Felder leeren und
            #Ok/Neu Buttons auswählbar machen
            ${$text_bezeic}->Contents($EMPTY);
            ${$text_beschr}->Contents($EMPTY);
            ${$kapitel} = $EMPTY;
            $w->configure( -background => 'snow1' );
            ${$button_ok}->configure( -state => 'normal' );
            ${$button_neu}->configure( -state => 'normal' );

            #Übernehmen-Button deaktivieren, da im Bearbeitungs-Modus
            #nur vorhandene Einträge bearbeite werden. Rein Theoretisch
            #könnte man auch mit dem Bearbeiten-Button Einträge anlegen,
            #jedoch würde as nur unnötig für Verwirrung sorgen.
            ${$button_uebernehmen}->configure( -state => 'disabled' );
        }
    }
    else {

        #Wenn keine Nummer angegeben, Alle Buttons deaktivieren.
        ${$button_ok}->configure( -state => 'disabled' );
        ${$button_neu}->configure( -state => 'disabled' );
        ${$button_uebernehmen}->configure( -state => 'disabled' );
    }

    return;
}    # ----------  end of subroutine test  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  datum_dialog_neu
#
#      			 Diese Funktion erstellt ein Dialog mit dem ein neuer
#      			 Produktdaten-Datensatzes erstellt oder geändert werden kann.
#
#   Parameters:
#   			 $table	- Enthält die Referenz auf die zubearbeitende Tabelle
#     			 $id - die eindeutige Id des Datensatzes
#
#     See Also:
#     			 <funktion_dialog_neu> ist funktionsgleich
#-------------------------------------------------------------------------------
sub datum_dialog_neu {
    my ( $table, $nummer ) = @_;
    my $toplevel_datum =
      $frame_stack[4]->Toplevel( -title => 'neues Datum anlegen' );

    Readonly my $BREITE => 300;
    Readonly my $HOEHE  => 435;
    modal( \$toplevel_datum, $BREITE, $HOEHE );

    my $eingabe =
      $toplevel_datum->Frame( -borderwidth => '2', -relief => 'groove' );
    my $frame_nummer = $eingabe->Frame();
    my $lab_nummer =
      $frame_nummer->Label( -text => 'Nummer', -width => '8', -anchor => 'w' );

    #    my $entry_nummer  = $frame_nummer->Entry( -width => '4' );
    my @choices      = keys %daten;
    my $entry_nummer = $frame_nummer->MatchEntry(
        -choices      => \@choices,
        -fixedwidth   => 1,
        -ignorecase   => 1,
        -maxheight    => 5,
        -textvariable => \$nummer,
    );
    my $frame_kapitel = $eingabe->Frame();
    my $label_kapitel = $frame_kapitel->Label(
        -text   => 'Kapitel',
        -width  => '8',
        -anchor => 'w'
    );

    my @klist = keys %daten_kapitel;    #alle Funktionskapitel holen
    my $kapitel;
    my $combo_kapitel = $frame_kapitel->ComboEntry(
        -textvariable => \$kapitel,
        -itemlist     => [@klist],
        -width        => 28,
        -borderwidth  => '0'
    );

    my $lab_bezeichnung = $eingabe->Label( -text => 'Bezeichnung' );
    my $text_bezeic = $eingabe->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_bezeic->configure( -width => 40, height => 9 );

    my $lab_beschr = $eingabe->Label( -text => 'Beschreibung' );
    my $text_beschr = $eingabe->Scrolled( 'Text', -scrollbars => 'oe' );
    $text_beschr->configure( -width => 40, height => 9 );

    my $frame_buttons = $toplevel_datum->Frame();

    if ( defined $nummer ) {

        #        $entry_nummer = $nummer;
        $text_bezeic->Contents( $daten{$nummer}[0] );
        $text_beschr->Contents( $daten{$nummer}[1] );
        $kapitel = suche_id( $nummer, \%daten_kapitel );
        $entry_nummer->focus();
    }

    my $button_ok = $frame_buttons->Button(
        -state    => 'disabled',
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            datum_tabelle_einfuegen(
                {
                    table        => $table,
                    nummer       => $nummer,
                    bezeichnung  => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    kapitel      => $kapitel,
                }
            );
            $toplevel_datum->destroy();
            set_aendern();
        }
    );

    my $button_uebernehmen = $frame_buttons->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            datum_tabelle_aendern(
                {
                    table        => $table,
                    nummer       => $nummer,
                    bezeichnung  => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    kapitel      => $kapitel,
                }
            );
            set_aendern();
            $toplevel_datum->destroy();
        }
    );
    my $button_neu = $frame_buttons->Button(
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -command  => \sub {
            datum_tabelle_einfuegen(
                {
                    table        => $table,
                    nummer       => $nummer,
                    bezeichnung  => $text_bezeic->get( '1.0', 'end -1 chars' ),
                    beschreibung => $text_beschr->get( '1.0', 'end -1 chars' ),
                    kapitel      => $kapitel,
                }
            );
            undef $nummer;
            $text_bezeic->Contents($EMPTY);
            $text_beschr->Contents($EMPTY);
            undef $kapitel;
            @klist = keys %daten_kapitel;
            $combo_kapitel->configure( -list => \@klist );
            @choices = keys %daten;
            $entry_nummer->configure( -choices => \@choices );
            $entry_nummer->focus();
            set_aendern();
        }
    );
    my $button_abbrechen = $frame_buttons->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text    => 'Abbrechen',
        -command => \sub {
            $toplevel_datum->destroy();
        }
    );

    $entry_nummer->bind(
        '<KeyRelease>',
        [
            \&dat_bind_nummer_type,
            {
                nummer             => \$nummer,
                text_bezeic        => \$text_bezeic,
                text_beschr        => \$text_beschr,
                kapitel            => \$kapitel,
                button_ok          => \$button_ok,
                button_neu         => \$button_neu,
                button_uebernehmen => \$button_uebernehmen,
            }
        ]
    );

    $entry_nummer->bind(
        '<FocusIn>',
        [
            \&bind_nummer_in, \$nummer, \$button_ok,
            \$button_neu,     \$button_uebernehmen
        ]
    );

    #---------------------------------------------------------------------------
    #  neues Datum packs
    #---------------------------------------------------------------------------

    $eingabe->pack( -pady => '2' );
    $frame_nummer->pack( -anchor => 'w' );
    $lab_nummer->pack( -side => 'left' );
    $entry_nummer->pack( -side => 'left' );
    $frame_kapitel->pack( -anchor => 'w', -fill => 'x' );
    $label_kapitel->pack( -side   => 'left' );
    $combo_kapitel->pack( -side   => 'left' );
    $lab_bezeichnung->pack( -anchor => 'w' );
    $text_bezeic->pack( -anchor => 'w' );
    $lab_beschr->pack( -anchor => 'w' );
    $text_beschr->pack( -anchor => 'w' );
    $frame_buttons->pack( -fill => 'x' );

    if ( defined $nummer ) {
        $button_uebernehmen->pack( -side => 'left' );
    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );
    return;
}

#-------------------------------------------------------------------------------
#     Subroutine:  datum_tabelle_einfuegen
#
#		Diese Funktion fügt eine neue Zeile in die Tabelle im Frame 5.Daten hinzu
#		und ändert entsprechend den Hash %daten.
#
#   PARAMETERS:
#   			 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#   			 $nummer - Die Nummer des Datensatzes
#   			 $bezeic - Die Bezeichnung des Datensatzes
#   			 $beschreibung - Die Beschreibung des Datensatzes
#                $kapitel      - Kapitel des Datensatzes
#   			 $id	- Die eindeutige ID des Datensatzes
#
#     See Also:
#     			 <funktion_tabelle_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub datum_tabelle_einfuegen {
    my ($parameter_ref) = @_;
    my $table           = ${$parameter_ref}{'table'};
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};
    if ( defined $nummer ) {
        datum_hash_aendern(
            {
                nummer       => $nummer,
                bezeichnung  => $bezeichnung,
                beschreibung => $beschreibung,
                kapitel      => $kapitel,
            }
        );
        ${ $projekt{datum_alt} }{$nummer} = $nummer;
    }
    else {
        datum_hash_einfuegen(
            {
                nummer       => $nummer,
                bezeichnung  => $bezeichnung,
                beschreibung => $beschreibung,
                kapitel      => $kapitel,
            }
        );
    }

    umbruch_entfernen( \$bezeichnung );
    umbruch_entfernen( \$beschreibung );

    my $lab_num = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $nummer,
        -width            => '6',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );

    my $lab_bez = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $bezeichnung,
        -width            => '35',
        -padx             => '2',
        -anchor           => 'w',
        -activebackground => 'LightSkyBlue'
    );

    my $lab_bes = ${$table}->Label(
        -background => 'snow1',
        -relief     => 'groove',
        -text       => $beschreibung,
        -width      => '41',
        -padx       => '2',
        -anchor     => 'w',
        -activebackground =>
          'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
    );

    my $akt_zeile = ${$table}->totalRows;

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bez->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bes->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $lab_num );
    ${$table}->put( $akt_zeile, 1, $lab_bez );
    ${$table}->put( $akt_zeile, 2, $lab_bes );

    #    ${$table}->put( $akt_zeile, 3, $lab_id );    #id des Eintrages

    return;
}    # ----------  end of subroutine datum_tabelle_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  datum_tabelle_aendern
#
#				 Diese Funktion ändert eine bestimmte Zeile in der Tabelle im Frame 5.Daten
#				 und ändert den Hash mit der Funktion 'datum_hash_aendern'.
#
#   PARAMETERS:
#   			 $table			- Die zu ändernde Tabelle
#   			 $nummer	    - Die neue Nummer des Datensatzes
#   			 $bezeichnung	- Die neue Bezeichnung
#   			 $beschreibung	- Die neue Beschreibung
#                $kapitel      - Kapitel des Datensatzes
#   			 $id		    - Die ID des Datensatzes
#
#     See Also:
#     			 <funktion_tabelle_aendern> Für detaillierte Erklärungen
#-------------------------------------------------------------------------------
sub datum_tabelle_aendern {
    my ($parameter_ref) = @_;
    my $table           = ${$parameter_ref}{'table'};
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    datum_hash_aendern(
        {
            nummer       => $nummer,
            bezeichnung  => $bezeichnung,
            beschreibung => $beschreibung,
            kapitel      => $kapitel,
        }
    );

    my $row;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) == $nummer ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$beschreibung );
    umbruch_entfernen( \$bezeichnung );

    ${$table}->get( $row, 0 )->configure( -text => $nummer );
    ${$table}->get( $row, 1 )->configure( -text => $bezeichnung );
    ${$table}->get( $row, 2 )->configure( -text => $beschreibung );

    return;
}    # ----------  end of subroutine datum_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
# Subroutine:  datum_tabelle_sync
#
# Hier werden die Einträge in der von @folge bestimmten Reihenfolge aus
# <%daten> geholt und wie in <datum_tabelle_einfuegen> in die Tabelle
# eingetragen
#
#   PARAMETERS:
#   			 $table	- Die zu synchronisierende Tabelle
#   			 @folge	- Enthält die Reihenfolge der Datensätze
#
#      RETURNS:
#      			 -
#
#     See Also:
#     			 <funktion_tabelle_sync> ist funktionsgleich
#-------------------------------------------------------------------------------
sub datum_tabelle_sync {
    my ( $table, @folge ) = @_;
    my ( $nummer, $bezeichnung, $beschreibung );
    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {

        $nummer       = $folge[$i];
        $bezeichnung  = $daten{ $folge[$i] }[0];
        $beschreibung = $daten{ $folge[$i] }[1];
        my $lab_num = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $nummer,
            -width            => '6',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        umbruch_entfernen( \$bezeichnung );
        my $lab_bezeichnung = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $bezeichnung,
            -width      => '35',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );

        umbruch_entfernen( \$beschreibung );
        my $lab_beschreibung = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $beschreibung,
            -width            => '41',
            -padx             => '2',
            -anchor           => 'w',
            -activebackground => 'LightSkyBlue'
        );

        $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_bezeichnung->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_beschreibung->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_num );
        ${$table}->put( $i, 1, $lab_bezeichnung );
        ${$table}->put( $i, 2, $lab_beschreibung );
    }

    return;
}    # ----------  end of subroutine datum_tabelle_sync  ----------

#-------------------------------------------------------------------------------
# Subroutine:  datum_bearbeiten
#
#	Eine bestimmte Zeile aus der Tabelle im Frame '5.Daten' bearbeiten
#
# Parameters:
#   $table	- Enthält die Referenz auf das entsprechende Table-Element
#
# See Also:
#   <funktion_bearbeiten> ist funktionsgleich
#-------------------------------------------------------------------------------
sub datum_bearbeiten {
    my ($table) = @_;
    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return;
    }
    datum_dialog_neu( $table, $nummer );
    return;
}    # ----------  end of subroutine datum_bearbeiten  ----------

#-------------------------------------------------------------------------------
# Subroutine:  datum_loeschen
#
#  Eine bestimmte Zeile aus der Tabelle in 5.Daten löschen
#
# PARAMETERS:
#  $table	- Enthält die Referenz auf das entsprechende Table-Element
#
#     SEE ALSO:
#     			 <funktion_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub datum_loeschen {
    my ($table) = @_;
    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }

    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    datum_hash_loeschen($nummer);

    # alte Reihenfolge der Tabelleneinträge über die
    # IDs speichern ohne die gelöschte Zeile
    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) ne $nummer )
        {    #gelöschte Zeile
            push @folge, ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    ${$table}->clear();

    datum_tabelle_sync( $table, @folge );

    return;
}    # ----------  end of subroutine datum_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  datum_hash_loeschen
#
#	 Löscht den Eintrag mit der entsprechenden ID aus dem Hash der Produktdaten
#
#   Parameters:
#	 $id	- Die ID des zu löschenden Eintrags
#
#     See Also:
#     			 <funktion_hash_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub datum_hash_loeschen {
    my ($nummer) = @_;

    delete $daten{$nummer};
    return;
}    # ----------  end of subroutine datum_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  datum_hash_aendern
#
#				 Ändert einen Eintrag im Hash der Produktdaten
#
#   Parameters:
#   			 $nummer	- Art des Kriterium
#   			 $bezeic	- Die Bezeichnung
#   			 $beschreibung	- Die Beschreibung
#                $kapitel      - Kapitel des Datensatzes
#   			 $id		- Die eindeutige Id des Eintrags
#
#      RETURNS:
#      			 -
#
#     See Also:
#     			 <funktion_hash_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub datum_hash_aendern {
    my ($parameter_ref) = @_;
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    $daten{$nummer} = [ $bezeichnung, $beschreibung ];
    einfuegen_id( $nummer, $kapitel, \%daten_kapitel );
    return;
}    # ----------  end of subroutine daten_hash_aendern ----------

#-------------------------------------------------------------------------------
#     Subroutine:  datum_hash_einfuegen
#
#      			 Erstellt einen Eintrag im Hash der Zielbestimmungen
#
#   Parameters:
#   			 $nummer	- Art des Kriterium
#   			 $bezeic	- Die Bezeichnung
#   			 $beschreibung	- Die Beschreibung
#                $kapitel      - Kapitel des Datensatzes
#
#      Returns:
#      			 $id		- ID des Eintrages
#
#     See Also:
#				 <funktion_hash_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub datum_hash_einfuegen {
    my ($parameter_ref) = @_;
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $kapitel         = ${$parameter_ref}{'kapitel'};

    einfuegen_id( $nummer, $kapitel, \%daten_kapitel );
    $daten{$nummer} = [ $bezeichnung, $beschreibung ];

    return ();
}    # ----------  end of subroutine datum_rein_ziel  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  teilprodukt_dialog_neu
#
#                Erstellt einen Dialog um dem Pflichtenheft eine neues Teilrpodukt
#                hinzuzufügen. Der Dialog wird auch zum Bearbeiten einer GUI
#                benutzt und muss zu diesem Zweck eine ID mit übergeben bekommen.
#
#                Der Unterschied zu <funktion_dialog_neu> ist der, dass wir hier
#                noch den Unterdialog <teilprodukt_funktion_dialog> aufrufen müssen,
#                um unserem Teilprodukt Funktionen zuzuweisen.
#                Diese werden in dem Variable %teilfunktionen abgespeichert, die
#                innerhalb von <teilprodukt_hash_einfuegen> dann <%teilprodukte>
#                zugewiesen wird.
#
#
#   Parameters:
#				 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 $id - Die ID des Datensatzes
#
#-------------------------------------------------------------------------------
sub teilprodukt_dialog_neu {
    my ( $table, $id ) = @_;
    my %teilfunktionen;
    my $frame_tp = $frame_stack[11]->Toplevel( -title => 'Neues Teilprodukt' );

    Readonly my $BREITE => 350;
    Readonly my $HOEHE  => 400;
    modal( \$frame_tp, $BREITE, $HOEHE );

    my $label_bezeichnung = $frame_tp->Label( -text => 'Bezeichnung' );
    my $text_bezeichnung = $frame_tp->Scrolled(
        'Text',
        -height     => '7',
        -scrollbars => 'oe',
    );

    #---------------------------------------------------------------------------
    #  Tabelle von Teilproduktdialog
    #---------------------------------------------------------------------------
    my $table_funktionen = $frame_tp->Table(
        -columns    => 3,
        -rows       => 7,
        -scrollbars => 'oe',
        -relief     => 'raised',
    );

    my $table_funktionen_kopf = $frame_tp->Table(
        -columns    => 2,
        -relief     => 'raised',
        -scrollbars => '0',
    );

    my $head1_label = $table_funktionen_kopf->Label(
        -text   => 'Bemerkung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 22
    );

    my $head2_label = $table_funktionen_kopf->Label(
        -text   => 'Funktion',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 22
    );

    $table_funktionen_kopf->put( 0, 1, $head1_label );
    $table_funktionen_kopf->put( 0, 2, $head2_label );

    my $frame_buttons = $frame_tp->Frame();
    my $button_hinzuf = $frame_buttons->Button(
        -text     => 'Funktion hinz.',
        -compound => 'left',
        -image    => $pic_add,
        -command  => \sub {
            if ( not %funktionen ) {
                $frame_tp->Dialog(
                    -title          => 'Achtung',
                    -text           => 'Es sind keine Funktionen vorhanden.',
                    -default_button => 'OK',
                    -buttons        => ['OK'],
                    -bitmap         => 'warning'
                )->Show();
                return;
            }
            else {
                teilprodukt_funktion_dialog( $frame_tp, \%teilfunktionen,
                    \$table_funktionen );
            }
        }
    );
    my $button_bearbeiten = $frame_buttons->Button(
        -text     => 'Bearbeiten',
        -compound => 'left',
        -image    => $pic_edit,
        -command  => \sub {
            teilfunktion_bearbeiten( $frame_tp, \%teilfunktionen,
                \$table_funktionen );
        }
    );
    my $button_loeschen = $frame_buttons->Button(
        -text    => 'Löschen',
        -command => \sub {
            teilfunktion_loeschen( $frame_tp, \%teilfunktionen,
                \$table_funktionen );
        }
    );
    if ( defined $id ) {
        $frame_tp->configure( -title => 'Teilprodukt bearbeiten' );
        $text_bezeichnung->Contents( $teilprodukte{$id}[0] );
        teilfunktion_tabelle_sync(
            \$table_funktionen,
            \%{ $teilprodukte{$id}[1] },
            keys %{ $teilprodukte{$id}[1] }
        );
        %teilfunktionen = %{ $teilprodukte{$id}[1] };
    }
    my $frame_buttons2 = $frame_tp->Frame();
    my $button_ok      = $frame_buttons2->Button(
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            teilprodukt_tabelle_einfuegen( $table,
                $text_bezeichnung->get( '1.0', 'end -1 chars' ),
                \%teilfunktionen, );
            $frame_tp->destroy();
            set_aendern();
        }
    );
    my $button_uebernehmen = $frame_buttons2->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            teilprodukt_tabelle_aendern( $table,
                $text_bezeichnung->get( '1.0', 'end -1 chars' ),
                \%teilfunktionen, $id, );
            $frame_tp->destroy();
            set_aendern();
        }
    );
    my $button_abbrechen = $frame_buttons2->Button(
        -compound => 'left',
        -image    => $pic_exit,
        -text    => 'Abbrechen',
        -command => \sub {
            $frame_tp->destroy();
        }
    );

    #---------------------------------------------------------------------------
    #  packs
    #---------------------------------------------------------------------------

    $label_bezeichnung->pack( -anchor => 'w' );
    $text_bezeichnung->pack( -anchor => 'w' );
    $frame_buttons->pack( -fill => 'x' );
    $button_hinzuf->pack( -side => 'left' );
    $button_bearbeiten->pack( -side => 'left' );
    $button_loeschen->pack( -side => 'right' );
    $table_funktionen_kopf->pack( -anchor => 'w' );
    $table_funktionen->pack( -fill => 'x' );
    $frame_buttons2->pack( -fill => 'x', -side => 'bottom' );

    if ( defined $id ) {
        $button_uebernehmen->pack( -side => 'left' );
    }
    else {
        $button_ok->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );

    return;
}    # ----------  end of subroutine teilprodukt_dialog_neu  ----------

#-------------------------------------------------------------------------------
# Subroutine:  teilprodukt_bearbeiten
#
#	Eine bestimmte Zeile aus der Tabelle im Frame '12. Teilprodukte' bearbeiten
#
# Parameters:
#   $table	- Enthält die Referenz auf das entsprechende Table-Element
#
# See Also:
#   <funktion_bearbeiten> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilprodukt_bearbeiten {
    my ($table) = @_;
    my $id;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $id = ${$table}->get( $i, 1 )->cget( -text );
        }
    }
    if ( !defined $id ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return;
    }
    teilprodukt_dialog_neu( $table, $id );
    return;
}    # ----------  end of subroutine teilprodukt_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
# Subroutine:  datum_loeschen
#
#  Eine bestimmte Zeile aus der Tabelle löschen
#
# PARAMETERS:
#  $table	- Enthält die Referenz auf das entsprechende Table-Element
#
#     SEE ALSO:
#     			 <funktion_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilprodukt_loeschen {
    my ($table) = @_;
    my $id;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $id = ${$table}->get( $i, 1 )->cget( -text );
        }
    }

    if ( !defined $id ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    teilprodukt_hash_loeschen($id);

    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 1 )->cget( -text ) != $id ) { #gelöschte Zeile
            push @folge, ${$table}->get( $i, 1 )->cget( -text );
        }
    }
    ${$table}->clear();

    teilprodukt_tabelle_sync( $table, @folge );
    return;
}    # ----------  end of subroutine teilprodukt_loeschen  ----------

#-------------------------------------------------------------------------------
# Subroutine:  teilprodukt_tabelle_sync
#
# Hier werden die Einträge in der von @folge bestimmten Reihenfolge aus
# <%teilprodukte> geholt und wie in <teilprodukt_tabelle_einfuegen> in die Tabelle
# eingetragen
#
#   PARAMETERS:
#   			 $table	- Die zu synchronisierende Tabelle
#   			 @folge	- Enthält die Reihenfolge der Datensätze
#
#     See Also:
#     			 <funktion_tabelle_sync> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilprodukt_tabelle_sync {
    my ( $table, @folge ) = @_;
    my ( $id, $bezeichnung );

    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {
        $bezeichnung = $teilprodukte{ $folge[$i] }[0];
        $id          = $folge[$i];

        umbruch_entfernen( \$bezeichnung );
        my $lab_bezeichnung = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $bezeichnung,
            -width      => '84',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );
        my $lab_id = ${$table}->Label(
            -foreground => 'snow1',    #gleiche farbe wie hintergrund
            -text       => $id,
            -width      => '0'
        );

        $lab_bezeichnung->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_bezeichnung );
        ${$table}->put( $i, 1, $lab_id );
    }
    return;
}    # ----------  end of subroutine teilprodukt_tabelle_sync  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  teilprodukt_tabelle_einfuegen
#
#		Diese Funktion fügt eine neue Zeile in die übergebene Tabelle hinzu
#		und ändert entsprechend den Hash <%teilprodukte>
#
#   PARAMETERS:
#   			 $table	         - Enthält die Referenz auf die zu bearbeitende Tabelle
#   			 $bezeic         - Die Bezeichnung des Datensatzes
#   			 $teilfunktionen - Referenz auf %teilfunktion
#   			 $id	         - ID des Datensatzes
#
#     See Also:
#     			 <funktion_tabelle_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilprodukt_tabelle_einfuegen {
    my ( $table, $bezeic, $teilfunktionen, $id ) = @_;

    if ( defined $id ) {
        teilprodukt_hash_aendern( $bezeic, $teilfunktionen, $id );
    }
    else {
        $id = teilprodukt_hash_einfuegen( $bezeic, $teilfunktionen );
    }
    umbruch_entfernen( \$bezeic );

    my $lab_bez = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $bezeic,
        -width            => '84',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );

    my $lab_id = ${$table}->Label(
        -foreground => 'snow1',    #gleiche farbe wie hintergrund
        -text       => $id,
        -width      => '0'
    );
    my $akt_zeile = ${$table}->totalRows;

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $lab_bez->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $lab_bez );
    ${$table}->put( $akt_zeile, 1, $lab_id );    #id des Eintrages

    return;
}    # ----------  end of subroutine teilprodukt_listbox_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  datum_tabelle_aendern
#
#            Diese Funktion ändert eine bestimmte Zeile in der übergebenen Tabelle
#            und ändert den Hash mit der Funktion <teilprodukt_hash_aendern>.
#
#   PARAMETERS:
#            $table			- Die zu ändernde Tabelle
#            $teilfunktionen - Referenz auf %teilfunktion
#            $bezeic        - Die neue Bezeichnung
#            $id		    - Die ID des Datensatzes
#
#     See Also:
#     			 <funktion_tabelle_aendern> Für detaillierte Erklärungen
#-------------------------------------------------------------------------------
sub teilprodukt_tabelle_aendern {
    my ( $table, $bezeic, $teilfunktionen, $id ) = @_;
    my $row;
    teilprodukt_hash_aendern( $bezeic, $teilfunktionen, $id );
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 1 )->cget( -text ) == $id ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$bezeic );
    ${$table}->get( $row, 0 )->configure( -text => $bezeic );
    return;
}    # ----------  end of subroutine teilprodukt_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  teilprodukte_hash_aendern
#
#				 Ändert einen Eintrag im Hash %teiprodukte
#
#   Parameters:
#   			 $bezeic	- Die Bezeichnung
#   			 $teilfunktion - Referenz auf %teilfunktion
#   			 $id		- Die eindeutige Id des Eintrags
#
#     See Also:
#     			 <funktion_hash_aendern> ist funktionsgleich

#-------------------------------------------------------------------------------
sub teilprodukt_hash_aendern {
    my ( $bezeic, $teilfunktion, $id ) = @_;
    $teilprodukte{$id} = [ $bezeic, $teilfunktion ];
    return;
}    # ----------  end of subroutine teilprodukt_hash_aendern  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  teilprodukt_hash_einfuegen
#
#      			 Erstellt einen Eintrag im Hash der Zielbestimmungen
#
#   Parameters:
#   			 $bezeic	- Die Bezeichnung
#   			 $teilfunktion - Referenz auf %teilfunktion
#
#      Returns:
#      			 $id		- ID des Eintrages
#
#     See Also:
#				 <funktion_hash_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilprodukt_hash_einfuegen {
    my ( $bezeic, $teilfunktionen ) = @_;
    my $id;

    for my $i ( 0 .. keys %teilprodukte ) {    #finde unbenutzte IDS heraus
        if ( !exists $teilprodukte{$i} ) {
            $id = $i;
        }
    }
    $teilprodukte{$id} = [ $bezeic, $teilfunktionen ];
    return ($id);

}    # ----------  end of subroutine teilprodukt_hash_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine: teilprodukt_hash_loeschen
#
#	 Löscht den Eintrag mit der entsprechenden ID aus dem Hash %teilprodukte
#
#   Parameters:
#	 $id	- Die ID des zu löschenden Eintrags
#
#     See Also:
#     			 <funktion_hash_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilprodukt_hash_loeschen {
    my ($nummer) = @_;

    #    delete @{$teilprodukt{$id}}[1]{$nummer};
    delete $teilprodukte{$nummer};
    return;
}    # ----------  end of subroutine teilprodukt_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  teilfunktion_bearbeiten
#
#   Findet markierte Zeile heraus und ruft <teilprodukt_funktion_dialog> mit der zu
#   editierenden ID auf.
#
#   PARAMETERS:
#
#    $frame_tp - aufrufendes Toplevel-Widget
#    $teilfunktionen - Referenz auf Hash mit den Funktionen des Teilproduktes
#    $table_funktionen - Referenz auf Tabelle mit Funktionen
#
#   See Also:
#
#    <funktion_bearbeiten>   hat nahezu gleiche Funktionalität
#
#
#-------------------------------------------------------------------------------
sub teilfunktion_bearbeiten {

    my ( $frame_tp, $teilfunktionen, $table_funktionen ) = @_;
    my $nummer;
    for my $i ( 0 .. ${$table_funktionen}->totalRows() - 1 ) {
        if ( ${$table_funktionen}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table_funktionen}->get( $i, 0 )->cget( -text );
        }
    }
    if ( !defined $nummer ) {
        $frame_tp->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();

        return;
    }

    teilprodukt_funktion_dialog( $frame_tp, $teilfunktionen, $table_funktionen,
        $nummer );
    return;

}    # ----------  end of subroutine gui_rolle_bearbeiten  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  teilprodukt_funktion_dialog
#
#    Wird aus <teilprodukt_dialog_neu> aufgerufen und fügt dem Teilprodukt
#    Funktionen hinzu. Dieser Dialog hat ebenfalls wie <gui_dialog_neu>
#    2 Modis die über die $id angesteuert werden, jedoch ist seine
#    Funktionsweise eine andere.
#
#  - *normaler Modus*
#  Über <teilfunktionen_aktualisieren> wird eine Liste aller Funktionen die
#  es im Hash %funktionen gibt angelegt und in einer Tabelle übersichtlich
#  präsentiert. Dargestellt durch Ihre Funktionsnummer und Beschreibung.
#  Der Benutzer kann sich durch Klick in gewunschte Zeile der Tabelle
#  die Funktion aussuchen die er seinem Teilprodukt hinzufügen will und eine
#  Anmerkung dazu verfassen.
#
#  $button_ok - holt aus der Tabelle über die Funktion <ausgewaehlte_funktion> die
#  Funktions- nummer, -beschreibung, und -id. Übergibt diese dann an
#  <teilfunktion_tabelle_einfuegen> zum einfügen in die Tabelle des aufrufenden
#  Widgets $table. Dialog wird anschließend geschlossen.
#
#  $button_neu - ist wie OK, nur Dialog schliesst nicht, sondert es leert sich
#  das Eingabetextfeld.
#
#  ACHTUNG: Wird eine bereits hinzugefügte Funktion ausgewählt, wird der alte
#  Eintrag überschrieben. Da die Funktionen über ihre Funktionsnummern identifiziert
#  werden, ist keine mehrfaches Einfügen von Funktionen in ein Teilprodukt möglich.
#
# - *bearbeitender Modus*
#  Wird die Funktion mit den Parameter $id aufgerufen, erscheint die GUI im
#  bearbeitenden Modus. Das heisst, das Eingabetextfeld wird gefüllt mit dem
#  zu bearbeitenden Eintrag. Es wird auch die Funktion markiert die gerade
#  bearbeitet wird, dies geschieht durch <teilfunktion_tabelle_markieren>. Die
#  ausgewählte ID wird in $old_id gespeichert. Dies wird gemacht um in
#  <teilfunktion_tabelle_aendern> zu prüfen ob sich die ID geändert hat.
#
#  Unten links im Dialog werden die Buttons
#  vom normalen Modus ausgeblendet und stattdesen der Übernehmen Button eingeblendet.
#
#  $button_uebernehmen - Ähnlich wie $button_ok nur es wird
#  <teilfunktion_tabelle_aendern> aufgerufen.
#
#
#   PARAMETERS:
#
#    $frame_tp - aufrufendes Toplevel-Widget
#    $teilfunktionen - Referenz auf Hash mit den Funktionen des Teilproduktes
#    $table - Referenz auf Tabelle mit bereits eingefügten Funktionen
#    $id - ID der hinzugefügten Teilfunktion
#
#-------------------------------------------------------------------------------
sub teilprodukt_funktion_dialog {
    my ( $frame_tp, $teilfunktionen, $table, $nummer ) = @_;

    my $toplevel_tfunktion =
      $frame_tp->Toplevel( -title => 'Funktion hinzufügen' );

    #Fenster mittig positionieren
    $toplevel_tfunktion->geometry('400x400');
    $toplevel_tfunktion->geometry( q{+}
          . int( $screen_width / 2 - 400 / 2 ) . q{+}
          . int( $screen_height / 2 - 400 / 2 ) );
    $toplevel_tfunktion->raise($frame_tp);
    $toplevel_tfunktion->grab();    #macht Fenster modal
    $toplevel_tfunktion->resizable( 0, 0 );

    my $label_textbox = $toplevel_tfunktion->Label( -text => 'Bemerkungen' );
    my $text_bemerkung = $toplevel_tfunktion->Scrolled(
        'Text',
        -scrollbars => 'oe',
        -height     => '6',
    );

    #Tabellenüberschriften
    my $table_tfunktion_kopf = $toplevel_tfunktion->Table(
        -columns    => 2,
        -relief     => 'raised',
        -scrollbars => '0',
    );

    my $lab_tfunktion_kopf1 = $table_tfunktion_kopf->Label(
        -text   => 'Nummer',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 10
    );

    my $lab_tfunktion_kopf2 = $table_tfunktion_kopf->Label(
        -text   => 'Beschreibung',
        -padx   => 2,
        -anchor => 'w',
        -relief => 'groove',
        -width  => 40
    );

    $table_tfunktion_kopf->put( 0, 1, $lab_tfunktion_kopf1 );
    $table_tfunktion_kopf->put( 0, 2, $lab_tfunktion_kopf2 );

    #Erstellt die Tabelle die die Daten enthält
    my $table_tfunktion = $toplevel_tfunktion->Table(
        -columns    => 3,
        -rows       => 6,
        -scrollbars => 'oe',
        -relief     => 'raised'
    );

    teilfunktionen_aktualisieren( \$table_tfunktion );
    my $old_nummer;
    if ( defined $nummer ) {
        $toplevel_tfunktion->configure( -title => 'Eintrag bearbeiten' );
        $text_bemerkung->Contents( ${$teilfunktionen}{$nummer}[1] );
        teilfunktion_tabelle_markieren( \$table_tfunktion, $nummer );
        $old_nummer = $nummer;

        #        $toplevel_tfunktion->geometry('400x200');
    }
    my $button_frame = $toplevel_tfunktion->Frame();

    my $button_ok = $button_frame->Button(
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            my ( $funk_nummer, $funk_beschreibung ) =
              ausgewaehlte_funktion($table_tfunktion);
            teilfunktion_tabelle_einfuegen(
                {
                    table              => $table,
                    toplevel_tfunktion => $toplevel_tfunktion,
                    funk_nummer        => $funk_nummer,
                    funk_beschreibung  => $funk_beschreibung,
                    teilfunktionen     => $teilfunktionen,
                    bemerkung => $text_bemerkung->get( '1.0', 'end -1 chars' ),
                }
            );
            $toplevel_tfunktion->destroy();
        }
    );

    my $button_uebernehmen = $button_frame->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            my ( $funk_nummer, $funk_beschreibung ) =
              ausgewaehlte_funktion($table_tfunktion);
            teilfunktion_tabelle_aendern(
                {
                    toplevel_tfunktion => $toplevel_tfunktion,
                    old_nummer         => $old_nummer,
                    table              => $table,
                    funk_nummer        => $funk_nummer,
                    funk_beschreibung  => $funk_beschreibung,
                    teilfunktionen     => $teilfunktionen,
                    bemerkung => $text_bemerkung->get( '1.0', 'end -1 chars' ),
                }
            );
            $toplevel_tfunktion->destroy();
        }
    );

    my $button_neu = $button_frame->Button(
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -command  => \sub {
            my ( $funk_nummer, $funk_beschreibung ) =
              ausgewaehlte_funktion($table_tfunktion);
            teilfunktion_tabelle_einfuegen(
                {
                    table              => $table,
                    toplevel_tfunktion => $toplevel_tfunktion,
                    funk_nummer        => $funk_nummer,
                    funk_beschreibung  => $funk_beschreibung,
                    teilfunktionen     => $teilfunktionen,
                    bemerkung => $text_bemerkung->get( '1.0', 'end -1 chars' ),
                }
            );
            $text_bemerkung->Contents($EMPTY);
        }
    );
    my $button_abbrechen = $button_frame->Button(
        -text     => 'Abbrechen',
        -compound => 'left',
        -image    => $pic_exit,
        -command  => \sub {
            $toplevel_tfunktion->destroy();
        }
    );

    #---------------------------------------------------------------------------
    #  packs
    #---------------------------------------------------------------------------
    $label_textbox->pack( -anchor => 'w' );
    $text_bemerkung->pack();
    $table_tfunktion_kopf->pack( -fill => 'x' );
    $table_tfunktion->pack( -fill => 'x' );
    $button_frame->pack( -anchor => 's', -fill => 'x', -side => 'bottom' );
    if ( defined $nummer ) {
        $button_uebernehmen->pack( -side => 'left' );
    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );

    return;
}    # ----------  end of subroutine teilprodukt_funktion_dialog  ----------

#-------------------------------------------------------------------------------
# Subroutine:  teilfunktion_tabelle_aendern
# Dient zum ändern von Einträgen in der Tabelle der Teilprodukte
# und dem Hash der %teilfunktionen.
#
#
#
#
# PARAMETERS:
# $toplevel_tfunktion   - aufrufendes toplevel_widget
# $old_id               - alte ID der ausgewählten Funktion
# $table                - Referenz auf Tabelle mit Funktionen
# $funk_id              - neue ID der ausgewählten Funktion
# $funk_nummer          - Funktionsnummer
# $funk_beschreibung    - Funktionsbescheibung
# $teilfunktionen       - Referenz auf Hash mit Teilfunktion
# $bemerkung            - Bemerkung
#-------------------------------------------------------------------------------
sub teilfunktion_tabelle_aendern {
    my ($parameter_ref)    = @_;
    my $toplevel_tfunktion = ${$parameter_ref}{'toplevel_tfunktion'};
    my $old_nummer         = ${$parameter_ref}{'old_nummer'};
    my $table              = ${$parameter_ref}{'table'};
    my $funk_nummer        = ${$parameter_ref}{'funk_nummer'};
    my $funk_beschreibung  = ${$parameter_ref}{'funk_beschreibung'};
    my $teilfunktionen     = ${$parameter_ref}{'teilfunktionen'};
    my $bemerkung          = ${$parameter_ref}{'bemerkung'};

   #---------------------------------------------------------------------------
   #  Funktion ist bereits im Teilprodukt wenn:
   #  die neu ausgewählte Funktions-ID sich bereits im Hash befindet
   #  und sich nicht von der alten unterscheidet. Da es hier auch möglich
   #  ist, während der Bearbeitung eine andere Funktion auszuwählen ist dieser
   #  Schritt notwendig.
   #---------------------------------------------------------------------------
    if ( ${$teilfunktionen}{$funk_nummer} and $funk_nummer ne $old_nummer ) {
        $toplevel_tfunktion->Dialog(
            -title          => 'Hinweis',
            -text           => 'Funktion ist bereits in Teilprodukt.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();

        return;
    }

   #---------------------------------------------------------------------------
   #  Wenn man sich eine andere Funktion ausgesucht hat, als die zu bearbeitende
   #  dann lösche die vormals zur Bearbeitung ausgesuchte Funktion und füge
   #  die aktuelle an deren Stelle hinzu.
   #
   #  Ansonsten ändere nur den Kommentarblock.
   #---------------------------------------------------------------------------
    if ( $funk_nummer ne $old_nummer ) {
        teilfunktion_tabelle_einfuegen(
            {
                table              => $table,
                toplevel_tfunktion => $toplevel_tfunktion,
                funk_nummer        => $funk_nummer,
                funk_beschreibung  => $funk_beschreibung,
                teilfunktionen     => $teilfunktionen,
                bemerkung          => $bemerkung,
                old_nummer         => $old_nummer,
            }
        );
        teilfunktion_loeschen( $toplevel_tfunktion, $teilfunktionen, $table,
            $old_nummer );
    }
    else {
        teilfunktion_hash_aendern(
            {
                teilfunktionen    => $teilfunktionen,
                funk_nummer       => $funk_nummer,
                funk_beschreibung => $funk_beschreibung,
                bemerkung         => $bemerkung,
            }
        );
    }
    my $row;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) eq $funk_nummer ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$bemerkung );
    ${$table}->get( $row, 0 )->configure( -text => $funk_nummer );
    ${$table}->get( $row, 1 )->configure( -text => $funk_beschreibung );
    ${$table}->get( $row, 2 )->configure( -text => $bemerkung );
    return;
}    # ----------  end of subroutine teilfunktion_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  teilfunktion_hash_aendern
#
#      Ändert einen Eintrag im Hash der Funktionen der Teilprodukte
#
#   Parameters:
#      $funk_id            - ID der Funktion
#      $funk_nummer        - Nummer der Funktion
#      $funk_beschreibung  - Beschreibung der Funktion
#      $teilfunktionen     - Hash der bereits zugewiesenen Funktion
#      $bemerkung          - Bemerkung zur zugewiesenen ID
#
#     See Also:
#     			 <teilfunktionen_hash_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilfunktion_hash_aendern {
    my ($parameter_ref)   = @_;
    my $funk_nummer       = ${$parameter_ref}{'funk_nummer'};
    my $funk_beschreibung = ${$parameter_ref}{'funk_beschreibung'};
    my $teilfunktionen    = ${$parameter_ref}{'teilfunktionen'};
    my $bemerkung         = ${$parameter_ref}{'bemerkung'};

    #    @{$teilprodukt{$id}}[1]{$funk_nummer}=$bemerkung;

    ${$teilfunktionen}{$funk_nummer} = [ $funk_beschreibung, $bemerkung ];
    return;
}    # ----------  end of subroutine teilfunktion_hash_aendern  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  ausgewaehlte_funktion
#
#      Liest den Inhalt der ausgewählten Tabellenzeile aus. Der Inhalt stellt
#      die benötigten Daten der ausgewählten Funktion da.
#
#   Parameters:
#
#      $table_tfunktion - Tabelle mit allen Funktionen
#
#   Returns:
#      $funk_nummer       - Nummer der ausgewählten Funktion
#      $funk_beschreibung - Beschreibung der ausgewählten Funktion
#      $funk_id           - Id der ausgewählten Funktion
#
#-------------------------------------------------------------------------------
sub ausgewaehlte_funktion {
    my ($table_tfunktion) = @_;
    my $funk_nummer;
    my $funk_beschreibung;

    for my $i ( 0 .. $table_tfunktion->totalRows() - 1 ) {
        if ( $table_tfunktion->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $funk_nummer       = $table_tfunktion->get( $i, 0 )->cget( -text );
            $funk_beschreibung = $table_tfunktion->get( $i, 1 )->cget( -text );
        }
    }
    return ( $funk_nummer, $funk_beschreibung );
}

#-------------------------------------------------------------------------------
#     Subroutine:  teilfunktion_hash_einfuegen
#
#      			Fügt die funktionen dem Hash %teilfunktionen hinzu. Da hier
#      			die IDs von den Funktionen benutzt werden, gibt es kein
#      			Rückgabewert.
#
#   Parameters:
#
#   	$funk_id           - ID der Funktion
#   	$funk_nummer       - Nummer der Funktion
#   	$funk_beschreibung - Beschreibung der Funktion
#       $bemerkung         - Bemerkung zur Funktion
#       $teilfunktionen    - Hash in dem die übergebenen Werte eingefügt werden
#
#-------------------------------------------------------------------------------
sub teilfunktion_hash_einfuegen {
    my ($parameter_ref)   = @_;
    my $funk_nummer       = ${$parameter_ref}{'funk_nummer'};
    my $funk_beschreibung = ${$parameter_ref}{'funk_beschreibung'};
    my $teilfunktionen    = ${$parameter_ref}{'teilfunktionen'};
    my $bemerkung         = ${$parameter_ref}{'bemerkung'};

    ${$teilfunktionen}{$funk_nummer} = [ $funk_beschreibung, $bemerkung ];

    return ();
}    # ----------  end of subroutine teilfunktion_hash_einfuegen  ----------

#---------------------------------------------------------------------------
# Subroutine:  teilfunktion_tabelle_einfuegen
#
#     Dient zum neu anlegen von Einträgen in der übergebenen Tabelle und Hash.
#
#
#
# PARAMETERS:
#     $toplevel_tfunktion - Toplevel-Widget der aufrufenden Funktion
#     $table              - Zu füllende Tabelle
#     $funk_id            - Id der Funktion
#     $funk_nummer        - Nummer der Funktion
#     $funk_beschreibung  - Beschreibung der Funktion
#     $teilfunktionen     - Zu füllender Hash
#     $bemerkung          - Bemerkung zur Funktion
#
#  See Also:
#     <funktion_tabelle_einfuegen> ist funktionsgleich
#
#---------------------------------------------------------------------------
sub teilfunktion_tabelle_einfuegen {
    my ($parameter_ref)    = @_;
    my $toplevel_tfunktion = ${$parameter_ref}{'toplevel_tfunktion'};
    my $table              = ${$parameter_ref}{'table'};
    my $funk_nummer        = ${$parameter_ref}{'funk_nummer'};
    my $funk_beschreibung  = ${$parameter_ref}{'funk_beschreibung'};
    my $teilfunktionen     = ${$parameter_ref}{'teilfunktionen'};
    my $bemerkung          = ${$parameter_ref}{'bemerkung'};
    my $old_nummer         = ${$parameter_ref}{'old_nummer'};

    if ( ${$teilfunktionen}{$funk_nummer} and not defined $old_nummer ) {
        $toplevel_tfunktion->Dialog(
            -title          => 'Hinweis',
            -text           => 'Funktion ist bereits in Teilprodukt.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return;
    }

    teilfunktion_hash_einfuegen(
        {
            funk_nummer       => $funk_nummer,
            funk_beschreibung => $funk_beschreibung,
            teilfunktionen    => $teilfunktionen,
            bemerkung         => $bemerkung,
        }
    );
    umbruch_entfernen( \$funk_beschreibung );
    umbruch_entfernen( \$bemerkung );

    my $lab_funk_num = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $funk_nummer,
        -width            => '6',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_bem = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $bemerkung,
        -width            => '18',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_bes = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $funk_beschreibung,
        -width            => '18',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );

    my $akt_zeile = ${$table}->totalRows();

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $lab_bem->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bes->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_funk_num->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $lab_funk_num );
    ${$table}->put( $akt_zeile, 1, $lab_bes );
    ${$table}->put( $akt_zeile, 2, $lab_bem );

    return;
}    # ----------  end of subroutine teilprodukt_funktion_einfuegen  ----------

#-------------------------------------------------------------------------------
# Subroutine:  teilfunktion_loeschen
#
#  Hier wird ein bestimmter Eintrag in der Tabelle und im Hash gelöscht.
#  Wenn bereits eine id angegeben wurde stammt kommt der Aufruf von der Funktion
#  <teilfunktion_aendern> und es muss nicht mehr nachgeschaut werden welche
#  Zeile in der Tabelle markiert wurde.
#  Ansonsten ist hier alles wie in <funktion_loeschen> bereits ausführlich
#  beschrieben.
#
# PARAMETERS:
#  $p - aufrufendes Toplevel-Widget
#  $teilfunktionen - Hash mit Teilfunktionen
#  $table	- Enthält die Referenz auf das entsprechende Table-Element
#  $old_id  - Zu löschende ID bereits bekannt.
#
#     SEE ALSO:
#     			 <funktion_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilfunktion_loeschen {
    my ( $p, $teilfunktionen, $table, $old_nummer ) = @_;
    my $nummer;
    if ( defined $old_nummer ) {
        $nummer = $old_nummer;
    }
    else {
        for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
            if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
            {    #markierte Zeile herausfinden
                $nummer = ${$table}->get( $i, 0 )->cget( -text );
            }
        }
    }

    if ( not defined $nummer ) {  #Fehlermeldung wenn keine Zeile markiert wurde
        $p->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    teilfunktion_hash_loeschen( $nummer, $teilfunktionen );

    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) ne $nummer )
        {    #gelöschte Zeile
            push @folge, ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    ${$table}->clear();
    teilfunktion_tabelle_sync( $table, $teilfunktionen, @folge );
    return;
}    # ----------  end of subroutine teilfunktion_loeschen  ----------

#-------------------------------------------------------------------------------
# Subroutine:  teilfunktion_tabelle_sync
#
# Hier werden die Einträge in der von @folge bestimmten Reihenfolge aus
# <%teilfunktionen> geholt und wie in <teilfunktionen_tabelle_einfuegen>
# in die Tabelle eingetragen.
# Da die Funktion aber auch von <teilprodukt_dialog_neu> aufgerufen wird
# und dort dazu dient die momentan einem Teilprodukt zugewiesenen
# Funktion darzustellen, kann man die Funktion auch ohne @folge starten.
# Dann werden einfach alle momentan vorhandenen Funktionen angezeigt.
#
#   PARAMETERS:
#   			 $table	- Die zu synchronisierende Tabelle
#   			 $teilfunktionen - Referenz auf Hash mit Funktions-IDs
#   			 @folge	- Enthält die Reihenfolge der Datensätze
#
#     See Also:
#     			 <funktion_tabelle_sync> ist nahezu funktionsgleich
#-------------------------------------------------------------------------------
sub teilfunktion_tabelle_sync {
    my ( $table, $teilfunktionen, @folge ) = @_;
    my ( $bemerkung, $funk_beschreibung, $nummer );

    #    if ( not @folge ) {
    #        @folge = sort keys %{$teilfunktionen};
    #    }

    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {
        $nummer            = $folge[$i];
        $bemerkung         = ${$teilfunktionen}{ $folge[$i] }[1];
        $funk_beschreibung = ${$teilfunktionen}{ $folge[$i] }[0];
        umbruch_entfernen( \$bemerkung );
        umbruch_entfernen( \$funk_beschreibung );
        my $lab_funk_num = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $nummer,
            -width            => '6',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );
        my $lab_bem = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $bemerkung,
            -width            => '18',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        my $lab_bes = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $funk_beschreibung,
            -width      => '18',
            -padx       => '2',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );

        $lab_bem->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_bes->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_funk_num->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_funk_num );
        ${$table}->put( $i, 1, $lab_bes );
        ${$table}->put( $i, 2, $lab_bem );
    }

    return;
}    # ----------  end of subroutine teilfunktion_tabelle_sync  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  teilfunktion_hash_loeschen
#
#				 Löscht das Key/Value-Paar mit der entsprechenden
#				 ID im Hash %teilfunktionen
#
#   PARAMETERS:
#   			 $id     - Die ID des zu löschenden Eintrages
#   			 $teilfunktionen - Enthält die Referenz auf hash %teilfunktionen
#
#     See Also:
#     			 <funktion_hash_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub teilfunktion_hash_loeschen {
    my ( $nummer, $teilfunktionen ) = @_;
    delete ${$teilfunktionen}{$nummer};
    return;
}    # ----------  end of subroutine teilfunktion_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  teilfunktionen_aktualisieren
#
#          Lädt alle momentan vorhandenen Funktionen aus %funktionen
#          in die übergebene Tabelle. Wird von <teilprodukt_funktion_dialog>
#          aufgerufen um den Dialog zur Funktionsauswahl zu erzeugen.
#
#   PARAMETERS:
#                $table     - Zu aktualisierende Tabelle
#
#-------------------------------------------------------------------------------
sub teilfunktionen_aktualisieren {
    my ($table) = @_;
    my ( $nummer, $beschreibung );
    my @folge = keys %funktionen;

    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {

        $nummer       = $folge[$i];
        $beschreibung = $funktionen{ $folge[$i] }[7];
        my $lab_num = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $nummer,
            -width            => '10',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );
        umbruch_entfernen( \$beschreibung );
        my $lab_beschreibung = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $beschreibung,
            -width            => '40',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_beschreibung->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_num );
        ${$table}->put( $i, 1, $lab_beschreibung );
    }

    return;
}    # ----------  end of subroutine funktionen_aktualisieren  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  teilfunktion_tabelle_markieren
#
#       Wenn eine bereits in einem Teilprodukt vorhandene Funktion bearbeitet
#       wird, wird der zu bearbeitende Eintrag mit dieser Funktion bereits markiert
#       in der Tabelle dargestellt.
#
#
#   PARAMETERS:
#                $table     - Zu markierende Tabelle
#                $id        - id der zu markierenden Zeile
#
#-------------------------------------------------------------------------------
sub teilfunktion_tabelle_markieren {

    #---------------------------------------------------------------------------
    #  Zu bearbeitende Funktion soll durch vorherige Markierung kenntlich
    #  gemacht werden.
    #---------------------------------------------------------------------------
    my ( $table, $nummer ) = @_;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {

        #Finde Zeile mit der passenden ID heraus
        if ( ${$table}->get( $i, 0 )->cget( -text ) eq $nummer ) {
            for my $j ( 0 .. ${$table}->totalColumns - 1 ) {

                #Setze alle Spalten der Zeile auf 'active'
                ${$table}->get( $i, $j )->configure( -state => 'active' );
            }
        }
    }

    return;
}    # ----------  end of subroutine teilfunktion_tabelle_markieren  ----------

#---------------------------------------------------------------------------
#  Subroutine: test_bind_nummer_type
#  
#      Dem Binding werden alle Eingadbefelder übergeben und es überprüft nach jedem
#      Tastenschlag ob die eingegebene Nummer bereits vorhanden ist. Dabei wird
#      anhand des Modus indem sich der Dialog befindet entschieden ob ein Button
#      aktiviert oder deaktiviert wird. Durch die ismapped-Funktion von Tk findet
#      das Binding heraus ob der OK- (neu anlegen-Modus) oder der Übernehmen-Button
#      (Bearbeitungs-Modus) aktiv ist. Unabhängig vom Modus werden bei Existenz
#      der Nummer die Eingabefelder den dazugehörigen Daten gefüllt.
#
#      *Übernehmen Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - Nummernfeld weiss färben
#
#      *Neu anlegen-Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - deaktiviere Neu-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - aktiviere Neu-Button
#      - Nummernfeld weiss farben
#
# Parameters: 
#
#    $w                 - aufrufendes Widget 
#    $parameter_ref     - Folgende Parameter werden per Hashreferenz übergeben:
#    num                - Nummer
#    text_bezeichnung   - Text-Widget
#    text_vorbedingung  - Text-Widget
#    text_beschreibung  - Text-Widget
#    text_sollverhalten - Text-Widget
#    button_ok          - Button-Widget
#    button_neu         - Button-Widget
#    button_uebernehmen - Button-Widget
#
#---------------------------------------------------------------------------
sub test_bind_nummer_type {
    my ( $w, $parameter_ref ) = @_;
    my $num                = ${$parameter_ref}{'nummer'};
    my $text_bezeichnung   = ${$parameter_ref}{'text_bezeichnung'};
    my $text_vorbedingung  = ${$parameter_ref}{'text_vorbedingung'};
    my $text_beschreibung  = ${$parameter_ref}{'text_beschreibung'};
    my $text_sollverhalten = ${$parameter_ref}{'text_sollverhalten'};
    my $button_ok          = ${$parameter_ref}{'button_ok'};
    my $button_neu         = ${$parameter_ref}{'button_neu'};
    my $button_uebernehmen = ${$parameter_ref}{'button_uebernehmen'};

    my $nummer = ${$num};

    if ($nummer) {
        if ( $testfaelle{$nummer} ) {

            # wenn Eintrag im Hash dann auf jeden Fall Einträge laden
            ${$text_bezeichnung}->Contents( $testfaelle{$nummer}[0] );
            ${$text_vorbedingung}->Contents( $testfaelle{$nummer}[1] );
            ${$text_beschreibung}->Contents( $testfaelle{$nummer}[2] );
            ${$text_sollverhalten}->Contents( $testfaelle{$nummer}[3] );

            ${$button_uebernehmen}->configure( -state => 'normal' );

            # Wenn OK-Button gemapped dann befindet man sich im
            # "Neu anlegen"-Modus und die Buttons und Eingaben
            # deaktivieren um zu verdeutlichen, dass die Zahl bereits
            # vergeben ist.
            if ( ${$button_ok}->ismapped() ) {
                $w->configure( -background => '#ff9696' );
                ${$button_ok}->configure( -state => 'disabled' );
                ${$button_neu}->configure( -state => 'disabled' );
            }
        }
        else {

            #Ansonsten alle Felder leeren, aktivieren und
            #Ok/Neu Buttons auswählbar machen
            ${$text_bezeichnung}->Contents($EMPTY);
            ${$text_vorbedingung}->Contents($EMPTY);
            ${$text_beschreibung}->Contents($EMPTY);
            ${$text_sollverhalten}->Contents($EMPTY);
            $w->configure( -background => 'snow1' );
            ${$button_ok}->configure( -state => 'normal' );
            ${$button_neu}->configure( -state => 'normal' );

            #Übernehmen-Button deaktivieren, da im Bearbeitungs-Modus
            #nur vorhandene Einträge bearbeite werden. Rein Theoretisch
            #könnte man auch mit dem Bearbeiten-Button Einträge anlegen,
            #jedoch würde as nur unnötig für Verwirrung sorgen.
            ${$button_uebernehmen}->configure( -state => 'disabled' );
        }
    }
    else {

        #Wenn keine Nummer angegeben, Alle Buttons deaktivieren.
        ${$button_ok}->configure( -state => 'disabled' );
        ${$button_neu}->configure( -state => 'disabled' );
        ${$button_uebernehmen}->configure( -state => 'disabled' );
    }
    return;
}    # ----------  end of subroutine test_bind_nummer_type  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  testfall_dialog_neu
#
#     Erstellt einen Dialog um einen neuen Testfall.
#     Der Dialog wird auch zum Bearbeiten eines Testfalls
#     benutzt und muss zu diesem Zweck eine ID mit übergeben
#     bekommen.
#
#   PARAMETERS:
#				 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 $id - Die ID des Datensatzes
#
#     See Also:
#     			 <funktion_dialog_neu> ist funktionsgleich
#-------------------------------------------------------------------------------
sub testfall_dialog_neu {
    my ( $table, $nummer ) = @_;
    my $toplevel_tfunktion =
      $frame_stack[13]->Toplevel( -title => 'Testfall hinzufügen' );

    Readonly my $BREITE => 400;
    Readonly my $HOEHE  => 400;
    modal( \$toplevel_tfunktion, $BREITE, $HOEHE );

    my $frame_nummer = $toplevel_tfunktion->Frame();
    my $label_nummer = $frame_nummer->Label( -text => 'Nummer' );
    my @choices      = keys %testfaelle;
    my $entry_nummer = $frame_nummer->MatchEntry(
        -choices      => \@choices,
        -fixedwidth   => 1,
        -ignorecase   => 1,
        -maxheight    => 5,
        -textvariable => \$nummer,
    );
    my $label_bezeichnung =
      $toplevel_tfunktion->Label( -text => 'Bezeichnung' );
    my $text_bezeichnung = $toplevel_tfunktion->Scrolled(
        'Text',
        -scrollbars => 'oe',
        -height     => '2'
    );

    my $label_vorbedingung =
      $toplevel_tfunktion->Label( -text => 'Vorbedingung' );
    my $text_vorbedingung = $toplevel_tfunktion->Scrolled(
        'Text',
        -scrollbars => 'oe',
        -height     => '4',
    );

    my $label_beschreibung =
      $toplevel_tfunktion->Label( -text => 'Beschreibung' );
    my $text_beschreibung = $toplevel_tfunktion->Scrolled(
        'Text',
        -scrollbars => 'oe',
        -height     => '4',
    );

    my $label_sollverhalten =
      $toplevel_tfunktion->Label( -text => 'Sollverhalten' );
    my $text_sollverhalten = $toplevel_tfunktion->Scrolled(
        'Text',
        -scrollbars => 'oe',
        -height     => '4',
    );

    if ( defined $nummer ) {
        $toplevel_tfunktion->configure( -title => 'Funktion bearbeiten' );
        $text_bezeichnung->Contents( $testfaelle{$nummer}[0] );
        $text_vorbedingung->Contents( $testfaelle{$nummer}[1] );
        $text_beschreibung->Contents( $testfaelle{$nummer}[2] );
        $text_sollverhalten->Contents( $testfaelle{$nummer}[3] );
    }
    my $button_frame = $toplevel_tfunktion->Frame();
    my $button_ok    = $button_frame->Button(
        -state    => 'disabled',
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            testfall_tabelle_einfuegen(
                {
                    table  => $table,
                    nummer => $nummer,
                    bezeichnung =>
                      $text_bezeichnung->get( '1.0', 'end -1 chars' ),
                    vorbedingung =>
                      $text_vorbedingung->get( '1.0', 'end -1 chars' ),
                    beschreibung =>
                      $text_beschreibung->get( '1.0', 'end -1 chars' ),
                    sollverhalten =>
                      $text_sollverhalten->get( '1.0', 'end -1 chars' ),
                    id => undef,
                }
            );
            set_aendern();
            $toplevel_tfunktion->destroy();
        }
    );

    my $button_neu = $button_frame->Button(
        -state    => 'disabled',
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -command  => \sub {
            testfall_tabelle_einfuegen(
                {
                    table  => $table,
                    nummer => $nummer,
                    bezeichnung =>
                      $text_bezeichnung->get( '1.0', 'end -1 chars' ),
                    vorbedingung =>
                      $text_vorbedingung->get( '1.0', 'end -1 chars' ),
                    beschreibung =>
                      $text_beschreibung->get( '1.0', 'end -1 chars' ),
                    sollverhalten =>
                      $text_sollverhalten->get( '1.0', 'end -1 chars' ),
                }
            );
            undef $nummer;
            $text_bezeichnung->Contents($EMPTY);
            $text_vorbedingung->Contents($EMPTY);
            $text_beschreibung->Contents($EMPTY);
            $text_sollverhalten->Contents($EMPTY);
            @choices = keys %testfaelle;
            $entry_nummer->configure( -choices => \@choices );
            $entry_nummer->focus();
            set_aendern();
        }
    );

    my $button_uebernehmen = $button_frame->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            testfall_tabelle_aendern(
                table       => $table,
                nummer      => $nummer,
                bezeichnung => $text_bezeichnung->get( '1.0', 'end -1 chars' ),
                vorbedingung =>
                  $text_vorbedingung->get( '1.0', 'end -1 chars' ),
                beschreibung =>
                  $text_beschreibung->get( '1.0', 'end -1 chars' ),
                sollverhalten =>
                  $text_sollverhalten->get( '1.0', 'end -1 chars' ),
            );
            set_aendern();
            $toplevel_tfunktion->destroy();
        }
    );
    my $button_abbrechen = $button_frame->Button(
        -text     => 'Abbrechen',
        -compound => 'left',
        -image    => $pic_exit,
        -command  => \sub {
            $toplevel_tfunktion->destroy();
        }
    );

    $entry_nummer->bind(
        '<KeyRelease>',
        [
            \&test_bind_nummer_type,
            {
                nummer             => \$nummer,
                text_bezeichnung   => \$text_bezeichnung,
                text_vorbedingung  => \$text_vorbedingung,
                text_beschreibung  => \$text_beschreibung,
                text_sollverhalten => \$text_sollverhalten,
                button_ok          => \$button_ok,
                button_neu         => \$button_neu,
                button_uebernehmen => \$button_uebernehmen,
            }
        ]
    );

    $entry_nummer->bind(
        '<FocusIn>',
        [
            \&bind_nummer_in, \$nummer, \$button_ok,
            \$button_neu,     \$button_uebernehmen
        ]
    );

    #---------------------------------------------------------------------------
    #  packs
    #---------------------------------------------------------------------------
    $frame_nummer->pack( -fill => 'x' );
    $label_nummer->pack( -side => 'left' );
    $entry_nummer->pack( -side => 'left' );
    $label_bezeichnung->pack( -anchor => 'w' );
    $text_bezeichnung->pack( -anchor => 'w' );
    $label_vorbedingung->pack( -anchor => 'w' );
    $text_vorbedingung->pack( -anchor => 'w' );
    $label_beschreibung->pack( -anchor => 'w' );
    $text_beschreibung->pack( -anchor => 'w' );
    $label_sollverhalten->pack( -anchor => 'w' );
    $text_sollverhalten->pack( -anchor => 'w' );
    $button_frame->pack( -anchor => 'w', -fill => 'x' );

    if ( defined $nummer ) {
        $button_uebernehmen->pack( -side => 'left' );
    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine testfall_dialog_neu  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  testfall_tabelle_einfuegen
#
#		Diese Funktion fügt eine neue Zeile in die übergebene Tabelle hinzu
#		und ändert entsprechend den Hash %testfaelle.
#
#   PARAMETERS:
#     	 $table	        - Enthält die Referenz auf die zu bearbeitende Tabelle
#     	 $nummer        - Die Nummer des Datensatzes
#     	 $bezeichnung   - Bezeichnung
#     	 $vorbedingung  - Vorbedingung
#        $beschreibung  - Beschreibung
#     	 $sollverhalten - Sollverhalten
#
#     See Also:
#     			 <funktion_tabelle_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub testfall_tabelle_einfuegen {
    my ($parameter_ref) = @_;
    my $table           = ${$parameter_ref}{'table'};
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $vorbedingung    = ${$parameter_ref}{'vorbedingung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $sollverhalten   = ${$parameter_ref}{'sollverhalten'};

    if ( defined $nummer ) {
        testfall_hash_aendern(
            {
                nummer        => $nummer,
                bezeichnung   => $bezeichnung,
                vorbedingung  => $vorbedingung,
                beschreibung  => $beschreibung,
                sollverhalten => $sollverhalten,
            }
        );
    }
    else {
        testfall_hash_einfuegen(
            {
                nummer        => $nummer,
                bezeichnung   => $bezeichnung,
                vorbedingung  => $vorbedingung,
                beschreibung  => $beschreibung,
                sollverhalten => $sollverhalten
            }
        );
    }

    umbruch_entfernen( \$bezeichnung );
    umbruch_entfernen( \$beschreibung );

    my $lab_num = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $nummer,
        -width            => '6',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_bez = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $bezeichnung,
        -width            => '35',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );
    my $lab_bes = ${$table}->Label(
        -background => 'snow1',
        -relief     => 'groove',
        -text       => $beschreibung,
        -width      => '41',
        -padx       => '2',
        -anchor     => 'w',
        -activebackground =>
          'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
    );
    my $akt_zeile = ${$table}->totalRows;

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bez->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $lab_bes->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $lab_num );
    ${$table}->put( $akt_zeile, 1, $lab_bez );
    ${$table}->put( $akt_zeile, 2, $lab_bes );

    return;
}    # ----------  end of subroutine testfall_tabelle_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  testfall_hash_einfuegen
#
#                Ändert einen Eintrag im Hash der Produktdaten
#
#   Parameters:
#
#        $nummer        - Die Nummer des Datensatzes
#        $bezeichnung   - Bezeichnung
#        $vorbedingung  - Vorbedingung
#        $beschreibung  - Beschreibung
#        $sollverhalten - Sollverhalten
#
#      RETURNS:
#      	 $id            - ID des neuen Eintrages
#
#     See Also:
#        <funktion_hash_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub testfall_hash_einfuegen {
    my ($parameter_ref) = @_;
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $vorbedingung    = ${$parameter_ref}{'vorbedingung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $sollverhalten   = ${$parameter_ref}{'sollverhalten'};

    $testfaelle{$nummer} =
      [ $bezeichnung, $vorbedingung, $beschreibung, $sollverhalten ];

    return ();
}    # ----------  end of subroutine testfall_hash_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  testfall_tabelle_aendern
#
#        Diese Funktion ändert eine bestimmte Zeile in der Tabelle
#        und ändert den Hash mit der Funktion <testfall_hash_aendern>.
#
#
#   PARAMETERS:
#        $table	        - Enthält die Referenz auf die zu bearbeitende Tabelle
#        $nummer        - Die Nummer des Datensatzes
#        $bezeichnung   - Bezeichnung
#        $vorbedingung  - Vorbedingung
#        $beschreibung  - Beschreibung
#        $sollverhalten - Sollverhalten
#
#     See Also:
#     			 <funktion_tabelle_aendern> Für detaillierte Erklärungen
#-------------------------------------------------------------------------------
sub testfall_tabelle_aendern {
    my ($parameter_ref) = @_;
    my $table           = ${$parameter_ref}{'table'};
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $vorbedingung    = ${$parameter_ref}{'vorbedingung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $sollverhalten   = ${$parameter_ref}{'sollverhalten'};

    my $row;
    testfall_hash_aendern( $nummer, $bezeichnung, $vorbedingung, $beschreibung,
        $sollverhalten );
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) eq $nummer ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$beschreibung );
    umbruch_entfernen( \$bezeichnung );

    ${$table}->get( $row, 0 )->configure( -text => $nummer );
    ${$table}->get( $row, 1 )->configure( -text => $bezeichnung );
    ${$table}->get( $row, 2 )->configure( -text => $beschreibung );
    return;
}    # ----------  end of subroutine testfall_tabelle aendern  ----------

#-------------------------------------------------------------------------------
# Subroutine:  testfall_tabelle_sync
#
# Hier werden die Einträge in der von @folge bestimmten Reihenfolge aus
# <%testfaelle> geholt und wie in <testfaelle_tabelle_einfuegen> in die Tabelle
# eingetragen
#
#   PARAMETERS:
#   			 $table	- Die zu synchronisierende Tabelle
#   			 @folge	- Enthält die Reihenfolge der Datensätze
#
#     See Also:
#     			 <funktion_tabelle_sync> ist funktionsgleich
#-------------------------------------------------------------------------------
sub testfall_tabelle_sync {
    my ( $table, @folge ) = @_;
    my ( $nummer, $bezeichnung, $beschreibung );
    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {

        $nummer       = $folge[$i];
        $bezeichnung  = $testfaelle{ $folge[$i] }[1];
        $beschreibung = $testfaelle{ $folge[$i] }[2];
        my $lab_num = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $nummer,
            -width            => '6',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        umbruch_entfernen( \$bezeichnung );
        my $lab_bezeichnung = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $bezeichnung,
            -width      => '35',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );

        umbruch_entfernen( \$beschreibung );
        my $lab_beschreibung = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $beschreibung,
            -width            => '41',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        $lab_num->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_bezeichnung->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $lab_beschreibung->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $lab_num );
        ${$table}->put( $i, 1, $lab_bezeichnung );
        ${$table}->put( $i, 2, $lab_beschreibung );
    }

    return;
}    # ----------  end of subroutine datum_tabelle_sync  ----------

#-------------------------------------------------------------------------------
# Subroutine:  testfall_bearbeiten
#
#	Eine bestimmte Zeile aus der übergebenen Tabelle bearbeiten
#
# Parameters:
#   $table	- Enthält die Referenz auf das entsprechende Table-Element
#
# See Also:
#   <funktion_bearbeiten> ist funktionsgleich
#-------------------------------------------------------------------------------
sub testfall_bearbeiten {
    my ($table) = @_;
    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return;
    }
    testfall_dialog_neu( $table, $nummer );
    return;
}    # ----------  end of subroutine datum_bearbeiten  ----------

#-------------------------------------------------------------------------------
# Subroutine:  testfall_loeschen
#
#  Eine bestimmte Zeile aus der Tabelle löschen
#
# PARAMETERS:
#  $table	- Enthält die Referenz auf das entsprechende Table-Element
#
#     SEE ALSO:
#     			 <funktion_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub testfall_loeschen {
    my ($table) = @_;
    my $nummer;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $nummer = ${$table}->get( $i, 0 )->cget( -text );
        }
    }

    if ( !defined $nummer ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    testfall_hash_loeschen($nummer);

    # alte Reihenfolge der Tabelleneinträge über die
    # IDs speichern ohne die gelöschte Zeile
    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) ne $nummer )
        {    #gelöschte Zeile
            push @folge, ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    ${$table}->clear();

    testfall_tabelle_sync( $table, @folge );

    return;
}    # ----------  end of subroutine datum_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  testfall_hash_loeschen
#
#	 Löscht den Eintrag mit der entsprechenden ID aus dem Hash der Testfälle
#
#   Parameters:
#	 $id	- Die ID des zu löschenden Eintrags
#
#     See Also:
#     			 <funktion_hash_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub testfall_hash_loeschen {
    my ($nummer) = @_;

    delete $testfaelle{$nummer};
    return;
}    # ----------  end of subroutine datum_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  testfall_hash_aendern
#
#				 Ändert einen Eintrag im Hash der Produktdaten
#
#   Parameters:
#
#     	 $nummer        - Die Nummer des Datensatzes
#     	 $bezeichnung   - Bezeichnung
#     	 $vorbedingung  - Vorbedingung
#        $beschreibung  - Beschreibung
#     	 $sollverhalten - Sollverhalten
#        $id            - ID
#
#      RETURNS:
#      			 -
#
#     See Also:
#     			 <funktion_hash_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub testfall_hash_aendern {
    my ($parameter_ref) = @_;
    my $nummer          = ${$parameter_ref}{'nummer'};
    my $bezeichnung     = ${$parameter_ref}{'bezeichnung'};
    my $vorbedingung    = ${$parameter_ref}{'vorbedingung'};
    my $beschreibung    = ${$parameter_ref}{'beschreibung'};
    my $sollverhalten   = ${$parameter_ref}{'sollverhalten'};

    $testfaelle{$nummer} =
      [ $bezeichnung, $vorbedingung, $beschreibung, $sollverhalten ];
    return;
}    # ----------  end of subroutine daten_hash_aendern ----------

#---------------------------------------------------------------------------
#  Subroutine: glo_bind_nummer_type
#  
#      Dem Binding werden alle Eingadbefelder übergeben und es überprüft nach jedem
#      Tastenschlag ob die eingegebene Nummer bereits vorhanden ist. Dabei wird
#      anhand des Modus indem sich der Dialog befindet entschieden ob ein Button
#      aktiviert oder deaktiviert wird. Durch die ismapped-Funktion von Tk findet
#      das Binding heraus ob der OK- (neu anlegen-Modus) oder der Übernehmen-Button
#      (Bearbeitungs-Modus) aktiv ist. Unabhängig vom Modus werden bei Existenz
#      der Nummer die Eingabefelder den dazugehörigen Daten gefüllt.
#
#      *Übernehmen Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - Nummernfeld weiss färben
#
#      *Neu anlegen-Modus*
#
#      _Nummer vorhanden_
#      - deaktiviere Übernehmen-Button
#      - deaktiviere Neu-Button
#      - Nummernfeld rot färben
#
#      _Nummer nicht vorhanden_
#      - aktiviere Übernehmen-Button
#      - aktiviere Neu-Button
#      - Nummernfeld weiss farben
#
# Parameters: 
#
#    $w                 - aufrufendes Widget 
#    $parameter_ref     - Folgende Parameter werden per Hashreferenz übergeben:
#    beg                - Begriff
#    text_erklaerung    - Text-Widget
#    button_ok          - Button-Widget
#    button_neu         - Button-Widget
#    button_uebernehmen - Button-Widget
#
#---------------------------------------------------------------------------
sub glo_bind_begriff_type {
    my ( $w, $parameter_ref ) = @_;
    my $beg                = ${$parameter_ref}{'begriff'};
    my $text_erklaerung    = ${$parameter_ref}{'text_erklaerung'};
    my $button_ok          = ${$parameter_ref}{'button_ok'};
    my $button_neu         = ${$parameter_ref}{'button_neu'};
    my $button_uebernehmen = ${$parameter_ref}{'button_uebernehmen'};

    my $begriff = ${$beg};

    if ($begriff) {
        if ( $glossar{$begriff} ) {

            # wenn Eintrag im Hash dann auf jeden Fall Einträge laden
            ${$text_erklaerung}->Contents( $glossar{$begriff}[0] );
            ${$button_uebernehmen}->configure( -state => 'normal' );

            # Wenn OK-Button gemapped dann befindet man sich im
            # "Neu anlegen"-Modus und die Buttons und Eingaben
            # deaktivieren um zu verdeutlichen, dass die Zahl bereits
            # vergeben ist.
            if ( ${$button_ok}->ismapped() ) {
                $w->configure( -background => '#ff9696' );
                ${$button_ok}->configure( -state => 'disabled' );
                ${$button_neu}->configure( -state => 'disabled' );
            }
        }
        else {

            #Ansonsten alle Felder leeren, aktivieren und
            #Ok/Neu Buttons auswählbar machen
            ${$text_erklaerung}->Contents($EMPTY);
            $w->configure( -background => 'snow1' );
            ${$button_ok}->configure( -state => 'normal' );
            ${$button_neu}->configure( -state => 'normal' );

            #Übernehmen-Button deaktivieren, da im Bearbeitungs-Modus
            #nur vorhandene Einträge bearbeite werden. Rein Theoretisch
            #könnte man auch mit dem Bearbeiten-Button Einträge anlegen,
            #jedoch würde as nur unnötig für Verwirrung sorgen.
            ${$button_uebernehmen}->configure( -state => 'disabled' );
        }
    }
    else {

        #Wenn keine Nummer angegeben, Alle Buttons deaktivieren.
        ${$button_ok}->configure( -state => 'disabled' );
        ${$button_neu}->configure( -state => 'disabled' );
        ${$button_uebernehmen}->configure( -state => 'disabled' );
    }

    return;
}    # ----------  end of subroutine glo_bind_begriff_type  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  glossar_dialog_neu
#
#     Erstellt einen Dialog um einen neuen Eintrag im Glossar anzulegen.
#     Der Dialog wird auch zum Bearbeiten eines Begriffs benutzt und muss
#     zu diesem Zweck eine ID mit übergeben bekommen.
#
#   PARAMETERS:
#				 $table	- Enthält die Referenz auf die zu bearbeitende Tabelle
#				 $id -    Die ID des Datensatzes
#
#     See Also:
#     			 <funktion_dialog_neu> ist funktionsgleich
#-------------------------------------------------------------------------------
sub glossar_dialog_neu {
    my ( $table, $begriff ) = @_;
    my $toplevel_glossar =
      $frame_stack[14]->Toplevel( -title => 'Neuen Begriff anlegen' );

    Readonly my $BREITE => 400;
    Readonly my $HOEHE  => 170;
    modal( \$toplevel_glossar, $BREITE, $HOEHE );

    my $frame_begriff = $toplevel_glossar->Frame();
    my $label_begriff = $frame_begriff->Label( -text => 'Begriff' );
    my @choices       = keys %glossar;

    my $entry_begriff = $frame_begriff->MatchEntry(
        -choices      => \@choices,
        -fixedwidth   => 1,
        -ignorecase   => 1,
        -maxheight    => 5,
        -textvariable => \$begriff,
    );

    my $label_erklaerung = $toplevel_glossar->Label( -text => 'Erklärung' );
    my $text_erklaerung = $toplevel_glossar->Scrolled(
        'Text',
        -scrollbars => 'oe',
        -height     => '5'
    );

    my $button_frame = $toplevel_glossar->Frame();
    my $button_ok    = $button_frame->Button(
        -state    => 'disabled',
        -text     => 'OK',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            glossar_tabelle_einfuegen( $table, $begriff,
                $text_erklaerung->get( '1.0', 'end -1 chars' ),
            );
            $toplevel_glossar->destroy();
            set_aendern();
        }
    );
    my $button_neu = $button_frame->Button(
        -state    => 'disabled',
        -text     => 'Neu',
        -compound => 'left',
        -image    => $pic_ok_redo,
        -command  => \sub {
            glossar_tabelle_einfuegen( $table, $begriff,
                $text_erklaerung->get( '1.0', 'end -1 chars' ) );
            undef $begriff;
            $text_erklaerung->Contents($EMPTY);
            @choices = keys %glossar;
            $entry_begriff->configure( -choices => \@choices );
            set_aendern();
        }
    );
    my $button_abbrechen = $button_frame->Button(
        -text     => 'Abbrechen',
        -compound => 'left',
        -image    => $pic_exit,
        -command  => \sub {
            $toplevel_glossar->destroy();
        }
    );

    my $button_uebernehmen = $button_frame->Button(
        -text     => 'Übernehmen',
        -compound => 'left',
        -image    => $pic_ok,
        -command  => \sub {
            glossar_tabelle_aendern( $table, $begriff,
                $text_erklaerung->get( '1.0', 'end -1 chars' ),
            );
            set_aendern();
            $toplevel_glossar->destroy();
        }
    );
    if ( defined $begriff ) {
        $toplevel_glossar->configure( -title => 'Begriff bearbeiten' );
        $text_erklaerung->Contents( $glossar{$begriff}[0] );
    }
    $entry_begriff->bind(
        '<KeyRelease>',
        [
            \&glo_bind_begriff_type,
            {
                begriff            => \$begriff,
                text_erklaerung    => \$text_erklaerung,
                button_ok          => \$button_ok,
                button_neu         => \$button_neu,
                button_uebernehmen => \$button_uebernehmen,
            }
        ]
    );

    $entry_begriff->bind(
        '<FocusIn>',
        [
            \&bind_nummer_in, \$begriff, \$button_ok,
            \$button_neu,     \$button_uebernehmen
        ]
    );

    #---------------------------------------------------------------------------
    #  packs
    #---------------------------------------------------------------------------
    $frame_begriff->pack( -fill => 'x' );
    $label_begriff->pack( -side => 'left' );
    $entry_begriff->pack( -side => 'left', -fill => 'x', -expand => '1' );
    $label_erklaerung->pack( -anchor => 'w' );
    $text_erklaerung->pack( -anchor => 'w' );
    $button_frame->pack( -anchor => 'w', -fill => 'x' );
    if ( defined $begriff ) {
        $button_uebernehmen->pack( -side => 'left' );

    }
    else {
        $button_ok->pack( -side => 'left' );
        $button_neu->pack( -side => 'left' );
    }
    $button_abbrechen->pack( -side => 'right' );
    return;
}    # ----------  end of subroutine glossar_dialog_neu  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  glossar_tabelle_einfuegen
#
#		Diese Funktion fügt eine neue Zeile in die übergebene Tabelle hinzu
#		und ändert entsprechend den Hash %glossar.
#
#   PARAMETERS:
#     	 $table	           - Enthält die Referenz auf die zu bearbeitende Tabelle
#     	 $entry_begriff    - Begriff
#        $entry_erklaerung - Erklärung
#
#     See Also:
#     			 <funktion_tabelle_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub glossar_tabelle_einfuegen {
    my ( $table, $begriff, $erklaerung ) = @_;

    my $id = glossar_hash_einfuegen( $begriff, $erklaerung );

    umbruch_entfernen( \$erklaerung );

    my $begriff_lab = ${$table}->Label(
        -background       => 'snow1',
        -relief           => 'groove',
        -text             => $begriff,
        -width            => '20',
        -padx             => '2',
        -activebackground => 'LightSkyBlue'
    );

    my $erklaerung_lab = ${$table}->Label(
        -background => 'snow1',
        -relief     => 'groove',
        -text       => $erklaerung,
        -width      => '63',
        -padx       => '2',
        -anchor     => 'w',
        -activebackground =>
          'LightSkyBlue'    #wenn aktiviert bzw markiert auf Blau setzen
    );

    my $akt_zeile = ${$table}->totalRows;

    # Verknüpfen der einzelnen Tabellenzeilen mit Events
    $begriff_lab->bind( '<Button>', [ \&mark_umschalten, $table ] );
    $erklaerung_lab->bind( '<Button>', [ \&mark_umschalten, $table ] );

    ${$table}->put( $akt_zeile, 0, $begriff_lab );
    ${$table}->put( $akt_zeile, 1, $erklaerung_lab );

    #    ${$table}->put( $akt_zeile, 2, $lab_id );           #id des Eintrages

    return;
}    # ----------  end of subroutine tabelle_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  glossar_tabelle_aendern
#
#        Diese Funktion ändert eine bestimmte Zeile in der Tabelle
#        und den Hash mit der Funktion <glossar_hash_aendern>.
#
#
#   PARAMETERS:
#        $table	           - Enthält die Referenz auf die zu bearbeitende Tabelle
#     	 $entry_begriff    - Begriff
#        $entry_erklaerung - Erklärung
#        $id               - ID
#
#     See Also:
#     			 <funktion_tabelle_aendern> Für detaillierte Erklärungen
#-------------------------------------------------------------------------------
sub glossar_tabelle_aendern {
    my ( $table, $begriff, $erklaerung ) = @_;
    my $row;
    glossar_hash_aendern( $begriff, $erklaerung );
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) eq $begriff ) {
            $row = $i;
        }
    }
    umbruch_entfernen( \$erklaerung );
    ${$table}->get( $row, 0 )->configure( -text => $begriff );
    ${$table}->get( $row, 1 )->configure( -text => $erklaerung );
    return;
}    # ----------  end of subroutine ziel_tabelle_aendern  ----------

#-------------------------------------------------------------------------------
# Subroutine:  glossar_tabelle_sync
#
# Hier werden die Einträge in der von @folge bestimmten Reihenfolge aus
# <%glossar> geholt und wie in <glossar_tabelle_einfuegen> in die Tabelle
# eingetragen
#
#   PARAMETERS:
#   			 $table	- Die zu synchronisierende Tabelle
#   			 @folge	- Enthält die Reihenfolge der Datensätze
#
#     See Also:
#     			 <funktion_tabelle_sync> ist funktionsgleich
#-------------------------------------------------------------------------------
sub glossar_tabelle_sync {
    my ( $table, @folge ) = @_;
    my $begriff;
    my $erklaerung;
    foreach my $i ( 0 .. ( scalar @folge ) - 1 ) {
        $begriff    = $folge[$i];
        $erklaerung = $glossar{ $folge[$i] }[0];
        my $begr_lab = ${$table}->Label(
            -background       => 'snow1',
            -relief           => 'groove',
            -text             => $begriff,
            -width            => '20',
            -padx             => '2',
            -activebackground => 'LightSkyBlue'
        );

        umbruch_entfernen( \$erklaerung );
        my $erkl_lab = ${$table}->Label(
            -background => 'snow1',
            -relief     => 'groove',
            -text       => $erklaerung,
            -width      => '63',
            -padx       => '2',
            -anchor     => 'w',
            -activebackground =>
              'LightSkyBlue'    #wenn aktiviert bzw markiert auf grün setzen
        );

        $begr_lab->bind( '<Button>', [ \&mark_umschalten, $table ] );
        $erkl_lab->bind( '<Button>', [ \&mark_umschalten, $table ] );

        ${$table}->put( $i, 0, $begr_lab );
        ${$table}->put( $i, 1, $erkl_lab );

        #        ${$table}->put( $i, 2, $lab_id );     #id des Eintrages
    }

    return;
}    # ----------  end of subroutine sync_table_hash  ----------

#-------------------------------------------------------------------------------
# Subroutine:  glossar_bearbeiten
#
#	Eine bestimmte Zeile aus der übergebenen Tabelle bearbeiten
#
# Parameters:
#   $table	- Enthält die Referenz auf das entsprechende Table-Element
#
# See Also:
#   <funktion_bearbeiten> ist funktionsgleich
#-------------------------------------------------------------------------------
sub glossar_bearbeiten {
    my ($table) = @_;
    my $begriff;

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $begriff = ${$table}->get( $i, 0 )->cget( -text );
        }
    }

    if ( !defined $begriff ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum bearbeiten bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();

        return;

    }

    glossar_dialog_neu( $table, $begriff );
    return;
}    # ----------  end of subroutine ziel_bearbeiten  ----------

#-------------------------------------------------------------------------------
# Subroutine:  glossar_loeschen
#
#  Eine bestimmte Zeile aus der Tabelle löschen
#
# PARAMETERS:
#  $table	- Enthält die Referenz auf das entsprechende Table-Element
#
#     SEE ALSO:
#     			 <funktion_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub glossar_loeschen {
    my ($table) = @_;
    my $begriff;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -state ) eq 'active' )
        {    #markierte Zeile herausfinden
            $begriff = ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    if ( !defined $begriff ) {
        $mw->Dialog(
            -title          => 'Hinweis',
            -text           => 'Zum löschen bitte Zeile markieren.',
            -default_button => 'OK',
            -buttons        => ['OK'],
            -bitmap         => 'warning'
        )->Show();
        return ();
    }

    glossar_hash_loeschen($begriff);

    # alte Reihenfolge der Tabelleneinträge über die
    # IDs speichern ohne die gelöschte Zeile
    my @folge;
    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {
        if ( ${$table}->get( $i, 0 )->cget( -text ) ne $begriff )
        {    #gelöschte Zeile
            push @folge, ${$table}->get( $i, 0 )->cget( -text );
        }
    }
    ${$table}->clear();
    glossar_tabelle_sync( $table, @folge );

    return;
}    # ----------  end of subroutine ziel_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  glossar_hash_einfuegen
#
#        Fügt einen neuen Eintrag in den Hash <%glossar> ein.
#
#   Parameters:
#
#        $begriff       - Begriff
#        $erkl          - Erklärung
#
#      RETURNS:
#      	 $id            - ID des neuen Eintrages
#
#     See Also:
#        <funktion_hash_einfuegen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub glossar_hash_einfuegen {
    my ( $begriff, $erkl ) = @_;

    $glossar{$begriff} = [$erkl];

    return ();
}    # ----------  end of subroutine hash_rein_ziel  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  glossar_hash_loeschen
#
#	 Löscht den Eintrag mit der entsprechenden ID aus dem Hash des Glossars
#
#   Parameters:
#	 $id	- Die ID des zu löschenden Eintrags
#
#     See Also:
#     			 <glossar_hash_loeschen> ist funktionsgleich
#-------------------------------------------------------------------------------
sub glossar_hash_loeschen {
    my ($begriff) = @_;

    delete $glossar{$begriff};
    return;
}    # ----------  end of subroutine ziel_hash_loeschen  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  glossar_hash_aendern
#
#				 Ändert einen Eintrag im Hash der Produktdaten
#
#   Parameters:
#
#        $entry_begriff   - Begriff
#        $text_erklaerung - Erklärung
#        $id              - ID
#
#     See Also:
#     			 <funktion_hash_aendern> ist funktionsgleich
#-------------------------------------------------------------------------------
sub glossar_hash_aendern {
    my ( $begriff, $erklaerung, $id ) = @_;

    $glossar{$begriff} = [$erklaerung];
    return;
}

#---------------------------------------------------------------------------
#  Subroutine: set_aendern
#  
#  Benachrichtigt Benutzer, daß was geändert wurde. 
#  Wenn irgendwo eine Funktion aufgerufen wird, die einen Wert verändern
#  könnte wie zb.: ein OK-Button oder ein Tastenanschlag in einem Textfeld
#  wird diese Funktion aufgerufen. Aus den Textfeldern heraus als Binding
#  und aus den Buttons in der '-command'-Option als normale Subroutine.
#  Nur aus <speichern> wird sie mit dem Parameter '1' aufgerufen.
#
#  Parameters:
#  $widget - aufrufendes Widget oder 1, je nachdem von wo aufgerufen wird
#---------------------------------------------------------------------------
sub set_aendern {
    my	( $widget )	= @_;
    if ($widget eq '1'){
        $mw->title('Morili - Pflichtenheftgenerator');
        $geaendert = 0;
    }else{
        $mw->title('Morili - Pflichtenheftgenerator *geändert*');
        $geaendert = 1;
    }
    return ;
}	# ----------  end of subroutine bind_aendern  ----------
#-------------------------------------------------------------------------------
#     Subroutine:  einfuegen_id
#
#       Fügt Id in gewünschtes Kapitel ein, wenn nicht bereits drin. Ist das
#       Kapitel und Id nicht vorhanden wird ein neues Kapitel angelegt.
#
#   Parameters:
#
#        $kapitel_ref  - Referenz auf gewünschtes Kapitel
#        $kapitel      - Erklärung
#        $id           - ID
#
#-------------------------------------------------------------------------------
sub einfuegen_id {
    my ( $id, $kapitel, $kapitel_ref ) = @_;
    my $akt_kapitel = suche_id( $id, $kapitel_ref );    # hole Kapitel von id
    if ( not defined $akt_kapitel and defined $kapitel )
    {                                                   #id in keinem Kapitel?
        ${$kapitel_ref}{$kapitel}{$id} = $id;   # neues Kapitel mit ID erstellen
    }

    #Hier wird noch einmal explizit getestet of $kapitel und $akt_kapitel
    #definiert sind,  da "ne" nichts undefiniertes verträgt
    elsif ( defined $akt_kapitel and defined $kapitel ) {

        if ( $akt_kapitel ne $kapitel ) {    # id nicht im erwünschten Kapitel?

            loesche_id( $id, $kapitel_ref )
              ;    # dann lösche ID aus dem vorherigem Kapitel
            ${$kapitel_ref}{$kapitel}{$id} = $id;    # und hänge ID dran
        }
    }
    return;
}    # ----------  end of subroutine einfuegen_id  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  suche_id
#
#     Sucht id im Kapitel, wenn gefunden wird der Name des Kapitels
#     zurückgegeben.
#
#   Parameters:
#
#        $kapitel_ref  - Referenz auf gewünschtes Kapitel
#        $id           - ID
#
#      RETURNS:
#        $k            - Name des Kapitels
#-------------------------------------------------------------------------------
sub suche_id {
    my ( $id, $kapitel_ref ) = @_;    #gesuchte id und hash von Kapiteln

    foreach my $k ( keys %{$kapitel_ref} ) {
        if ( exists ${ ${$kapitel_ref}{$k} }{$id} ) {

            return ($k);
        }
    }
    return;
}    # ----------  end of subroutine suche_id  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  loesche_id
#
#       Löscht id im Kapitel-Hash, wenn keine Ids mehr im Kapitel, Kapitel
#       löschen.
#
#   Parameters:
#
#        $kapitel_ref  - Referenz auf gewünschtes Kapitel
#        $id           - ID
#
#-------------------------------------------------------------------------------
sub loesche_id {
    my ( $id, $kapitel_ref ) = @_;
    my $kapitel = suche_id( $id, $kapitel_ref );

    #Hier wird noch einmal explizit getestet of $kapitel
    #definiert ist, da sonst warning von delete kommt
    if ( defined $kapitel ) {
        delete ${ ${$kapitel_ref}{$kapitel} }{$id};

        #Wenn keine Elemente mehr im Kapitel, dann löschen
        my $anzahl = keys %{ ${$kapitel_ref}{$kapitel} };
        if ( $anzahl == 0 ) {
            my $antwort;
            if ( trimm($kapitel) ) {
                $antwort = $mw->Dialog(
                    -title => 'Achtung',
                    -text  => "Kapitel $kapitel enthält keine Elemente.\n"
                      . 'Soll es gelöscht werden?',
                    -buttons => [ 'Ja', 'Nein' ],
                    -bitmap  => 'question'
                )->Show();
                if ( $antwort eq 'Nein' ) {
                    return;
                }

            }
            delete ${$kapitel_ref}{$kapitel};
        }
        return;
    }
}    # ----------  end of subroutine loesche_id  ----------

#-------------------------------------------------------------------------------
# Subroutine:  mark_umschalten
#
#  Wenn eine Tabellenzeile angeklickt wird, wird sie wenn markiert demarkiert und
#  vice versa.
#
#  Zuvor werden aber alle markierten Zeilen bis auf die angeklickte demarkiert
#
#   PARAMETERS:
#   			 $w	- Das angeklickte Widget (wird durch das Binding übertragen)
#   			 $table	- Die zu bearbeitende Tabelle
#-------------------------------------------------------------------------------
sub mark_umschalten {
    my ( $w,   $table ) = @_;
    my ( $row, $col )   = ${$table}->Posn($w);    #angeklickte Position holen

    for my $i ( 0 .. ${$table}->totalRows() - 1 ) {    #alles demarkieren
        for my $j ( 0 .. ${$table}->totalColumns() - 1 ) {
            if ( $i != $row ) {    #wenn nicht geklickte Zeile
                                   #und auf normalen Zustand setzen
                ${$table}->get( $i, $j )->configure( -state => 'normal' );
            }
        }
    }

    #Den Zustand der angeklickten Zeile immer negieren
    for my $i ( 0 .. ${$table}->totalColumns - 1 ) {
        if ( ${$table}->get( $row, $i )->cget( -state ) eq 'normal' )
        {                          # wenn normal
            ${$table}->get( $row, $i )
              ->configure( -state => 'active' )    #auf aktiv setzen
        }
        else {
            ${$table}->get( $row, $i )->configure( -state => 'normal' )
              ;                                    #ansonsten auf normal
        }
    }
    return;
}    # ----------  end of subroutine mark_umschalten  ----------

#-------------------------------------------------------------------------------
#  Subroutine:  switch_frame
#  Wechselt zum nächsten Frame oder zum vorherigen Frame
#  PARAMETERS:
#  $frm - Wenn als Parameter 1 übergeben wird geht es einen Schritt weiter
#         und bei -1 einen Schritt zurück
#-------------------------------------------------------------------------------
sub switch_frame {
    my ($frm) = @_;
    if ( $frm == -1 ) {    #wenn -1
        if ( $aktueller_frame > 0 ) {    #und aktueller Frame > 0
            $aktueller_frame--;          #ein Schritt zurück
        }
    }
    if ( $frm == 1 ) {                   #wenn 1
        if ( $aktueller_frame < 14 ) {    #und aktueller frame < 9
            $aktueller_frame++;           #einen Schritt nach vorne
        }

    }
    show_frame($aktueller_frame);         #Anzeigen
    return;
}    # ----------  end of subroutine nextFrame  ----------

#-------------------------------------------------------------------------------
#     Subroutine:  show_frame
#
#   Diese Funktion sorgt dafür, dass der Frame mit dem übergebenen Index
#   angezeigt wird. Die besagten Frames sind die Frames für 1.Zielbestimmung
#   2.Einsatz, etc.
#   Alle Frames ausser dem angegebenen Frame werden aus dem geometry-manager
#   mit ->packForget() gelöscht. Wobei das Frame nur unsichtbar wird und nicht
#   tatsächlich gelöscht. Desweiteren wird der passende Button aus dem
#   <@button_array> auf der rechten Seite der GUI eingefärbt
#
#   Parameters:
#   			 frm -	Der anzuzeigende Frame
#-------------------------------------------------------------------------------
sub show_frame {
    my ($frm) = @_;

    #Durchlaufe alle Frames
    foreach ( 0 .. 14 ) {
        if ( $_ != $frm ) {    #Wenn nicht hervorzuhebender Frame
            $frame_stack[$_]->packForget();   #aus dem geometry-manager löschen
            $button_array[$_]->configure( -background => 'LightGray' )
              ;                               #ausgrauen
        }
        else {

            $frame_stack[$_]->configure();
            $frame_stack[$_]
              ->pack( -side => 'left', -fill => 'both', -expand => '1' );
            $button_array[$_]->configure( -background => 'LightSkyBlue' );
        }
    }
    $aktueller_frame = $frm;
    return;
}    # ----------  end of subroutine show_frame  ----------

#-------------------------------------------------------------------------------
# Subroutine: trimm
#
#      			 Es werden führende und abschließende Leerzeichen entfernt.
#
#   Parameters:
#   			 $par1    -	Enthält den zu trimmenden String
#
#      Returns:
#      			 Der Rueckgabewert ist der String ohne fuehrende und
#      			 abschließende Leerzeichen.
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
#   Subroutine:  check_bild
#
#      Überprüft ausgewählte Datei auf folgende Eigenschaften
#      (in der Reihenfolge)
#
#          1: existiert
#          2: lesbar
#          3: gültiges Format
#             untertützte Formate sind: Jpg, Png, Gif, Bmp
#      und zeigt die entsprechende Fehlermeldung als Popup-Dialog
#
#
#   Parameters:
#      $bild  -  Pfad zur Bilddatei
#
#   Returns:
#      1 - nicht vorhanden
#      2 - keine Leserechte
#      3 - kein unterstütztes Format
#      0 - Korrekt
#   Comments:
#      Alle Fehler haben den gleichen Rückgabewert da die Aktion
#      die danach folgt immer die selber ist und somit nicht
#      unterschieden werden muss
#-------------------------------------------------------------------------------
sub check_bild {
    my ($bild) = @_;
    if ( $bild ne $EMPTY ) {
        if ( !-e $bild ) {
            return 1;
        }
        elsif ( !-r $bild ) {
            return 2;
        }
        if ( !eval { my $i = $mw->Photo( -file => $bild ); 1 } ) {
            return 3;
        }
    }
    return 0;
}    # ----------  end of subroutine check_bild  ----------

#-------------------------------------------------------------------------------
#   Subroutine: check_bild_bind
#      Diese Funktion wird aufgerufen wenn irgendwo im Programm ein Pfad
#      zu einer Bild-datei angegeben wird. Wenn der Rückgabewert von check_bild()
#      ungleich 0 ist wird der Hintergrund des Eingabefeldes auf ein helles Rot
#      gesetzt um den Benutzer auf das Problem aufmerksam zu machen
#   Parameters:
#      $e_widget - Widget
#-------------------------------------------------------------------------------
sub check_bild_bind {
    my ($e_widget) = @_;

    my $bild = $e_widget->get();
    my $isok = check_bild($bild);

    if ( $isok == 1 ) {
        $e_widget->Dialog(
            -title   => 'Achtung',
            -text    => 'Bilddatei nicht gefunden',
            -buttons => ['OK'],
            -bitmap  => 'warning'
        )->Show();

    }
    elsif ( $isok == 2 ) {
        $e_widget->Dialog(
            -title   => 'Achtung',
            -text    => 'Keine Leserechte für die angegebene Datei.',
            -buttons => ['OK'],
            -bitmap  => 'warning'
        )->Show();

    }
    elsif ( $isok == 3 ) {

        $e_widget->Dialog(
            -title   => 'Achtung',
            -text    => 'Bildformat wird nicht unterstützt',
            -buttons => ['OK'],
            -bitmap  => 'warning'
        )->Show();

    }
    if ( $isok == 0 ) {
        $e_widget->configure( -background => 'gray85' );
    }
    else {
        $e_widget->configure( -background => '#ff9696' );   #(RGB)ein helles rot
    }
    return;
}    # ----------  end of subroutine check_bild_bind  ----------

#-------------------------------------------------------------------------------
#   Subroutine:  umbruch_entfernen
#
#   Alle Zeilenumbrüche aus String entfernen
#
#   Parameters:
#   $par1 - String
#-------------------------------------------------------------------------------
sub umbruch_entfernen {
    my ($par1) = @_;
    if ( defined ${$par1} ) {
        ${$par1} =~ s/\n/ /g;
    }
    return;
}    # ----------  end of subroutine umbruch_entfernen  ----------

#-------------------------------------------------------------------------------
#    Subroutine:  neues_projekt
#
#    Löscht alle Einträge
#-------------------------------------------------------------------------------

sub neues_projekt {

    #Details
#    $projekt{titel}   = $EMPTY;
#    $projekt{version} = $EMPTY;
    $projekt{autor}   = $EMPTY;
    $projekt{datum}   = $EMPTY;
    $projekt{status}  = $EMPTY;
    $projekt{kommentar}->Contents($EMPTY);

    #frame0
    ${ $projekt{zielbestimmungen} }->clear();
    %zielbestimmung = ();

    #frame1
    $projekt{produkteinsatz}->Contents($EMPTY);
    $projekt{zielgruppen}->Contents($EMPTY);
    $projekt{arbeitsbereiche}->Contents($EMPTY);
    $projekt{betriebsbedingungen}->Contents($EMPTY);

    #frame2
    undef ${ $projekt{produktuebersicht_bildbeschreibung} };
    undef ${ $projekt{produktuebersicht_bildpfad} };
    $projekt{produktuebersicht}->Contents($EMPTY);

    #frame3
    ${ $projekt{funktionen} }->clear();
    %funktionen = ();

    #frame4
    ${ $projekt{daten} }->clear();
    %daten = ();

    #frame5
    ${ $projekt{leistungen} }->clear();
    %leistungen = ();

    #frame6
    foreach my $key ( keys %{ $projekt{qualitaet} } ) {
        $projekt{qualitaet}->{$key} = $EMPTY;
    }

    #frame7
    ${ $projekt{gui} }->clear();
    %gui = ();

    #frame8
    $projekt{anforderungen}->Contents($EMPTY);

    #frame9
    $projekt{produktumgebung}->Contents($EMPTY);
    $projekt{software}->Contents($EMPTY);
    $projekt{hardware}->Contents($EMPTY);
    $projekt{orgware}->Contents($EMPTY);
    $projekt{schnittstellen}->Contents($EMPTY);

    #frame10
    $projekt{e_produktumgebung}->Contents($EMPTY);
    $projekt{e_software}->Contents($EMPTY);
    $projekt{e_schnittstellen}->Contents($EMPTY);
    $projekt{e_orgware}->Contents($EMPTY);
    $projekt{e_hardware}->Contents($EMPTY);

    #frame11
    $projekt{teilprodukte_beschreibung}->Contents($EMPTY);
    ${ $projekt{teilprodukte} }->clear();
    %teilprodukte = ();

    #frame12
    undef ${ $projekt{Ergaenzungen_Bild} };
    $projekt{Ergaenzungen_txt}->Contents($EMPTY);
    undef ${ $projekt{Ergaenzungen_bes} };

    #frame13
    ${ $projekt{testfaelle} }->clear();
    %testfaelle = ();

    #frame14
    ${ $projekt{glossar} }->clear();
    %glossar = ();

    return;
}

#-------------------------------------------------------------------------------
# Subroutine:  laden
#
#     Lädt die übergebene XML-Datei in den Arbeitsbereich
#-------------------------------------------------------------------------------
sub laden {
    my ($pfad) = @_;

    #    print "$pfad\n";
    neues_projekt();
    if ($pfad) {
        my $laden_xml     = MoliriXML->new($pfad);
        my $pflichtenheft = ();
        $pflichtenheft = $laden_xml->import_xml();

    #---------------------------------------------------------------------------
    #  Kapitel einlesen
    #---------------------------------------------------------------------------
        if ( scalar keys %{ ${$pflichtenheft}{'kfunktionen'} } ) {
            %funktionen_kapitel = %{ ${$pflichtenheft}{'kfunktionen'} };
        }
        if ( scalar keys %{ ${$pflichtenheft}{'kdaten'} } ) {
            %daten_kapitel = %{ ${$pflichtenheft}{'kdaten'} };
        }
        if ( scalar keys %{ ${$pflichtenheft}{'kleistungen'} } ) {
            %leistungen_kapitel = %{ ${$pflichtenheft}{'kleistungen'} };
        }

    #---------------------------------------------------------------------------
    #  Pflichtenheftdetails einlesen
    #---------------------------------------------------------------------------

        $projekt{'titel'}   = ${$pflichtenheft}{'details'}{'titel'};
        $projekt{'version'} = ${$pflichtenheft}{'details'}{'version'};
        $projekt{'autor'}   = ${$pflichtenheft}{'details'}{'autor'};
        $projekt{'datum'}   = ${$pflichtenheft}{'details'}{'datum'};
        $projekt{'status'}  = ${$pflichtenheft}{'details'}{'status'};
        $projekt{'kommentar'}
          ->Contents( ${$pflichtenheft}{'details'}{'kommentar'} );

    #---------------------------------------------------------------------------
    #  Zielbestimmungen einlesen
    #---------------------------------------------------------------------------
        foreach my $num ( keys %{ ${$pflichtenheft}{'zielbestimmungen'} } ) {
            ziel_tabelle_einfuegen(
                $projekt{zielbestimmungen},
                ${ ${$pflichtenheft}{'zielbestimmungen'} }{$num}[0],
                ${ ${$pflichtenheft}{'zielbestimmungen'} }{$num}[1],
                $num
            );
        }

    #---------------------------------------------------------------------------
    #  Produkteinsatz einlesen
    #---------------------------------------------------------------------------
        $projekt{'produkteinsatz'}
          ->Contents( ${$pflichtenheft}{'einsatz'}{'produkteinsatz'} );
        $projekt{'zielgruppen'}
          ->Contents( ${$pflichtenheft}{'einsatz'}{'zielgruppen'} );
        $projekt{'arbeitsbereiche'}
          ->Contents( ${$pflichtenheft}{'einsatz'}{'arbeitsbereiche'} );
        $projekt{'betriebsbedingungen'}
          ->Contents( ${$pflichtenheft}{'einsatz'}{'betriebsbedingungen'} );

    #---------------------------------------------------------------------------
    #  Produktübersicht
    #---------------------------------------------------------------------------
        ${ $projekt{produktuebersicht_bildbeschreibung} } =
          ${$pflichtenheft}{'uebersicht'}{'bildbeschreibung'};
        ${ $projekt{produktuebersicht_bildpfad} } =
          ${$pflichtenheft}{'uebersicht'}{'bildpfad'};
        $projekt{produktuebersicht}
          ->Contents( ${$pflichtenheft}{'uebersicht'}{'uebersicht'} );

    #---------------------------------------------------------------------------
    #  Funktionen einlesen
    #---------------------------------------------------------------------------
        foreach my $num ( keys %{ ${$pflichtenheft}{'funktionen'} } ) {
            funktion_tabelle_einfuegen(
                {
                    'table' => $projekt{funktionen},
                    'geschaeft' =>
                      ${ ${$pflichtenheft}{'funktionen'} }{$num}[0],
                    'ziel' => ${ ${$pflichtenheft}{'funktionen'} }{$num}[1],
                    'vor'  => ${ ${$pflichtenheft}{'funktionen'} }{$num}[2],
                    'nach_erfolg' =>
                      ${ ${$pflichtenheft}{'funktionen'} }{$num}[3],
                    'nach_fehl' =>
                      ${ ${$pflichtenheft}{'funktionen'} }{$num}[4],
                    'akteure'  => ${ ${$pflichtenheft}{'funktionen'} }{$num}[5],
                    'ereignis' => ${ ${$pflichtenheft}{'funktionen'} }{$num}[6],
                    'beschreibung' =>
                      ${ ${$pflichtenheft}{'funktionen'} }{$num}[7],
                    'erweiterung' =>
                      ${ ${$pflichtenheft}{'funktionen'} }{$num}[8],
                    'alternativen' =>
                      ${ ${$pflichtenheft}{'funktionen'} }{$num}[9],
                    'nummer'  => $num,
                    'kapitel' => suche_id( $num, \%funktionen_kapitel ),
                }
            );

            #            print "$num";
        }

    #---------------------------------------------------------------------------
    #  Daten einlesen
    #---------------------------------------------------------------------------

        foreach my $num ( keys %{ ${$pflichtenheft}{'daten'} } ) {
            datum_tabelle_einfuegen(
                {
                    'table'        => $projekt{'daten'},
                    'nummer'       => $num,
                    'bezeichnung'  => ${ ${$pflichtenheft}{'daten'} }{$num}[0],
                    'beschreibung' => ${ ${$pflichtenheft}{'daten'} }{$num}[1],
                    'kapitel'      => suche_id( $num, \%daten_kapitel ),
                }
            );
        }

    #---------------------------------------------------------------------------
    #  Leistung einlesen
    #---------------------------------------------------------------------------

        foreach my $num ( keys %{ ${$pflichtenheft}{'leistungen'} } ) {
            leistung_tabelle_einfuegen(
                {
                    'table'  => $projekt{'leistungen'},
                    'nummer' => $num,
                    'bezeichnung' =>
                      ${ ${$pflichtenheft}{'leistungen'} }{$num}[0],
                    'beschreibung' =>
                      ${ ${$pflichtenheft}{'leistungen'} }{$num}[1],
                    'kapitel' => suche_id( $num, \%leistungen_kapitel ),
                }
            );
        }

    #---------------------------------------------------------------------------
    #  Qualitätsanforderungen einlesen
    #---------------------------------------------------------------------------

        foreach my $key ( keys %{ ${$pflichtenheft}{'qualitaet'} } ) {
            $projekt{qualitaet}->{$key} = ${$pflichtenheft}{'qualitaet'}{$key};
        }

    #---------------------------------------------------------------------------
    #  GUI einlesen
    #---------------------------------------------------------------------------

        foreach my $num ( keys %{ ${$pflichtenheft}{'gui'} } ) {
            gui_tabelle_einfuegen(
                {
                    'table'       => $projekt{'gui'},
                    'nummer'      => $num,
                    'bezeichnung' => ${ ${$pflichtenheft}{'gui'} }{$num}[0],
                    'bildpfad'    => ${ ${$pflichtenheft}{'gui'} }{$num}[1],
                    'bildbeschreibung' =>
                      ${ ${$pflichtenheft}{'gui'} }{$num}[2],
                    'beschreibung' => ${ ${$pflichtenheft}{'gui'} }{$num}[3],
                    'rollen'       => ${ ${$pflichtenheft}{'gui'} }{$num}[4],
                }
            );
        }

    #---------------------------------------------------------------------------
    #  Nichtfunktionale Anforderung einlesen
    #---------------------------------------------------------------------------
        $projekt{'anforderungen'}
          ->Contents( ${$pflichtenheft}{'nfanforderungen'} );

    #---------------------------------------------------------------------------
    #  Technische Umgebung einlesen
    #---------------------------------------------------------------------------
        $projekt{'produktumgebung'}
          ->Contents( ${$pflichtenheft}{'tumgebung'}{'produktumgebung'} );
        $projekt{'software'}
          ->Contents( ${$pflichtenheft}{'tumgebung'}{'software'} );
        $projekt{'hardware'}
          ->Contents( ${$pflichtenheft}{'tumgebung'}{'hardware'} );
        $projekt{'orgware'}
          ->Contents( ${$pflichtenheft}{'tumgebung'}{'orgware'} );
        $projekt{'schnittstellen'}
          ->Contents( ${$pflichtenheft}{'tumgebung'}{'schnittstellen'} );

    #---------------------------------------------------------------------------
    #  Entwicklungsumgebung einlesen
    #---------------------------------------------------------------------------

        $projekt{'e_produktumgebung'}
          ->Contents( ${$pflichtenheft}{'eumgebung'}{'produktumgebung'} );
        $projekt{'e_software'}
          ->Contents( ${$pflichtenheft}{'eumgebung'}{'software'} );
        $projekt{'e_hardware'}
          ->Contents( ${$pflichtenheft}{'eumgebung'}{'hardware'} );
        $projekt{'e_orgware'}
          ->Contents( ${$pflichtenheft}{'eumgebung'}{'orgware'} );
        $projekt{'e_schnittstellen'}
          ->Contents( ${$pflichtenheft}{'eumgebung'}{'schnittstellen'} );

    #---------------------------------------------------------------------------
    #  Teilprodukte einlesen
    #---------------------------------------------------------------------------
        $projekt{'teilprodukte_beschreibung'}
          ->Contents( ${$pflichtenheft}{'teilprodukte_beschreibung'} );

        foreach my $num ( keys %{ ${$pflichtenheft}{'teilprodukte'} } ) {
            teilprodukt_tabelle_einfuegen(
                $projekt{'teilprodukte'},
                ${ ${$pflichtenheft}{'teilprodukte'} }{$num}[0],
                ${ ${$pflichtenheft}{'teilprodukte'} }{$num}[1],
                $num,
            );
        }

    #---------------------------------------------------------------------------
    #  Produktergänzung
    #---------------------------------------------------------------------------

        ${ $projekt{'Ergaenzungen_Bild'} } =
          ${$pflichtenheft}{'pergaenzungen'}{'bildpfad'};
        ${ $projekt{'Ergaenzungen_bes'} } =
          ${$pflichtenheft}{'pergaenzungen'}{'bildbeschreibung'};
        $projekt{'Ergaenzungen_txt'}
          ->Contents( ${$pflichtenheft}{'pergaenzungen'}{'ergaenzungen'} );

    #---------------------------------------------------------------------------
    #  Testfaelle
    #---------------------------------------------------------------------------

        foreach my $num ( keys %{ ${$pflichtenheft}{'testfaelle'} } ) {
            testfall_tabelle_einfuegen(
                {
                    'table'  => $projekt{'testfaelle'},
                    'nummer' => $num,
                    'bezeichnung' =>
                      ${ ${$pflichtenheft}{'testfaelle'} }{$num}[0],
                    'vorbedingung' =>
                      ${ ${$pflichtenheft}{'testfaelle'} }{$num}[1],
                    'beschreibung' =>
                      ${ ${$pflichtenheft}{'testfaelle'} }{$num}[2],
                    'sollverhalten' =>
                      ${ ${$pflichtenheft}{'testfaelle'} }{$num}[3],
                }
            );
        }

    #---------------------------------------------------------------------------
    #  Glossar
    #---------------------------------------------------------------------------

        foreach my $num ( keys %{ ${$pflichtenheft}{'glossar'} } ) {
            glossar_tabelle_einfuegen( $projekt{'glossar'}, $num,
                ${ ${$pflichtenheft}{'glossar'} }{$num}[0],
            );
        }

    }
    else {
        print "Keinen Pfad angegeben, Programm wird beendet\n";

        exit;
    }
    return;
}    # ----------  end of subroutine laden  ----------

#-------------------------------------------------------------------------------
# Subroutine:  speichern
#
#     Speichert den Arbeitsbereich als XML-Datei
#-------------------------------------------------------------------------------
sub speichern {
    my $speichern_xml = MoliriXML->new($xml_pfad);
    $speichern_xml->export_xml(
        {
            Titel     => $projekt{titel},
            Version   => $projekt{version},
            Autor     => $projekt{autor},
            Datum     => $projekt{datum},
            Status    => $projekt{status},
            Kommentar => $projekt{kommentar}->get( '1.0', 'end -1 chars' ),
            Zielbestimmungen => \%zielbestimmung,
            Produkteinsatz =>
              $projekt{produkteinsatz}->get( '1.0', 'end -1 chars' ),
            Zielgruppen => $projekt{zielgruppen}->get( '1.0', 'end -1 chars' ),
            Arbeitsbereiche =>
              $projekt{arbeitsbereiche}->get( '1.0', 'end -1 chars' ),
            Betriebsbedingungen =>
              $projekt{betriebsbedingungen}->get( '1.0', 'end -1 chars' ),
            Puebersicht_Bildbeschreibung =>
              $projekt{produktuebersicht_bildbeschreibung},
            Puebersicht_Bildpfad => $projekt{produktuebersicht_bildpfad},
            Puebersicht =>
              $projekt{produktuebersicht}->get( '1.0', 'end -1 chars' ),
            Funktionen => \%funktionen,
            Daten      => \%daten,
            Leistungen => \%leistungen,
            Qualitaet  => $projekt{qualitaet},
            GUI        => \%gui,
            Anforderungen =>
              $projekt{anforderungen}->get( '1.0', 'end -1 chars' ),
            T_Produktumgebung =>
              $projekt{produktumgebung}->get( '1.0', 'end -1 chars' ),
            T_Software => $projekt{software}->get( '1.0', 'end -1 chars' ),
            T_Hardware => $projekt{hardware}->get( '1.0', 'end -1 chars' ),
            T_Orgware  => $projekt{orgware}->get( '1.0',  'end -1 chars' ),
            T_Schnittstellen =>
              $projekt{schnittstellen}->get( '1.0', 'end -1 chars' ),
            E_Produktumgebung =>
              $projekt{e_produktumgebung}->get( '1.0', 'end -1 chars' ),
            E_Software => $projekt{e_software}->get( '1.0', 'end -1 chars' ),
            E_Schnittstellen =>
              $projekt{e_schnittstellen}->get( '1.0', 'end -1 chars' ),
            E_Orgware  => $projekt{e_orgware}->get( '1.0',  'end -1 chars' ),
            E_Hardware => $projekt{e_hardware}->get( '1.0', 'end -1 chars' ),
            Teilprodukte_Beschreibung =>
              $projekt{teilprodukte_beschreibung}->get( '1.0', 'end -1 chars' ),
            Teilprodukte                  => \%teilprodukte,
            Ergaenzungen_Bild             => $projekt{Ergaenzungen_Bild},
            Ergaenzungen_Bildbeschreibung => $projekt{Ergaenzungen_bes},
            Ergaenzungen =>
              $projekt{Ergaenzungen_txt}->get( '1.0', 'end -1 chars' ),
            Testfaelle         => \%testfaelle,
            Glossar            => \%glossar,
            Kapitel_Funktion   => \%funktionen_kapitel,
            Kapitel_Daten      => \%daten_kapitel,
            Kapitel_Leistungen => \%leistungen_kapitel,
        }
    );
    set_aendern(1);
    return;
}    # ----------  end of subroutine speichern  ----------

