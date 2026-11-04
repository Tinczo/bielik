# 06: Hasło zespołu i ustawienia Rozszerzenia

**What to build:** Osoba przygotowująca sesję ustawia w REAPERze hasło i port Rozszerzenia. Muzyk przy pierwszym połączeniu podaje hasło, a Bielik je zapamiętuje. Złe hasło i niezgodna wersja protokołu dają czytelne, różne komunikaty.

**Blocked by:** 01

**Status:** resolved

- [ ] `hello` niesie hasło. Złe hasło → `error` `bad_password` i zamknięcie połączenia. Niezgodna wersja → `error` `unsupported_version` i zamknięcie.
- [ ] Hasło i port są zapisywane w ExtState REAPERa i ustawiane akcją albo okienkiem w REAPERze. Domyślny port jest inny niż 8080.
- [ ] Zmiana portu restartuje serwer bez restartu REAPERa.
- [ ] Bielik przechowuje hasło w bezpiecznym magazynie Androida i odróżnia w UI błąd hasła od błędu sieci i od niezgodnej wersji.
- [ ] Testy obu stron i protokół zostały uzupełnione.
