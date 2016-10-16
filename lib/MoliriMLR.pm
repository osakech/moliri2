#===============================================================================
#
# Class: MoliriMLR.pm
#
#  Das eigene Dateiformat von Moliri ist eine Zip-Datei die wie der Pflichtenheftordner
#  aus Ordnern und XML-Dateien besteht.
#
#  *Aufbau der Zip-Datei*
#
#  _Ordner/XML-Datei_
#
#  Zum Beispiel:
#  >Moliri/1.0.xml
#  >Moliri/2.0.xml
#  >gBrain/1.0 pre.xml
#  >gBrain/2.0
#
#  In diesem Beispiel sind 2 Pflichtenhefte mit jeweils 2 Versionen
#
#
#   *Benutzt folgende Module*
#     - Archive::Zip       -- <http://search.cpan.org/~adamk/Archive-Zip-1.30/>
#
#  >Autor:       Alexandros Kechagias (Alexandros.Kechagias@gmx.de)
#  >Firma:       Fachhochschule Südwestfalen
#  >Version:     1.0
#  >Erstellt am: 13.04.2011 17:19:05
#  >Revision:    0.2
#===============================================================================
package MoliriMLR;

use strict;
use warnings;
use utf8;
#use Archive::Zip;
use English q{-no_match_vars};

#---------------------------------------------------------------------------
#  Subroutine: new
#
#  Konstruktor, als Parameter den Pfad zu dem man expoortieren will
#---------------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self = { _pfad => shift };
    bless $self, $class;
    return $self;
}    # ----------  end of subroutine new  ----------

#---------------------------------------------------------------------------
#   Subroutine: export_mlr 
#
#   Es werden die Pfade zu den XML-Dateien angegeben die Exportiert werden
#   sollen.
#---------------------------------------------------------------------------
sub export_mlr {
    my ( $self, @dateien ) = @_;
    my $pfad = $self->{'_pfad'};

    if ( $pfad =~ /\/$/ ) {
        chop $pfad;
    }

    my $zip = Archive::Zip->new();
    foreach (@dateien) {
        # Substring ist der Pfad zum Pflichtenheft
        my $pfad_ordner = substr $ARG, 0, ( rindex $ARG, q{/} );
        # Substring ergibt den Pfad innerhalb der MLR-Datei
        my $dname = substr $ARG, ( rindex $pfad_ordner, q{/} ) + 1;
        # zum hinzufügen der Datei wird der absolute Pfad zur Datei 
        # und der interne Pfad in der MLR-Datei angegeben
        $zip->addFile( $ARG, $dname );
    }

    # Speichere die MLR-Datei
    if ( $pfad =~ /\.mlr$/ ) {
        $zip->writeToFileNamed($pfad);
    }
    else {
        # Wenn kein mlr-Suffix angegeben wurde hänge automatisch dran
        $zip->writeToFileNamed( $pfad . '.mlr' );
    }

    return;
}    # ----------  end of subroutine export_mlr  ----------

#---------------------------------------------------------------------------
#  Subroutine: check_mlr 
#
#  Hole alle Einträge aus der ausgewählten MLR-Datei.
#---------------------------------------------------------------------------
sub check_mlr {
    my $self = shift;
    my $pfad = $self->{'_pfad'};

    my $zip     = Archive::Zip->new($pfad);
    my @members = $zip->memberNames();
    return @members;
}    # ----------  end of subroutine check_mlr  ----------

#---------------------------------------------------------------------------
#  Subroutine: import_mlr
#  
#  Die Funktion kriegt den Pflichtenheftordner und die Dateien die
#  importiert werden sollen als Parameter. Die Dateien werden in den 
#  angegebenen pfad entpackt.
#
#---------------------------------------------------------------------------
sub import_mlr {
    my ( $self, $pordner, @dateien ) = @_;

    my $pfad = $self->{'_pfad'};
    my $zip  = Archive::Zip->new($pfad);
    foreach (@dateien) {
        $zip->extractMember( $ARG, $pordner . q{/} . $ARG );
    }
    return;
}    # ----------  end of subroutine import_mlr  ----------

END { }    # module clean-up code

1;

