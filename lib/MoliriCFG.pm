#===============================================================================
#
# Class: MoliriCFG.pm
#
# Diese Klasse liest und speichert die Konfiguratiosdaten des Moliri.
# Die Daten werden aus moliricfg.xml geladen und geschrieben.
#
#   *Benutzt folgende Module*
#   - XML::LibXML        -- <http://search.cpan.org/~pajas/XML-LibXML-1.70/>
#   - XML::Writer        -- <http://search.cpan.org/~josephw/XML-Writer-0.605/>
#
#  >Autor:       Alexandros Kechagias (Alexandros.Kechagias@gmx.de)
#  >Firma:       Fachhochschule Südwestfalen
#  >Version:     1.0
#  >Erstellt am: 13.04.2011 17:19:05
#  >Revision:    0.2
#===============================================================================
package MoliriCFG;
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';    # Konsolenausgabe in Unicode

use English qw( -no_match_vars );

use IO::File;
use XML::Writer;
use XML::LibXML;
#use Data::Dumper;

#---------------------------------------------------------------------------
#  Subroutine: new
#
#  Konstruktor, ruft zusätzlich <check_config> auf um zu überprüfen ob 
#  Konfigurationsdatei moliri.xml existiert
#---------------------------------------------------------------------------
sub new {
    my $self = {};
    bless $self, 'MoliriCFG';
    $self->check_config('moliricfg.xml');
    return $self;
}

#---------------------------------------------------------------------------
#  Subroutine: check_config
#
#  Überprüft ob Konfigurationsdatei existiert und gültig ist.
#---------------------------------------------------------------------------
sub check_config {
    my ( $self, $par1 ) = @_;

    if ( not -e $par1 ) {
        return (1);    #Fehler: Datei existiert nicht
    }
    else {

        my $in_file_name = 'moliricfg.xml';    # input file name

        open my $in, '<', $in_file_name
          or die
"$PROGRAM_NAME : Konnte Eingabedatei '$in_file_name' nicht öffnen: $ERRNO\n";

        my $parser = XML::LibXML->new();
        $parser->validation(1);                #aktiviere dtd-überprüfung
        my $dom = $parser->load_xml( IO => $in );

        close $in
          or warn
"$PROGRAM_NAME : Konnte Eingabedatei '$in_file_name' nicht schließen : $ERRNO\n";
    }
    return;
}    # ----------  end of subroutine check_config  ----------

#---------------------------------------------------------------------------
#   Subroutine: set_config
#
#   Setzt Konfigurationsdatei auf die neuen Konfigurationsdaten.
#   Übergebener Hash hat immer die Form:
#
#     *Dumperausgabe*
#     >$VAR1 = {
#     >         'rschreib' => '0',
#     >         'azeit' => '1',
#     >         'aan' => '0',
#     >         'sordner' => '/home/alexandros/',
#     >         'aordner' => '/home/alexandros/Desktop/moliri-pflichtenhefte'
#     >};
#
#---------------------------------------------------------------------------
sub set_config {
    my ( $self, $par1 ) = @_;
    my $out_file_name = 'moliricfg.xml';    # output file name

    open my $out, '>', $out_file_name
      or die
"$PROGRAM_NAME : Konnte Ausgabedatei '$out_file_name' nicht öffnen : $ERRNO\n";

    my $writer = XML::Writer->new(
        OUTPUT      => $out,
        DATA_MODE   => 'true',
        DATA_INDENT => 2,
        ENCODING    => 'utf-8',
        UNSAFE      => '1',       # wegen raw, zum schreiben der internen dtd
    );

    #---------------------------------------------------------------------------
    #  XML-Kopf schreiben
    #---------------------------------------------------------------------------
    $writer->xmlDecl('UTF-8');

    #---------------------------------------------------------------------------
    #  DTD schreiben
    #---------------------------------------------------------------------------
    my $dtd =

      '<!DOCTYPE config [' . "\n"
      . '<!ELEMENT config (Arbeitsordner,Sicherungsordner,auto,Rechtschreib)>'
      . "\n"
      . '<!ELEMENT Arbeitsordner (#PCDATA)>' . "\n"
      . '<!ELEMENT Sicherungsordner (#PCDATA)>' . "\n"
      . '<!ELEMENT auto (an, zeit)>' . "\n"
      . '<!ELEMENT an (#PCDATA)>' . "\n"
      . '<!ELEMENT zeit (#PCDATA)>' . "\n"
      . '<!ELEMENT Rechtschreib (#PCDATA)> ' . "\n" . ']>' . "\n\n";

    $writer->comment(
'Dieses Dokument wurde mit dem "Moliri - Pflichtenheftgenerator" erstellt'
    );
    $writer->comment('Nur Änderungen vornehmen wenn Sie wissen was sie tuen');
    $writer->raw($dtd);
    $writer->startTag('config');
    $writer->dataElement( 'Arbeitsordner',    ${$par1}{'aordner'} );
    $writer->dataElement( 'Sicherungsordner', ${$par1}{'sordner'} );
    $writer->startTag('auto');
    $writer->dataElement( 'an',   ${$par1}{'aan'} );
    $writer->dataElement( 'zeit', ${$par1}{'azeit'} );
    $writer->endTag('auto');
    $writer->dataElement( 'Rechtschreib', ${$par1}{'rschreib'} );
    $writer->endTag('config');
    $writer->end();

    close $out
      or warn
"$PROGRAM_NAME : Konnte Ausgabedatei '$out_file_name' nicht schließen : $ERRNO\n";
    return;
}

#---------------------------------------------------------------------------
#  
#   Subroutine: get_config
#
#   Liest Konfigurationsdatei in Hash ein.
#   Zurückgegebener Hash hat immer die Form:
#
#     *Dumperausgabe*
#     >$VAR1 = {
#     >         'rschreib' => '0',
#     >         'azeit' => '1',
#     >         'aan' => '0',
#     >         'sordner' => '/home/alexandros/',
#     >         'aordner' => '/home/alexandros/Desktop/moliri-pflichtenhefte'
#     >};
#
#---------------------------------------------------------------------------
sub get_config {
    my ($par1) = @_;
    my $in_file_name = 'moliricfg.xml';    # input file name

    open my $in, '<', $in_file_name
      or die
"$PROGRAM_NAME : Konnte Eingabedatei '$in_file_name' nicht öffnen: $ERRNO\n";

    my $parser = XML::LibXML->new();
    my $dom = $parser->load_xml( IO => $in );

    close $in
      or warn
"$PROGRAM_NAME : Konnte Eingabedatei '$in_file_name' nicht schließen : $ERRNO\n";

    my $aordner  = $dom->findnodes('/config/Arbeitsordner');
    my $sordner  = $dom->findnodes('/config/Sicherungsordner');
    my $aan      = $dom->findnodes('/config/auto/an');
    my $azeit    = $dom->findnodes('/config/auto/zeit');
    my $rschreib = $dom->findnodes('/config/Rechtschreib');

    my %config = (
        'aordner'  => $aordner->string_value(),
        'sordner'  => $sordner->string_value(),
        'aan'      => $aan->string_value(),
        'azeit'    => $azeit->string_value(),
        'rschreib' => $rschreib->string_value(),
    );

    return \%config;
}    # ----------  end of subroutine get_config  ----------

END { }    # module clean-up code

1;
