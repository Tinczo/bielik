# 09: Master odsłuchu — głośność wyjścia sprzętowego

**What to build:** Muzyk reguluje z telefonu głośność całego swojego odsłuchu suwakiem **Master**, który steruje hardware sendem (wyjściem sprzętowym) ścieżki `Odsłuch: …`. Gdy odsłuch klipuje, ścisza się jednym suwakiem zamiast każdego źródła osobno. Zgłosili Wiktor, Szymon i Łukasz.

Master to głośność hardware sendu (kategoria 1 w API REAPERa, `D_VOL`), nie fader ścieżki. Poprawnie skonfigurowany odsłuch ma dokładnie jeden hardware send.

- Brak hardware sendu: baner „O KURWA, ZJEBAŁO SIĘ: brakuje wyjścia sprzętowego”.
- Więcej niż jeden: baner „O KURWA, ZJEBAŁEŚ: za dużo wyjść sprzętowych”.
- W obu przypadkach baner jest czerwony i z iskrami przy Masterze, suwak Master jest zablokowany, a suwaki źródeł działają dalej.

Protokół w wersji 2, bez zgodności wstecznej: w `monitor` pole `output` (`{status: ok, level}`, `{status: missing}`, `{status: multiple}`), wiadomości `set_output_level` i `output_level`, kod błędu `output_unavailable`. Zmiana zaczyna się od `docs/protocol.md` i `protocol/examples/`. Zmiany z REAPERa wykrywa istniejący timer ze `GetProjectStateChangeCount`.

Poza zakresem: mierniki poziomu i wskaźnik clipowania; przyciski ±1 dB przy Masterze (ticket 05).

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] `docs/protocol.md` i przykłady w `protocol/examples/` opisują wersję 2: `output`, `set_output_level`, `output_level`, `output_unavailable`.
- [ ] Rozszerzenie podaje głośność hardware sendu odsłuchu i ustawia ją przez `set_output_level`; zmiana z REAPERa albo innego telefonu dociera do subskrybentów.
- [ ] Przy 0 albo 2+ hardware sendach status to `missing` albo `multiple`, a `set_output_level` kończy się błędem `output_unavailable`.
- [ ] Aplikacja pokazuje wyróżniony suwak Master na górze ekranu odsłuchu, w dB, z tym samym zakresem co źródła.
- [ ] Zmiana Mastera jest jednym krokiem cofania i ponawiania (ticket 09 z `odsluchy-v1`).
- [ ] Przy `missing` i `multiple` Aplikacja pokazuje czerwony baner z właściwym tekstem i iskrami przy Masterze, master jest zablokowany, a źródła nadal działają.
- [ ] Testy Rozszerzenia i Aplikacji na wspólnych przykładach protokołu.
