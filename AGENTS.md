<!-- BEGIN HARNESS GIT WORKFLOW -->
<!-- Quelle: deployment/harness/git-workflow.md; mit harness-sync verteilen. -->
## Commits und Pushes bündeln

- Änderungen zuerst als zusammenhängendes Arbeitspaket fertigstellen und die
  passenden Prüfungen abschließen. Nicht nach jeder Datei, kleinen Korrektur
  oder jedem Zwischenschritt committen.
- Pro abgeschlossenem Arbeitspaket und betroffenem Repository möglichst einen
  nachvollziehbaren Commit erstellen. Mehrere Commits sind sinnvoll, wenn sie
  unabhängig prüfbare Änderungen trennen; fremde Änderungen nicht mit aufnehmen.
- Commits erst gesammelt nach Abschluss des Arbeitspakets pushen, nicht nach
  jedem einzelnen Commit. Kein automatischer Commit-/Push-Zyklus während der
  Umsetzung. Pushes nur im bereits autorisierten Umfang ausführen.
- Repoübergreifende Arbeiten bleiben getrennte Commits je Repository; vor einem
  gebündelten Push die erforderlichen Prüfungen der betroffenen Repos abschließen.
- Bestehende Commit-Historie nicht zum Zusammenfassen umschreiben, sofern das
  nicht ausdrücklich beauftragt wurde. Kein Force-Push und kein Agenten-Push
  auf `main`. Explizite Nutzerwünsche zu Zwischenständen haben Vorrang.
<!-- END HARNESS GIT WORKFLOW -->
