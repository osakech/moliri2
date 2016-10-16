#===============================================================================
#
# Class: MoliriXML.pm
#
# Diese Klasse stellt Funktionalitaeten zum Export/Import der Daten
# eines Pflichtenheftes mittels XML-Dateien.
#
#
#  >Autor:       Alexandros Kechagias (Alexandros.Kechagias@gmx.de)
#  >Firma:       Fachhochschule Südwestfalen
#  >Version:     1.0
#  >Erstellt am: 13.04.2011 17:19:05
#  >Revision:    0.2
#===============================================================================
package MoliriXML;
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';    # Konsolenausgabe in Unicode

use English qw( -no_match_vars );

use IO::File;
use XML::Writer;
use XML::LibXML;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = { _pfad => shift };
    bless $self, $class;
    return $self;
}    # ----------  end of subroutine new  ----------


#---------------------------------------------------------------------------
#  Subroutine: version_xml
#  
#  Erstellt eine neue Version von Pflichtenheft indem das in $old_ver
#  angegebene Pflichtenheft eingelesen und nur die Versionsbezeichnung geändert
#  wird. Anschließend wird alles unter dem vom $new_ver angegebenen Pfad
#  abgespeichert.
#
#  Parameters: 
#  $new_ver - Pfad zur neuen Version
#  $old_ver - Pfad zur alten Version
#  $version - Neue Versionsbezeichnung die für $new_ver verwendet wird
#
#---------------------------------------------------------------------------
sub version_xml {
    my ( $self, $new_ver, $old_ver, $version ) = @_;

    my $in_file_name = $old_ver;    # input file name
    my $parser = XML::LibXML->new();

    open my $in, '<', $in_file_name
      or die
      "$PROGRAM_NAME : failed to open  input file '$in_file_name' : $ERRNO\n";

    my $dom = $parser->load_xml( IO => $in );

    close $in
      or warn
      "$PROGRAM_NAME : failed to close input file '$in_file_name' : $ERRNO\n";


    my ($node_version) =
      $dom->findnodes('//Pflichtenheft/Pflichtenheftdetails/Version/text()');

    # Version ändern
    $node_version->setData($version);


    my $out_file_name = $new_ver;    # output file name

    open my $out, '>', $out_file_name
      or die
      "$PROGRAM_NAME : failed to open  output file '$out_file_name' : $ERRNO\n";

    #in neue Datei schreiben
    $dom->toFH($out);

    close $out
      or warn
      "$PROGRAM_NAME : failed to close output file '$out_file_name' : $ERRNO\n";

    return;
}    # ----------  end of subroutine copy_xml  ----------

#---------------------------------------------------------------------------
#  Subroutine: export_xml
#  
#  Exportiert den Inhalt des übergebenen Pflichtenheftes in eine XML-Datei
#
#  Parameters: 
#  $par_ref = Referenz auf Pflichtenhefthash aus dem Hauptprogramm
#
#---------------------------------------------------------------------------
sub export_xml {
    my ( $self, $par_ref ) = @_;

    my $out_file_name = $self->{'_pfad'};               # output file name
#    my $ret           = check_rechte($out_file_name);
#    if ($ret) {
#        print "\nFEHLER $ret : Datei wird nicht beschrieben \n";
#        return ($ret);
#    }

    open my $out, '>', $out_file_name
      or die
"$PROGRAM_NAME : Konnte Ausgabedatei: '$out_file_name' nicht öffnen $ERRNO\n";

    my $writer = XML::Writer->new(
        OUTPUT      => $out,
        DATA_MODE   => 'true',
        DATA_INDENT => 2,
        ENCODING    => 'utf-8',
    );

    #---------------------------------------------------------------------------
    #  XML-Kopf schreiben
    #---------------------------------------------------------------------------
    $writer->xmlDecl('UTF-8');

    #    $writer->doctype('text/xml');
    $writer->comment(
        'Dieses Dokument wurde mit "Moliri - Pflichtenheftgenerator" erstellt');

    $writer->startTag('Pflichtenheft');

    #---------------------------------------------------------------------------
    #  Pflichtenheftdetails einfügen
    #---------------------------------------------------------------------------
    $writer->comment('Pflichtenheftdetails');

    $writer->startTag('Pflichtenheftdetails');

    my $titel     = ${$par_ref}{'Titel'};
    my $version   = ${$par_ref}{'Version'};
    my $autor     = ${$par_ref}{'Autor'};
    my $datum     = ${$par_ref}{'Datum'};
    my $status    = ${$par_ref}{'Status'};
    my $kommentar = ${$par_ref}{'Kommentar'};

    $writer->dataElement( 'Titel',     $titel );
    $writer->dataElement( 'Version',   $version );
    $writer->dataElement( 'Autor',     $autor );
    $writer->dataElement( 'Datum',     $datum );
    $writer->dataElement( 'Status',    $status );
    $writer->dataElement( 'Kommentar', $kommentar );

    $writer->endTag('Pflichtenheftdetails');

    #---------------------------------------------------------------------------
    #  Zielbestimmungen
    #---------------------------------------------------------------------------
    $writer->comment('Zielbestimmungen');
    my $zielbestimmungen = ${$par_ref}{'Zielbestimmungen'};
    $writer->startTag('Zielbestimmungen');
    foreach ( keys %{$zielbestimmungen} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Nummer', $ARG );
        $writer->dataElement( 'Typ',    @{ ${$zielbestimmungen}{$ARG} }[0] );
        $writer->dataElement( 'Beschreibung',
            @{ ${$zielbestimmungen}{$ARG} }[1] );

        $writer->endTag('eintrag');
    }
    $writer->endTag('Zielbestimmungen');

    #---------------------------------------------------------------------------
    #  Produkteinsatz
    #  -Produkteinsatz
    #  -Zielgruppen
    #  -Arbeitsbereiche
    #  -Betriebsbedingungen
    #---------------------------------------------------------------------------

    $writer->comment('Produkteinsatz');
    $writer->startTag('Einsatz');

    my $produkteinsatz      = ${$par_ref}{'Produkteinsatz'};
    my $zielgruppen         = ${$par_ref}{'Zielgruppen'};
    my $arbeitsbereiche     = ${$par_ref}{'Arbeitsbereiche'};
    my $betriebsbedingungen = ${$par_ref}{'Betriebsbedingungen'};

    $writer->dataElement( 'Produkteinsatz',      $produkteinsatz );
    $writer->dataElement( 'Zielgruppen',         $zielgruppen );
    $writer->dataElement( 'Arbeitsbereiche',     $arbeitsbereiche );
    $writer->dataElement( 'Betriebsbedingungen', $betriebsbedingungen );

    $writer->endTag('Einsatz');

    #---------------------------------------------------------------------------
    #  Produktübersicht
    #  -Bildbeschreibung
    #  -Bildpfad
    #  -Übersicht
    #---------------------------------------------------------------------------
    $writer->comment('Produktübersicht');
    $writer->startTag('PUebersicht');

    my $puebersicht_bildbeschreibung =
      ${$par_ref}{'Puebersicht_Bildbeschreibung'};
    my $puebersicht_bildpfad = ${$par_ref}{'Puebersicht_Bildpfad'};
    my $puebersicht          = ${$par_ref}{'Puebersicht'};

    $writer->dataElement( 'Bildbeschreibung',
        ${$puebersicht_bildbeschreibung} );
    $writer->dataElement( 'Bildpfad',   ${$puebersicht_bildpfad} );
    $writer->dataElement( 'Uebersicht', $puebersicht );

    $writer->endTag('PUebersicht');

    #---------------------------------------------------------------------------
    #  Funktionen
    #---------------------------------------------------------------------------
    $writer->comment('Funktionen');
    my $funktionen = ${$par_ref}{'Funktionen'};

    $writer->startTag('Funktionen');
    foreach ( keys %{$funktionen} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Nummer', $ARG );
        $writer->dataElement( 'Geschaeftsprozess',
            @{ ${$funktionen}{$ARG} }[0] );
        $writer->dataElement( 'Ziel',           @{ ${$funktionen}{$ARG} }[1] );
        $writer->dataElement( 'Vorbedingung',   @{ ${$funktionen}{$ARG} }[2] );
        $writer->dataElement( 'NachbedingungE', @{ ${$funktionen}{$ARG} }[3] );
        $writer->dataElement( 'NachbedingungF', @{ ${$funktionen}{$ARG} }[4] );
        $writer->dataElement( 'Akteure',        @{ ${$funktionen}{$ARG} }[5] );
        $writer->dataElement( 'AusEreignis',    @{ ${$funktionen}{$ARG} }[6] );
        $writer->dataElement( 'Beschreibung',   @{ ${$funktionen}{$ARG} }[7] );
        $writer->dataElement( 'Erweiterung',    @{ ${$funktionen}{$ARG} }[8] );
        $writer->dataElement( 'Alternativen',   @{ ${$funktionen}{$ARG} }[9] );
        $writer->endTag('eintrag');
    }
    $writer->endTag('Funktionen');

    #---------------------------------------------------------------------------
    #  Daten
    #---------------------------------------------------------------------------
    $writer->comment('Daten');
    my $daten = ${$par_ref}{'Daten'};

    $writer->startTag('Daten');
    foreach ( keys %{$daten} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Nummer',       $ARG );
        $writer->dataElement( 'Bezeichnung',  @{ ${$daten}{$ARG} }[0] );
        $writer->dataElement( 'Beschreibung', @{ ${$daten}{$ARG} }[1] );
        $writer->endTag('eintrag');
    }
    $writer->endTag('Daten');

    #---------------------------------------------------------------------------
    #  Leistungen
    #---------------------------------------------------------------------------
    $writer->comment('Leistungen');
    my $leistungen = ${$par_ref}{'Leistungen'};

    $writer->startTag('Leistungen');
    foreach ( keys %{$leistungen} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Nummer',       $ARG );
        $writer->dataElement( 'Bezeichnung',  @{ ${$leistungen}{$ARG} }[0] );
        $writer->dataElement( 'Beschreibung', @{ ${$leistungen}{$ARG} }[1] );
        $writer->endTag('eintrag');
    }
    $writer->endTag('Leistungen');

    #---------------------------------------------------------------------------
    #  Qualität
    #---------------------------------------------------------------------------

    $writer->comment('Qualität');
    my $qualitaet = ${$par_ref}{'Qualitaet'};

    $writer->startTag('Qualitaet');
    foreach ( keys %{$qualitaet} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Art',         $ARG );
        $writer->dataElement( 'Anforderung', ${$qualitaet}{$ARG} );
        $writer->endTag('eintrag');
    }
    $writer->endTag('Qualitaet');

    #---------------------------------------------------------------------------
    #  GUI
    #---------------------------------------------------------------------------

    $writer->comment('GUI');
    $writer->startTag('GUI');
    my $gui = ${$par_ref}{'GUI'};

    foreach my $k ( keys %{$gui} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Nummer',           $k );
        $writer->dataElement( 'Bezeichnung',      @{ ${$gui}{$k} }[0] );
        $writer->dataElement( 'Bildpfad',         @{ ${$gui}{$k} }[1] );
        $writer->dataElement( 'Bildbeschreibung', @{ ${$gui}{$k} }[2] );
        $writer->dataElement( 'Beschreibung',     @{ ${$gui}{$k} }[3] );
        $writer->startTag('Rollen');
        my %temp_rollen = %{ @{ ${$gui}{$k} }[4] };

        foreach my $l ( keys %temp_rollen ) {
            $writer->startTag('rolle');
            $writer->dataElement( 'Nummer',      $l );
            $writer->dataElement( 'Bezeichnung', $temp_rollen{$l}[0] );
            $writer->dataElement( 'Rechte',      $temp_rollen{$l}[1] );
            $writer->endTag('rolle');
        }
        $writer->endTag('Rollen');
        $writer->endTag('eintrag');
    }
    $writer->endTag('GUI');

    #---------------------------------------------------------------------------
    #  Nichtfunktionale Anforderungen
    #---------------------------------------------------------------------------
    $writer->comment('Nichtfunktionale Anforderungen');
    my $anforderungen = ${$par_ref}{'Anforderungen'};
    $writer->dataElement( 'NfAnforderungen', $anforderungen );

    #---------------------------------------------------------------------------
    #  Technische Umgebung
    #---------------------------------------------------------------------------

    $writer->comment('Technische Umgebung');
    $writer->startTag('TUmgebung');

    my $t_produktumgebung = ${$par_ref}{'T_Produktumgebung'};
    my $t_software        = ${$par_ref}{'T_Software'};
    my $t_hardware        = ${$par_ref}{'T_Hardware'};
    my $t_orgware         = ${$par_ref}{'T_Orgware'};
    my $t_schnittstellen  = ${$par_ref}{'T_Schnittstellen'};

    $writer->dataElement( 'TProduktumgebung', $t_produktumgebung );
    $writer->dataElement( 'TSoftware',        $t_software );
    $writer->dataElement( 'THardware',        $t_hardware );
    $writer->dataElement( 'TOrgware',         $t_orgware );
    $writer->dataElement( 'TSchnittstellen',  $t_schnittstellen );

    $writer->endTag('TUmgebung');

    #---------------------------------------------------------------------------
    #  Entwicklungsumgebung
    #---------------------------------------------------------------------------

    $writer->comment('Entwicklungsumgebung');
    $writer->startTag('EUmgebung');

    my $e_produktumgebung = ${$par_ref}{'E_Produktumgebung'};
    my $e_software        = ${$par_ref}{'E_Software'};
    my $e_hardware        = ${$par_ref}{'E_Hardware'};
    my $e_orgware         = ${$par_ref}{'E_Orgware'};
    my $e_schnittstellen  = ${$par_ref}{'E_Schnittstellen'};

    $writer->dataElement( 'EProduktumgebung', $e_produktumgebung );
    $writer->dataElement( 'ESoftware',        $e_software );
    $writer->dataElement( 'EHardware',        $e_hardware );
    $writer->dataElement( 'EOrgware',         $e_orgware );
    $writer->dataElement( 'ESchnittstellen',  $e_schnittstellen );
    $writer->endTag('EUmgebung');

    #---------------------------------------------------------------------------
    #  Teilprodukt
    #---------------------------------------------------------------------------
    $writer->comment('Teilprodukt');
    my $teilprodukte_beschreibung = ${$par_ref}{'Teilprodukte_Beschreibung'};
    my $teilprodukte              = ${$par_ref}{'Teilprodukte'};

    #    print Dumper( %{$teilprodukte} );

    $writer->startTag('Teilprodukte');
    $writer->dataElement( 'Beschreibung', $teilprodukte_beschreibung );

    foreach my $k ( keys %{$teilprodukte} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Nummer',       $k );
        $writer->dataElement( 'Beschreibung', @{ ${$teilprodukte}{$k} }[0] );

        $writer->startTag('Funktionen');
        my %temp_funktionen = %{ @{ ${$teilprodukte}{$k} }[1] };
        foreach my $l ( keys %temp_funktionen ) {
            $writer->startTag('funktion');
            $writer->dataElement( 'Nummer',       $l );
            $writer->dataElement( 'Beschreibung', $temp_funktionen{$l}[0] );
            $writer->dataElement( 'Bemerkung',    $temp_funktionen{$l}[1] );
            $writer->endTag('funktion');
        }
        $writer->endTag('Funktionen');

        $writer->endTag('eintrag');
    }

    $writer->endTag('Teilprodukte');

    #---------------------------------------------------------------------------
    #  Produktergänzungen
    #---------------------------------------------------------------------------
    $writer->comment('Produktergänzungen');
    $writer->startTag('PErgaenzungen');
    my $ergaenzungen_bild = ${$par_ref}{'Ergaenzungen_Bild'};
    my $ergaenzungen_bildbeschreibung =
      ${$par_ref}{'Ergaenzungen_Bildbeschreibung'};
    my $ergaenzungen = ${$par_ref}{'Ergaenzungen'};

    $writer->dataElement( 'EBild', ${$ergaenzungen_bild} );
    $writer->dataElement( 'EBildbeschreibung',
        ${$ergaenzungen_bildbeschreibung} );
    $writer->dataElement( 'Ergaenzungen', $ergaenzungen );

    $writer->endTag('PErgaenzungen');

    #---------------------------------------------------------------------------
    #  Testfälle
    #---------------------------------------------------------------------------
    $writer->comment('Testfälle');
    my $testfaelle = ${$par_ref}{'Testfaelle'};

    $writer->startTag('Testfaelle');
    foreach ( keys %{$testfaelle} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Nummer',        $ARG );
        $writer->dataElement( 'Bezeichnung',   @{ ${$testfaelle}{$ARG} }[0] );
        $writer->dataElement( 'Vorbedingung',  @{ ${$testfaelle}{$ARG} }[1] );
        $writer->dataElement( 'Beschreibung',  @{ ${$testfaelle}{$ARG} }[2] );
        $writer->dataElement( 'Sollverhalten', @{ ${$testfaelle}{$ARG} }[3] );
        $writer->endTag('eintrag');
    }
    $writer->endTag('Testfaelle');

    #---------------------------------------------------------------------------
    #  Glossar
    #---------------------------------------------------------------------------
    $writer->comment('Glossar');
    $writer->startTag('Glossar');
    my $glossar = ${$par_ref}{'Glossar'};
    foreach ( keys %{$glossar} ) {
        $writer->startTag('eintrag');
        $writer->dataElement( 'Begriff',    $ARG );
        $writer->dataElement( 'Erklaerung', @{ ${$glossar}{$ARG} }[0] );
        $writer->endTag('eintrag');
    }
    $writer->endTag('Glossar');

    #---------------------------------------------------------------------------
    #  Kapitel - Funktionen
    #---------------------------------------------------------------------------
    $writer->comment('Kapitel - Funktionen');
    $writer->startTag('KapitelFunktionen');
    my $kapitel_funktion = ${$par_ref}{'Kapitel_Funktion'};

    foreach ( keys %{$kapitel_funktion} ) {
        $writer->startTag('kapitel');
        $writer->dataElement( 'Bezeichnung', $ARG );
        $writer->startTag('kfunktionen');
        foreach my $k ( keys %{ ${$kapitel_funktion}{$ARG} } ) {
            $writer->dataElement( 'Nummer', $k );
        }
        $writer->endTag('kfunktionen');
        $writer->endTag('kapitel');
    }
    $writer->endTag('KapitelFunktionen');

    #---------------------------------------------------------------------------
    #  Kapitel - Daten
    #---------------------------------------------------------------------------
    $writer->comment('Kapitel - Daten');
    $writer->startTag('KapitelDaten');
    my $kapitel_daten = ${$par_ref}{'Kapitel_Daten'};

    foreach ( keys %{$kapitel_daten} ) {
        $writer->startTag('kapitel');
        $writer->dataElement( 'Bezeichnung', $ARG );
        $writer->startTag('kfunktionen');
        foreach my $k ( keys %{ ${$kapitel_daten}{$ARG} } ) {
            $writer->dataElement( 'Nummer', $k );
        }
        $writer->endTag('kfunktionen');
        $writer->endTag('kapitel');
    }
    $writer->endTag('KapitelDaten');

    #---------------------------------------------------------------------------
    #  Kapitel - Leistungen
    #---------------------------------------------------------------------------
    $writer->comment('Kapitel - Leistungen');
    $writer->startTag('KapitelLeistungen');
    my $kapitel_leistungen = ${$par_ref}{'Kapitel_Leistungen'};

    foreach ( keys %{$kapitel_leistungen} ) {
        $writer->startTag('kapitel');
        $writer->dataElement( 'Bezeichnung', $ARG );
        $writer->startTag('kfunktionen');
        foreach my $k ( keys %{ ${$kapitel_leistungen}{$ARG} } ) {
            $writer->dataElement( 'Nummer', $k );
        }
        $writer->endTag('kfunktionen');
        $writer->endTag('kapitel');
    }
    $writer->endTag('KapitelLeistungen');
    $writer->endTag('Pflichtenheft');

    $writer->end();
    close $out
      or warn
      "$PROGRAM_NAME : failed to close output file '$out_file_name' : $ERRNO\n";

    return;
}    # ----------  end of subroutine export_xml  ----------

#---------------------------------------------------------------------------
#  Subroutine: import_xml
#  
#  Exportiert den Inhalt des übergebenen Pflichtenheftes in eine XML-Datei
#
#  Returns:
#  \%pflichtenheft = Referenz auf Pflichtenhefthash
#
#---------------------------------------------------------------------------
sub import_xml {
    my ( $self ) = @_;

    my $in_file_name = $self->{'_pfad'};    # input file name

    open my $in, '<', $in_file_name
      or die
"$PROGRAM_NAME : Konnte Eingabedatei '$in_file_name' nicht öffnen: $ERRNO\n";

    my $parser = XML::LibXML->new();
    my $dom = $parser->load_xml( IO => $in );

    #---------------------------------------------------------------------------
    #  Pflichtenheftdetails
    #
    # <Pflichtenheftdetails>
    #   <Titel></Titel>
    #   <Version></Version>
    #   <Autor></Autor>
    #   <Datum></Datum>
    #   <Status></Status>
    #   <Kommentar></Kommentar>
    # </Pflichtenheftdetails>
    #
    #---------------------------------------------------------------------------
    my %pflichtenheft;
    my $titel = $dom->findnodes('//Pflichtenheft/Pflichtenheftdetails/Titel');
    my $version =
      $dom->findnodes('//Pflichtenheft/Pflichtenheftdetails/Version');
    my $autor  = $dom->findnodes('//Pflichtenheft/Pflichtenheftdetails/Autor');
    my $datum  = $dom->findnodes('//Pflichtenheft/Pflichtenheftdetails/Datum');
    my $status = $dom->findnodes('//Pflichtenheft/Pflichtenheftdetails/Status');
    my $kommentar =
      $dom->findnodes('//Pflichtenheft/Pflichtenheftdetails/Kommentar');

    $pflichtenheft{'details'} = {
        'titel'     => $titel->string_value(),
        'version'   => $version->string_value(),
        'autor'     => $autor->string_value(),
        'datum'     => $datum->string_value(),
        'status'    => $status->string_value(),
        'kommentar' => $kommentar->string_value()
    };

    #---------------------------------------------------------------------------
    #  Zielbestimmungen
    #
    # <Zielbestimmungen>
    #   <eintrag>
    #     <Nummer></Nummer>
    #     <Typ>Wunschkriterium</Typ>
    #     <Beschreibung></Beschreibung>
    #   </eintrag>
    # </Zielbestimmungen>
    #
    #---------------------------------------------------------------------------

    foreach my $eintrag (
        $dom->findnodes('//Pflichtenheft/Zielbestimmungen/eintrag') )
    {
        my $nummer       = $eintrag->findnodes('./Nummer');
        my $typ          = $eintrag->findnodes('./Typ');
        my $beschreibung = $eintrag->findnodes('./Beschreibung');
        $pflichtenheft{'zielbestimmungen'}{ $nummer->string_value() } =
          [ $typ->string_value(), $beschreibung->string_value(), ];

    }

    #---------------------------------------------------------------------------
    # Produkteinsatz
    #
    # <Einsatz>
    #   <Produkteinsatz></Produkteinsatz>
    #   <Zielgruppen></Zielgruppen>
    #   <Arbeitsbereiche></Arbeitsbereiche>
    #   <Betriebsbedingungen></Betriebsbedingungen>
    # </Einsatz>
    #
    #---------------------------------------------------------------------------

    my $produkteinsatz =
      $dom->findnodes('//Pflichtenheft/Einsatz/Produkteinsatz');
    my $zielgruppen = $dom->findnodes('//Pflichtenheft/Einsatz/Zielgruppen');
    my $arbeitsbereiche =
      $dom->findnodes('//Pflichtenheft/Einsatz/Arbeitsbereiche');
    my $betriebsbedingungen =
      $dom->findnodes('//Pflichtenheft/Einsatz/Betriebsbedingungen');

    $pflichtenheft{'einsatz'} = {
        'produkteinsatz'      => $produkteinsatz->string_value(),
        'zielgruppen'         => $zielgruppen->string_value(),
        'arbeitsbereiche'     => $arbeitsbereiche->string_value(),
        'betriebsbedingungen' => $betriebsbedingungen->string_value(),
    };

    #---------------------------------------------------------------------------
    #  Produktübersicht
    #
    # <PUebersicht>
    #   <Bildbeschreibung></Bildbeschreibung>
    #   <Bildpfad></Bildpfad>
    #   <Uebersicht></Uebersicht>
    # </PUebersicht>
    #
    #---------------------------------------------------------------------------
    my $produktuebersicht_pfad =
      $dom->findnodes('//Pflichtenheft/PUebersicht/Bildpfad');
    my $produktuebersicht_beschreibung =
      $dom->findnodes('//Pflichtenheft/PUebersicht/Bildbeschreibung');
    my $produktuebersicht =
      $dom->findnodes('//Pflichtenheft/PUebersicht/Uebersicht');

    $pflichtenheft{'uebersicht'} = {
        'bildpfad'         => $produktuebersicht_pfad->string_value(),
        'bildbeschreibung' => $produktuebersicht_beschreibung->string_value(),
        'uebersicht'       => $produktuebersicht->string_value(),
    };

    #---------------------------------------------------------------------------
    #  Produktfunktion
    #
    # <Funktionen>
    #   <eintrag>
    #     <Nummer></Nummer>
    #     <Geschaeftsprozess></Geschaeftsprozess>
    #     <Ziel></Ziel>
    #     <Vorbedingung></Vorbedingung>
    #     <NachbedingungE></NachbedingungE>
    #     <NachbedingungF></NachbedingungF>
    #     <Akteure></Akteure>
    #     <AusEreignis></AusEreignis>
    #     <Beschreibung></Beschreibung>
    #     <Erweiterung></Erweiterung>
    #     <Alternativen></Alternativen>
    #   </eintrag>
    # </Funktionen>
    #
    #---------------------------------------------------------------------------

    foreach
      my $eintrag ( $dom->findnodes('//Pflichtenheft/Funktionen/eintrag') )
    {
        my $nummer            = $eintrag->findnodes('./Nummer');
        my $geschaeftsprozess = $eintrag->findnodes('./Geschaeftsprozess   ');
        my $ziel              = $eintrag->findnodes('./Ziel');
        my $vorbedingung      = $eintrag->findnodes('./Vorbedingung');
        my $nachbedingunge    = $eintrag->findnodes('./NachbedingungE');
        my $nachbedingungf    = $eintrag->findnodes('./NachbedingungF');
        my $akteure           = $eintrag->findnodes('./Akteure');
        my $ausereignis       = $eintrag->findnodes('./AusEreignis');
        my $beschreibung      = $eintrag->findnodes('./Beschreibung');
        my $erweiterung       = $eintrag->findnodes('./Erweiterung');
        my $alternativen      = $eintrag->findnodes('./Alternativen');

        $pflichtenheft{'funktionen'}{ $nummer->string_value() } = [
            $geschaeftsprozess->string_value(),    #0
            $ziel->string_value(),                 #1
            $vorbedingung->string_value(),         #2
            $nachbedingunge->string_value(),       #3
            $nachbedingungf->string_value(),       #4
            $akteure->string_value(),              #5
            $ausereignis->string_value(),          #6
            $beschreibung->string_value(),         #7
            $erweiterung->string_value(),          #8
            $alternativen->string_value(),         #9
        ];

    }

    #---------------------------------------------------------------------------
    #  Daten
    #
    # <Daten>
    #   <eintrag>
    #     <Nummer></Nummer>
    #     <Bezeichnung></Bezeichnung>
    #     <Beschreibung></Beschreibung>
    #   </eintrag>
    # </Daten>
    #
    #---------------------------------------------------------------------------

    foreach my $eintrag ( $dom->findnodes('//Pflichtenheft/Daten/eintrag') ) {
        my $nummer       = $eintrag->findnodes('./Nummer');
        my $bezeichnung  = $eintrag->findnodes('./Bezeichnung');
        my $beschreibung = $eintrag->findnodes('./Beschreibung');

        $pflichtenheft{'daten'}{ $nummer->string_value() } = [
            $bezeichnung->string_value(),     #0
            $beschreibung->string_value(),    #1
        ];

    }

    #---------------------------------------------------------------------------
    #  Leistungen
    #
    # <Leistungen>
    #   <eintrag>
    #     <Nummer>30</Nummer>
    #     <Bezeichnung></Bezeichnung>
    #     <Beschreibung></Beschreibung>
    #   </eintrag>
    # </Leistungen>
    #
    #---------------------------------------------------------------------------

    foreach
      my $eintrag ( $dom->findnodes('//Pflichtenheft/Leistungen/eintrag') )
    {
        my $nummer       = $eintrag->findnodes('./Nummer');
        my $bezeichnung  = $eintrag->findnodes('./Bezeichnung');
        my $beschreibung = $eintrag->findnodes('./Beschreibung');

        $pflichtenheft{'leistungen'}{ $nummer->string_value() } = [
            $bezeichnung->string_value(),     #0
            $beschreibung->string_value(),    #1
        ];

    }

    #---------------------------------------------------------------------------
    #  Qualität
    #
    # <eintrag>
    #   <Art>analysierbarkeit</Art>
    #   <Anforderung>sehr gut</Anforderung>
    # </eintrag>
    #
    #---------------------------------------------------------------------------
    foreach my $eintrag ( $dom->findnodes('//Pflichtenheft/Qualitaet/eintrag') )
    {
        my $art         = $eintrag->findnodes('./Art');
        my $anforderung = $eintrag->findnodes('./Anforderung');
        $pflichtenheft{'qualitaet'}{ $art->string_value() } =
          $anforderung->string_value();
    }

    #---------------------------------------------------------------------------
    #  GUI
    #
    # <GUI>
    #   <eintrag>
    #     <Nummer>12</Nummer>
    #     <Bezeichnung></Bezeichnung>
    #     <Bildpfad></Bildpfad>
    #     <Bildbeschreibung></Bildbeschreibung>
    #     <Beschreibung></Beschreibung>
    #     <Rollen>
    #       <rolle>
    #         <Nummer></Nummer>
    #         <Bezeichnung></Bezeichnung>
    #         <Rechte></Rechte>
    #       </rolle>
    #     </Rollen>
    #   </eintrag>
    # </GUI>
    #---------------------------------------------------------------------------
    foreach my $eintrag ( $dom->findnodes('//Pflichtenheft/GUI/eintrag') ) {
        my $nummer           = $eintrag->findnodes('./Nummer');
        my $bezeichnung      = $eintrag->findnodes('./Bezeichnung');
        my $bildpfad         = $eintrag->findnodes('./Bildpfad');
        my $bildbeschreibung = $eintrag->findnodes('./Bildbeschreibung');
        my $beschreibung     = $eintrag->findnodes('./Beschreibung');
        my %tmp_rollen;

        foreach my $rollen ( $eintrag->findnodes('./Rollen/rolle') ) {
            my $nummer_      = $rollen->findnodes('./Nummer');
            my $bezeichnung_ = $rollen->findnodes('./Bezeichnung');
            my $rechte_      = $rollen->findnodes('./Rechte');
            $tmp_rollen{ $nummer_->string_value } = [
                $bezeichnung_->string_value(),    #0
                $rechte_->string_value(),         #1
            ];
        }
        $pflichtenheft{'gui'}{ $nummer->string_value() } = [
            $bezeichnung->string_value(),         #0
            $bildpfad->string_value(),            #1
            $bildbeschreibung->string_value(),    #2
            $beschreibung->string_value(),        #3
            \%tmp_rollen,                         #4
        ];
    }

    #---------------------------------------------------------------------------
    #  Nichtfunktionale Anforderung
    #
    # <NfAnforderungen>Was ist den los hier Bitach</NfAnforderungen>
    #
    #---------------------------------------------------------------------------
    my $nfanforderungen = $dom->findnodes('//Pflichtenheft/NfAnforderungen');

    $pflichtenheft{'nfanforderungen'} = $nfanforderungen->string_value();

    #---------------------------------------------------------------------------
    #  Technische Umgebung
    #
    # <TUmgebung>
    #   <TProduktumgebung></TProduktumgebung>
    #   <TSoftware></TSoftware>
    #   <THardware></THardware>
    #   <TOrgware></TOrgware>
    #   <TSchnittstellen></TSchnittstellen>
    # </TUmgebung>
    #
    #---------------------------------------------------------------------------

    my $tproduktumgebung =
      $dom->findnodes('//Pflichtenheft/TUmgebung/TProduktumgebung');
    my $tsoftware = $dom->findnodes('//Pflichtenheft/TUmgebung/TSoftware');
    my $thardware = $dom->findnodes('//Pflichtenheft/TUmgebung/THardware');
    my $torgware  = $dom->findnodes('//Pflichtenheft/TUmgebung/TOrgware');
    my $tschnittstellen =
      $dom->findnodes('//Pflichtenheft/TUmgebung/TSchnittstellen');

    $pflichtenheft{'tumgebung'} = {
        'produktumgebung' => $tproduktumgebung->string_value(),
        'software'        => $tsoftware->string_value(),
        'hardware'        => $thardware->string_value(),
        'orgware'         => $torgware->string_value(),
        'schnittstellen'  => $tschnittstellen->string_value(),
    };

    #---------------------------------------------------------------------------
    #  Entwicklungsumgebung
    #---------------------------------------------------------------------------

    my $eproduktumgebung =
      $dom->findnodes('//Pflichtenheft/EUmgebung/EProduktumgebung');
    my $esoftware = $dom->findnodes('//Pflichtenheft/EUmgebung/ESoftware');
    my $ehardware = $dom->findnodes('//Pflichtenheft/EUmgebung/EHardware');
    my $eorgware  = $dom->findnodes('//Pflichtenheft/EUmgebung/EOrgware');
    my $eschnittstellen =
      $dom->findnodes('//Pflichtenheft/EUmgebung/ESchnittstellen');

    $pflichtenheft{'eumgebung'} = {
        'produktumgebung' => $eproduktumgebung->string_value(),
        'software'        => $esoftware->string_value(),
        'hardware'        => $ehardware->string_value(),
        'orgware'         => $eorgware->string_value(),
        'schnittstellen'  => $eschnittstellen->string_value(),
    };

   #---------------------------------------------------------------------------
   #  Teilprodukte
   #
   # <Teilprodukte>
   #   <Beschreibung></Beschreibung>
   #   <eintrag>
   #     <Nummer></Nummer>
   #     <Beschreibung></Beschreibung>
   #     <Funktionen>
   #       <funktion>
   #         <Nummer></Nummer>
   #         <Beschreibung></Beschreibung>
   #         <Bemerkung></Bemerkung>
   #       </funktion>
   #     </Funktionen>
   #   </eintrag>
   # </Teilprodukte>
   #
   # ---------------------------------------------------------------------------
    my $tpkommentar =
      $dom->findnodes('//Pflichtenheft/Teilprodukte/Beschreibung');
    foreach
      my $eintrag ( $dom->findnodes('//Pflichtenheft/Teilprodukte/eintrag') )
    {
        my $nummer       = $eintrag->findnodes('./Nummer');
        my $beschreibung = $eintrag->findnodes('./Beschreibung');
        my %tmp_funkt;

        foreach my $funkt ( $eintrag->findnodes('./Funktionen/funktion') ) {
            my $nummer_       = $funkt->findnodes('./Nummer');
            my $beschreibung_ = $funkt->findnodes('./Beschreibung');
            my $bemerkung_    = $funkt->findnodes('./Bemerkung');
            $tmp_funkt{ $nummer_->string_value } = [
                $beschreibung_->string_value(),    #0
                $bemerkung_->string_value(),       #1
            ];
        }
        $pflichtenheft{'teilprodukte'}{ $nummer->string_value() } = [
            $beschreibung->string_value(),         #0
            \%tmp_funkt,                           #1
        ];
    }
    $pflichtenheft{'teilprodukte_beschreibung'} = $tpkommentar->string_value();

    #---------------------------------------------------------------------------
    #  Produktergänzungen
    #
    # <PErgaenzungen>
    #     <EBild></EBild>
    #     <EBildbeschreibung></EBildbeschreibung>
    #     <Ergaenzungen></Ergaenzungen>
    # </PErgaenzungen>
    #---------------------------------------------------------------------------
    my $produktergaenzung_pfad =
      $dom->findnodes('//Pflichtenheft/PErgaenzungen/EBild');
    my $produktergaenzung_beschreibung =
      $dom->findnodes('//Pflichtenheft/PErgaenzungen/EBildbeschreibung');
    my $produktergaenzung =
      $dom->findnodes('//Pflichtenheft/PErgaenzungen/Ergaenzungen');

    $pflichtenheft{'pergaenzungen'} = {
        'bildpfad'         => $produktergaenzung_pfad->string_value(),
        'bildbeschreibung' => $produktergaenzung_beschreibung->string_value(),
        'ergaenzungen'     => $produktergaenzung->string_value(),
    };

    #---------------------------------------------------------------------------
    #  Testfälle
    #
    # <Testfaelle>
    #     <eintrag>
    #         <Nummer></Nummer>
    #         <Bezeichnung></Bezeichnung>
    #         <Vorbedingung></Vorbedingung>
    #         <Beschreibung></Beschreibung>
    #         <Sollverhalten></Sollverhalten>
    #     </eintrag>
    # </Testfaelle>
    #---------------------------------------------------------------------------

    foreach
      my $eintrag ( $dom->findnodes('//Pflichtenheft/Testfaelle/eintrag') )
    {
        my $nummer        = $eintrag->findnodes('./Nummer');
        my $bezeichnung   = $eintrag->findnodes('./Bezeichnung');
        my $vorbedingung  = $eintrag->findnodes('./Vorbedingung');
        my $beschreibung  = $eintrag->findnodes('./Beschreibung');
        my $sollverhalten = $eintrag->findnodes('./Sollverhalten');

        $pflichtenheft{'testfaelle'}{ $nummer->string_value() } = [
            $bezeichnung->string_value(),      #0
            $vorbedingung->string_value(),     #1
            $beschreibung->string_value(),     #2
            $sollverhalten->string_value(),    #3
        ];
    }

    #---------------------------------------------------------------------------
    #  Glossar
    #
    # <Glossar>
    #   <eintrag>
    #     <Begriff></Begriff>
    #     <Erklaerung></Erklaerung>
    #   </eintrag>
    # </Glossar>
    #
    #---------------------------------------------------------------------------

    foreach my $eintrag ( $dom->findnodes('//Pflichtenheft/Glossar/eintrag') ) {
        my $begriff    = $eintrag->findnodes('./Begriff');
        my $erklaerung = $eintrag->findnodes('./Erklaerung');

        $pflichtenheft{'glossar'}{ $begriff->string_value() } = [
            $erklaerung->string_value(),    #0
        ];
    }

    #---------------------------------------------------------------------------
    # Kapitel Funktionen
    #
    # <KapitelFunktionen>
    #   <kapitel>
    #     <Bezeichnung></Bezeichnung>
    #     <kfunktionen>
    #       <Nummer></Nummer>
    #     </kfunktionen>
    #   </kapitel>
    # </KapitelFunktionen>
    #
    #---------------------------------------------------------------------------

    foreach my $eintrag (
        $dom->findnodes('//Pflichtenheft/KapitelFunktionen/kapitel') )
    {
        my $bezeichnung = $eintrag->findnodes('./Bezeichnung');
        my %tmp_nummer;
        foreach my $funk ( $eintrag->findnodes('./kfunktionen') ) {
            foreach my $nummer ( $funk->findnodes('./Nummer') ) {
                my $nummer_ = $nummer->string_value();
                $pflichtenheft{'kfunktionen'}{ $bezeichnung->string_value }
                  {$nummer_} = $nummer_;
            }
        }
    }

    #---------------------------------------------------------------------------
    #  Kapitel Daten
    #
    #  <KapitelDaten>
    #    <kapitel>
    #      <Bezeichnung>Datum 20 wa</Bezeichnung>
    #      <kfunktionen>
    #        <Nummer>20</Nummer>
    #      </kfunktionen>
    #    </kapitel>
    #  </KapitelDaten>
    #
    #---------------------------------------------------------------------------
    foreach
      my $eintrag ( $dom->findnodes('//Pflichtenheft/KapitelDaten/kapitel') )
    {
        my $bezeichnung = $eintrag->findnodes('./Bezeichnung');
        my %tmp_nummer;
        foreach my $funk ( $eintrag->findnodes('./kfunktionen') ) {
            foreach my $nummer ( $funk->findnodes('./Nummer') ) {
                my $nummer_ = $nummer->string_value();
                $pflichtenheft{'kdaten'}{ $bezeichnung->string_value }
                  {$nummer_} = $nummer_;
            }

 #            my $nummer  = $funk->findnodes('./Nummer');
 #            my $nummer_ = $nummer->string_value();
 #            $pflichtenheft{'kdaten'}{ $bezeichnung->string_value }{$nummer_} =
 #              $nummer_;
        }
    }

    #---------------------------------------------------------------------------
    #   Kapitel Leistungen
    #
    #  <KapitelLeistungen>
    #    <kapitel>
    #      <Bezeichnung>Leistung 30</Bezeichnung>
    #      <kfunktionen>
    #        <Nummer>30</Nummer>
    #      </kfunktionen>
    #    </kapitel>
    #  </KapitelLeistungen>
    #
    #---------------------------------------------------------------------------

    foreach my $eintrag (
        $dom->findnodes('//Pflichtenheft/KapitelLeistungen/kapitel') )
    {
        my $bezeichnung = $eintrag->findnodes('./Bezeichnung');
        my %tmp_nummer;
        foreach my $funk ( $eintrag->findnodes('./kfunktionen') ) {
            foreach my $nummer ( $funk->findnodes('./Nummer') ) {
                my $nummer_ = $nummer->string_value();
                $pflichtenheft{'kleistungen'}{ $bezeichnung->string_value }
                  {$nummer_} = $nummer_;
            }

        #            my $nummer  = $funk->findnodes('./Nummer');
        #            my $nummer_ = $nummer->string_value();
        #            $pflichtenheft{'kleistungen'}{ $bezeichnung->string_value }
        #              {$nummer_} = $nummer_;
        }
    }

    close $in
      or warn
"$PROGRAM_NAME : Konnte Eingabedatei '$in_file_name' nicht schließen : $ERRNO\n";
    return ( \%pflichtenheft );
}    # ----------  end of subroutine import_xml  ----------

END { }    # module clean-up code

1;
