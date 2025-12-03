# Úloha na hledání v textu

Napište shellový skript, který splní následující dílčí úkoly.

---

## 1. Najděte soubor, ve kterém je uložený samotný citát
Citát je jediný soubor, který:

- obsahuje pouze jeden řádek,
- **neobsahuje** následující text:
  ```
  This is a random Fairy tale
  ```

### Požadavek
Pomocí kombinace příkazů `cat` a `grep -q` najděte tento soubor. Cestu k němu vytiskněte na standardní výstup:
```bash
Citát nalezen:
Soubor: uloha9/fuzzy-penguin/kind-koala/bold-dolphin.txt
Citát: "Debugging is like being the detective in a crime movie where you are also the murderer." — Filipe Fortes
```

1. Pomocí příkazu `find ./excercise -type f` prohledejte celou stromovou strukturu a výsledek načtěte do pole.
2. Vytvořte funkci `is_quote()`, která bude vracet `true`, pokud daný soubor obsahuje citát, a `false`, pokud citát neobsahuje. 
3. Projděte každý prvek pole a pomocí vámi implementované funkce `is_quote()` zkontrolujte, zda daný soubor obsahuje citát.
4. Výsledek vypište jako standardní výstup do konzole.

---

## 2. Spočítejte šťastná zvířátka
Vytvořte counter `happy_counter`a spočítejte všechny soubory obsahující slovo "happy" v názvu souboru. 
1. Vytvořte funkci `count_happy()` ve které se bude jako argument předávat název souboru
2. pokud název souboru začíná slovem happy, pak se hodnota counteru zvýší o 1.
   lze použít kombinaci podmínku
   ```bash
   filename=$(basename "$file")   # získáme jen název souboru
   if [[ $filename == *happy* ]]; then
   ```
   případně
   ```bash
   if [[ $file =~ /([^/]*happy[^/]*)\.txt$ ]]; then
   ```
  
3. Na konci scriptu vypište hodnotu counteru.

Příklad:
```bash
Počet štastných zvířátek: 1008.
```
---
