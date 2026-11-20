#!/usr/bin/env bash
# Procura, no código do app e da API, padrões que o projeto não aceita
# (requisitos RNF05 e RNF07 e boas práticas de segurança).
#
# Uso: .github/scripts/check-policy.sh
#
# Para aceitar uma linha de propósito, escreva "policy-ignore: motivo" na mesma
# linha. Linhas de comentário e arquivos de teste são ignorados.
# Termina com código 1 se encontrar algo.
set -u
export LC_ALL=C

case "${1:-}" in
  -h | --help)
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
    exit 0
    ;;
  "") ;;
  *)
    echo "Opção desconhecida: $1" >&2
    exit 2
    ;;
esac

root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Execute dentro de um repositório git." >&2
  exit 2
}
cd "$root" || exit 2

findings="$(mktemp)"
trap 'rm -f "$findings"' EXIT

# scan "descrição e o que fazer" "expressão" "pasta" "padrão de arquivo" [-i]
scan() {
  local description="$1" regex="$2" dir="$3" glob="$4" case_flag="${5:-}"
  [[ -d "$dir" ]] || return 0

  local match file rest line text
  while IFS= read -r match; do
    file="${match%%:*}"
    rest="${match#*:}"
    line="${rest%%:*}"
    text="${rest#*:}"
    [[ "$text" =~ ^[[:space:]]*(//|/\*|\*|#) ]] && continue
    [[ "$text" == *policy-ignore:* ]] && continue
    printf '%s:%s: %s\n' "$file" "$line" "$description" >>"$findings"
  done < <(
    grep -rn -I -E ${case_flag:+"$case_flag"} \
      --include="$glob" \
      --exclude='*.test.*' --exclude='*_test.dart' --exclude='*.spec.*' \
      --exclude-dir=node_modules --exclude-dir=build --exclude-dir=dist \
      --exclude-dir=__tests__ --exclude-dir=tests --exclude-dir=test \
      -e "$regex" "$dir"
  )
}

# Logs que escrevem segredo ou dado pessoal. Só olha os argumentos da chamada do
# console e só o que está FORA de textos fixos: console.error('Defina DATABASE_URL')
# é aceito; console.log(senha) não.
scan_log_leaks() { # pasta
  local dir="$1"
  [[ -d "$dir" ]] || return 0

  local perl_code
  perl_code="$(
    cat <<'PERL'
next unless /console\.\w+\(/;
next if /^\s*(\/\/|\*)/ || /policy-ignore:/;
my $code = $_;
$code =~ s#`((?:\\.|[^`\\])*)`# join(' ', $1 =~ m/\$\{([^}]*)\}/g) #ge;
$code =~ s#"(?:\\.|[^"\\])*"##g;
$code =~ s#'(?:\\.|[^'\\])*'##g;
next unless $code =~ /console\.\w+\((.*)$/;
my $arguments = $1;
print "$ARGV:$.:$_" if $arguments =~ /\b\w*(password|senha|token|secret|database_?url|phone|telefone)\w*/i;
PERL
  )"

  local file match line output
  while IFS= read -r -d '' file; do
    # Se o perl falhar, a rotina para: não pode "passar" sem ter verificado.
    output="$(perl -ne "$perl_code" "$file" 2>&1)" || {
      echo "Erro ao analisar $file com perl: $output" >&2
      exit 2
    }
    [[ -n "$output" ]] || continue
    while IFS= read -r match; do
      line="${match#*:}"
      line="${line%%:*}"
      printf '%s:%s: %s\n' "$file" "$line" 'segredo ou dado pessoal no log (RNF05, RNF07)' >>"$findings"
    done <<<"$output"
  done < <(
    find "$dir" \( -name node_modules -o -name dist -o -name build -o -name test -o -name tests -o -name __tests__ \) -prune \
      -o -type f \( -name '*.ts' -o -name '*.js' \) ! -name '*.test.*' ! -name '*.spec.*' -print0
  )
}

# --- App (Flutter) ---------------------------------------------------------
scan 'endereço fixo no código: receba a URL da API por --dart-define (API_BASE_URL)' \
  'https?://' app/lib '*.dart'
scan 'não imprima no console: pode vazar dado pessoal (RNF07)' \
  '\b(print|debugPrint)\(' app/lib '*.dart'
scan 'HTML montado por texto abre brecha de XSS: use componentes do Flutter' \
  '\.innerHTML[[:space:]]*=|setInnerHtml|\.innerHtml' app/lib '*.dart'

# --- API (Node.js + TypeScript) -------------------------------------------
for glob in '*.ts' '*.js'; do
  scan 'SQL montado com ${...}: use parâmetros ($1, $2) para evitar injeção de SQL' \
    '`[^`]*\b(select|insert|update|delete)\b[^`]*\$\{' api/src "$glob" -i
  scan 'SQL montado por concatenação: use parâmetros ($1, $2) para evitar injeção de SQL' \
    "['\"][^'\"]*\\b(select|insert|update|delete)\\b[^'\"]*['\"][[:space:]]*\\+" api/src "$glob" -i
  scan 'Math.random não é seguro: use crypto.randomInt ou crypto.randomBytes (códigos, tokens)' \
    'Math\.random\(' api/src "$glob"
  scan 'CORS aberto para qualquer origem: liste só a origem do app' \
    "origin:[[:space:]]*(['\"]\\*['\"]|true)" api/src "$glob"
  scan 'eval e new Function executam texto como código' \
    '\beval\(|new Function\(' api/src "$glob"
  scan 'verificação de TLS desligada: a conexão com o banco precisa validar o certificado' \
    'rejectUnauthorized:[[:space:]]*false|NODE_TLS_REJECT_UNAUTHORIZED|sslmode=disable' api/src "$glob"
done

scan_log_leaks api/src

if [[ -s "$findings" ]]; then
  count="$(sort -u "$findings" | wc -l | tr -d ' ')"
  echo "Padrões não aceitos encontrados ($count):" >&2
  sort -u "$findings" | sed 's/^/  /' >&2
  echo >&2
  echo "Se for de propósito, escreva \"policy-ignore: motivo\" na linha." >&2
  exit 1
fi

echo "Nenhum padrão não aceito encontrado no código."
