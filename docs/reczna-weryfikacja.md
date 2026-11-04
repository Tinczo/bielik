# Ręczna weryfikacja

Rzeczy, których testy automatyczne nie sprawdzą, bo wymagają prawdziwego REAPERa, telefonu albo sieci. Lista na jedno przejście: REAPER 7.24 na laptopie z Windows i Bielik na prawdziwym telefonie z Androidem, oba w tej samej sieci Wi-Fi.

## Przygotowanie

- [ ] Zbuduj Rozszerzenie, skopiuj `reaper_mobile_mixer.dll` do `%APPDATA%\REAPER\UserPlugins` i uruchom REAPERa. Rozszerzenie ładuje się bez komunikatu o błędzie, a sam plik .dll wystarcza do instalacji.
- [ ] Zainstaluj Bielika na telefonie. Pod ikoną widać nazwę „Bielik”.
- [ ] Przygotuj projekt z dwiema ścieżkami `Odsłuch: …`, receive'ami z kilku ścieżek-źródeł i jedną ścieżką-źródłem bez nazwy.

## Sieć i wykrywanie

- [ ] Zapora Windows: przy pierwszym uruchomieniu REAPER dostaje zgodę na dostęp do sieci, a ruch przechodzi na porcie TCP Rozszerzenia (domyślnie 8790) i na UDP 5353 (mDNS).
- [ ] Bielik sam pokazuje laptopa na liście wykrytych. To ważne sprawdzenie: Rozszerzenie rejestruje usługę z `pIp4=nullptr` (bez adresu IP), więc trzeba potwierdzić, że Android rozwiązuje ją na adres i port.
- [ ] Stuknięcie wykrytego laptopa łączy z nim.
- [ ] Zmiana portu akcją `Mobile mixer: Settings (port, band password)...`: serwer działa na nowym porcie bez restartu REAPERa, a Bielik widzi laptopa z nowym portem. Zapis bez zmiany portu nie ogłasza usługi od nowa.
- [ ] Zamknięcie REAPERa wycofuje ogłoszenie: laptop znika z listy wykrytych.
- [ ] Ręczny adres działa, gdy wykrywanie nie działa (np. w sieci blokującej multicast).

## Odsłuchy i źródła

- [ ] Telefon pokazuje oba odsłuchy z nazwami z REAPERa.
- [ ] Źródła odsłuchu i ich poziomy zgadzają się z receive'ami w REAPERze.
- [ ] Ścieżka bez nazwy pojawia się jako `Track N`, a ścieżka bez prefiksu nie staje się odsłuchem.
- [ ] Dodanie i usunięcie receive'a, zmiana nazwy ścieżki i nowy odsłuch są widoczne w telefonie bez ponownego łączenia.
- [ ] Usunięcie oglądanego odsłuchu cofa do listy z komunikatem.
- [ ] Przełączenie karty projektu w REAPERze pokazuje odsłuchy nowego projektu.

## Poziomy

- [ ] Ruch suwaka w telefonie słychać i widać w mikserze REAPERa już w trakcie gestu.
- [ ] Ruch fadera receive'a myszką w REAPERze przesuwa suwak w telefonie.
- [ ] Dwa telefony na tym samym odsłuchu pozostają zgodne.
- [ ] Telefon na innym odsłuchu nie reaguje na te zmiany.
- [ ] Podwójne stuknięcie palcem wraca do 0 dB, a pojedyncze dotknięcie suwaka niczego nie zmienia.
- [ ] Kilka telefonów naraz nie spowalnia REAPERa i nie powoduje trzasków w audio.

## Undo i zapis projektu w REAPERze

- [ ] Zmiany z telefonu nie dodają punktów do historii undo REAPERa (Edit > Undo History).
- [ ] Po zmianie z telefonu projekt jest oznaczony jako zmieniony, a przy zamknięciu REAPER pyta o zapis. Sprawdź przy włączonym w preferencjach pytaniu o zapis, bo od niego zależy `MarkProjectDirty`.
- [ ] Po zapisaniu i ponownym otwarciu projektu poziomy z telefonu są na miejscu.

## Połączenie

- [ ] Hasło: złe hasło daje czytelny komunikat, dobre jest zapamiętane na kolejne uruchomienie.
- [ ] Zmiana hasła w trakcie: po zerwaniu połączenia Bielik przestaje próbować i wraca do ekranu połączenia z komunikatem o złym haśle.
- [ ] Wyłączenie Wi-Fi w telefonie: w ciągu kilku sekund widać pasek rozłączenia i zablokowane suwaki. Po włączeniu Wi-Fi Bielik sam wraca do odsłuchu.
- [ ] Restart REAPERa: Bielik sam wraca do odsłuchu, a port jest od razu wolny.
- [ ] Zerwanie połączenia w trakcie przeciągania suwaka: po powrocie „Cofnij” wraca do poziomu sprzed gestu.
- [ ] Ponowne uruchomienie Bielika wraca do ostatniego laptopa i odsłuchu. Gdy laptop był wyłączony, po stuknięciu „Połącz” odsłuch i tak się otwiera.
- [ ] Ekran nie gaśnie, gdy odsłuch jest otwarty, i wygasza się normalnie po wyjściu z niego.
