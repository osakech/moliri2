#===============================================================================
#
# Class: MoliriODT.pm
#
#  Diese Klasse ist für den Export ins ODT-Format zuständig.
#
#   *Benutzt folgende Module*
#     - Image::Size        -- <http://search.cpan.org/~rjray/Image-Size-3.220/>
#     - OpenOffice::OODoc  -- <http://search.cpan.org/~jmgdoc/OpenOffice-OODoc-2.112/>
#
#  >Autor:       Alexandros Kechagias (Alexandros.Kechagias@gmx.de)
#  >Firma:       Fachhochschule Südwestfalen
#  >Version:     1.0
#  >Erstellt am: 19.07.2011 17:19:05
#  >Revision:    0.2
#===============================================================================

package MoliriODT;

use strict;
use utf8;
use warnings;
use OpenOffice::OODoc;
odfLocalEncoding 'utf8';
use Image::Size;
use Encode;
use English qw( -no_match_vars );
use Data::Dumper;
use Cwd;
use lib Cwd::cwd() . '/lib';    # /lib-Ordner einbinden

#---------------------------------------------------------------------------
#  Subroutine: new
#
#  Konstruktor, kriegt den Pfad zur ODT-Datei
#---------------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self  = {
        _pfad  => shift,
        kap_no => 1
    };
    bless $self, $class;
    return $self;
}                               # ----------  end of subroutine new  ----------

#---------------------------------------------------------------------------
#  Subroutine: set_styles
#
#  Setzt Styles für die einzelnen Elemente des ODF-Dokuments
#---------------------------------------------------------------------------
sub set_styles {
    my ( $self, $doc ) = @_;

    $doc->createStyle(
        'fett',
        family     => 'text',
        properties => { 'fo:font-weight' => 'bold' }
    );

    $doc->createStyle(
        'einschub_typ',
        family     => 'paragraph',
        properties => { 'fo:margin-left' => '1cm' }

    );

    $doc->createStyle(
        'einschub_inhalt',
        family     => 'paragraph',
        properties => { 'fo:margin-left' => '2cm' }

    );

    $doc->createStyle(
        'bbeschreibung',
        family     => 'text',
        properties => {
            'fo:font-size'  => '10',
            'fo:font-style' => 'italic',
        },
    );

    $doc->createStyle(
        'einschub_uschrift',
        family     => 'paragraph',
        properties => { 'fo:margin-left' => '1cm' }
    );

    $doc->createImageStyle(
        'bild',
        family     => 'graphics',
        properties => { 'fo:margin-left' => '1cm' }
    );
    return;
}    # ----------  end of subroutine set_styles  ----------

#---------------------------------------------------------------------------
#  Subroutine: export_odt
#
#  Dies ist die einzige Funktion auf die das Hauptprogramm zugreift. Im 
#  Konstruktor wird der Pfad zum gewünschten Exportziel angegeben
#
#  Parameters: 
#     %ref_pflicht - Hash mit Pflichtenheft
#
#---------------------------------------------------------------------------
sub export_odt {
    my ( $self, %ref_pflicht ) = @_;
    # Gewünschter Exportpfad
    my $ausgabe = $self->{'_pfad'};    # output file name
    # Die Templatedatei
    my $template = Cwd::cwd() . '/template/moliri-template.odt';
    my $doc = odfDocument( 'file' => $template );


    # Styles werden übernommen
    $self->set_styles($doc);
    # Den einzelnen Funktionen werden wird eine Referenz
    # auf das Pflichtenheft und der Filehandler übergeben
    $self->titel( \%ref_pflicht, $doc );
    $self->ziele( \%ref_pflicht, $doc );
    $self->produkteinsatz( \%ref_pflicht, $doc );
    $self->puebersicht( \%ref_pflicht, $doc );
    $self->funktionen( \%ref_pflicht, $doc );
    $self->daten( \%ref_pflicht, $doc );
    $self->leistungen( \%ref_pflicht, $doc );
    $self->qualitaet( \%ref_pflicht, $doc );
    $self->gui( \%ref_pflicht, $doc );
    $self->nfkt_anforderungen( \%ref_pflicht, $doc );
    $self->tech_umgebung( \%ref_pflicht, $doc );
    $self->entw_umgebung( \%ref_pflicht, $doc );
    $self->teilprodukte( \%ref_pflicht, $doc );
    $self->ergaenzungen( \%ref_pflicht, $doc );
    $self->testfaelle( \%ref_pflicht, $doc );
    $self->glossar( \%ref_pflicht, $doc );

    # odt speichern
    if ( $ausgabe !~ /\.odt$/ ) {
        $ausgabe = $ausgabe . '.odt';
    }
    $doc->save($ausgabe);

    my $meta = odfMeta( file => $ausgabe );

    my $titel   = encode_utf8( $ref_pflicht{'details'}{'titel'});
    my $version = encode_utf8( $ref_pflicht{'details'}{'version'});
    my $autor   = encode_utf8( $ref_pflicht{'details'}{'autor'});
    # Metadaten ändern
    $meta->initial_creator( $autor );
    $meta->title( encode_utf8( $titel.' '.$version) );
    $meta->save($ausgabe);

    return ();
}

#---------------------------------------------------------------------------
#  Subroutine: titel
#
#  Fügt die Pflichtenheftdetails ein.
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#---------------------------------------------------------------------------
sub titel {
    my ( $self, $ref_pflicht, $doc ) = @_;
    # Alle Elemente müssen explizit nach demn einlesen
    # als utf8 codiert werden.
    my @elemente = map { encode_utf8($ARG) } (
        ${$ref_pflicht}{'details'}{'titel'},
        ${$ref_pflicht}{'details'}{'version'},
        ${$ref_pflicht}{'details'}{'autor'},
        ${$ref_pflicht}{'details'}{'datum'},
        ${$ref_pflicht}{'details'}{'status'},
        ${$ref_pflicht}{'details'}{'kommentar'},
    );
    
    # Exportdatum
    my @loc = localtime;
    my $jahr = $loc[5]+1900;
    my $monat = $loc[4]+1;
    my $tag = $loc[3];
    my $exdatum = "$jahr-$monat-$tag";

    # Alle Elemente im Template nach dem String der zwischen
    # den Klammern steht durchsuchen und durch die Pflichtenheft-
    # details erstezen
    $doc->selectElementsByContent( '<titel>',   $elemente[0] );
    $doc->selectElementsByContent( '<version>', $elemente[1] );
    $doc->selectElementsByContent( '<autor>',   $elemente[2] );
    $doc->selectElementByContent( '<datum>',   $elemente[3] );
    $doc->selectElementByContent( '<status>',  $elemente[4] );
    $doc->selectElementByContent( '<exdatum>',  $exdatum );
    return;
}    # ----------  end of subroutine titel  ----------

#---------------------------------------------------------------------------
#  Subroutine: ziele
#
#  Fügt die Ziele ein
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#---------------------------------------------------------------------------
sub ziele {
    my ( $self, $ref_pflicht, $doc ) = @_;

    # Referenz auf Hash mit Zielbestimmungen
    my $ref_ziele  = ${$ref_pflicht}{'zielbestimmungen'};
    my @keys_ziele = keys %{$ref_ziele};

    # Es wird getestet ob Keys vorhanden sind
    if ( test_empty( \@keys_ziele ) ) {
        # Überschrift hinzufügen
        my $sec = $doc->appendHeading(
            text  => $self->{'kap_no'} . ' Zielbestimmungen',
            style => 'Heading 1'
        );
        my @musskriterien;
        my @wunschkriteri;
        my @abgrenzungskr;
        # Sortiere die Ziele in Musskriterien, Wunschkriterien 
        # und Abgrenzungskriterien 
        foreach my $key (@keys_ziele) {
            my @inhalt = map { encode_utf8($ARG) } @{ ${$ref_ziele}{$key} };
            if ( test_empty( $inhalt[1] ) ) {
                if ( $inhalt[0] eq 'Musskriterium' ) {
                    push @musskriterien, $key;
                }
                if ( $inhalt[0] eq 'Wunschkriterium' ) {
                    push @wunschkriteri, $key;
                }
                if ( $inhalt[0] eq 'Abgrenzungskriterium' ) {
                    push @abgrenzungskr, $key;
                }
            }
        }

    #---------------------------------------------------------------------------
    #  Musskriterien
    #---------------------------------------------------------------------------
        # Zuerst wird ein leerer Absatz eingefügt 
        $doc->appendParagraph();
        # Ein Absatz vom Style-Typ 'einschub_typ'
        my $tmp = $doc->appendParagraph(
            text  => q{},
            style => 'einschub_typ',
        );
        # Dieser Absatz wird nun erweitert mit dem Style-Typ 'fett' und dem
        # Inhalt 'Musskriterium'
        $doc->extendText( $tmp, 'Musskriterien', 'fett' );
        # Die beiden Schritte sind notwendig, da man einen Absatz nicht 
        # gleichzeitig mit einem Style von der Familie 'font' und 'paragraph'
        # bestücken kann.

        # Hier wird eine Liste eingefügt
        my $liste = $doc->appendItemList();
        # Diese Liste wird gefüllt mit den Musskriterien
        # Auf die einzelnen Elemente wird mit den vorhin sortierten Keys 
        # zugegriffen
        foreach my $key (@musskriterien) {
            my @inhalt = map { encode_utf8($ARG) } @{ ${$ref_ziele}{$key} };
            # Listenelement hinzufügen
            $doc->appendListItem( $liste, text => $inhalt[1] );
        }

    #---------------------------------------------------------------------------
    #  Wunschkriterien
    #---------------------------------------------------------------------------
        # siehe Musskriterien
        $doc->appendParagraph();
        $tmp = $doc->appendParagraph(
            text  => q{},
            style => 'einschub_typ',
        );
        $doc->extendText( $tmp, 'Wunschkriterien', 'fett' );
        $liste = $doc->appendItemList();

        foreach my $key (@wunschkriteri) {
            my @inhalt = map { encode_utf8($ARG) } @{ ${$ref_ziele}{$key} };
            $doc->appendListItem( $liste, text => $inhalt[1] );
        }

    #---------------------------------------------------------------------------
    #  Abgrenzungskriterien
    #---------------------------------------------------------------------------
        # siehe Musskriterien
        $doc->appendParagraph();
        $tmp = $doc->appendParagraph(
            text  => q{},
            style => 'einschub_typ',
        );
        $doc->extendText( $tmp, 'Abgrenzungskriterien', 'fett' );
        $liste = $doc->appendItemList();

        foreach my $key (@abgrenzungskr) {
            my @inhalt = map { encode_utf8($ARG) } @{ ${$ref_ziele}{$key} };
            $doc->appendListItem( $liste, text => $inhalt[1] );
        }
        
        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        #Kapitelnummer iteriern
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine Ziele  ----------

#---------------------------------------------------------------------------
#  Subroutine: test_empty
#
#  Testet den übergebenen Array oder Skalar ob er leer ist. 
#---------------------------------------------------------------------------
sub test_empty {
    my ($par1) = @_;
    my $res;
    if ( ref($par1) eq 'ARRAY' ) {
        # Das Resultat ist leer wenn das Array leer ist
        $res = join q{}, map { trimm($ARG) } @{$par1};

    }
    else {
        # Wenn die variable nur aus Leerzeichen besteht, ist das 
        # Resultat ''
        $res = trimm($par1);
    }
    # fängt ab wenn ID = 0 ist.
    if ( defined $res and $res eq '0' ) {    
        $res = q{OK};
    }
    return $res;
}    # ----------  end of subroutine test_array_empty  ----------

#---------------------------------------------------------------------------
#  Subroutine: produkteinsatz
#  
#  Fügt den Punkt Produkteinsatz hinzu
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#
#---------------------------------------------------------------------------
sub produkteinsatz {
    my ( $self, $ref_pflicht, $doc ) = @_;
    # Elemente in UTF-8 encodieren
    my @elemente = map { encode_utf8($ARG) } (
        ${$ref_pflicht}{'einsatz'}{'produkteinsatz'},
        ${$ref_pflicht}{'einsatz'}{'zielgruppen'},
        ${$ref_pflicht}{'einsatz'}{'arbeitsbereiche'},
        ${$ref_pflicht}{'einsatz'}{'betriebsbedingungen'},
    );
    # Teste ob Elemente vorhanden
    if ( test_empty( \@elemente ) ) {
        # Füge Überschrift ein
        my $sec = $doc->appendHeading(
            text  => $self->{'kap_no'} . '. Produkteinsatz',
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        my @titel = qw{ Zielgruppen Arbeitsbereiche Betriebsbedingungen };
        
        # Erstes Element braucht keine Kennung da es den Produkteinsatz
        # selber beschreibt
        $doc->appendParagraph(
            text  => $elemente[0],
            style => 'einschub_typ',
        );
        for ( 1 .. $#titel ) {
            # Nur vorhandene Elemente schreiben, damit keine leeren
            # Einträge enstehen
            if ( test_empty( $elemente[$ARG] ) ) {
                # Einschub
                my $para = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                # Kennung
                $doc->extendText( $para, $titel[ $ARG - 1 ], 'fett' );
                # Inhalt
                $doc->appendParagraph(
                    text  => $elemente[$ARG],
                    style => 'einschub_inhalt',
                );
            }
        }
        # Kapitel iterieren
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine produkteinsatz  ----------

#---------------------------------------------------------------------------
#  Subroutine: puebersicht
#
#  Fügt die Produktübersicht ein.
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#
#---------------------------------------------------------------------------
sub puebersicht {
    my ( $self, $ref_pflicht, $doc ) = @_;
    my $bildpfad      = ${$ref_pflicht}{'uebersicht'}{'bildpfad'};
    my $bbeschreibung = ${$ref_pflicht}{'uebersicht'}{'bildbeschreibung'};
    my $uebersicht = encode_utf8( ${$ref_pflicht}{'uebersicht'}{'uebersicht'} );
    # Wenn Bild eingefügt oder Programmübersicht ausgefüllt
    if ( test_empty($bildpfad) or test_empty($uebersicht) ) {
        # Erstelle den Titel
        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. Produktübersicht' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        # Wenn Bild eingefügt
        if ( test_empty($bildpfad) ) {
            # Füge Bild ein
            $self->bild_einfuegen( $bildpfad, $bbeschreibung, $doc );
        }
        
        # Wenn Programmübersicht angegeben
        if ( test_empty($uebersicht) ) {
            # Erstelle die Programmübersicht
            $doc->appendParagraph(
                text  => $uebersicht,
                style => 'einschub_typ',
            );
        }

        # Kapitel iterieren
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine Ziele  ----------

#---------------------------------------------------------------------------
#  Subroutine: bild_einfuegen
#  
#  Fügt Bild mit Beschreibung ein
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#---------------------------------------------------------------------------
sub bild_einfuegen {
    my ( $self, $bildpfad, $bbeschreibung, $doc ) = @_;
    
    # Wenn Bildpfad angegeben
    if ($bildpfad) {

        # Eventuell Bildgrösse anpassen
        my ( $x, $y ) = $self->bild_anpassen($bildpfad);

        # Bild einfügen
        my $image = $doc->createImageElement(
            'Bild_Übersicht',
            style => 'bild',
            size  => $x . 'pt, ' . $y . ' pt',
            link  => $bildpfad,
        );

        # Wenn Bildbeschreibung vorhanden
        if ($bbeschreibung) {
            $bbeschreibung = encode_utf8($bbeschreibung);
            # Bildbeschreibung von Style-Typ 'bbeschreibung' verwenden
            my $para =
              $doc->appendParagraph( text => q{}, style => 'einschub_typ' );
            $doc->extendText( $para, $bbeschreibung, 'bbeschreibung' );
            $doc->appendParagraph();
        }
    }
    return;
}    # ----------  end of subroutine bild_einfuegen  ----------

#---------------------------------------------------------------------------
#  Subroutine: bild_anpassen
#
#  Bildmaße ermitteln und eventuell anpassen
#
#  Parameters: 
#
#   $bildpfad - Pfad zum Bilddatei
#
#  Return:
#   new_x - Seitenbreite
#   new_y - Seitenhöhe
#
#---------------------------------------------------------------------------
sub bild_anpassen {
    my ( $self, $bildpfad ) = @_;
    # Bildhöhe und -breite ermitteln
    my ( $x,    $y )        = imgsize($bildpfad);
    my ( $new_x, $new_y, $ratio );
    # Bildverhältnis ausrechnen
    $ratio = $x / $y;

    #---------------------------------------------------------------------------
    #  max breite: 425
    #  max hoehe: 690
    #---------------------------------------------------------------------------

    # Wenn die maximal zulässige Breite überschritten wird, dann setze
    # das Bild auf die maximale Breite und passe die Höhe im richtigen
    # Seitenverhältniss an.
    #
    # Mache das gleiche auch für die Höhe

    if ( $x > 425 ) { 
        $new_x = 425;
        $new_y = $new_x / $ratio;
        $new_y = int $new_y;
    }
    elsif ( $y > 690 ) {
        $new_y = 690;
        $new_x = $new_y * $ratio;
        $new_x = int $new_x;
    }
    # Ansonsten passt das Bild und soll nich verädert werden.
    else {
        $new_x = $x;
        $new_y = $y;
    }

    return ( $new_x, $new_y );
}    # ----------  end of subroutine bild_anpassen  ----------

#---------------------------------------------------------------------------
#  Subroutine: funktionen
#
#  Fügt die Überschriften ein und sortiert die einzelnen Einträge. Einträge werden
#  werden über <funktion_einfuegen> eingefügt
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#---------------------------------------------------------------------------
sub funktionen {
    my ( $self, $ref_pflicht, $doc ) = @_;
    my @keys_funktionen = keys %{ ${$ref_pflicht}{'funktionen'} };
    my @keys_kapitel    = keys %{ ${$ref_pflicht}{'kfunktionen'} };
    
    # Teste ob Funktionen vorhaden sind
    if ( test_empty( \@keys_funktionen ) ) {

        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. Funktionen' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        my %funk_in_kapitel = ();
        my %funk_sonst      = ();

    #---------------------------------------------------------------------------
    #  Sortieren: Wenn Funktion in einem kapitel auftaucht dann mit Kapitel-
    #  bezeichnung und Nummer in %funk_in_kapitel speihern
    #
    #  Ansonsten in %funk_sonst
    #---------------------------------------------------------------------------
        foreach my $key (@keys_funktionen) {
            my $kapitel = $self->suche_id( $key, ${$ref_pflicht}{'kfunktionen'} );
            if ($kapitel) {
                $funk_in_kapitel{$kapitel}{$key} = $key;
            }
            else {
                $funk_sonst{'Sonstige'}{$key} = $key;
            }
        }

        my @titel = map { encode_utf8($ARG) } (
            'Nummer:',        'Geschäftsprozess:',
            'Ziel:',          'Vorbedingung:',
            'Nachb. Erfolg:', 'Nachb. Fehlschlag:',
            'Akteure:',       'Auslösendes Ereignis:',
            'Beschreibung:',  'Erweiterung:',
            'Alternativen:',
        );
        # Unterkapitel werden ebenfalls nummeriert
        my $u_kapitel = 1;

    #---------------------------------------------------------------------------
    #  Funktionen im Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_in_kapitel ) {
            my $kapitel = encode_utf8($ARG);
            $doc->appendHeading(
                text  => encode_utf8( $self->{'kap_no'} . ".$u_kapitel $ARG" ),
                style => 'Heading 2'
            );

            my @sort_kapitel = sort keys %{ $funk_in_kapitel{$ARG} };
            $self->funktion_einfuegen( $doc, $ref_pflicht, \@sort_kapitel,
                \@titel );

            $u_kapitel++;
        }

    #---------------------------------------------------------------------------
    #  Funktionen in keinem Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_sonst ) {
            my $kapitel = encode_utf8($ARG);
            # Wenn Funktionen bereits in einem Kapitel stehen, dann ist $u_kapitel > 1
            # Wenn nicht, brauchen wie keine Überschrift für Sonstige
            if ( $u_kapitel > 1 ) {
                $doc->appendHeading(
                    text =>
                      encode_utf8( $self->{'kap_no'} . ".$u_kapitel $ARG" ),
                    style => 'Heading 2'
                );
            }
            my @sort_kapitel = sort keys %{ $funk_sonst{$ARG} };
            $self->funktion_einfuegen( $doc, $ref_pflicht, \@sort_kapitel,
                \@titel );
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine funktionen  ----------

#---------------------------------------------------------------------------
#  Subroutine: funktion_einfuegen
#
#  Fügt die einzelnen Funktions-Einträge ein
#
#  Parameters: 
#   $ref_pflicht      - Referenz auf Hash mit Pflichtenheft
#   $doc              - Filehandler
#   $ref_sort_kapitel - Kapitelnummern in Array
#   $ref_titel        - Titel in Array
#---------------------------------------------------------------------------
sub funktion_einfuegen {
    my ( $self, $doc, $ref_pflicht, $ref_sort_kapitel, $ref_titel ) = @_;
    my @sort_kapitel = @{$ref_sort_kapitel};
    my @titel        = @{$ref_titel};

    foreach my $f (@sort_kapitel) {

        my $ref_funktion = ${ ${$ref_pflicht}{'funktionen'} }{$f};

        # Funktionsinhalt herauskopieren encodieren und in Array speichern
        my @funktion = map { encode_utf8($ARG) } @{$ref_funktion};
        
        # Fügt leere Zeile ein
        $doc->appendParagraph();

        # Absatz mit Einschub einfügen
        my $tmp = $doc->appendParagraph(
            text  => q{},
            style => 'einschub_typ',
        );
        

        #---------------------------------------------------------------------------
        #  Titel     :  2xTab   Funktionsnummer 
        #  $titel[0] :  "\t\t"  $f
        #---------------------------------------------------------------------------
        # Elementtitel mit fetter Schrift
        $doc->extendText( $tmp, $titel[0], 'fett' );

        # Elementinhalt mit normaler Schrift
        $doc->extendText( $tmp, encode_utf8( "\t\t" . $f ), 'default' );

        

        #  Ab jetzt werden Funktionselemente nur noch eingefügt wenn sie existieren
        if ( test_empty( $funktion[0] ) ) {
        #---------------------------------------------------------------------------
        #     Einschub->  Titel     :  Tab   Inhalt
        #  'einschub_typ' $titel[0] :  "\t"  $funktion[0];
        #---------------------------------------------------------------------------
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[1],           'fett' );
            $doc->extendText( $tmp, "\t" . $funktion[0], 'default' );
        }
        if ( test_empty( $funktion[1] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[2], 'fett' );
            $doc->extendText( $tmp, "\t\t\t" . $funktion[1], 'default' );
        }
        if ( test_empty( $funktion[2] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[3],           'fett' );
            $doc->extendText( $tmp, "\t" . $funktion[2], 'default' );
        }
        if ( test_empty( $funktion[3] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[4],           'fett' );
            $doc->extendText( $tmp, "\t" . $funktion[3], 'default' );
        }
        if ( test_empty( $funktion[4] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[5],           'fett' );
            $doc->extendText( $tmp, "\t" . $funktion[4], 'default' );
        }
        if ( test_empty( $funktion[5] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[6],             'fett' );
            $doc->extendText( $tmp, "\t\t" . $funktion[5], 'default' );
        }
        if ( test_empty( $funktion[6] ) ) {
        #---------------------------------------------------------------------------
        #  Titel:
        #     Inhalt
        #
        #  'einschub_typ' -> $titel[7]  
        #
        #  'einschub_inhalt' ->  $funktion[6];
        #---------------------------------------------------------------------------
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[7], 'fett' );
            $doc->appendParagraph(
                text  => $funktion[6],
                style => 'einschub_inhalt'
            );
        }
        if ( test_empty( $funktion[7] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[8], 'fett' );
            $doc->appendParagraph(
                text  => $funktion[7],
                style => 'einschub_inhalt'
            );
        }
        if ( test_empty( $funktion[8] ) ) {

            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[9], 'fett' );
            $doc->appendParagraph(
                text  => $funktion[8],
                style => 'einschub_inhalt'
            );
        }
        if ( test_empty( $funktion[9] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[10], 'fett' );
            $doc->appendParagraph(
                text  => $funktion[9],
                style => 'einschub_inhalt'
            );
        }
    }
    return;
}    # ----------  end of subroutine funktion_einfuegen  ----------

#-------------------------------------------------------------------------------
#     Subroutine: suche_id
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
    my ( $self, $id, $kapitel_ref ) = @_;    #gesuchte id und hash von Kapiteln

    foreach my $k ( keys %{$kapitel_ref} ) {
        if ( exists ${ ${$kapitel_ref}{$k} }{$id} ) {
            return ($k);
        }
    }
    return;
}    # ----------  end of subroutine suche_id  ----------

#---------------------------------------------------------------------------
#  Subroutine: daten
#
#  Fügt die Überschriften ein und sortiert die einzelnen Einträge. Einträge werden
#  werden über <datum_einfuegen> eingefügt
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#
# See Also: 
#   Funktionsgleich mit <funktionen>
#
#---------------------------------------------------------------------------
sub daten {
    my ( $self, $ref_pflicht, $doc ) = @_;

    my @keys_funktionen = keys %{ ${$ref_pflicht}{'daten'} };
    my @keys_kapitel    = keys %{ ${$ref_pflicht}{'kdaten'} };
    if ( test_empty(@keys_funktionen) ) {
        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. Daten' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        my %funk_in_kapitel = ();
        my %funk_sonst      = ();

    #---------------------------------------------------------------------------
    #  sortieren
    #---------------------------------------------------------------------------
        foreach my $k (@keys_funktionen) {
            my $fff = suche_id( $k, ${$ref_pflicht}{'kdaten'} );
            if ($fff) {
                $funk_in_kapitel{$fff}{$k} = $k;
            }
            else {
                $funk_sonst{'Sonstige'}{$k} = $k;
            }
        }

        my @titel =
          map { encode_utf8($ARG) }
          ( 'Nummer:', 'Bezeichnung:', 'Beschreibung:' );

        my $u_kapitel = 1;

#---------------------------------------------------------------------------
#  Funktionen im Kapitel
#---------------------------------------------------------------------------

        foreach ( sort keys %funk_in_kapitel ) {
            my $kapitel = encode_utf8($ARG);
            $doc->appendHeading(
                text  => encode_utf8( $self->{'kap_no'} . ".$u_kapitel $ARG" ),
                style => 'Heading 2'
            );

            my @sort_kapitel = sort keys %{ $funk_in_kapitel{$ARG} };
            $self->datum_einfuegen( $doc, $ref_pflicht, \@sort_kapitel,
                \@titel );
            $u_kapitel++;
        }

    #---------------------------------------------------------------------------
    #  Funktionen in keinem Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_sonst ) {
            my $kapitel = encode_utf8($ARG);
            if ( $u_kapitel > 1 ) {
                $doc->appendHeading(
                    text =>
                      encode_utf8( $self->{'kap_no'} . ".$u_kapitel $ARG" ),
                    style => 'Heading 2'
                );
            }
            my @sort_kapitel = sort keys %{ $funk_sonst{$ARG} };
            $self->datum_einfuegen( $doc, $ref_pflicht, \@sort_kapitel,
                \@titel );
        }

        $self->{'kap_no'}++;
    }
    return;
}

#---------------------------------------------------------------------------
#  Subroutine: datum_einfuegen
#   
#    Fügt die einzelnen Datums-Einträge ein
#
#  Parameters: 
#   $ref_pflicht      - Referenz auf Hash mit Pflichtenheft
#   $doc              - Filehandler
#   $ref_sort_kapitel - Kapitelnummern in Array
#   $ref_titel        - Titel in Array
#
#  See Also: 
#   Funktionsgleich mit funktion_einfuegen
#---------------------------------------------------------------------------
sub datum_einfuegen {
    my ( $self, $doc, $ref_pflicht, $ref_sort_kapitel, $ref_titel, $leistung ) =
      @_;

    my @sort_kapitel = @{$ref_sort_kapitel};
    my @titel        = @{$ref_titel};

    foreach my $f (@sort_kapitel) {
        my $funktion;
        # Da die Datenstruktur von Daten und Leistungen identisch ist, wird die
        # selbe Funktion benutzt.
        if ($leistung) {
            $funktion = ${ ${$ref_pflicht}{'leistungen'} }{$f};
        }
        else {
            $funktion = ${ ${$ref_pflicht}{'daten'} }{$f};
        }

        my @funktion = map { encode_utf8($ARG) } @{$funktion};
        $doc->appendParagraph();
        my $tmp = $doc->appendParagraph(
            text  => q{},
            style => 'einschub_typ',
        );
        $doc->extendText( $tmp, $titel[0], 'fett' );
        $doc->extendText( $tmp, encode_utf8( "\t\t" . $f ), 'default' );

        if ( test_empty( $funktion[0] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[1], 'fett' );
            $doc->appendParagraph(
                text  => $funktion[0],
                style => 'einschub_inhalt'
            );
        }

        if ( test_empty( $funktion[1] ) ) {
            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[2], 'fett' );
            $doc->appendParagraph(
                text  => $funktion[1],
                style => 'einschub_inhalt'
            );

        }
    }
    return;
}    # ----------  end of subroutine datum_einfuegen  ----------

#---------------------------------------------------------------------------
#  Subroutine: leistungen
#
#  Fügt die Überschriften ein und sortiert die einzelnen Einträge. Einträge werden
#  werden über <datum_einfuegen> eingefügt, da Datenstruktur identisch.
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#
# See Also: 
#   Funktionsgleich mit <funktionen>
#
#---------------------------------------------------------------------------
sub leistungen {
    my ( $self, $ref_pflicht, $doc ) = @_;

    my @keys_funktionen = keys %{ ${$ref_pflicht}{'leistungen'} };
    my @keys_kapitel    = keys %{ ${$ref_pflicht}{'kleistungen'} };

    if ( test_empty( \@keys_funktionen ) ) {
        my ($par1) = @_;
        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. Leistungen' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        my %funk_in_kapitel = ();
        my %funk_sonst      = ();

    #---------------------------------------------------------------------------
    #  sortieren
    #---------------------------------------------------------------------------
        foreach my $k (@keys_funktionen) {
            my $fff = suche_id( $k, ${$ref_pflicht}{'kleistungen'} );
            if ($fff) {
                $funk_in_kapitel{$fff}{$k} = $k;
            }
            else {
                $funk_sonst{'Sonstige'}{$k} = $k;
            }
        }

        my @titel =
          map { encode_utf8($ARG) }
          ( 'Nummer:', 'Bezeichnung:', 'Beschreibung:' );

        my $u_kapitel = 1;

    #---------------------------------------------------------------------------
    #  Funktionen im Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_in_kapitel ) {
            my $kapitel = encode_utf8($ARG);
            $doc->appendHeading(
                text  => encode_utf8( $self->{'kap_no'} . ".$u_kapitel $ARG" ),
                style => 'Heading 2'
            );

            my @sort_kapitel = sort keys %{ $funk_in_kapitel{$ARG} };
            $self->datum_einfuegen( $doc, $ref_pflicht, \@sort_kapitel, \@titel,
                '1' );

            $u_kapitel++;

        }

    #---------------------------------------------------------------------------
    #  Funktionen in keinem Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_sonst ) {
            my $kapitel = encode_utf8($ARG);
            if ( $u_kapitel > 1 ) {
                $doc->appendHeading(
                    text =>
                      encode_utf8( $self->{'kap_no'} . ".$u_kapitel $ARG" ),
                    style => 'Heading 2'
                );
            }
            my @sort_kapitel = sort keys %{ $funk_sonst{$ARG} };
            $self->datum_einfuegen( $doc, $ref_pflicht, \@sort_kapitel, \@titel,
                '1' );
        }

        $self->{'kap_no'}++;
    }
    return;
}

#---------------------------------------------------------------------------
#  Subroutine: qualitaet
#
#   Fügt die Überschriften und die Tabelle für Qualitätsanforderungen ein.
#   Erst <qualitaet_einfuegen> füllt die Tabelle mit Inhalt. 
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $doc         - Filehandler
#
#---------------------------------------------------------------------------
sub qualitaet {

    my ( $self, $ref_pflicht, $doc ) = @_;
    
    # Da die Keys immer gefüllt sind, muss in den Values geguckt werden
    # ob den einzelnen Qualitätsanforderungen Werte zugewiesen wurden
    my @val_qual = values %{ ${$ref_pflicht}{'qualitaet'} };

    if ( test_empty( \@val_qual ) ) {

        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. Qualität' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        my @qualitaet = keys %{ ${$ref_pflicht}{'qualitaet'} };

    #---------------------------------------------------------------------------
    #  Tabellenkopf erzeugen
    #---------------------------------------------------------------------------
        $doc->appendTable( 'kopf', 1, 5 );

        my $para =
          $doc->appendParagraph( attachment => $doc->getCell( 'kopf', 0, 0 ) );
        $doc->extendText( $para, encode_utf8('Produktqualität'), 'fett' );
        $para =
          $doc->appendParagraph( attachment => $doc->getCell( 'kopf', 0, 1 ) );
        $doc->extendText( $para, 'Sehr Gut', 'fett' );
        $para =
          $doc->appendParagraph( attachment => $doc->getCell( 'kopf', 0, 2 ) );
        $doc->extendText( $para, 'Gut', 'fett' );
        $para =
          $doc->appendParagraph( attachment => $doc->getCell( 'kopf', 0, 3 ) );
        $doc->extendText( $para, 'Normal', 'fett' );
        $para =
          $doc->appendParagraph( attachment => $doc->getCell( 'kopf', 0, 4 ) );
        $doc->extendText( $para, 'Nicht Relevant', 'fett' );
        $self->leere_zeile( $doc, 'kopf' );

        my $qual = ${$ref_pflicht}{'qualitaet'};

    #---------------------------------------------------------------------------
    #  Funktionalität
    #---------------------------------------------------------------------------

        my @funktionalitaet = qw{
          angemessenheit
          richtigkeit
          interoperabilitaet
          ordnungsmaessigkeit
          sicherheit};

        $self->qualitaet_einfuegen( $doc, $ref_pflicht, 'Funktionalität',
            \@funktionalitaet );

    #---------------------------------------------------------------------------
    #  Zuverlässigkeit
    #---------------------------------------------------------------------------

        my @zuverlaesigkeit = qw{
          reife
          fehlertoleranz
          wiederherstellbarkeit};

        $self->qualitaet_einfuegen( $doc, $ref_pflicht, 'Zuverlässigkeit',
            \@zuverlaesigkeit );

    #---------------------------------------------------------------------------
    #  Benutzbarkeit
    #---------------------------------------------------------------------------
        my @benutzbarkeit = qw{
          verstaendlichkeit
          erlernbarkeit
          bedienbarkeit
        };

        $self->qualitaet_einfuegen( $doc, $ref_pflicht, 'Benutzbarkeit',
            \@benutzbarkeit );

    #---------------------------------------------------------------------------
    #  Effizienz
    #---------------------------------------------------------------------------
        my @effizienz = qw{
          zeitverhalten
          verbrauchsverhalten
        };
        $self->qualitaet_einfuegen( $doc, $ref_pflicht, 'Effizienz',
            \@benutzbarkeit );

    #---------------------------------------------------------------------------
    #  Änderbarkeit
    #---------------------------------------------------------------------------
        my @aenderbarkeit = qw{
          analysierbarkeit
          modifizierbarkeit
          stabilitaet
          pruefbarkeit};

        $self->qualitaet_einfuegen( $doc, $ref_pflicht, 'Änderbarkeit',
            \@aenderbarkeit );

    #---------------------------------------------------------------------------
    #  Übertragbarkeit
    #---------------------------------------------------------------------------
        my @uebertragbarkeit = qw{
          anpassbarkeit
          installierbarkeit
          konformitaet
          austauschbarkeit};

        $self->qualitaet_einfuegen( $doc, $ref_pflicht, 'Übertragbarkeit',
            \@uebertragbarkeit );
        $self->{'kap_no'}++;
    }


    return;
}    # ----------  end of subroutine qualitaet  ----------

#---------------------------------------------------------------------------
#  Subroutine: qualitaet_einfuegen
#
#   Erstellt für die Unterpunkte Funktionalität, Zuverlässigkeit, 
#   Benutzbarkeit, Effizienz, Änderbarkeit und Übertragbarkeit Einträge in
#   der Tabelle und füllt diese mit Ihren dazugehörigen Werten
#
#  Parameters: 
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#   $bezeichnung         - Gruppen-Bezeichnung
#   $ref_funktionalitaet - Array mit den einzelnen Bezeichnungen
#---------------------------------------------------------------------------
sub qualitaet_einfuegen {
    my ( $self, $doc, $ref_pflicht, $bezeichnung, $ref_funktionalitaet ) = @_;

    my @funktionalitaet = @{$ref_funktionalitaet};
    my @lol = map { ${$ref_pflicht}{'qualitaet'}{$ARG} } @funktionalitaet;

    if ( test_empty( \@lol ) ) {

        # Füge eine eine Tabellen ein mit 5 Spalten und nenne sie 
        # nach dem Inhalt von $bezeichnung.
        $doc->appendTable( $bezeichnung, 1, 5 );

        my $funktion = $doc->appendParagraph(
            attachment => $doc->getCell( $bezeichnung, 0, 0 ) );

        # Erste Spalte der ersten Zeile ist die Überschrift des Unterpunktes
        $doc->extendText( $funktion, encode_utf8($bezeichnung), 'fett' );

        my $qualitaetsanf = ${$ref_pflicht}{'qualitaet'};

        foreach my $anforderung (@funktionalitaet) {
            if ( test_empty( ${$qualitaetsanf}{$anforderung} ) ) {
                my $temp_anford = $anforderung;

                # Macht aus Produktanforderungen wie
                # interoperabilitaet -> Interoperabilität
                # verstaendlichkeit  -> Verstädlichkeit
                # da sie in die GUI eingefügt werden.
                $temp_anford = ucfirst $temp_anford;
                $temp_anford =~ s/ae/ä/g;
                $temp_anford =~ s/ue/ü/g;
                $temp_anford =~ s/oe/ö/g;

                # Leere Zeile einfügen
                my $temp_row = $self->leere_zeile( $doc, $bezeichnung );

                # Erste Spalte ist die Bezeichnung der Produktanforderung
                $doc->cellValue( $temp_row, 0, encode_utf8($temp_anford) );

                # Abhängig von der Auswahl der Anforderung wird eine der
                # 4 Zellen mit einem 'X' belegt
                if ( ${$qualitaetsanf}{$anforderung} eq 'sehr gut' ) {
                    $doc->cellValue( $temp_row, 1, q{X} );
                }
                elsif ( ${$qualitaetsanf}{$anforderung} eq 'gut' ) {
                    $doc->cellValue( $temp_row, 2, q{X} );
                }
                elsif ( ${$qualitaetsanf}{$anforderung} eq 'normal' ) {
                    $doc->cellValue( $temp_row, 3, q{X} );
                }
                else {
                    $doc->cellValue( $temp_row, 4, q{X} );
                }
            }
        }

        # leere Zeile einfügen
        $self->leere_zeile( $doc, $bezeichnung );
    }
    return;
}    # ----------  end of subroutine qualitaet_einfuegen  ----------

#---------------------------------------------------------------------------
#  Subroutine: leere_zeile
#
#   Beim einfügen einer neuen Zeile wird durch das Modul, die vorherige 
#   Zeile kopiert. Diese Funktion fügt eine neue Zeile ein und löscht 
#   alle Zellen. Damit eine leere Zeile in die Tabelle kopiert werden kann.
#
#  Parameters:
#   $doc          - Referenz auf Hash mit Pflichtenheft
#   $bezeichnung  - Name der Tabelle die hinzugefügt wird
#  
#  Return:
#   $row   - leere Zeile wird zurückgegeben 
#   
#---------------------------------------------------------------------------
sub leere_zeile {
    my ( $self, $doc, $bezeichnung ) = @_;
    my $row = $doc->appendRow($bezeichnung);

    for ( 0 .. 4 ) {
        $doc->cellValue( $row, $ARG, q{} );
    }
    return $row;
}    # ----------  end of subroutine leere_zeile  ----------

#---------------------------------------------------------------------------
#  Subroutine: gui
#   
#   Fügt die Gui-Elemente in das Pflichtenheft ein
#
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#
#---------------------------------------------------------------------------
sub gui {

    my ( $self, $ref_pflicht, $doc ) = @_;

    my $gui_ref  = ${$ref_pflicht}{'gui'};
    my @gui_keys = keys %{$gui_ref};
    if ( test_empty( \@gui_keys ) ) {
        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. GUI' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        foreach ( sort @gui_keys ) {
            my $nummer = encode_utf8($ARG);
            $doc->appendParagraph();
            my $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, 'Nummer:', 'fett' );
            $doc->extendText( $tmp, encode_utf8( "\t\t" . $nummer ),
                'default' );

            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, 'Bezeichnung:', 'fett' );
            if ( test_empty( ${$gui_ref}{$ARG}[1] ) ) {
                $doc->appendParagraph(
                    text  => encode_utf8( ${$gui_ref}{$ARG}[0] ),
                    style => 'einschub_inhalt',
                );
                my $bildpfad      = ${$gui_ref}{$ARG}[1];
                my $bbeschreibung = ${$gui_ref}{$ARG}[2];
                $self->bild_einfuegen( $bildpfad, $bbeschreibung, $doc );
            }

            if ( test_empty( ${$gui_ref}{$ARG}[3] ) ) {
                $tmp = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $tmp, 'Beschreibung:', 'fett' );

                $doc->appendParagraph(
                    text  => encode_utf8( ${$gui_ref}{$ARG}[3] ),
                    style => 'einschub_inhalt',
                );
            }
            # Rollen aus dem Array holen
            my $rollen      = ${$gui_ref}{$ARG}[4];
            my @keys_rollen = keys %{$rollen};
            if ( \@keys_rollen ) {
                $tmp = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $tmp, 'Rollen:', 'fett' );
                # Rollen einfügen
                foreach my $r (@keys_rollen) {
                    my $para = $doc->appendParagraph(
                        text  => q{},
                        style => 'einschub_inhalt',
                    );
                    $doc->extendText( $para, encode_utf8( ${$rollen}{$r}[0] ),
                        'fett' );
                    $doc->extendText( $para,
                        "\t\t" . encode_utf8( ${$rollen}{$r}[1] ), 'default' );
                }
            }
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine gui  ----------

#---------------------------------------------------------------------------
#  Subroutine: nfkt_anforderungen
#
#   Fügt die Nichtfunktionalen Anforderungen ein
#
#  Parameters:
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#---------------------------------------------------------------------------
sub nfkt_anforderungen {

    my ( $self, $ref_pflicht, $doc ) = @_;

    my $nfkt = encode_utf8( ${$ref_pflicht}{'nfanforderungen'} );
    if ( test_empty($nfkt) ) {
        my $sec = $doc->appendHeading(
            text => encode_utf8(
                $self->{'kap_no'} . '. Nichtfunktionale Anforderungen'
            ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        $doc->appendParagraph();
        $doc->appendParagraph(
            text  => $nfkt,
            style => 'einschub_typ',
        );
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine nfkt_anforderungen  ----------

#---------------------------------------------------------------------------
#  Subroutine: tech_umgebung
#
#   Fügt die Felder der technischen Umgebung ein.
#
#  Parameters:
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub tech_umgebung {

    my ( $self, $ref_pflicht, $doc ) = @_;

    my @elemente = map { encode_utf8($ARG) } (
        ${$ref_pflicht}{'tumgebung'}{'produktumgebung'},
        ${$ref_pflicht}{'tumgebung'}{'software'},
        ${$ref_pflicht}{'tumgebung'}{'hardware'},
        ${$ref_pflicht}{'tumgebung'}{'orgware'},
        ${$ref_pflicht}{'tumgebung'}{'schnittstellen'},
    );

    if ( test_empty( \@elemente ) ) {

        my $sec = $doc->appendHeading(
            text  => $self->{'kap_no'} . '. Technische Umgebung',
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        my @titel = qw{ Software Hardware Orgware Schnittstellen };
        $doc->appendParagraph(
            text  => $elemente[0],
            style => 'einschub_typ',
        );
        for ( 1 .. $#titel ) {
            if ( test_empty( $elemente[$ARG] ) ) {
                my $para = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $para, $titel[ $ARG - 1 ], 'fett' );
                $doc->appendParagraph(
                    text  => $elemente[$ARG],
                    style => 'einschub_inhalt',
                );
            }
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine tech_umgebung  ----------

#---------------------------------------------------------------------------
#  Subroutine: entw_umgebung
#
#   Fügt die Felder der Entwicklungsumgebung ein.
#
#  Parameters:
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub entw_umgebung {

    my ( $self, $ref_pflicht, $doc ) = @_;

    my @elemente = map { encode_utf8($ARG) } (
        ${$ref_pflicht}{'eumgebung'}{'produktumgebung'},
        ${$ref_pflicht}{'eumgebung'}{'software'},
        ${$ref_pflicht}{'eumgebung'}{'hardware'},
        ${$ref_pflicht}{'eumgebung'}{'orgware'},
        ${$ref_pflicht}{'eumgebung'}{'schnittstellen'},
    );
    if ( test_empty( \@elemente ) ) {
        my $sec = $doc->appendHeading(
            text  => $self->{'kap_no'} . '. Entwicklungsumgebung',
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );
        my @titel = qw{ Software Hardware Orgware Schnittstellen };

        $doc->appendParagraph(
            text  => $elemente[0],
            style => 'einschub_typ',
        );

        for ( 1 .. $#titel ) {
            if ( test_empty( $titel[$ARG] ) ) {
                my $para = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $para, $titel[ $ARG - 1 ], 'fett' );
                $doc->appendParagraph(
                    text  => $elemente[$ARG],
                    style => 'einschub_inhalt',
                );
            }
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine entw_umgebung  ----------

#---------------------------------------------------------------------------
#  Subroutine: teilprodukte
#
#   Fügt die Felder der Teilprodukte ein.
#
#  Parameters:
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#   
#---------------------------------------------------------------------------
sub teilprodukte {

    my ( $self, $ref_pflicht, $doc ) = @_;

    my $ref_tp  = ${$ref_pflicht}{'teilprodukte'};
    my @tp_keys = keys %{$ref_tp};

    my $tp_beschreibung =
      encode_utf8( ${$ref_pflicht}{'teilprodukte_beschreibung'} );

    if ( test_empty($tp_beschreibung) or test_empty( \@tp_keys ) ) {
        my $sec = $doc->appendHeading(
            text  => $self->{'kap_no'} . '. Teilprodukte',
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        if ( test_empty($tp_beschreibung) ) {

            # Allgemeine Teilproduktbeschreibung einfügen
            $doc->appendParagraph(
                text  => $tp_beschreibung,
                style => 'einschub_typ',
            );
        }

        $doc->appendParagraph();
        if ( test_empty( \@tp_keys ) ) {
            foreach my $key (@tp_keys) {
                # Teilprodukte 
                my $beschreibung = encode_utf8( ${$ref_tp}{$key}[0] );
                my $para         = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $para, 'Teilproduktbeschreibung', 'fett' );
                $doc->appendParagraph(
                    text  => $beschreibung,
                    style => 'einschub_inhalt',
                );

                $para = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $para = $doc->extendText( $para, 'Funktionen', 'fett' );

                my $ref_funkt  = ${$ref_tp}{$key}[1];
                my @funktionen = keys %{$ref_funkt};
                foreach my $funk (@funktionen) {
                    $doc->appendParagraph();
                    my $funk_beschr = encode_utf8( ${$ref_funkt}{$funk}[0] );
                    my $funk_bemerk =
                      encode_utf8( "\t" . ${$ref_funkt}{$funk}[1] );
                    $para = $doc->appendParagraph(
                        text  => q{},
                        style => 'einschub_typ',
                    );
                    $doc->extendText( $para, $funk, 'fett' );
                    if ( test_empty($funk_beschr) ) {
                        $para = $doc->appendParagraph(
                            text  => q{},
                            style => 'einschub_typ',
                        );
                        $doc->extendText( $para, 'Beschreibung:', 'fett' );
                        $para = $doc->extendText( $para, $funk_beschr );
                    }
                    if ( test_empty($funk_bemerk) ) {
                        $para = $doc->appendParagraph(
                            text  => q{},
                            style => 'einschub_typ',
                        );
                        $doc->extendText( $para, 'Bemerkung:', 'fett' );
                        $para = $doc->extendText( $para, $funk_bemerk );
                    }

                }
            }
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine teilprodukte  ----------

#---------------------------------------------------------------------------
#  Subroutine: ergaenzungen
#
#   Fügt die Felder der Ergaenzungen ein.
#
#  Parameters:
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub ergaenzungen {

    my ( $self, $ref_pflicht, $doc ) = @_;
    my $bildpfad = ${$ref_pflicht}{'pergaenzungen'}{'bildpfad'};
    my $uebersicht =
      encode_utf8( ${$ref_pflicht}{'pergaenzungen'}{'ergaenzungen'} );
    if ( test_empty($bildpfad) or test_empty($uebersicht) ) {
        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. Ergänzungen' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        if ( test_empty($bildpfad) ) {
            my $bbeschreibung =
              ${$ref_pflicht}{'pergaenzungen'}{'bildbeschreibung'};
            $self->bild_einfuegen( $bildpfad, $bbeschreibung, $doc );
        }
        if ( test_empty($uebersicht) ) {
            $doc->appendParagraph(
                text  => $uebersicht,
                style => 'einschub_typ',
            );
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine ergaenzungen  ----------

#---------------------------------------------------------------------------
#  Subroutine: testfaelle
#
#   Fügt die Felder der Testfälle ein
#
#  Parameters:
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub testfaelle {

    my ( $self, $ref_pflicht, $doc ) = @_;

    my $ref_test        = ${$ref_pflicht}{'testfaelle'};
    my @keys_testfaelle = sort keys %{$ref_test};
    if ( test_empty( \@keys_testfaelle ) ) {
        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. Testfälle' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        my @titel = map { encode_utf8($ARG) } (
            'Nummer:',       'Bezeichnung:',
            'Vorbedingung:', 'Beschreibung:',
            'Sollverhalten:'
        );
        foreach my $key (@keys_testfaelle) {
            my @testfall = map { encode_utf8($ARG) } @{ ${$ref_test}{$key} };
            $doc->appendParagraph();
            my $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[0], 'fett' );
            $doc->extendText( $tmp, encode_utf8( "\t\t" . $key ), 'default' );
            if ( test_empty( $testfall[0] ) ) {
                $tmp = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $tmp, $titel[1], 'fett' );
                $doc->appendParagraph(
                    text  => $testfall[0],
                    style => 'einschub_inhalt'
                );
            }
            if ( test_empty( $testfall[1] ) ) {
                $tmp = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $tmp, $titel[2], 'fett' );
                $doc->appendParagraph(
                    text  => $testfall[1],
                    style => 'einschub_inhalt'
                );
            }
            if ( test_empty( $testfall[2] ) ) {
                $tmp = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $tmp, $titel[3], 'fett' );
                $doc->appendParagraph(
                    text  => $testfall[2],
                    style => 'einschub_inhalt'
                );
            }
            if ( test_empty( $testfall[3] ) ) {
                $tmp = $doc->appendParagraph(
                    text  => q{},
                    style => 'einschub_typ',
                );
                $doc->extendText( $tmp, $titel[4], 'fett' );
                $doc->appendParagraph(
                    text  => $testfall[3],
                    style => 'einschub_inhalt'
                );
            }
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine testfaelle  ----------

#---------------------------------------------------------------------------
#  Subroutine: glossar
#
#   Fügt die Felder des Glossars ein
#
#  Parameters:
#   $doc                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub glossar {
    my ( $self, $ref_pflicht, $doc ) = @_;

    my $ref_glossar  = ${$ref_pflicht}{'glossar'};
    my @keys_glossar = sort keys %{$ref_glossar};
    if ( test_empty( \@keys_glossar ) ) {
        my $sec = $doc->appendHeading(
            text  => encode_utf8( $self->{'kap_no'} . '. Glossar' ),
            style => 'Heading 1'
        );

        # Seitenumbruch hinzugefügen
        $doc->setPageBreak( $sec, style => 'Heading 1' );

        my @titel = map { encode_utf8($ARG) } ( 'Begriff:', 'Erklärung:' );

        foreach my $key (@keys_glossar) {
            my @glossar = map { encode_utf8($ARG) } @{ ${$ref_glossar}{$key} };
            $doc->appendParagraph();
            my $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[0], 'fett' );
            $doc->extendText( $tmp, encode_utf8( "\t" . $key ), 'default' );

            $tmp = $doc->appendParagraph(
                text  => q{},
                style => 'einschub_typ',
            );
            $doc->extendText( $tmp, $titel[1], 'fett' );
            $doc->appendParagraph(
                text  => $glossar[0],
                style => 'einschub_inhalt'
            );
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine glossar  ----------

#===============================================================================
# Function: trimm
#
#      			 Es werden führende und abschließende Leerzeichen entfernt.
#
#   Parameters:
#   			 $par1    -	Enthält den zu trimmenden String
#
#      Returns:
#      			 Der Rueckgabewert ist der String ohne fuehrende und
#      			 abschließende Leerzeichen.
#===============================================================================
sub trimm {
    my ($par1) = @_;
    if ($par1) {
        $par1 =~ s/^\s+//;    #führende Leerezeichen entfernen
        $par1 =~ s/\s+$//;    #abschließende Leerzeichen entfernen
    }
    return $par1;
}    # ----------  end of subroutine trimm  ----------

END { }    # module clean-up code

1;
