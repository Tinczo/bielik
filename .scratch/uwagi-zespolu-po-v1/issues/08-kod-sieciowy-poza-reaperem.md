# 08: Przeniesienie kodu sieciowego poza proces REAPERa

**What to build:** Kod sieciowy działa w osobnym procesie, np. w Pythonie, a w C++ zostają tylko wywołania API REAPERa i komunikacja między procesami. Błąd w kodzie sieciowym nie wywali wtedy REAPERa na próbie ani na koncercie. Propozycja Wiktora, który od razu zastrzegł: „nie poprawiajmy, póki nie ma takiej potrzeby”.

_Contradicts ADR-0001 (natywne rozszerzenie z serwerem WebSocket), ale warto do tego wrócić, jeśli ticket 07 pokaże problemy ze stabilnością._ Dodatkowy koszt to instalacja: dziś wystarczy jeden plik .dll.

**Blocked by:** 07

**Status:** needs-triage

- [ ] Wyniki z ticketu 07 pokazują, czy zmiana jest potrzebna.
- [ ] Jeśli tak, powstaje nowy ADR zastępujący lub uzupełniający ADR-0001.
