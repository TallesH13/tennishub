#!/usr/bin/env bash
# Testes dos scripts de qualidade e segurança (check-secrets, check-coverage,
# check-policy). Cada teste monta um repositório temporário com um exemplo e
# confere se o script aceita ou recusa.
#
# Uso: .github/scripts/tests/run-tests.sh
#
# Os "segredos" de exemplo são montados em pedaços para que este arquivo não
# pareça um vazamento aos próprios scanners.
set -u

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
secrets="$scripts_dir/check-secrets.sh"
coverage="$scripts_dir/check-coverage.sh"
policy="$scripts_dir/check-policy.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

passed=0
failed=0
last_output=""

ok() {
  passed=$((passed + 1))
  printf '  ok    %s\n' "$1"
}
bad() {
  failed=$((failed + 1))
  printf '  FALHA %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '        %s\n' "$2"
}

# expect_rc "nome" CODIGO comando...   (guarda a saída em last_output)
expect_rc() {
  local name="$1" expected="$2"
  shift 2
  last_output="$("$@" 2>&1)"
  local rc=$?
  if [[ "$rc" -eq "$expected" ]]; then
    ok "$name"
  else
    bad "$name" "esperado código $expected, veio $rc: ${last_output:0:200}"
  fi
}

expect_in_output() { # "nome" texto
  if [[ "$last_output" == *"$2"* ]]; then ok "$1"; else bad "$1" "a saída não traz: $2"; fi
}
expect_not_in_output() { # "nome" texto
  if [[ "$last_output" != *"$2"* ]]; then ok "$1"; else bad "$1" "a saída mostra: $2"; fi
}

# new_repo: cria um repositório git vazio e entra nele
repo_count=0
new_repo() {
  repo_count=$((repo_count + 1))
  local dir="$work/repo$repo_count"
  mkdir -p "$dir"
  git -C "$dir" init -q
  cd "$dir" || exit 2
}

# put ARQUIVO  (conteúdo pela entrada padrão) e versiona
put() {
  mkdir -p "$(dirname "$1")"
  cat >"$1"
  git add "$1"
}

# --- peças de segredos de exemplo, montadas em pedaços ---------------------
aws_key="AKI""AABCDEFGHIJKLMNOP"
pem_header="-----BEGIN ""RSA PRIVATE KEY-----"
gh_token="gh""p_""abcdefghijklmnopqrstuvwxyz0123456789"
jwt_token="ey""JhbGciOiJIUzI1NiJ9"".ey""JzdWIiOiIxMjM0NTY3ODkwIn0"".abcdefghijklmnop"
neon_secret="AbCdEf123456GhIjKl"
generic_secret="Zx9Qw3Er5Ty7Ui1O"

echo "check-secrets.sh"

new_repo
put app/lib/a.dart <<<"void main() {}"
expect_rc "repositório limpo passa" 0 "$secrets"

new_repo
put chave.txt <<<"$pem_header"
expect_rc "recusa chave privada" 1 "$secrets"
expect_in_output "diz em que arquivo está" "chave.txt"

new_repo
put a.txt <<<"id = $aws_key"
expect_rc "recusa chave de acesso da AWS" 1 "$secrets"

new_repo
put a.txt <<<"token = $gh_token"
expect_rc "recusa token do GitHub" 1 "$secrets"

new_repo
put a.txt <<<"Authorization: Bearer $jwt_token"
expect_rc "recusa token JWT" 1 "$secrets"

new_repo
put api/src/db.ts <<<"const url = 'postgresql://neondb_owner:${neon_secret}@ep-teste.sa-east-1.aws.neon.tech/neondb';"
expect_rc "recusa endereço do Neon com senha" 1 "$secrets"
expect_not_in_output "não mostra a senha do Neon" "$neon_secret"
expect_in_output "mostra o servidor" "ep-teste.sa-east-1.aws.neon.tech"

new_repo
put api/.env.example <<<"DATABASE_URL=postgresql://usuario:<senha>@servidor.neon.tech/neondb"
expect_rc "aceita endereço com <senha> de exemplo" 0 "$secrets"

new_repo
put api/.env.example <<<'DATABASE_URL=postgresql://usuario:${DB_PASSWORD}@servidor.neon.tech/neondb'
expect_rc "aceita endereço com variável no lugar da senha" 0 "$secrets"

new_repo
put .github/ci.yml <<<"DATABASE_URL: postgres://postgres:${neon_secret}@localhost:5432/teste"
expect_rc "aceita banco local descartável (localhost)" 0 "$secrets"

new_repo
put app/lib/a.dart <<<'const dbPassword = "'"$generic_secret"'";'
expect_rc "recusa senha escrita no código" 1 "$secrets"
expect_not_in_output "não mostra a senha escrita no código" "$generic_secret"

new_repo
put app/lib/a.dart <<<'const dbPassword = "troque-por-changeme-aqui";'
expect_rc "aceita valor de exemplo (changeme)" 0 "$secrets"

new_repo
put app/lib/a.dart <<<'const dbPassword = "'"$generic_secret"'"; // secret-scan:ignore'
expect_rc "respeita secret-scan:ignore" 0 "$secrets"

new_repo
put api/.env <<<"DATABASE_URL=x"
expect_rc "recusa .env versionado" 1 "$secrets"

new_repo
put api/.env.example <<<"DATABASE_URL="
expect_rc "aceita .env.example" 0 "$secrets"

new_repo
put certificado.pem <<<"qualquer coisa"
expect_rc "recusa arquivo .pem versionado" 1 "$secrets"

new_repo
put api/test/unit/a.test.ts <<<"const u = 'postgresql://neondb_owner:segredo@ep-teste.neon.tech/neondb';"
expect_rc "teste: aceita senha curta fictícia no endereço" 0 "$secrets"

new_repo
put api/test/unit/a.test.ts <<<"const u = 'postgresql://neondb_owner:${neon_secret}@ep-teste.neon.tech/neondb';"
expect_rc "teste: recusa senha longa (parece de verdade)" 1 "$secrets"

new_repo
put api/test/unit/a.test.ts <<<'const senha = "'"$generic_secret"'";'
expect_rc "teste: aceita senha fictícia atribuída" 0 "$secrets"

new_repo
put api/test/unit/a.test.ts <<<"id = $aws_key"
expect_rc "teste: recusa chave da AWS mesmo em teste" 1 "$secrets"

new_repo
put a.txt <<<"nada"
mkdir -p build/web
echo "$pem_header" >build/web/main.js
expect_rc "pasta não versionada passa sem --extra" 0 "$secrets"
expect_rc "--extra examina a pasta não versionada" 1 "$secrets" --extra build/web

new_repo
put app/lib/a.dart <<<'const dbPassword = "'"$generic_secret"'";'
expect_rc "--high-confidence pula a regra de senha escrita" 0 "$secrets" --high-confidence

new_repo
expect_rc "opção desconhecida dá erro de uso" 2 "$secrets" --nada

echo
echo "check-coverage.sh"

lcov_file() { # arquivo, depois linhas "SF LF LH" pela entrada padrão
  local out="$1" sf lf lh
  : >"$out"
  while read -r sf lf lh; do
    printf 'SF:%s\nLF:%s\nLH:%s\nend_of_record\n' "$sf" "$lf" "$lh" >>"$out"
  done
}

new_repo
lcov_file cov.info <<'EOF'
lib/core/formatting/a.dart 10 10
lib/ui/b.dart 10 5
EOF
expect_rc "cobertura acima da meta passa" 0 "$coverage" --lcov cov.info --source-dir none --min-total 70
expect_in_output "mostra a porcentagem total" "75,0%"
expect_rc "cobertura abaixo da meta falha" 1 "$coverage" --lcov cov.info --source-dir none --min-total 80
expect_in_output "diz que ficou abaixo" "ABAIXO DA META"
COVERAGE_MIN_TOTAL=80 expect_rc "usa COVERAGE_MIN_TOTAL" 1 "$coverage" --lcov cov.info --source-dir none

new_repo
lcov_file cov.info <<'EOF'
lib/features/x/domain/m.dart 10 5
lib/ui/b.dart 90 90
EOF
expect_rc "lógica de negócio abaixo da meta falha" 1 "$coverage" --lcov cov.info --source-dir none --min-total 50 --min-logic 90
expect_in_output "aponta a lógica de negócio" "50,0%"

new_repo
lcov_file cov.info <<'EOF'
lib/a.dart 10 10
lib/a.g.dart 100 0
EOF
expect_rc "código gerado não conta" 0 "$coverage" --lcov cov.info --source-dir none --min-total 99

new_repo
lcov_file cov.info <<'EOF'
lib/a.dart 10 10
EOF
mkdir -p lib/features/y/domain
printf 'int f() {\n  return 1;\n}\n' >lib/features/y/domain/z.dart
expect_rc "arquivo que nenhum teste carregou conta como 0%" 1 "$coverage" --lcov cov.info --min-total 95
expect_in_output "lista o arquivo sem teste" "lib/features/y/domain/z.dart"

new_repo
lcov_file cov.info <<'EOF'
lib/a.dart 10 10
EOF
mkdir -p lib
printf "abstract final class Cores {\n  static const int azul = 1;\n}\n" >lib/cores.dart
expect_rc "arquivo só de constantes não atrapalha" 0 "$coverage" --lcov cov.info --min-total 95

new_repo
expect_rc "sem arquivo lcov dá erro de uso" 2 "$coverage" --lcov nao-existe.info

echo
echo "check-policy.sh"

new_repo
put app/lib/a.dart <<<"void main() {}"
put api/src/a.ts <<<"export const ok = 1;"
expect_rc "código limpo passa" 0 "$policy"

new_repo
put app/lib/a.dart <<<"const url = 'https://api.exemplo.com';"
expect_rc "app: recusa endereço fixo" 1 "$policy"

new_repo
put app/lib/a.dart <<<"/// Exemplo: http://localhost:8080"
expect_rc "app: aceita endereço em comentário" 0 "$policy"

new_repo
put app/lib/a.dart <<<"const url = 'https://x.com'; // policy-ignore: página de ajuda"
expect_rc "respeita policy-ignore" 0 "$policy"

new_repo
put app/lib/a.dart <<<"void f() { print('oi'); }"
expect_rc "app: recusa print" 1 "$policy"

new_repo
put app/lib/a.dart <<<"void f(dynamic e) { e.innerHTML = valor; }"
expect_rc "app: recusa innerHTML" 1 "$policy"

new_repo
put api/src/a.ts <<<'const q = `SELECT * FROM quadras WHERE id = ${id}`;'
expect_rc "api: recusa SQL com \${...}" 1 "$policy"

new_repo
put api/src/a.ts <<<"const q = 'SELECT * FROM quadras WHERE id = ' + id;"
expect_rc "api: recusa SQL concatenado" 1 "$policy"

new_repo
put api/src/a.ts <<<"const q = 'SELECT * FROM quadras WHERE id = \$1';"
expect_rc "api: aceita SQL com parâmetros" 0 "$policy"

new_repo
put api/src/a.ts <<<"const codigo = Math.random().toString(36);"
expect_rc "api: recusa Math.random" 1 "$policy"

new_repo
put api/src/a.ts <<<"app.register(cors, { origin: '*' });"
expect_rc "api: recusa CORS aberto" 1 "$policy"

new_repo
put api/src/a.ts <<<"const ssl = { rejectUnauthorized: false };"
expect_rc "api: recusa TLS desligado" 1 "$policy"

new_repo
put api/src/a.ts <<<"eval(texto);"
expect_rc "api: recusa eval" 1 "$policy"

new_repo
put api/src/a.ts <<<"console.log(password);"
expect_rc "api: recusa log da senha" 1 "$policy"

new_repo
put api/src/a.ts <<<'console.log(`cliente ${phone}`);'
expect_rc "api: recusa telefone dentro de texto com \${...}" 1 "$policy"

new_repo
put api/src/a.ts <<<"console.error('Defina DATABASE_URL para rodar o seed.');"
expect_rc "api: aceita log que só cita o NOME da variável" 0 "$policy"

new_repo
put api/src/a.ts <<<"const r = await migrate({ databaseUrl, log: (m) => console.log(m) });"
expect_rc "api: aceita dado sensível fora da chamada do console" 0 "$policy"

new_repo
put api/src/a.test.ts <<<"const x = Math.random();"
put api/src/b.ts <<<"export const ok = 1;"
expect_rc "arquivos de teste são ignorados" 0 "$policy"

echo
printf 'Resultado: %d ok, %d com falha.\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
