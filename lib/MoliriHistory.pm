#===============================================================================
#
# Class: MoliriHistory.pm
#
#  Verlaufsfunktionalität von Moliri
#
#  >Autor:       Alexandros Kechagias (Alexandros.Kechagias@gmx.de)
#  >Firma:       Fachhochschule Südwestfalen
#  >Version:     1.0
#  >Erstellt am: 13.04.2011 17:19:05
#  >Revision:    0.2
#===============================================================================
package MoliriHistory;
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';    # Ausgabe in Unicode
use English qw( -no_match_vars );

use Data::Dumper;

#---------------------------------------------------------------------------
#   Subroutine: new
#
#   Konstruktor, kriegt Pflichtenheftordner als Parameter
#---------------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self = { _projektpfad => shift };
    bless $self, $class;
    return $self;
}                           # ----------  end of subroutine new  ----------


#---------------------------------------------------------------------------
#   Subroutine: history_hinzu 
#
#   Fügt der History-Datei einen Eintrag hinzu. 
#   Der Eintrag wird nur geschrieben wenn er nicht bereits existiert. 
#   Die alte History-Datei wird eingelesen aber nur die Dateien die 
#   existieren und beschreibbar sind werden übernommen.
#---------------------------------------------------------------------------
sub history_hinzu {
    my ( $self, $element ) = @_;

    my @history = $self->history_rein();
    my $pfad    = $self->{'_projektpfad'};
    
    # Das übergebene Element kommt als erstes nach oben, aber nur 
    # wenn das oberste Element nicht bereits das selbe ist.
    if ($history[0]){
        if ( $history[0] eq $element ) {
            return;
        }
    }
    
    my $out_file_name = 'history';    # output file name
    open my $out, '>', $out_file_name
      or die
      "$PROGRAM_NAME : failed to open  output file '$out_file_name' : $ERRNO\n";

    print {$out} $element . "\n";

    # Nun kommen die restlichen Elemente aus der alten History-Datei
    # Es werden nur Dateien übernommen die existieren und beschreibbar sind

    # Maximal 9 Elemente aus @history reinschreiben, somit bleibt die
    # gesamtzahl der Elemente plus dem neu Hinzufügten auf 10
    for ( 0 .. 8 ) {
        if (    $history[$ARG]
            and $history[$ARG] ne $element
#            and -e $history[$ARG] 
#            and -w $history[$ARG]
        )
        {
            print {$out} $history[$ARG] . "\n";
        }
    }

    close $out
      or warn
      "$PROGRAM_NAME : failed to close output file '$out_file_name' : $ERRNO\n";

    return;
}    # ----------  end of subroutine history_add  ----------

#---------------------------------------------------------------------------
#  Subroutine: history_rein
#
#  Es wird dir History-Datei in Array eingelesen und zurückgegeben
#---------------------------------------------------------------------------
sub history_rein {
    my ($par1) = @_;
    my @history;
    my $in_file_name = 'history';    # input file name
    open my $in, '<', $in_file_name
      or die
      "$PROGRAM_NAME : failed to open  input file '$in_file_name' : $ERRNO\n";

    while (<$in>) {
        chomp $ARG;
        if (    $ARG
            and -e $ARG
            and -w $ARG )
        {

            push @history, $ARG;
        }
    }

    close $in
      or warn
      "$PROGRAM_NAME : failed to close input file '$in_file_name' : $ERRNO\n";
    return @history;
}    # ----------  end of subroutine history_in  ----------

END { }    # module clean-up code

1;
