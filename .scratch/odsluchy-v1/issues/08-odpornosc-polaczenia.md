# 08: Odporność połączenia na próbie

**What to build:** Po chwilowej utracie Wi-Fi albo restarcie REAPERa Bielik łączy się ponownie sam. Stan rozłączenia jest widoczny, a suwaki są wtedy zablokowane. Po ponownym otwarciu Aplikacja wraca do ostatniego serwera i ostatniego odsłuchu, a ekran nie gaśnie przy otwartym odsłuchu. Rozszerzenie czysto zamyka połączenia i port razem z REAPERem.

**Blocked by:** 02, 06

**Status:** ready-for-agent

- [ ] Automatyczne ponowne łączenie z narastającym odstępem, a po połączeniu ponowna subskrypcja tego samego odsłuchu.
- [ ] W stanie rozłączonym suwaki są nieaktywne i widać wskaźnik połączenia.
- [ ] Aplikacja pamięta ostatni serwer, hasło i odsłuch między uruchomieniami.
- [ ] Ekran nie gaśnie na ekranie odsłuchu.
- [ ] Rozładowanie Rozszerzenia (zamknięcie REAPERa) zamyka połączenia, zatrzymuje wątek sieciowy i zwalnia port.
- [ ] Test Aplikacji: fałszywy serwer zrywa połączenie i wraca, a Bielik odzyskuje stan bez akcji użytkownika.
