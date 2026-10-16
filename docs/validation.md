# Verifica del progetto autonomo

Verifica eseguita il 16 ottobre 2026 con Flutter 3.47.5 / Dart 3.13.4, Java 21, Android SDK 36.

- `flutter analyze`: nessuna segnalazione.
- `flutter test`: 30 test unitari e widget passati. Coprono geometria, validazione, persistenza, PIN, export, watchdog, lifecycle, layout, tastiera in landscape, zoom/pan e maniglie esterne.
- `flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/player_test.dart -d <id-emulatore>`: flusso Android passato su emulatore API 36, arm64, Full HD 1920 × 1080. Verificati decoder e texture reali, affine, Bézier, undo, salvataggio, loop, PIN, quattro angoli e ripristino della sessione dal preset salvato.
- `flutter build apk --debug --target lib/main.dart`: APK normale, distinto da quello di integrazione.
- Screenshot del flusso Android in [screenshots](screenshots/); osservato layout orizzontale e tema Material senza font aggiuntivi.

L’ID Android è `dev.dariocavada.dchs_video_mapping`: installazione e storage sono indipendenti da altre applicazioni. I preset e i video eventualmente presenti in altre app non vengono migrati automaticamente.

Il test di integrazione usa lo storage separato `player-integration` e un PIN esclusivamente di test; non configura il PIN dell’app normale. Il driver salva gli screenshot in `docs/screenshots/`.

Il collaudo fisico di HDMI, proiettore, riavvio del dispositivo, kiosk gestito e riproduzione prolungata richiede l’hardware di destinazione. L’APK verificato è debug; la firma di produzione non è configurata.
