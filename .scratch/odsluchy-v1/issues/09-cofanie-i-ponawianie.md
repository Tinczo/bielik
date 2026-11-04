# 09: Cofanie i ponawianie zmian poziomów

**What to build:** Muzyk, który przez przypadek przesunął suwak i nie pamięta poprzedniego ustawienia, cofa zmianę jednym przyciskiem, krok po kroku, i może ją ponowić. Cofanie obejmuje tylko jego własne zmiany w jego odsłuchu (pomysł Łukasza Świszczowskiego).

**Blocked by:** 04

**Status:** resolved

- [ ] Historia jest tylko w Bieliku, osobna dla każdego odsłuchu. Protokół i Rozszerzenie się nie zmieniają, a cofnięcie to zwykłe `set_level`.
- [ ] Jeden gest na jednym źródle (także reset do 0 dB) to jeden krok: (źródło, poziom przed, poziom po).
- [ ] Zmiany przychodzące z serwera nie trafiają do historii.
- [ ] Cofnięcie przywraca poziom sprzed gestu, a ponowienie poziom po geście. Nowy gest czyści stos ponowień.
- [ ] Kroki dla źródeł, których już nie ma, są pomijane.
- [ ] Historia jest w pamięci (do około 50 kroków na odsłuch), przetrwa ponowne połączenie i przełączanie odsłuchów, a przyciski są nieaktywne, gdy nie ma czego cofnąć ani ponowić.
- [ ] Testy Aplikacji przeciw fałszywemu serwerowi.
