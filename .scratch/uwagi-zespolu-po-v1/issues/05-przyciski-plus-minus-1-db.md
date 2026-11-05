# 05: Duże przyciski plus i minus przy suwaku

**What to build:** Oprócz suwaka każde źródło ma ogromne przyciski minus (po lewej) i plus (po prawej), które zmieniają poziom źródła o 1 dB. Na próbie łatwiej trafić w przycisk niż precyzyjnie przesunąć suwak. Zgłosił Wiktor, bo suwak jest mało ergonomiczny.

Zmiana dotyczy tylko Aplikacji, protokół wystarcza.

**Blocked by:** None (can start immediately)

**Status:** needs-triage

- [ ] Każde stuknięcie zmienia poziom źródła o dokładnie 1 dB, także przy poziomie w pobliżu −∞ i przy górnej granicy suwaka.
- [ ] Przyciski są duże i wygodne przy graniu, także na mniejszym telefonie.
- [ ] Jedno stuknięcie to jeden krok cofania.
- [ ] Przyciski są zablokowane przy braku połączenia, tak jak suwaki.
- [ ] Testy Aplikacji przeciw fałszywemu Rozszerzeniu.
- [ ] Po wdrożeniu mastera (ticket 09) te same przyciski −/+ 1 dB są też przy suwaku Master, nie tylko przy źródłach.
