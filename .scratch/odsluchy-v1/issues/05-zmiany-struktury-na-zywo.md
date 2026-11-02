# 05: Zmiany struktury projektu na żywo

**What to build:** Bez ponownego łączenia Bielik widzi:

- nowe i usunięte odsłuchy na liście,
- dodane i usunięte źródła oraz przemianowane ścieżki w odsłuchu,
- usunięcie odsłuchu, który muzyk ma otwarty: wraca wtedy do listy z komunikatem,
- przełączenie projektu w REAPERze: lista pokazuje odsłuchy nowego projektu.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Rozszerzenie reaguje na `SetTrackListChange`, `SetTrackTitle` i zmianę aktywnego projektu, przelicza model i wysyła `monitors` albo pełny `monitor` tylko przy faktycznej różnicy.
- [ ] Usunięcie subskrybowanego odsłuchu (także przez zmianę nazwy bez prefiksu) → `monitor_removed`.
- [ ] Identyfikacja po GUID: przesunięcie ścieżki w projekcie nie zmienia, który odsłuch i które źródło widzi telefon.
- [ ] Testy Rozszerzenia modyfikują fałszywy projekt (dodanie i usunięcie ścieżki, zmiana nazwy, zmiana receive'ów, przełączenie projektu). Testy Aplikacji sprawdzają reakcję UI.
