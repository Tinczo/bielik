# 04: Push zmian poziomów do wszystkich telefonów

**What to build:** Kiedy ktoś zmieni poziom źródła myszką w REAPERze albo z innego telefonu, suwak w Bieliku na każdym telefonie z tym odsłuchem przesuwa się sam. Dwóch muzyków dzielących podłogówkę może sterować nią jednocześnie bez rozjeżdżania się stanu, a suwak trzymany palcem nie skacze.

**Blocked by:** 03

**Status:** resolved

- [ ] Rozszerzenie wykrywa zmiany głośności receive'ów (ukryta powierzchnia kontrolna, `CSURF_EXT_SETRECVVOLUME`) i wysyła `level` subskrybentom tego odsłuchu, także nadawcy (echo).
- [ ] Jako siatka bezpieczeństwa timer porównuje `GetProjectStateChangeCount` i wysyła tylko różnice.
- [ ] Klienci subskrybujący inne odsłuchy nie dostają tych zdarzeń.
- [ ] Bielik ignoruje przychodzące `level` dla suwaka, którego użytkownik właśnie dotyka, a po puszczeniu pokazuje stan z serwera.
- [ ] Test Rozszerzenia: zmiana poziomu w fałszywym projekcie dociera do dwóch klientów. Test Aplikacji: push z fałszywego serwera przesuwa suwak.
