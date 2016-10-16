#===============================================================================
# Class: MoliriTXT.pm
#
#  Diese Klasse ist für den Export ins TXT-Format zuständig.
#
#  >Autor:       Alexandros Kechagias (Alexandros.Kechagias@gmx.de)
#  >Firma:       Fachhochschule Südwestfalen
#  >Version:     1.0
#  >Erstellt am: 19.07.2011 17:19:05
#  >Revision:    0.2
#===============================================================================

package MoliriTXT;

use strict;
use utf8;
use warnings;
use Encode;
use English qw( -no_match_vars );
use Text::Wrap;
$Text::Wrap::columns = 80; # maximale Breite
my $EMPTY = q{};
my $SPACE = q{ };

#---------------------------------------------------------------------------
#  Subroutine: new
#
#  Konstruktor, kriegt den Pfad zur TXT-Datei
#---------------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self  = {
        _pfad  => shift,
        kap_no => 1
    };
    bless $self, $class;
    return $self;
}    # ----------  end of subroutine new  ----------

#---------------------------------------------------------------------------
#  Subroutine: export_txt
#
#  Dies ist die einzige Funktion auf die das Hauptprogramm zugreift. Im 
#  Konstruktor wird der Pfad zum gewünschten Exportziel angegeben
#
#  Parameters: 
#     %ref_pflicht - Hash mit Pflichtenheft
#
#---------------------------------------------------------------------------
sub export_txt {
    my ( $self, %ref_pflicht ) = @_;
    my $ausgabe = $self->{'_pfad'};    # output file name

    if ( $ausgabe !~ /\.txt$/ ) {
        $ausgabe = $ausgabe . '.txt';
    }
    my $txt_file_name = $ausgabe;      # output file name

    #$PROGRAM_NAME
    open my $txt, '>', $txt_file_name
      or die
      "$PROGRAM_NAME : failed to open  output file '$txt_file_name' : $ERRNO\n";

    $self->titel( \%ref_pflicht, $txt );
    $self->ziele( \%ref_pflicht, $txt );
    $self->produkteinsatz( \%ref_pflicht, $txt );
    $self->puebersicht( \%ref_pflicht, $txt );
    $self->funktionen( \%ref_pflicht, $txt );
    $self->daten( \%ref_pflicht, $txt );
    $self->leistungen( \%ref_pflicht, $txt );
    $self->qualitaet( \%ref_pflicht, $txt );
    $self->gui( \%ref_pflicht, $txt );
    $self->nfkt_anforderungen( \%ref_pflicht, $txt );
    $self->tech_umgebung( \%ref_pflicht, $txt );
    $self->entw_umgebung( \%ref_pflicht, $txt );
    $self->teilprodukte( \%ref_pflicht, $txt );
    $self->ergaenzungen( \%ref_pflicht, $txt );
    $self->testfaelle( \%ref_pflicht, $txt );
    $self->glossar( \%ref_pflicht, $txt );

    close $txt
      or warn
      "$PROGRAM_NAME : failed to close output file '$txt_file_name' : $ERRNO\n";
    return ();
}

#---------------------------------------------------------------------------
#  Subroutine: titel
#
#  Fügt die Pflichtenheftdetails ein.
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $txt         - Filehandler
#---------------------------------------------------------------------------
sub titel {
    my ( $self, $ref_pflicht, $txt ) = @_;
    my @elemente = map { encode_utf8($ARG) } (
        ${$ref_pflicht}{'details'}{'titel'},
        ${$ref_pflicht}{'details'}{'version'},
        ${$ref_pflicht}{'details'}{'autor'},
        ${$ref_pflicht}{'details'}{'datum'},
        ${$ref_pflicht}{'details'}{'status'},
        ${$ref_pflicht}{'details'}{'kommentar'},
    );

    my @loc = localtime;
    my $jahr = $loc[5]+1900;
    my $monat = $loc[4]+1;
    my $tag = $loc[3];
    my $exdatum = "$jahr-$monat-$tag";

    print {$txt} "Titel:\t\t" . $elemente[0] . "\n";
    print {$txt} "Version:\t" . $elemente[1] . "\n";
    print {$txt} "Autor:\t\t" . $elemente[2] . "\n";
    print {$txt} "Datum:\t\t" . $elemente[3] . "\n";
    print {$txt} "Status:\t\t" . $elemente[4] . "\n";
    print {$txt} "\n";
    print {$txt} "Exportdatum:\t" . $exdatum . "\n";

    print {$txt} "\n";
    print {$txt} "\n";

    return;
}    # ----------  end of subroutine titel  ----------

#---------------------------------------------------------------------------
#  Subroutine: ueberschrift
#
#  Fügt die Überschrift ein
#
#  Parameters: 
#
#  $nummer - Kapitelnummer
#  $titel  - Bezeichnung der Überschrift
#
#---------------------------------------------------------------------------
sub ueberschrift {
    my ( $txt, $nummer, $titel ) = @_;
    printf {$txt}
      "###################################################################\n";
    if ( $titel =~ /ä|ö|ü/i ) {
        $titel = encode_utf8($titel);
        printf {$txt} "#        %2s. %-31s                       #\n", $nummer,
          $titel;
    }
    else {
        printf {$txt} "#        %2s. %-30s                       #\n", $nummer,
          $titel;
    }
    printf {$txt}
      "###################################################################\n";
    print {$txt} "\n";
    return;
}    # ----------  end of subroutine ueberschrift  ----------

#---------------------------------------------------------------------------
#  Subroutine: ziele
#
#  Fügt die Ziele ein
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $txt         - Filehandler
#---------------------------------------------------------------------------
sub ziele {
    my ( $self, $ref_pflicht, $txt ) = @_;

    my $einschub   = $SPACE x 4;
    my $ref_ziele  = ${$ref_pflicht}{'zielbestimmungen'};
    my @keys_ziele = keys %{$ref_ziele};
    if ( test_empty( \@keys_ziele ) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Zielbestimmungen' );
        my @musskriterien;
        my @wunschkriteri;
        my @abgrenzungskr;
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
        print {$txt} "\n";
        print {$txt} '--Musskriterien--' . "\n";
        print {$txt} "\n";

        my $einschub   = $SPACE x 4;
        foreach my $key (@musskriterien) {
            my @inhalt = map { encode_utf8($ARG) } @{ ${$ref_ziele}{$key} };
            print {$txt} wrap(q{  * }, $einschub, $inhalt[1]);
            print {$txt} "\n";
        }

    #---------------------------------------------------------------------------
    #  Wunschkriterien
    #---------------------------------------------------------------------------
        print {$txt} "\n";
        print {$txt} '--Wunschkriterien--' . "\n";
        print {$txt} "\n";

        foreach my $key (@wunschkriteri) {
            my @inhalt = map { encode_utf8($ARG) } @{ ${$ref_ziele}{$key} };
            my @temp = split /\n/, $inhalt[1];
            print {$txt} wrap(q{  * }, $einschub, $inhalt[1]);
            print {$txt} "\n";
        }

    #---------------------------------------------------------------------------
    #  Abgrenzungskriterien
    #---------------------------------------------------------------------------
        print {$txt} "\n";
        print {$txt} '--Abgrenzungskriterien--' . "\n";
        print {$txt} "\n";

        foreach my $key (@abgrenzungskr) {
            my @inhalt = map { encode_utf8($ARG) } @{ ${$ref_ziele}{$key} };
            my @temp = split /\n/, $inhalt[1];
            print {$txt} wrap(q{  * }, $einschub, $inhalt[1]);
            print {$txt} "\n";
        }

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
        $res = join $EMPTY, map { trimm($ARG) } @{$par1};

    }
    else {
        $res = trimm($par1);
    }
    if ( defined $res and $res eq '0' ) {    # fängt ab wenn ID = 0 ist.
        $res = q{OK};
    }
    return $res;
}    # ----------  end of subroutine test_array_empty  ----------

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

#---------------------------------------------------------------------------
#  Subroutine: produkteinsatz
#  
#  Fügt den Punkt Produkteinsatz hinzu
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $txt         - Filehandler
#
#---------------------------------------------------------------------------
sub produkteinsatz {
    my ( $self, $ref_pflicht, $txt ) = @_;
    my @elemente = map { encode_utf8($ARG) } (
        ${$ref_pflicht}{'einsatz'}{'produkteinsatz'},
        ${$ref_pflicht}{'einsatz'}{'zielgruppen'},
        ${$ref_pflicht}{'einsatz'}{'arbeitsbereiche'},
        ${$ref_pflicht}{'einsatz'}{'betriebsbedingungen'},
    );
    if ( test_empty( \@elemente ) ) {

        ueberschrift( $txt, $self->{'kap_no'}, 'Produkteinsatz' );

#---------------------------------------------------------------------------
#  Hier stimmt was nicht
#---------------------------------------------------------------------------
        my @titel = qw{Zielgruppen Arbeitsbereiche Betriebsbedingungen};
        ausgabe_textblock( $ref_pflicht, $txt, $elemente[0] );

        print {$txt} "\n";
        for ( 1 .. $#titel ) {
            if ( test_empty( $elemente[$ARG] ) ) {
                print {$txt} q{--} . $titel[ $ARG - 1 ] . "-- \n";
                ausgabe_textblock( $ref_pflicht, $txt, $elemente[$ARG] );
            }
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine produkteinsatz  ----------

#---------------------------------------------------------------------------
#  Subroutine: ausgabe_textblock
#
#  Erzeugt Textblock mit einem Einschub von 4 Leereichen
# 
#  Parameters: 
#  $txt - Filehandler
#  $inhalt - Inhalt des Textblocks
#---------------------------------------------------------------------------
sub ausgabe_textblock {
    my ( $ref_pflicht, $txt, $inhalt ) = @_;
    my $einschub = $SPACE x 4;

    print {$txt} wrap($einschub, $einschub, $inhalt);
    print {$txt} "\n";
    return;
}

#---------------------------------------------------------------------------
#  Subroutine: ausgabe_textblock_2
#
#  Erzeugt Textblock mit einem Einschub von 8 Leereichen
# 
#  Parameters: 
#  $txt - Filehandler
#  $inhalt - Inhalt des Textblocks
#---------------------------------------------------------------------------
sub ausgabe_textblock_2 {
    my ( $ref_pflicht, $txt, $inhalt ) = @_;
    my $einschub = $SPACE x 8;
    print {$txt} wrap($einschub, $einschub, $inhalt);
    print {$txt} "\n";
    return;
}

#---------------------------------------------------------------------------
#  Subroutine: puebersicht
#
#  Fügt die Produktübersicht ein.
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $txt         - Filehandler
#
#---------------------------------------------------------------------------
sub puebersicht {

    my ( $self, $ref_pflicht, $txt ) = @_;
    my $bildpfad      = ${$ref_pflicht}{'uebersicht'}{'bildpfad'};
    my $bbeschreibung = ${$ref_pflicht}{'uebersicht'}{'bildbeschreibung'};
    my $uebersicht = encode_utf8( ${$ref_pflicht}{'uebersicht'}{'uebersicht'} );
    if ( test_empty($uebersicht) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Produktübersicht ' );

        if ( test_empty($uebersicht) ) {
            ausgabe_textblock( $ref_pflicht, $txt, $uebersicht );
        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine Ziele  ----------

#---------------------------------------------------------------------------
#  Subroutine: funktionen
#
#  Fügt die Überschriften ein und sortiert die einzelnen Einträge. Einträge werden
#  werden über <funktion_einfuegen> eingefügt
#
#  Parameters: 
#   $ref_pflicht - Referenz auf Hash mit Pflichtenheft
#   $txt         - Filehandler
#---------------------------------------------------------------------------
sub funktionen {
    my ( $self, $ref_pflicht, $txt ) = @_;
    my @keys_funktionen = keys %{ ${$ref_pflicht}{'funktionen'} };
    my @keys_kapitel    = keys %{ ${$ref_pflicht}{'kfunktionen'} };

    if ( test_empty( \@keys_funktionen ) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Funktionen' );
        my %funk_in_kapitel = ();
        my %funk_sonst      = ();

    #---------------------------------------------------------------------------
    #  sortieren
    #---------------------------------------------------------------------------
        foreach my $k (@keys_funktionen) {
            my $fff = $self->suche_id( $k, ${$ref_pflicht}{'kfunktionen'} );
            if ($fff) {
                $funk_in_kapitel{$fff}{$k} = $k;
            }
            else {
                $funk_sonst{'Sonstige'}{$k} = $k;
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

        my $u_kapitel = 1;

    #---------------------------------------------------------------------------
    #  Funktionen im Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_in_kapitel ) {
            my $kapitel = encode_utf8($ARG);
            print {$txt} "\n";
            print {$txt} "-- $self->{'kap_no'}.$u_kapitel $kapitel --\n";
            print {$txt} "\n";

            my @sort_kapitel = sort keys %{ $funk_in_kapitel{$ARG} };
            $self->funktion_einfuegen( $txt, $ref_pflicht, \@sort_kapitel,
                \@titel );

            $u_kapitel++;
        }

    #---------------------------------------------------------------------------
    #  Funktionen in keinem Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_sonst ) {
            my $kapitel = encode_utf8($ARG);
            if ( $u_kapitel > 1 ) {
                print {$txt} "\n";
                print {$txt} "-- $self->{'kap_no'}. $kapitel --\n";
                print {$txt} "\n";
            }
            my @sort_kapitel = sort keys %{ $funk_sonst{$ARG} };
            $self->funktion_einfuegen( $txt, $ref_pflicht, \@sort_kapitel,
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
#   $txt              - Filehandler
#   $ref_sort_kapitel - Kapitelnummern in Array
#   $ref_titel        - Titel in Array
#---------------------------------------------------------------------------
sub funktion_einfuegen {
    my ( $self, $txt, $ref_pflicht, $ref_sort_kapitel, $ref_titel ) = @_;
    my $einschub = $EMPTY x 4;

    my @sort_kapitel = @{$ref_sort_kapitel};
    my @titel        = @{$ref_titel};

    #    my @titel = map { encode_utf8($ARG) } (
    #        'Nummer:',        'Geschäftsprozess:',
    #        'Ziel:',          'Vorbedingung:',
    #        'Nachb. Erfolg:', 'Nachb. Fehlschlag:',
    #        'Akteure:',       'Auslösendes Ereignis:',
    #        'Beschreibung:',  'Erweiterung:',
    #        'Alternativen:',
    #    );

    foreach my $f (@sort_kapitel) {

        my $funktion = ${ ${$ref_pflicht}{'funktionen'} }{$f};
        my @funktion = map { encode_utf8($ARG) } @{$funktion};

        #  nummer
        print {$txt} "\n";
        print {$txt} $einschub
          . $titel[0]
          . '         '
          . encode_utf8( "\t\t" . $f );
        print {$txt} "\n";
        if ( test_empty( $funktion[0] ) ) {

            #  geschäfts.
            print {$txt} "\n";
            my $t_titel = $titel[1].'  ';
            my $spaces = $SPACE x length($t_titel);
            print {$txt} wrap( 
                $t_titel,
                $spaces,
                $funktion[0]
            );
#            print {$txt} $einschub . $titel[1] . '  ' . $funktion[0];
            print {$txt} "\n";
        }
        if ( test_empty( $funktion[1] ) ) {

            #  Ziel
#            print {$txt} $einschub
#              . $titel[2]
#              . '              '
#              . $funktion[1];
            my $t_titel = $titel[2].'              ';
            my $spaces = $SPACE x length($t_titel);
            print {$txt} wrap( 
                $t_titel,
                $spaces,
                $funktion[1]
            );
            print {$txt} "\n";
        }
        if ( test_empty( $funktion[2] ) ) {

            #  Vorbedingung
#            print {$txt} $einschub . $titel[3] . '      ' . $funktion[2];
            my $t_titel = $titel[3].'      ';
            my $spaces = $SPACE x length($t_titel);
            print {$txt} wrap( 
                $t_titel,
                $spaces,
                $funktion[2]
            );
            print {$txt} "\n";
        }
        if ( test_empty( $funktion[3] ) ) {

            #  Nachb. Erfolg
#            print {$txt} $einschub . $titel[4] . '     ' . $funktion[3];
            my $t_titel = $titel[4].'     ';
            my $spaces = $SPACE x length($t_titel);
            print {$txt} wrap( 
                $t_titel,
                $spaces,
                $funktion[3]
            );
            print {$txt} "\n";
        }
        if ( test_empty( $funktion[4] ) ) {

            #  Nachb. Fehlschlag
#            print {$txt} $einschub . $titel[5] . ' ' . $funktion[4];
            my $t_titel = $titel[5].' ';
            my $spaces = $SPACE x length($t_titel);
            print {$txt} wrap( 
                $t_titel,
                $spaces,
                $funktion[4]
            );
            print {$txt} "\n";
        }
        if ( test_empty( $funktion[5] ) ) {

            #  Akteure
            my $t_titel = $titel[6].'           ';
            my $spaces = $SPACE x length($t_titel);
            print {$txt} wrap( 
                $t_titel,
                $spaces,
                $funktion[5]
            );
            print {$txt} "\n";
        }
        if ( test_empty( $funktion[6] ) ) {

            #  auslösendes Ereignis
            print {$txt} $einschub . $titel[7] . "\n";
            ausgabe_textblock_2( $ref_pflicht, $txt, $funktion[6] );
        }
        if ( test_empty( $funktion[7] ) ) {

            #  Beschreibung
            print {$txt} $einschub . $titel[8] . "\n";
            ausgabe_textblock_2( $ref_pflicht, $txt, $funktion[7] );
        }
        if ( test_empty( $funktion[8] ) ) {

            #  Erweiterung
            print {$txt} $einschub . $titel[9] . "\n";
            ausgabe_textblock_2( $ref_pflicht, $txt, $funktion[8] );
        }
        if ( test_empty( $funktion[9] ) ) {

            #  Alternativen
            print {$txt} $einschub . $titel[10] . "\n";
            ausgabe_textblock_2( $ref_pflicht, $txt, $funktion[9] );
        }
    }
    return;
}    # ----------  end of subroutine funktion_einfuegen  ----------

#===============================================================================
#     Function:  suche_id
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
#===============================================================================
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
#   $txt         - Filehandler
#
# See Also: 
#   Funktionsgleich mit <funktionen>
#
#---------------------------------------------------------------------------
sub daten {

    my ( $self, $ref_pflicht, $txt ) = @_;

    my @keys_funktionen = keys %{ ${$ref_pflicht}{'daten'} };
    my @keys_kapitel    = keys %{ ${$ref_pflicht}{'kdaten'} };
    if ( test_empty(@keys_funktionen) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Daten' );

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
            print {$txt} "\n";
            print {$txt} "-- $self->{'kap_no'} . $u_kapitel $kapitel --\n";
            print {$txt} "\n";

            my @sort_kapitel = sort keys %{ $funk_in_kapitel{$ARG} };
            $self->datum_einfuegen(
                $txt,
                $ref_pflicht,
                \@sort_kapitel,
                \@titel
            );
            $u_kapitel++;
        }

    #---------------------------------------------------------------------------
    #  Funktionen in keinem Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_sonst ) {
            my $kapitel = encode_utf8($ARG);
            if ( $u_kapitel > 1 ) {
                print {$txt} "\n";
                print {$txt} "-- $self->{'kap_no'} . $u_kapitel $kapitel --\n";
                print {$txt} "\n";
            }
            my @sort_kapitel = sort keys %{ $funk_sonst{$ARG} };
            $self->datum_einfuegen(
                $txt,
                $ref_pflicht,
                \@sort_kapitel,
                \@titel
            );
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
#   $txt              - Filehandler
#   $ref_sort_kapitel - Kapitelnummern in Array
#   $ref_titel        - Titel in Array
#
#  See Also: 
#   Funktionsgleich mit <funktion_einfuegen>
#---------------------------------------------------------------------------
sub datum_einfuegen {
    my ( $self, $txt, $ref_pflicht, $ref_sort_kapitel, $ref_titel, $leistung ) =
      @_;
    my $einschub     = $EMPTY x 4;
    my @sort_kapitel = @{$ref_sort_kapitel};
    my @titel        = @{$ref_titel};

    foreach my $f (@sort_kapitel) {
        my $funktion;
        if ($leistung) {
            $funktion = ${ ${$ref_pflicht}{'leistungen'} }{$f};
        }
        else {
            $funktion = ${ ${$ref_pflicht}{'daten'} }{$f};
        }

        my @funktion = map { encode_utf8($ARG) } @{$funktion};

        print {$txt} "\n";
        print {$txt} $einschub . $titel[0] . '           ' . encode_utf8($f) . "\n";
        print {$txt} "\n";
        if ( test_empty( $funktion[0] ) ) {
            print {$txt} $einschub . $titel[1] . "\n";
            ausgabe_textblock_2( $ref_pflicht, $txt, $funktion[0] );
        }

        if ( test_empty( $funktion[1] ) ) {
            print {$txt} $einschub . $titel[2] . "\n";
            ausgabe_textblock_2( $ref_pflicht, $txt, $funktion[1] );
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
#   $txt         - Filehandler
#
# See Also: 
#   Funktionsgleich mit <funktionen>
#
#---------------------------------------------------------------------------
sub leistungen {
    my ( $self, $ref_pflicht, $txt ) = @_;

    my @keys_funktionen = keys %{ ${$ref_pflicht}{'leistungen'} };
    my @keys_kapitel    = keys %{ ${$ref_pflicht}{'kleistungen'} };

    if ( test_empty( \@keys_funktionen ) ) {
        my ($par1) = @_;
        ueberschrift( $txt, $self->{'kap_no'}, 'Leistungen' );

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
            print {$txt} "\n";
            print {$txt} "-- $self->{'kap_no'} . $u_kapitel $kapitel --\n";
            print {$txt} "\n";

            my @sort_kapitel = sort keys %{ $funk_in_kapitel{$ARG} };
            $self->datum_einfuegen( $txt, $ref_pflicht, \@sort_kapitel, \@titel,
                '1' );

            $u_kapitel++;

        }

    #---------------------------------------------------------------------------
    #  Funktionen in keinem Kapitel
    #---------------------------------------------------------------------------

        foreach ( sort keys %funk_sonst ) {
            my $kapitel = encode_utf8($ARG);
            if ( $u_kapitel > 1 ) {
                print {$txt} "\n";
                print {$txt} "-- $self->{'kap_no'} . $u_kapitel $kapitel --\n";
                print {$txt} "\n";
            }
            my @sort_kapitel = sort keys %{ $funk_sonst{$ARG} };
            $self->datum_einfuegen( $txt, $ref_pflicht, \@sort_kapitel, \@titel,
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
#   $txt         - Filehandler
#
#---------------------------------------------------------------------------
sub qualitaet {

    my ( $self, $ref_pflicht, $txt ) = @_;

    my @val_qual = values %{ ${$ref_pflicht}{'qualitaet'} };

    if ( test_empty( \@val_qual ) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Qualität' );
        my @qualitaet = keys %{ ${$ref_pflicht}{'qualitaet'} };

    #---------------------------------------------------------------------------
    #  Tabellenkopf
    #---------------------------------------------------------------------------
        print {$txt}
q{|-----------------------------------------------------------------------------------------|}
          . "\n";
        print {$txt}
          encode_utf8(
q{|Produktqualität      |    Sehr Gut    |      Gut       |     Normal     | Nicht Relevant |}
          ) . "\n";
        print {$txt}
q{|-----------------------------------------------------------------------------------------|}
          . "\n";

        #        $self->leere_zeile($txt);

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

        $self->qualitaet_einfuegen( $txt, $ref_pflicht, 'Funktionalität',
            \@funktionalitaet );

    #---------------------------------------------------------------------------
    #  Zuverlässigkeit
    #---------------------------------------------------------------------------

        my @zuverlaesigkeit = qw{
          reife
          fehlertoleranz
          wiederherstellbarkeit};

        $self->qualitaet_einfuegen( $txt, $ref_pflicht, 'Zuverlässigkeit',
            \@zuverlaesigkeit );

    #---------------------------------------------------------------------------
    #  Benutzbarkeit
    #---------------------------------------------------------------------------
        my @benutzbarkeit = qw{
          verstaendlichkeit
          erlernbarkeit
          bedienbarkeit
        };

        $self->qualitaet_einfuegen( $txt, $ref_pflicht, 'Benutzbarkeit',
            \@benutzbarkeit );

    #---------------------------------------------------------------------------
    #  Effizienz
    #---------------------------------------------------------------------------
        my @effizienz = qw{
          zeitverhalten
          verbrauchsverhalten
        };
        $self->qualitaet_einfuegen( $txt, $ref_pflicht, 'Effizienz',
            \@benutzbarkeit );

    #---------------------------------------------------------------------------
    #  Änderbarkeit
    #---------------------------------------------------------------------------
        my @aenderbarkeit = qw{
          analysierbarkeit
          modifizierbarkeit
          stabilitaet
          pruefbarkeit};

        $self->qualitaet_einfuegen( $txt, $ref_pflicht, 'Änderbarkeit',
            \@aenderbarkeit );

    #---------------------------------------------------------------------------
    #  Übertragbarkeit
    #---------------------------------------------------------------------------
        my @uebertragbarkeit = qw{
          anpassbarkeit
          installierbarkeit
          konformitaet
          austauschbarkeit};

        $self->qualitaet_einfuegen( $txt, $ref_pflicht, 'Übertragbarkeit',
            \@uebertragbarkeit );
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine qualitaet  ----------

#---------------------------------------------------------------------------
#  Subroutine: zeile
#  
#  Erstellt Zeile mit Qualitätsmerkmal und dem dazugehörigem Wert in der 
#  Rabelle
#
#  Parameters:
#   $txt          - Referenz auf Hash mit Pflichtenheft
#   $qualitaet    - Qualitätsmerkmal
#   $a            - Sehr gut
#   $b            - Gut
#   $c            - Normal
#   $d            - Nicht Relevant
#  
#  Return:
#   $row   - leere Zeile wird zurückgegeben 
#   
#---------------------------------------------------------------------------
sub zeile {
    my ( $self, $txt, $qualitaet, $a, $b, $c, $d ) = @_;
    # Wenn Umlaute vorhanden sind wird ein Zeichen von printf "verschluckt"
    # deshalb wird Überprüft ob Umlate im Qualitätsmerkmal vorhanden sind.
    # Wenn dies der Fall wird ein Zeichen mehr für den Umlaut beansprucht
    if ( $qualitaet =~ /ä|ö|ü/i ) {
        $qualitaet = encode_utf8($qualitaet);
        printf {$txt}
q{|% 22s|      %s         |       %s        |        %s       |       %s        |}
          . "\n", $qualitaet, $a, $b, $c, $d;
    }
    else {
        printf {$txt}
q{|% 21s|        %s       |       %s        |       %s        |       %s        |}
          . "\n", $qualitaet, $a, $b, $c, $d;
    }
    return;
}    # ----------  end of subroutine leere_zeile  ----------

#---------------------------------------------------------------------------
#  Subroutine: leere Zeile
#
#  Fügt eine leere Zeile in die Tabelle ein
#  
#  Parameters: 
#  $txt - Filehandler
#---------------------------------------------------------------------------
sub leere_zeile {
    my ( $self, $txt ) = @_;
    print {$txt}
q{|-----------------------------------------------------------------------------------------|}
      . "\n";
    return;
}    # ----------  end of subroutine leere_zeile  ----------

#---------------------------------------------------------------------------
#  Subroutine: qualitaet_einfuegen
#
#   Erstellt für die Unterpunkte Funktionalität, Zuverlässigkeit, 
#   Benutzbarkeit, Effizienz, Änderbarkeit und Übertragbarkeit Einträge in
#   der Tabelle.
#
#  Parameters: 
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#   $bezeichnung         - Gruppen-Bezeichnung
#   $ref_funktionalitaet - Array mit den einzelnen Bezeichnungen
#---------------------------------------------------------------------------
sub qualitaet_einfuegen {
    my ( $self, $txt, $ref_pflicht, $bezeichnung, $ref_funktionalitaet ) = @_;

    my @funktionalitaet = @{$ref_funktionalitaet};
    my @test = map { ${$ref_pflicht}{'qualitaet'}{$ARG} } @funktionalitaet;

    if ( test_empty( \@test ) ) {

    # Wenn Umlaute vorhanden sind wird ein Zeichen von printf "verschluckt"
    # deshalb wird Überprüft ob Umlate im Unterpunkt vorhanden sind.
    # Wenn dies der Fall wird ein Zeichen mehr für den Umlaut beansprucht
        if ( $bezeichnung =~ /ä|ö|ü/i ) {
            $bezeichnung = encode_utf8($bezeichnung);
            printf {$txt}
q{|% 22s                                                                    |}
              . "\n", $bezeichnung;
        }
        else {
            printf {$txt}
q{|% 21s                                                                    |}
              . "\n", $bezeichnung;
        }
        print {$txt}
q{|-----------------------------------------------------------------------------------------|}
          . "\n";
        my $qualitaetsanf = ${$ref_pflicht}{'qualitaet'};
        foreach my $anforderung (@funktionalitaet) {
            if ( test_empty( ${$qualitaetsanf}{$anforderung} ) ) {
                my $temp_anford = $anforderung;
                $temp_anford = ucfirst $temp_anford;
                $temp_anford =~ s/ae/ä/g;
                $temp_anford =~ s/ue/ü/g;
                $temp_anford =~ s/oe/ö/g;

                if ( ${$qualitaetsanf}{$anforderung} eq 'sehr gut' ) {
                    $self->zeile( $txt, $temp_anford, q{X}, q{ }, q{ }, q{ } );
                }
                elsif ( ${$qualitaetsanf}{$anforderung} eq 'gut' ) {
                    $self->zeile( $txt, $temp_anford, q{ }, q{X}, q{ }, q{ } );
                }
                elsif ( ${$qualitaetsanf}{$anforderung} eq 'normal' ) {
                    $self->zeile( $txt, $temp_anford, q{ }, q{ }, q{X}, q{ } );
                }
                else {
                    $self->zeile( $txt, $temp_anford, q{ }, q{ }, q{ }, q{X} );
                }
            }
        }
        $self->leere_zeile($txt);
    }
    return;
}    # ----------  end of subroutine qualitaet_einfuegen  ----------

#---------------------------------------------------------------------------
#  Subroutine: gui
#   
#   Fügt die Gui-Elemente in das Pflichtenheft ein
#
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#
#---------------------------------------------------------------------------
sub gui {

    my ( $self, $ref_pflicht, $txt ) = @_;

    my $einschub = $SPACE x 4;

    my $gui_ref  = ${$ref_pflicht}{'gui'};
    my @gui_keys = keys %{$gui_ref};
    if ( test_empty( \@gui_keys ) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'GUI' );
        foreach ( sort @gui_keys ) {
            my $nummer = encode_utf8($ARG);
            print {$txt} "\n";
            print {$txt} '    Nummer:    ' . $nummer . "\n";
            print {$txt} "\n";

            if ( test_empty( ${$gui_ref}{$ARG}[0] ) ) {
                print {$txt} "    Bezeichnung:\n";
                ausgabe_textblock_2( $ref_pflicht, $txt,
                    encode_utf8( ${$gui_ref}{$ARG}[0] ) );
            }

            if ( test_empty( ${$gui_ref}{$ARG}[3] ) ) {
                print {$txt} "    Beschreibung:\n";
                ausgabe_textblock_2( $ref_pflicht, $txt,
                    encode_utf8( ${$gui_ref}{$ARG}[3] ) );
            }

            my $rollen      = ${$gui_ref}{$ARG}[4];
            my @keys_rollen = keys %{$rollen};
            if ( \@keys_rollen ) {
                print {$txt} "\n";
                print {$txt} "    -- Rollen:\n";
                foreach my $r (@keys_rollen) {
                    my $name   = encode_utf8( ${$rollen}{$r}[0] );
                    my $beschr = encode_utf8( ${$rollen}{$r}[1] );
                    
                    my $t_titel = $einschub . $name . ': ';
                    my $spaces = $SPACE x length($t_titel);
                    print {$txt} wrap( 
                        $t_titel,
                        $spaces,
                        $beschr
                    );
                    print {$txt} "\n";
#                    print {$txt} $einschub . $name . ': ' . $beschr . "\n";
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
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#---------------------------------------------------------------------------
sub nfkt_anforderungen {

    my ( $self, $ref_pflicht, $txt ) = @_;

    my $nfkt = encode_utf8( ${$ref_pflicht}{'nfanforderungen'} );
    if ( test_empty($nfkt) ) {
        ueberschrift( $txt, $self->{'kap_no'},
            'Nichtfunktionale Anforderungen' );
        ausgabe_textblock( $ref_pflicht, $txt, $nfkt );
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
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub tech_umgebung {

    my ( $self, $ref_pflicht, $txt ) = @_;

    my @elemente = map { encode_utf8($ARG) } (
        ${$ref_pflicht}{'tumgebung'}{'produktumgebung'},
        ${$ref_pflicht}{'tumgebung'}{'software'},
        ${$ref_pflicht}{'tumgebung'}{'hardware'},
        ${$ref_pflicht}{'tumgebung'}{'orgware'},
        ${$ref_pflicht}{'tumgebung'}{'schnittstellen'},
    );

    if ( test_empty( \@elemente ) ) {
        my @titel = qw{
          Produktumgebung Software Hardware Orgware Schnittstellen};

        ueberschrift( $txt, $self->{'kap_no'}, 'Technische Umgebung' );
        ausgabe_textblock( $ref_pflicht, $txt, $elemente[0] );
        print {$txt} "\n";

        for ( 1 .. $#titel ) {
            if ( test_empty( $elemente[$ARG] ) ) {
                print {$txt} q{--} . $titel[ $ARG - 1 ] . "-- \n";
                ausgabe_textblock( $ref_pflicht, $txt, $elemente[$ARG] );
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
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub entw_umgebung {

    my ( $self, $ref_pflicht, $txt ) = @_;

    my @elemente = map { encode_utf8($ARG) } (
        ${$ref_pflicht}{'eumgebung'}{'produktumgebung'},
        ${$ref_pflicht}{'eumgebung'}{'software'},
        ${$ref_pflicht}{'eumgebung'}{'hardware'},
        ${$ref_pflicht}{'eumgebung'}{'orgware'},
        ${$ref_pflicht}{'eumgebung'}{'schnittstellen'},
    );
    if ( test_empty( \@elemente ) ) {
        my @titel = qw{
          Entwicklungsumgebung Software Hardware Orgware Schnittstellen};
        ueberschrift( $txt, $self->{'kap_no'}, 'Entwicklungsumgebung' );
        ausgabe_textblock( $ref_pflicht, $txt, $elemente[0] );
        print {$txt} "\n";
        for ( 1 .. $#titel ) {
            if ( test_empty( $elemente[$ARG] ) ) {
                print {$txt} q{--} . $titel[ $ARG - 1 ] . "-- \n";
                ausgabe_textblock( $ref_pflicht, $txt, $elemente[$ARG] );
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
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#   
#---------------------------------------------------------------------------
sub teilprodukte {

    my ( $self, $ref_pflicht, $txt ) = @_;

    my $ref_tp  = ${$ref_pflicht}{'teilprodukte'};
    my @tp_keys = keys %{$ref_tp};
    my $tp_beschreibung =
      encode_utf8( ${$ref_pflicht}{'teilprodukte_beschreibung'} );

    if ( test_empty($tp_beschreibung) or test_empty( \@tp_keys ) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Teilprodukte' );
        if ( test_empty($tp_beschreibung) ) {
            ausgabe_textblock( $ref_pflicht, $txt, $tp_beschreibung );
        }

        print {$txt} "\n";
        if ( test_empty( \@tp_keys ) ) {
            foreach my $key (@tp_keys) {
                my $beschreibung = encode_utf8( ${$ref_tp}{$key}[0] );
                print {$txt} "    Teilproduktbeschreibung:\n";
                ausgabe_textblock_2( $ref_pflicht, $txt, $beschreibung );
                print {$txt} "  -- Funktionen:\n";

                my $ref_funkt  = ${$ref_tp}{$key}[1];
                my @funktionen = keys %{$ref_funkt};
                foreach my $funk (@funktionen) {
                    my $funk_beschr = encode_utf8( ${$ref_funkt}{$funk}[0] );
                    my $funk_bemerk =
                      encode_utf8( "\t" . ${$ref_funkt}{$funk}[1] );
                    print {$txt} "    $funk\n";
                    if ( test_empty($funk_beschr) ) {
#                        print {$txt} "    Beschreibung: $funk_beschr\n";

                        my $t_titel = '    Beschreibung: ';
                        my $spaces = $SPACE x length($t_titel);
                        print {$txt} wrap( 
                            $t_titel,
                            $spaces,
                            $funk_beschr."\n"
                        );
                    }
                    if ( test_empty($funk_bemerk) ) {
#                        print {$txt} "    Bemerkung: $funk_bemerk\n";

                        my $t_titel = '    Bemerkung: ';
                        my $spaces = $SPACE x length($t_titel);
                        print {$txt} wrap( 
                            $t_titel,
                            $spaces,
                            $funk_bemerk."\n"
                        );
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
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub ergaenzungen {

    my ( $self, $ref_pflicht, $txt ) = @_;
    my $bildpfad = ${$ref_pflicht}{'pergaenzungen'}{'bildpfad'};
    my $uebersicht =
      encode_utf8( ${$ref_pflicht}{'pergaenzungen'}{'ergaenzungen'} );
    if ( test_empty($bildpfad) or test_empty($uebersicht) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Ergänzungen' );
        if ( test_empty($uebersicht) ) {
            ausgabe_textblock( $ref_pflicht, $txt, $uebersicht );
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
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub testfaelle {

    my ( $self, $ref_pflicht, $txt ) = @_;
    my $einschub        = $SPACE x 4;
    my $ref_test        = ${$ref_pflicht}{'testfaelle'};
    my @keys_testfaelle = sort keys %{$ref_test};
    if ( test_empty( \@keys_testfaelle ) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Testfälle' );
        my @titel = map { encode_utf8($ARG) } (
            'Nummer:',       'Bezeichnung:',
            'Vorbedingung:', 'Beschreibung:',
            'Sollverhalten:'
        );
        foreach my $key (@keys_testfaelle) {
            my @testfall = map { encode_utf8($ARG) } @{ ${$ref_test}{$key} };
            print {$txt} "\n";
            print {$txt} $einschub
              . $titel[0] . '  '
              . encode_utf8($key) . "\n";
            print {$txt} "\n";
            if ( test_empty( $testfall[0] ) ) {
                print {$txt} $einschub . $titel[1] . "\n";
                ausgabe_textblock_2( $ref_pflicht, $txt, $testfall[0] );
            }
            if ( test_empty( $testfall[1] ) ) {
                print {$txt} $einschub . $titel[2] . "\n";
                ausgabe_textblock_2( $ref_pflicht, $txt, $testfall[1] );
            }
            if ( test_empty( $testfall[2] ) ) {
                print {$txt} $einschub . $titel[3] . "\n";
                ausgabe_textblock_2( $ref_pflicht, $txt, $testfall[2] );
            }
            if ( test_empty( $testfall[3] ) ) {
                print {$txt} $einschub . $titel[4] . "\n";
                ausgabe_textblock_2( $ref_pflicht, $txt, $testfall[3] );
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
#   $txt                 - Referenz auf Hash mit Pflichtenheft
#   $ref_pflicht         - Filehandler
#  
#  See Also:
#   Funktionsgleich mit <produkteinsatz>
#---------------------------------------------------------------------------
sub glossar {
    my ( $self, $ref_pflicht, $txt ) = @_;
    my $einschub     = $SPACE x 4;
    my $ref_glossar  = ${$ref_pflicht}{'glossar'};
    my @keys_glossar = sort keys %{$ref_glossar};
    if ( test_empty( \@keys_glossar ) ) {
        ueberschrift( $txt, $self->{'kap_no'}, 'Glossar' );
        my @titel = map { encode_utf8($ARG) } ( 'Begriff:', 'Erklärung:' );

        foreach my $key (@keys_glossar) {
            my @glossar = map { encode_utf8($ARG) } @{ ${$ref_glossar}{$key} };

            print {$txt} $einschub
              . $titel[0]
              . '              '
              . encode_utf8($key) . "\n";
            print {$txt} '    ' . $titel[1] . "\n";
            ausgabe_textblock_2( $ref_pflicht, $txt, $glossar[0] );

        }
        $self->{'kap_no'}++;
    }
    return;
}    # ----------  end of subroutine glossar  ----------

END { }    # module clean-up code

1;
