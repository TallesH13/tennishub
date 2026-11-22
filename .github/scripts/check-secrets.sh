#!/usr/bin/env bash
# Procura segredos e credenciais nos arquivos do repositório.
#
# Uso: .github/scripts/check-secrets.sh [--extra PASTA]... [--high-confidence]
#
#   (sem opções)       examina os arquivos versionados (git ls-files)
#   --extra PASTA      examina também os arquivos dessa pasta, mesmo que não
#                      estejam versionados (ex.: app/build/web)
#   --high-confidence  usa só as regras com pouco risco de falso positivo;
#                      indicado para código gerado ou minificado
#
# Arquivos de teste só passam pelas regras de alta confiança e aceitam senhas
# curtas (menos de 12 caracteres) em endereços, que são fictícias.
# Para ignorar uma linha de propósito, escreva "secret-scan:ignore" nela.
#
# O script nunca imprime o segredo inteiro, só o suficiente para achá-lo.
# Termina com código 1 se encontrar algo.
set -u
export LC_ALL=C

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

extra_dirs=()
high_confidence=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --extra)
      [[ $# -ge 2 ]] || { echo "Falta a pasta depois de --extra." >&2; exit 2; }
      extra_dirs+=("$2")
      shift 2
      ;;
    --high-confidence)
      high_confidence=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Opção desconhecida: $1" >&2
      exit 2
      ;;
  esac
done

root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Execute dentro de um repositório git." >&2
  exit 2
}
cd "$root" || exit 2

file_list="$(mktemp)"
findings="$(mktemp)"
trap 'rm -f "$file_list" "$findings"' EXIT

git ls-files -z >"$file_list"
for dir in "${extra_dirs[@]+"${extra_dirs[@]}"}"; do
  if [[ -d "$dir" ]]; then
    find "$dir" -type f -print0 >>"$file_list"
  fi
done

report() { # arquivo linha descrição
  printf '%s:%s: %s\n' "$1" "$2" "$3" >>"$findings"
}

# Valor que é só um exemplo (<senha>, ${SENHA}, "changeme"...).
is_placeholder() {
  local value="$1"
  [[ "$value" =~ [\<\>\$\{\}\*] ]] && return 0
  local lower="${value,,}"
  [[ "$lower" =~ ^(password|passwd|pass|senha|changeme|change-me|exemplo|example|sua-senha|seu-token|your-password|x+)$ ]] && return 0
  [[ "$lower" == *exemplo* || "$lower" == *example* || "$lower" == *changeme* ]] && return 0
  return 1
}

# Arquivo de teste? Lá é comum haver senhas e endereços fictícios.
is_test_file() {
  [[ "$1" =~ (^|/)(tests?|__tests__)/ || "$1" =~ \.(test|spec)\.[a-z]+$ || "$1" =~ _test\.[a-z]+$ ]]
}

# Linha marcada para ser ignorada?
is_ignored_line() { # arquivo linha
  sed -n "${2}p" "$1" 2>/dev/null | grep -q 'secret-scan:ignore'
}

# Regras simples: "descrição<TAB>expressão". Mostra o início do valor achado.
simple_rules=(
  $'chave privada\t-----BEGIN [A-Z ]*PRIVATE KEY-----'
  $'chave de acesso da AWS\tAKIA[0-9A-Z]{16}'
  $'token do GitHub\t(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})'
  $'token JWT\teyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}'
)
# Só no modo normal: atribuição de segredo a um texto fixo.
medium_rules=(
  $'segredo escrito no código\t(secret|token|passw(or)?d|senha|api[_-]?key|private[_-]?key)[A-Za-z0-9_]*["\x27]?[[:space:]]*[:=][[:space:]]*["\x27][^"\x27[:space:]]{12,}["\x27]'
)

run_rules() { # uma regra por argumento
  local rule description regex match file line text flags
  for rule in "$@"; do
    description="${rule%%$'\t'*}"
    regex="${rule#*$'\t'}"
    # Nomes como dbPassword ou API_KEY: a regra de atribuição ignora maiúsculas.
    flags=()
    [[ "$description" == "segredo escrito no código" ]] && flags=(-i)
    while IFS= read -r match; do
      file="${match%%:*}"
      text="${match#*:}"
      line="${text%%:*}"
      text="${text#*:}"
      is_ignored_line "$file" "$line" && continue
      if [[ "$description" == "segredo escrito no código" ]]; then
        # Em teste, senha fictícia é normal: só as regras de alta confiança valem lá.
        is_test_file "$file" && continue
        local value="${text#*[\"\']}"
        value="${value%[\"\']*}"
        is_placeholder "$value" && continue
      fi
      report "$file" "$line" "$description (${text:0:4}…, ${#text} caracteres)"
    done < <(xargs -0 -r grep -I -n -H -o -E -s ${flags[@]+"${flags[@]}"} -e "$regex" <"$file_list")
  done
}

# Endereços com usuário e senha (ex.: postgres://usuario:senha@servidor/banco).
# Aceita exemplos e bancos locais; recusa qualquer outro servidor, em especial o Neon.
check_connection_strings() {
  local regex='[A-Za-z][A-Za-z0-9+.-]*://[^/@[:space:]:]+:[^@[:space:]/]+@[^/[:space:]]+'
  local match file text line url scheme rest user pass host
  while IFS= read -r match; do
    file="${match%%:*}"
    text="${match#*:}"
    line="${text%%:*}"
    url="${text#*:}"
    is_ignored_line "$file" "$line" && continue

    scheme="${url%%://*}"
    rest="${url#*://}"
    user="${rest%%:*}"
    rest="${rest#*:}"
    pass="${rest%%@*}"
    host="${rest#*@}"
    host="${host%%[:/?]*}"

    is_placeholder "$pass" && continue
    # Senha de verdade (ex.: a do Neon) é longa; em teste, senha curta é fictícia.
    is_test_file "$file" && [[ ${#pass} -lt 12 ]] && continue
    case "$host" in
      localhost | 127.0.0.1 | ::1 | postgres | db) continue ;;
    esac
    report "$file" "$line" "endereço com senha para ${host} (${scheme}://${user}:***@${host})"
  done < <(xargs -0 -r grep -I -n -H -o -E -s -e "$regex" <"$file_list")
}

# Arquivos que não devem ser versionados, pelo nome.
check_forbidden_names() {
  local file name
  while IFS= read -r -d '' file; do
    name="$(basename "$file")"
    case "$name" in
      .env.example | .env.sample | .env.template) continue ;;
      .env | .env.*)
        report "$file" 1 "arquivo de variáveis de ambiente não pode ser versionado"
        ;;
      *.pem | *.key | *.p12 | *.pfx | *.jks | *.keystore | id_rsa | id_ed25519)
        report "$file" 1 "arquivo de chave ou certificado não pode ser versionado"
        ;;
    esac
  done <"$file_list"
}

run_rules "${simple_rules[@]}"
check_connection_strings
check_forbidden_names
if [[ "$high_confidence" -eq 0 ]]; then
  run_rules "${medium_rules[@]}"
fi

if [[ -s "$findings" ]]; then
  count="$(wc -l <"$findings" | tr -d ' ')"
  echo "Possíveis segredos encontrados ($count):" >&2
  sort -u "$findings" | sed 's/^/  /' >&2
  echo >&2
  echo "Se for um falso positivo, marque a linha com \"secret-scan:ignore\"." >&2
  echo "Se for um segredo de verdade, troque-o AGORA no serviço de origem e só depois remova do código." >&2
  exit 1
fi

total="$(tr -cd '\0' <"$file_list" | wc -c | tr -d ' ')"
echo "Nenhum segredo encontrado em $total arquivos."
