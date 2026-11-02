# 02: Podgląd odsłuchu — źródła i ich poziomy

**What to build:** Muzyk wybiera z listy swój odsłuch i widzi wszystkie jego źródła (nazwy ścieżek z REAPERa) z aktualnymi poziomami źródeł w dB, w kolejności receive'ów. Na razie tylko do odczytu.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `subscribe` z `monitorId` → pełny stan `monitor` (źródła: `id` = GUID źródła, `name`, `level` liniowo, 1.0 = 0 dB).
- [ ] Źródła to receive'y ścieżki-odsłuchu. Przy dwóch receive'ach z tego samego źródła pokazywany jest tylko pierwszy.
- [ ] Nieznany `monitorId` → `error` z kodem `not_found`.
- [ ] Bielik pokazuje poziom w dB, a poziom 0 jako −∞.
- [ ] Protokół i wspólne przykłady zostały uzupełnione. Testy obu stron przechodzą.
