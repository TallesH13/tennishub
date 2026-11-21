#!/usr/bin/env bash
# Rotina de qualidade e segurança do TennisHub. Roda no seu computador e no CI
# com os mesmos comandos, para o resultado ser o mesmo nos dois lugares.
#
# Uso: .github/scripts/quality.sh [alvo] [opções]
#
# Alvos:
#   all      tudo (padrão)
#   scripts  só os testes dos scripts desta rotina
#   repo     scripts, segredos e políticas do código
#   app      repo + app Flutter (formatação, análise, testes, cobertura)
#   api      repo + API Node.js (tipos, lint, testes, auditoria de dependências)
#
# Opções:
#   --with-build  também compila o app (flutter build web) e procura segredos no resultado
#   --install     roda "npm ci" na API antes de verificar
#   --only        nos alvos app e api, não repete as verificações do repositório
#
# Variáveis:
#   COVERAGE_MIN_TOTAL, COVERAGE_MIN_LOGIC   metas de cobertura (padrão 85 e 90)
#   TEST_DATABASE_URL                        se definida, roda também os testes de integração da API
#   AUDIT_FAIL_ON_DEV=1                      falha também com vulnerabilidade crítica em ferramenta
#                                            de desenvolvimento (por padrão, só avisa)
#
# Cada passo termina em: ok, AVISO (não bloqueia) ou FALHA. O código de saída é 1
# se algum passo falhar.
set -u

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git rev-parse --show-toplevel)" || exit 2
cd "$root" || exit 2

target="all"
with_build=0
install_api=0
only=0
for arg in "$@"; do
  case "$arg" in
    all | scripts | repo | app | api) target="$arg" ;;
    --with-build) with_build=1 ;;
    --install) install_api=1 ;;
    --only) only=1 ;;
    -h | --help)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $arg (use --help)" >&2
      exit 2
      ;;
  esac
done

summary=()
failures=0
warnings=0

# run_step "nome" comando...
# O comando devolve 0 (ok), 3 (aviso) ou outro código (falha).
run_step() {
  local name="$1"
  shift
  local started=$SECONDS rc output
  printf '▶ %s\n' "$name"
  # A saída vai por pipe (e não para um arquivo): o flutter instalado por snap
  # falha em silêncio quando a saída é redirecionada para arquivo.
  output="$("$@" 2>&1)"
  rc=$?
  local elapsed=$((SECONDS - started))

  case "$rc" in
    0)
      summary+=("ok     ${name} (${elapsed}s)")
      printf '  ok (%ss)\n' "$elapsed"
      ;;
    3)
      warnings=$((warnings + 1))
      summary+=("AVISO  ${name} (${elapsed}s)")
      printf '  AVISO (%ss)\n' "$elapsed"
      printf '%s\n' "$output" | sed 's/^/    /' | tail -n 30
      ;;
    *)
      failures=$((failures + 1))
      summary+=("FALHA  ${name} (${elapsed}s)")
      printf '  FALHA (%ss)\n' "$elapsed"
      printf '%s\n' "$output" | sed 's/^/    /' | tail -n 40
      ;;
  esac
}

need() { # ferramenta
  command -v "$1" >/dev/null 2>&1 || {
    echo "Ferramenta não encontrada: $1. Instale-a para rodar este passo."
    return 1
  }
}

# --- passos do repositório -----------------------------------------------------
step_script_tests() { "$scripts_dir/tests/run-tests.sh"; }
step_secrets() { "$scripts_dir/check-secrets.sh"; }
step_policy() { "$scripts_dir/check-policy.sh"; }

# --- passos do app ---------------------------------------------------------------
step_app_pub_get() { need flutter && (cd app && flutter pub get); }
step_app_format() { need dart && (cd app && dart format --output=none --set-exit-if-changed .); }
step_app_analyze() { need flutter && (cd app && flutter analyze); }
step_app_test() { need flutter && (cd app && flutter test --coverage); }
step_app_coverage() { (cd app && "$scripts_dir/check-coverage.sh"); }
step_app_build() { need flutter && (cd app && flutter build web --release); }
step_app_build_secrets() { "$scripts_dir/check-secrets.sh" --extra app/build/web --high-confidence; }

step_app_outdated() {
  need dart || return 1
  need jq || return 1
  local json list
  # O relatório em JSON sempre inclui as transitivas; o filtro abaixo fica só com as diretas.
  json="$(cd app && dart pub outdated --json 2>&1)" || {
    echo "$json"
    return 1
  }
  list="$(jq -r '.packages[]
      | select((.kind == "direct" or .kind == "dev") and .current != null and .latest != null and .current.version != .latest.version)
      | "  \(.package): \(.current.version) -> \(.latest.version)"' <<<"$json")" || return 1
  if [[ -n "$list" ]]; then
    echo "Dependências diretas com versão mais nova disponível:"
    echo "$list"
    return 3
  fi
  echo "Dependências diretas em dia."
}

# --- passos da API -----------------------------------------------------------------
step_api_install() { need npm && (cd api && npm ci); }

# Os passos que rodam ferramentas da API precisam das dependências instaladas.
api_deps() {
  need npm || return 1
  if [[ ! -d api/node_modules ]]; then
    echo "As dependências da API não estão instaladas."
    echo "Rode: cd api && npm ci   (ou use a opção --install)"
    return 1
  fi
}
step_api_typecheck() { api_deps && (cd api && npm run typecheck --if-present); }
step_api_lint() { api_deps && (cd api && npm run lint --if-present); }
step_api_unit() { api_deps && (cd api && npm run test:unit --if-present); }
step_api_integration() { api_deps && (cd api && npm run test:integration); }
step_api_audit_prod() { need npm && (cd api && npm audit --omit=dev --audit-level=high); }

step_api_audit_dev() {
  need npm || return 1
  local rc
  (cd api && npm audit --audit-level=critical)
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo
    echo "Há vulnerabilidade crítica em ferramenta de desenvolvimento (não vai para produção)."
    echo "Atualize a dependência indicada acima."
    [[ "${AUDIT_FAIL_ON_DEV:-0}" == "1" ]] && return 1
    return 3
  fi
}

want_repo=0
want_app=0
want_api=0
case "$target" in
  scripts) want_repo=1 ;;
  repo) want_repo=1 ;;
  app) want_repo=1 want_app=1 ;;
  api) want_repo=1 want_api=1 ;;
  all) want_repo=1 want_app=1 want_api=1 ;;
esac

if [[ "$only" -eq 0 || "$target" == "scripts" || "$target" == "repo" || "$target" == "all" ]]; then
  run_step "Testes dos scripts da rotina" step_script_tests
fi
if [[ "$target" != "scripts" && ( "$only" -eq 0 || "$target" == "repo" || "$target" == "all" ) ]]; then
  run_step "Segredos no repositório" step_secrets
  run_step "Políticas do código (RNF05, RNF07)" step_policy
fi

if [[ "$want_app" -eq 1 ]]; then
  if [[ -f app/pubspec.yaml ]]; then
    run_step "App: dependências" step_app_pub_get
    run_step "App: formatação" step_app_format
    run_step "App: análise estática" step_app_analyze
    run_step "App: testes com cobertura" step_app_test
    run_step "App: cobertura mínima" step_app_coverage
    run_step "App: dependências desatualizadas" step_app_outdated
    if [[ "$with_build" -eq 1 ]]; then
      run_step "App: build web" step_app_build
      run_step "App: segredos no resultado do build" step_app_build_secrets
    fi
  else
    summary+=("pulado App (app/pubspec.yaml não existe)")
  fi
fi

if [[ "$want_api" -eq 1 ]]; then
  if [[ -f api/package.json ]]; then
    [[ "$install_api" -eq 1 ]] && run_step "API: instalar dependências (npm ci)" step_api_install
    run_step "API: tipos (TypeScript)" step_api_typecheck
    run_step "API: lint" step_api_lint
    run_step "API: testes de unidade" step_api_unit
    if [[ -n "${TEST_DATABASE_URL:-}" ]]; then
      run_step "API: testes de integração" step_api_integration
    else
      summary+=("pulado API: testes de integração (defina TEST_DATABASE_URL)")
    fi
    run_step "API: auditoria de dependências de produção" step_api_audit_prod
    run_step "API: auditoria das ferramentas de desenvolvimento" step_api_audit_dev
  else
    summary+=("pulado API (api/package.json não existe)")
  fi
fi

echo
echo "==== Resumo ===="
printf '%s\n' "${summary[@]}"
echo "================="

# No GitHub Actions, mostra o resumo também na página da execução.
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Qualidade e segurança (${target})"
    echo
    echo '```'
    printf '%s\n' "${summary[@]}"
    echo '```'
  } >>"$GITHUB_STEP_SUMMARY"
fi
if [[ "$failures" -gt 0 ]]; then
  echo "Resultado: $failures falha(s), $warnings aviso(s)."
  exit 1
fi
echo "Resultado: tudo certo ($warnings aviso(s))."
