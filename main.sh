#! /bin/bash

# Busfahrplan-Shell-Script von Wolfram Reinke und Nils Rohde
# Emails:	WolframReinke@web.de
#			nils.rohde@core-control.de 

# Diese Funktion schreibt die Hilfenachricht auf die Ausgabe
function printHelpMessage(){
	echo "";
	echo "Busfahrplan-Script von Wolfram Reinke und Nils Rohde";
	echo "Benutzung:";
	echo -e "\tbfp.sh -s <Starthaltestelle> -z <Zielhaltestelle> [-t <Abfahrtszeit>] [-f <Name>] [-l <Name>] [-r] [-v]";
	echo "";
	echo "Parameter:";
	echo -e "\t-s\tDie Starthaltestelle der Suche. Bitte geben Sie die Starthaltestelle in";
	echo -e "\t  \tAnführungszeichen an.";
	echo -e "\t-z\tDie Zielhaltestelle der Suche. Bitte geben Sie die Zielhaltestelle in";
	echo -e "\t  \tAnführungszeichen an.";
	echo -e "\t-t\tDie Abfahrtszeit. Wenn keine Zeit angegeben wird, wird die aktuelle Zeit verwendet.";
	echo -e "\t  \tFormat: hh:mm.";
	echo -e "\t-h\tZeigt diese Hilfenachricht.";
	echo -e "\t-f\tDie Werte für <Starthaltestelle> und <Zielhaltestelle> werden als Favorit unter dem";
	echo -e "\t  \tgegebenen <Namen> gespeichert.";
	echo -e "\t-l\tLädt Starthaltestelle und Zielhaltestelle mit dem gegebenen <Namen> aus den Favoriten.";
	echo -e "\t-r\tLöscht die Favorit-Parameter, sodass beim Start wieder <Starthaltestelle> und";
	echo -e "\t  \t<Zielhaltestelle> angegeben werden müssen.";
	echo -e "\t-q\tUnterdrückt Status-Ausgaben auf die Standardausgabe. So können die Busdaten leichter";
	echo -e "\t  \tin eine Datei umgeleitet werden.";
	echo "";
}

# Favoriten-Datei
favorites="$HOME/.bfp_favs.db";

# Werte vorbelegen, um zu testen, ob der Benutzer etwas eingeben hat
departure="nil";
arrival="nil";
load="nil";
favorit="nil";
quite="false";

# Benutzereingaben abfragen
while getopts hs:z:t:f:l:rq input
do
	case $input in
		
		# Hilfe anzeigen
		h)	printHelpMessage;
			exit;;
		
		# Starthaltestelle angegeben
		s)  	departure=$OPTARG;;
		
		# Zielhaltestelle angegeben
		z)	arrival=$OPTARG;;
		
		# Abfahrtszeit angegeben
		t)	time=$OPTARG;;
		
		# Benutzer will die Eingabe als favorit speichern
		f)	favorit=$OPTARG;;
		
		# Benutzer möchte einen Favoriten laden
		l)	load=$OPTARG;;
		
		# Favorit resetten
		r)	rm "$favorites" 2> /dev/null \
			    && echo -e "Ihre Such-Favoriten wurde gelöscht.\n" \
			    || echo -e "Ihre Such-Favoriten war bereits gelöscht.\n" ;
			exit;;
		
		# Ausgaben auf die Standardausgabe sollen unterdrückt werden
		q)	quite="true";;
		
		# sonst Hilfenachricht anzeigen und exit
		\?) 	printHelpMessage;
			exit;;
		
	esac
done

if [ "$load" != "nil" ]
then

    if [ -e "$favorites" ] 
    then
    	entries="|$(sqlite3 "$favorites" "SELECT start, dest FROM favorites WHERE name='$load';")|";
    	if [ "$entries" = "||" ]
    	then
    		echo -e "Dieser Favorit existert nicht.\n" 1>&2;
    		exit;
    	fi
    	
 		departure=$(echo "$entries" | grep -Pio '.*?(?=\|)' | head -n1);
 		arrival=$(echo "$entries" | grep -Pio '.*?(?=\|)' | tail -n1);
    else

		echo "";
		if [ "$departure" = "nil" ]
		then
	   		echo "Sie müssen eine Starthaltestelle angeben oder als Favorit speichern (siehe Hilfe)" 1>&2;
		fi
	
		if [ "$arrival" = "nil" ]
		then
	    	echo "Sie müssen eine Zielhaltestelle angeben oder als Favorit speichern (siehe Hilfe)" 1>&2;
		fi
		echo "";
	
		printHelpMessage;
		exit;
    fi
else
	if ([ "$arrival" = "nil" ] || [ "$departure" = "nil" ])
	then
		echo -e "Sie müssen Start- und Zielhaltestelle angeben, oder sie aus den Favoriten laden.\n" 1>&2;
		printHelpMessage;
		exit;
	fi
fi

if [ "$favorit" != "nil" ]
then
	if [ ! -e "$favorites" ]
	then
		sqlite3 "$favorites" "CREATE TABLE favorites (name TEXT PRIMARY KEY, start TEXT, dest TEXT);";
	fi
	
    sqlite3 "$favorites" "INSERT INTO favorites (name, start, dest) VALUES ('$favorit', '$departure', '$arrival');" 2> /dev/null \
    	|| { echo "Dieser Favoriten-Name existiert bereits." 1>&2; exit; }
    
    # Ausgabe unterdrücken?
    if [ "$quite" = "false" ]
    then
		echo "Ihre Suche wurde als Favorit gespeichert.";
    fi
fi

# Wenn der User keine Zeit eingegeben hat, dann aktuelle Zeit verwenden.
if [ -z "$time" ]
then
    time=$(date +%H:%M);
fi

# aktuelles Datum verwenden. 
currentDate=$(date +%a%%2C+%d.%m.%g | sed s/Tue/Di/ | sed s/Wed/Mi/ | sed s/Th/Do/ | sed s/Sat/Sa/ | sed s/Su/So/ | sed s/Mon/Mo/);

# URL-Encoding auf die Eingaben anwenden, um Sonderzeichen wie Umlaute zu erlauben.
departure=$(echo -n "$departure" | perl -pe 's/([^-_.~A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg');
arrival=$(echo -n "$arrival" | perl -pe 's/([^-_.~A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg');
time=$(echo -n "$time" | perl -pe 's/([^-_.~A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg');

# URL konstruieren
url="http://reiseauskunft.bahn.de/bin/query.exe/dn?revia=yes&existOptimizePrice=1&country=DEU&dbkanal_007=L01_S01_D001_KIN0001_qf-bahn_LZ003&ignoreTypeCheck=yes&S=$departure&REQ0JourneyStopsSID=&REQ0JourneyStopsS0A=7&Z=$arrival&REQ0JourneyStopsZID=&REQ0JourneyStopsZ0A=7&trip-type=single&date=$currentDate&time=$time&timesel=depart&returnTimesel=depart&optimize=0&travelProfile=-1&adult-number=1&children-number=0&infant-number=0&tariffTravellerType.1=E&tariffTravellerReductionClass.1=0&tariffTravellerAge.1=&qf-trav-bday-1=&tariffTravellerReductionClass.2=0&tariffTravellerReductionClass.3=0&tariffTravellerReductionClass.4=0&tariffTravellerReductionClass.5=0&tariffClass=2&start=1&qf.bahn.button.suchen="

# Ausgabe unterdrücken?
if [ "$quite" = "false" ]
then
    echo "Ihre Anfrage wird bearbeitet...";
    echo "";
fi

tmpFile="/tmp/fpl.html";		# Datei, in die die heruntergeladene Seite gespeichert wird.
wget -O $tmpFile "$url" 2> /dev/null \
      || { echo "Die benötigten Daten konnten nicht geladen werden." 1>&2; exit; }

# Tabellenkopf ausgeben
printf "%-40s %-40s %-15s %-15s %-8s %-20s \n" "Startbahnhof" "Zielbahnhof" "Abfahrtszeit" "Ankunftszeit" "Dauer" "Verkehrsmittel";
echo -e "-----------------------------------------------------------------------------------------------------------------------------------------";

anzahlDurchlaeufe=3;	# Anzahl der Reisemöglichkeiten (die Deutsche Bahn Seite enthält immer 3 Reisemöglichkeiten)
timeGet=1;		# Die DB-Seite speichert An- und Ab-Zeit beide unter einem <td class="time"> Tag, daher muss hier
			# extra mitgezählt werden.
		
# Tabelle laden und ausgeben
for (( i=1; i<=$anzahlDurchlaeufe; i++ ))
do
	# Starthaltestelle, Zielhaltestelle, Dauer und Anbieter aus der HTML-Seite greppen
	startBhf=$(grep -Pzio '<div class="resultDep">\n(.*?)\n</div>' $tmpFile | grep -Pzio '(?<=>\n)(.*?)(?=\n<)' | head -n $i | tail -n 1);
	zielBhf=$(grep -Pzio '<td class="station stationDest pointer".*?>\n(.*?)\n</td>' $tmpFile | grep -Pzio '(?<=>\n)(.*?)(?=\n<)' | head -n $i | tail -n 1);
	duration=$(grep -Pzio '<td class="duration lastrow".*?>\n?(.*?)\n?</td>' $tmpFile | grep -Pzio '(?<=(>|\n))(.*?)(?=(\n|<))' | head -n $i | tail -n 1);
	provider=$(grep -Pzio '<td class="products lastrow".*?>\n?(.*?)\n?</td>' $tmpFile | grep -Pzio '(?<=(>|\n))(.*?)(?=(\n|<))' | head -n $i | tail -n 1);
	
	# Die Abfahrtszeit greppen
	timeAb=$(grep -Pzio '<td class="time".*?>\n?(.*?)\n?.*?</td>' $tmpFile | grep -Pzio '\d{1,2}\:\d{1,2}' | head -n $timeGet | tail -n 1);
	
	# Auf der DB-Seite werden auch die Verspätungen angezeigt. Diese fangen mit + oder - an und
	# werden hier ausgefiltert
	if ([ ${timeAb:0:1} = "+" ] || [ ${timeAb:0:1} = "-" ])
	then	
	
	  # Zeit neu laden, da sonst die Verspätungen statt der Zeit ausgegeben würde. Der nächste Treffer von grep ist
	  # garantiert keine Verspätungsangabe mehr, die kommen immer abwechselnd
	  let	timeGet=$timeGet+1;	
	  timeAb=$(grep -Pzio '<td class="time".*?>\n?(.*?)\n?.*?</td>' $tmpFile | grep -Pzio '\d{1,2}\:\d{1,2}' | head -n $timeGet | tail -n 1);
	fi
	
	# Zähler hochzählen für die Ankunftszeit
	let timeGet=$timeGet+1;
	
	# Die Ankunftszeit greppen
	timeAn=$(grep -Pzio '<td class="time".*?>\n?(.*?)\n?.*?</td>' $tmpFile | grep -Pzio '\d{1,2}\:\d{1,2}' | head -n $timeGet | tail -n 1);
	
	# Auf der DB-Seite werden auch die Verspätungen angezeigt. Diese fangen mit + oder - an und
	# werden hier ausgefiltert
	if ([ ${timeAn:0:1} = "+" ] || [ ${timeAn:0:1} = "-" ])
	then
	  # Und wieder die Zeit neu laden.
	  let	timeGet=$timeGet+1;
	  timeAn=$(grep -Pzio '<td class="time".*?>\n?(.*?)\n?.*?</td>' $tmpFile | grep -Pzio '\d{1,2}\:\d{1,2}' | head -n $timeGet | tail -n 1);				
	fi
	
	# Zähler für den nächsten Schleifendurchlauf hochzählen
	let timeGet=$timeGet+1;
	
	# Die grade geladene Reisemöglichkeit ausgeben
	printf "%-40s %-40s %-15s %-15s %-8s %-20s" "$startBhf" "$zielBhf" "$timeAb" "$timeAn" "$duration" "$provider";
	echo "";
done

# Leerzeile
echo "";

# Temporäre Datei löschen
rm $tmpFile;




