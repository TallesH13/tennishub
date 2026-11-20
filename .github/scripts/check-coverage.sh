#!/usr/bin/env bash
# Confere a cobertura de testes de um arquivo lcov (gerado por `flutter test --coverage`).
#
# Uso (dentro de app/): ../.github/scripts/check-coverage.sh [opções]
#
#   --lcov ARQUIVO     arquivo lcov (padrão: coverage/lcov.info)
#   --source-dir PASTA código-fonte, para achar arquivos que nenhum teste carregou
#                      (padrão: lib). Esses arquivos contam como 0%.
#   --min-total N      cobertura mínima de todo o código, em % (padrão: 85)
#   --min-logic N      cobertura mínima da lógica de negócio, em % (padrão: 90)
#   --logic REGEX      quais arquivos são "lógica de negócio" (domínio, dados,
#                      estado e formatação)
#   --exclude REGEX    arquivos ignorados (código gerado, main.dart e o que só
#                      existe no navegador e não roda no teste)
#
# Os padrões também podem vir das variáveis COVERAGE_MIN_TOTAL e COVERAGE_MIN_LOGIC.
# Termina com código 1 se alguma meta não for atingida.
set -u
export LC_ALL=C

lcov_file="coverage/lcov.info"
source_dir="lib"
min_total="${COVERAGE_MIN_TOTAL:-85}"
min_logic="${COVERAGE_MIN_LOGIC:-90}"
logic_regex='^lib/(core/(formatting|time)|features/[^/]+/(domain|data|presentation/state))/'
exclude_regex='(\.g\.dart|\.freezed\.dart|/main\.dart|_web\.dart)$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lcov) lcov_file="$2"; shift 2 ;;
    --source-dir) source_dir="$2"; shift 2 ;;
    --min-total) min_total="$2"; shift 2 ;;
    --min-logic) min_logic="$2"; shift 2 ;;
    --logic) logic_regex="$2"; shift 2 ;;
    --exclude) exclude_regex="$2"; shift 2 ;;
    -h | --help)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
      exit 0
      ;;
    *)
      echo "Opção desconhecida: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$lcov_file" ]]; then
  echo "Arquivo de cobertura não encontrado: $lcov_file" >&2
  echo "Gere com: flutter test --coverage" >&2
  exit 2
fi

merged="$(mktemp)"
trap 'rm -f "$merged"' EXIT
cp "$lcov_file" "$merged"

# Arquivos que nenhum teste carregou não aparecem no lcov. Entram como 0%.
if [[ -d "$source_dir" ]]; then
  while IFS= read -r -d '' file; do
    [[ "$file" =~ $exclude_regex ]] && continue
    grep -q "^SF:${file}\$" "$lcov_file" && continue
    # Arquivo só de constantes ou enums não tem linha executável: não há o que cobrir.
    grep -qE '\)[[:space:]]*(async[[:space:]]*)?(\{|=>)' "$file" || continue
    lines="$(grep -cvE '^[[:space:]]*(//.*)?$' "$file")"
    printf 'SF:%s\nLF:%s\nLH:0\nend_of_record\n' "$file" "$lines" >>"$merged"
  done < <(find "$source_dir" -name '*.dart' -print0 | sort -z)
fi

awk -v min_total="$min_total" -v min_logic="$min_logic" \
  -v logic_regex="$logic_regex" -v exclude_regex="$exclude_regex" '
function pct(hit, found) { return found > 0 ? hit * 100 / found : 100 }
function fmt(value, s) { s = sprintf("%.1f", value); sub(/\./, ",", s); return s }

/^SF:/ { file = substr($0, 4); next }
/^LF:/ { found = substr($0, 4) + 0; next }
/^LH:/ { hit = substr($0, 4) + 0; next }
/^end_of_record/ {
  if (file ~ exclude_regex) { next }
  total_found += found; total_hit += hit
  file_found[file] += found; file_hit[file] += hit
  if (file ~ logic_regex) { logic_found += found; logic_hit += hit }
  if (hit == 0 && found > 0) { untested[file] = 1 }
  next
}

END {
  total = pct(total_hit, total_found)
  logic = pct(logic_hit, logic_found)
  fail = 0

  status = (total + 0.0001 >= min_total) ? "ok" : "ABAIXO DA META"
  if (status != "ok") fail = 1
  printf "Cobertura de linhas (todo o código): %s%% (%d/%d), meta >= %s%%: %s\n", fmt(total), total_hit, total_found, min_total, status

  status = (logic + 0.0001 >= min_logic) ? "ok" : "ABAIXO DA META"
  if (status != "ok") fail = 1
  printf "Cobertura da lógica de negócio:      %s%% (%d/%d), meta >= %s%%: %s\n", fmt(logic), logic_hit, logic_found, min_logic, status

  print ""
  print "Arquivos com menor cobertura:"
  for (shown = 0; shown < 5; shown++) {
    best = ""
    for (f in file_found) {
      if (file_found[f] == 0 || (f in used)) { continue }
      value = pct(file_hit[f], file_found[f])
      if (best == "" || value < best_value || (value == best_value && f < best)) { best = f; best_value = value }
    }
    if (best == "") { break }
    used[best] = 1
    printf "  %s%%  %s (%d/%d)\n", fmt(best_value), best, file_hit[best], file_found[best]
  }

  count = 0
  for (f in untested) { count++ }
  if (count > 0) {
    print ""
    print "Arquivos sem nenhum teste (contam como 0%):"
    for (i = 0; i < count; i++) {
      best = ""
      for (f in untested) { if (!(f in listed) && (best == "" || f < best)) { best = f } }
      listed[best] = 1
      print "  " best
    }
  }
  exit fail
}' "$merged"
