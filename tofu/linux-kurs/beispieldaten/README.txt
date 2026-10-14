Beispieldaten für Terminal-Übungen
====================================

studenten.csv  – CSV-Datei mit Studierenden (für Aufgaben mit cut, grep, sort)
server.log     – Simuliertes Server-Log   (für Aufgaben mit grep, tail, wc)

Probiere zum Beispiel:
  grep "ERROR" server.log
  cut -d',' -f1,3 studenten.csv
  grep "Informatik" studenten.csv | wc -l
  sort -t',' -k4 -n studenten.csv
