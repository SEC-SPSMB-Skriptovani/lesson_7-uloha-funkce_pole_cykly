#!/usr/bin/env bash
# make_tree_hide_quote.sh
# Vytvoří náhodnou stromovou strukturu a v jednom souboru ukryje citát.
# Autor: (upraveno ChatGPT)
# Ve výchozím nastavení vytvoří rozumné množství souborů (několik stovek na adresář).

set -euo pipefail

get_random_quote() {
    local file="$1"

    # ověření existence souboru
    if [[ ! -f "$file" ]]; then
        echo "Soubor s citáty '$file' neexistuje!" >&2
        return 1
    fi

    # zjištění počtu řádků
    local line_count
    line_count=$(wc -l < "$file")

    if (( line_count == 1 )); then
        # jen jeden řádek → vezmeme celý
        cat "$file"
    else
        # více řádků → vyber náhodný
        if command -v shuf >/dev/null 2>&1; then
            shuf -n 1 "$file"
        else
            # fallback pro systémy bez shuf (např. macOS)
            awk 'BEGIN{srand()} {lines[NR]=$0} END{print lines[int(rand()*NR)+1]}' "$file"
        fi
    fi
}

# --- Výchozí parametry (změňit podle potřeby) ---
TARGET_DIR="./exercise_tree"   # kam vytvářet
MAX_DEPTH=3                    # maximální hloubka stromu
MAX_BRANCH=4                   # maximální počet podsložek v jednom adresáři
FILES_PER_DIR=200              # počet souborů v každém adresáři (výchozí: 200 = "několik stovek")
AVG_FILE_BYTES=1024            # průměrná velikost souboru (bajty) - používané pro odhad volného místa
QUOTE="Buď změnou, kterou chceš vidět ve světě. — Mahátma Gándhí"  # výchozí citát
VERBOSE=1                      # 1 = ano, 0 = ne

# --- Parse args (jednoduché) ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir) TARGET_DIR="$2"; shift 2 ;;
    -n|--files-per-dir) FILES_PER_DIR="$2"; shift 2 ;;
    -D|--max-depth) MAX_DEPTH="$2"; shift 2 ;;
    -b|--branch) MAX_BRANCH="$2"; shift 2 ;;
    -q|--quote) QUOTE="$2"; shift 2 ;;
    --no-verbose) VERBOSE=0; shift ;;
    --quote-file) QUOTE=$(get_random_quote "$2"); shift 2;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]

Options:
  -d, --dir DIR            Target directory (default ./exercise_tree)
  -n, --files-per-dir N    Files per directory (default 200)
  -D, --max-depth N        Max tree depth (default 3)
  -b, --branch N           Max subdirs per directory (default 4)
  -q, --quote "text"       Quote text to hide (default a Gandhi quote)
  --quote-file FILE        Read quote from file
  --no-verbose             Don't print progress
  -h, --help               Show this help
EOF
      exit 0
      ;;
    *)
      echo "Neznámý parametr: $1" >&2
      exit 1
      ;;
  esac
done

# --- Utility functions ---
log() { if [[ $VERBOSE -eq 1 ]]; then echo "$@"; fi }

randname() {
  local adjectives=(brave happy clever tiny sleepy shiny silent quick noisy kind fuzzy gentle bold proud curious goofy calm lazy sneaky)
  local animals=(penguin koala fox cat dog bear tiger rabbit dolphin whale eagle lion frog panda lizard otter wolf sparrow monkey)

  local adj=${adjectives[$RANDOM % ${#adjectives[@]}]}
  local animal=${animals[$RANDOM % ${#animals[@]}]}

  # Přidáme náhodné číslo, aby se minimalizovaly kolize
  echo "${adj}-${animal}"
}

# --- Odhad volného místa ---
estimate_needed() {
  # odhad = AVG_FILE_BYTES * FILES_PER_DIR * (počet adresářů odhadněný)
  # odhadneme počet adresářů přibližně jako (branch^(depth+1)-1)/(branch-1)
  local b=${MAX_BRANCH}
  local d=${MAX_DEPTH}
  if [[ $b -le 1 ]]; then
    est_dirs=$((d+1))
  else
    # geometric series: sum_{i=0..d} b^i = (b^{d+1}-1)/(b-1)
    est_dirs=$(( ( $(echo "$b^($d+1)" | bc) - 1 ) / (b-1) ))
  fi
  echo $(( AVG_FILE_BYTES * FILES_PER_DIR * est_dirs ))
}

write_random_content() {
  local fpath="$1"                   # cesta k souboru
  local size="${2:-1024}"            # velikost souboru v bajtech
  local animals=(penguin koala fox cat dog bear tiger rabbit dolphin whale eagle lion frog panda lizard otter wolf sparrow monkey "[ANIMAL_PLACEHOLDER]")

  local animal=${animals[$RANDOM % ${#animals[@]}]}
  local prefix="This is a random fairy tale about ${animal} and \n"
  local prefix_len=${#prefix}
  local random_size=$((size - prefix_len))
  (( random_size < 0 )) && random_size=0

  {
    echo -n "$prefix"
    head -c "$random_size" /dev/urandom | base64 | head -c "$random_size"
  } > "$fpath"

  # volitelně: přidej prázdný řádek na konec
  # echo >> "$fpath"
}

# zkontroluj místo (v KB)
#free_kb=99999999
if df -k --output=avail . &>/dev/null; then
  free_kb=$(df -k --output=avail "$TARGET_DIR" | tail -n1)
else
  free_kb=$(df -k "$TARGET_DIR" | awk 'NR==2 {print $(NF-2)}')
fi
: "${free_kb:=0}"

needed_bytes=$(estimate_needed)
needed_kb=$(( (needed_bytes + 1023) / 1024 ))

if [[ $free_kb -lt $needed_kb ]]; then
  echo "Varování: odhadovaná potřeba je $needed_kb KB, místo volné: ${free_kb} KB."
  echo "Snížím počet souborů automaticky, aby to bylo bezpečné."
  # upravíme FILES_PER_DIR tak, aby se vešlo (s rezervou 20%)
  safe_kb=$(( free_kb * 80 / 100 ))
  # odhad počtu adresářů stejný jako dříve:
  # aby bylo jednoduché, snížíme FILES_PER_DIR ≈ safe_kb / (est_dirs * avg_kb)
  est_dirs=1
  if [[ $MAX_BRANCH -le 1 ]]; then
    est_dirs=$((MAX_DEPTH+1))
  else
    est_dirs=$(( ( $(echo "$MAX_BRANCH^($MAX_DEPTH+1)" | bc) - 1 ) / (MAX_BRANCH-1) ))
  fi
  avg_kb=$(( (AVG_FILE_BYTES + 1023) / 1024 ))
  if [[ $est_dirs -le 0 ]]; then est_dirs=1; fi
  new_files_per_dir=$(( safe_kb / (est_dirs * avg_kb) ))
  if [[ $new_files_per_dir -lt 1 ]]; then
    echo "Není dost místa ani pro 1 soubor na adresář. Ukončuji." >&2
    exit 1
  fi
  log "FILES_PER_DIR z $FILES_PER_DIR -> $new_files_per_dir"
  FILES_PER_DIR=$new_files_per_dir
fi

# --- Vytvoření stromu ---
mkdir -p "$TARGET_DIR"
declare -a DIR_QUEUE
DIR_QUEUE=("$TARGET_DIR")
created_dirs=0
created_files=0
declare -a ALL_FILES   # uložíme všechny vytvořené soubory

while [[ ${#DIR_QUEUE[@]} -gt 0 ]]; do
  dir="${DIR_QUEUE[0]}"
  DIR_QUEUE=("${DIR_QUEUE[@]:1}")
  created_dirs=$((created_dirs+1))

  # vytvoř soubory v tomto adresáři
  for ((i=0;i<FILES_PER_DIR;i++)); do
    fname="$(randname).txt"
    fpath="$dir/$fname"
    # vygeneruj náhodný text (krátký) + nový řádek
    # používáme base64 z /dev/urandom, oříznuté na náhodnou délku do ~AVG_FILE_BYTES
    size=$(( AVG_FILE_BYTES + (RANDOM % (AVG_FILE_BYTES/2 + 1)) - (AVG_FILE_BYTES/4) ))
    # zabezpečení: minimální velikost 100
    if [[ $size -lt 100 ]]; then size=100; fi
    write_random_content "$fpath" "$size"
    echo >> "$fpath"
    ALL_FILES+=("$fpath")
    created_files=$((created_files+1))
  done

  # pokud jsme ještě nedosáhli max depth, přidej náhodný počet podsložek
  # vypočítáme aktuální hloubku od TARGET_DIR
  rel="${dir#$TARGET_DIR}"
  # count slashes v rel (bez počátečního /)
  if [[ -z "$rel" || "$rel" == "$dir" ]]; then
    depth=0
  else
    depth=$(awk -F"/" '{print NF-1}' <<< "${rel#/}")
  fi

  if [[ $depth -lt $MAX_DEPTH ]]; then
    # náhodný počet podsložek od 1 do MAX_BRANCH
    nsub=$(( 1 + RANDOM % MAX_BRANCH ))
    for ((j=0;j<nsub;j++)); do
      sub="${dir}/$(randname)"
      mkdir -p "$sub"
      DIR_QUEUE+=("$sub")
    done
  fi
done

log "Vytvořeno $created_dirs adresářů a $created_files souborů (přibližně)."

# --- Vyber náhodný soubor a vlož citát ---
if [[ ${#ALL_FILES[@]} -eq 0 ]]; then
  echo "Žádné soubory nebyly vytvořeny. Konec." >&2
  exit 1
fi

rand_index=$(( RANDOM % ${#ALL_FILES[@]} ))
chosen="${ALL_FILES[$rand_index]}"

# vložíme citát (vymažeme předchozí obsah a napíšeme pouze citát)
# pokud chceš citát přidat místo přepsání, změň > na >> zde
printf "%s\n" "$QUOTE" > "$chosen"

log "Citát byl uložen do souboru: $chosen"

# --- Volitelné: tisk přehledu pro učitele (komentovat pro studenty) ---
if [[ $VERBOSE -eq 1 ]]; then
  cat <<EOF
Hotovo!
Cílový adresář: $TARGET_DIR
Počet adresářů: $created_dirs
Počet souborů: $created_files
Soubor s citátem: $chosen
EOF
fi

# konec scriptu