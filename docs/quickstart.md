# WGX Quickstart Wizard

Die Option `wgx init --wizard` führt Schritt für Schritt durch die Erstellung
eines `.wgx/profile.yml` im Repository. Nach der Auswahl des Repository-Typs
und der gewünschten Standard-Tasks (z. B. `test`, `lint`, `build`) erzeugt der
Wizard ein Profil im Format `apiVersion: v1.1` mit getrennten `cmd`- und
`args`-Feldern. Zum Abschluss wird automatisch `wgx validate` gestartet; bei
Fehlern zeigt der Wizard den Diff zur erzeugten Datei, damit Anpassungen
schnell möglich sind.
