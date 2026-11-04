# 03: Ustawianie poziomu źródła suwakiem

**What to build:** Muzyk przesuwa suwak źródła w swoim odsłuchu i słyszy zmianę już w trakcie gestu. Podwójne stuknięcie wraca do 0 dB, a suwak dociągnięty do końca wycisza źródło (−∞). Zmiana dotyczy tylko tego odsłuchu, a w REAPERze zachowuje się jak ruch na kontrolerze (UI się odświeża).

**Blocked by:** 02

**Status:** resolved

- [ ] `set_level` (`monitorId`, `sourceId`, `level`) ustawia głośność właściwego receive'a. To samo źródło w innym odsłuchu się nie zmienia.
- [ ] Zapis odświeża UI REAPERa bez zaśmiecania historii undo. Wybór między `CSurf_OnRecvVolumeChange` a `SetTrackSendUIVol` jest udokumentowany.
- [ ] Rozszerzenie zlewa wiele `set_level` dla tego samego receive'a w jednym takcie timera i stosuje ostatnią wartość.
- [ ] Bielik ogranicza wysyłanie w trakcie gestu (rzędu 20–30 wiadomości/s) i zawsze wysyła wartość końcową po puszczeniu.
- [ ] Krzywa suwaka i konwersja na dB są w Aplikacji, a na łączu jest liniowe wzmocnienie.
- [ ] Niepoprawne pola → `error` bez rozłączenia. Testy obu stron i protokół zostały uzupełnione.
