# 02: Stały adres laptopa, a mDNS jako droga awaryjna

**What to build:** Bielik najpierw łączy się ze znanym, stałym adresem laptopa, a dopiero gdy to się nie uda, szuka go przez mDNS. Muzyk na scenie nie zostaje bez połączenia tylko dlatego, że jedna metoda zawiodła. Propozycja Wiktora, np. stały adres `192.168.1.10`.

Zgłoszone przypadki:

- mDNS nie działa, bo pakiety multicast nigdy nie docierają. Łukasz ma złe doświadczenia z mDNS.
- Ktoś zmienił stały adres laptopa i aplikacja nie znajduje go pod znanym adresem.

Do rozstrzygnięcia w triage: Bielik już zapamiętuje ostatni laptop i ma ręczny adres, więc trzeba sprawdzić, czego faktycznie brakuje. Możliwe, że wystarczy ustalona kolejność prób przy starcie albo stały adres z ticketu 01. Zespół rozważał usunięcie mDNS, ale Wiktor chce go zostawić, także dla wygody przy rozwoju, więc nie jest to część tego ticketu.

**Blocked by:** 01

**Status:** needs-triage

- [ ] Ustalona kolejność: zapamiętany lub stały adres, potem mDNS.
- [ ] Gdy obie drogi zawiodą, muzyk widzi czytelny komunikat i może wpisać adres ręcznie.
