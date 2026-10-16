# Componenti di terze parti

La licenza MIT del progetto non sostituisce le licenze delle dipendenze.

- Flutter e Dart: licenze BSD, con attribuzioni incluse negli SDK e nel registro licenze Flutter.
- `video_player`, `video_player_android`, `file_selector`, `path_provider`, `share_plus`, `vector_math`: BSD-3-Clause.
- `cryptography`: Apache-2.0.
- `archive`: MIT.
- AndroidX Media3: Apache-2.0; testo incluso in `assets/licenses/ANDROIDX-MEDIA3.txt` e mostrato nell’app.

Le dipendenze e le versioni risolte sono elencate in `pubspec.lock`. **Sistema → Licenze** mostra i testi registrati dai pacchetti Flutter e il testo nativo Media3 incluso. In caso di distribuzione di binari, conservare anche gli avvisi delle dipendenze native Android/AndroidX presenti nella build.

`assets/demo.mp4` è un segnale di prova generato con FFmpeg (`testsrc2`), senza contenuti editoriali o media di terzi. Il comando per rigenerarlo si trova nel README. Non vengono distribuiti font aggiuntivi.
