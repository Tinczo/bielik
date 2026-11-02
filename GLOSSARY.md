# reaper-mobile-mixer

Pilot do odsłuchów zespołu: każdy muzyk ustawia z telefonu, jak głośno słyszy poszczególne źródła w swoim odsłuchu, który miksuje REAPER na laptopie podczas próby.

## Miksowanie

**Odsłuch**:
Osobisty miks jednego muzyka (albo jednej podłogówki), który trafia na jego słuchawki lub monitor. W REAPERze to ścieżka-szyna, którą zespół sam routuje na wyjście interfejsu.
_Avoid_: mikser, uszy, monitor mix, kanał

**Źródło**:
Ścieżka w REAPERze z sygnałem, który można usłyszeć w odsłuchu (gitara, wokal, stopa…).
_Avoid_: kanał, wejście, instrument

**Poziom źródła**:
Jak głośno dane źródło gra w danym odsłuchu. Każdy odsłuch ma własne poziomy, więc ściszenie gitary w jednym odsłuchu nie zmienia jej w innym.
_Avoid_: kanał, suwak, send (send to mechanizm REAPERa, którym poziom jest realizowany)

## Elementy systemu

**Rozszerzenie**:
Natywna wtyczka REAPERa, która udostępnia odsłuchy w sieci lokalnej i przyjmuje zmiany poziomów.
_Avoid_: serwerek, serwer, plugin, web remote

**Aplikacja**:
Aplikacja na telefon, w której muzyk wybiera swój odsłuch i ustawia poziomy źródeł. Nazwa produktu: **Bielik** (logo: głowa orła).
_Avoid_: klient, mikser, apka
