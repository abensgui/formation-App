#!/usr/bin/env bash
# =============================================================
#  run-tests.sh — App + Tests Cucumber/Playwright + Allure
# =============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET} $*"; }
header()  {
  echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
  echo -e "${BOLD}${CYAN}  $*${RESET}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}\n"
}

# ── Répertoires ───────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
ALLURE_RESULTS="$TESTS_DIR/allure-results"
ALLURE_REPORT="$TESTS_DIR/allure-report"
APP_URL="${APP_URL:-http://localhost:3000}"

# ── Options ───────────────────────────────────────────────────
OPEN_REPORT=false
SKIP_APP=false

for arg in "$@"; do
  case $arg in
    --open)     OPEN_REPORT=true ;;
    --skip-app) SKIP_APP=true ;;
    --help|-h)
      echo "Usage: $0 [--open] [--skip-app]"
      echo "  --open      Ouvrir le rapport Allure après les tests"
      echo "  --skip-app  Ne pas gérer Docker (app déjà lancée)"
      exit 0 ;;
  esac
done

cleanup() {
  if [ "$SKIP_APP" = false ]; then
    info "Arrêt des conteneurs Docker..."
    cd "$PROJECT_DIR" && docker compose down -v --remove-orphans 2>/dev/null || true
  fi
}
trap cleanup EXIT

# =============================================================
header "1/5 — Vérification des dépendances"
# =============================================================

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    error "$1 introuvable. $2"; exit 1
  fi
  success "$1 → $(command -v "$1")"
}

check_cmd docker "Installer Docker : https://docs.docker.com/get-docker/"
check_cmd node   "Installer Node.js : https://nodejs.org/"
check_cmd npm    "npm est inclus avec Node.js"

# Détection allure (node_modules en priorité → évite les problèmes de PATH)
ALLURE_BIN=""
if [ -f "$TESTS_DIR/node_modules/.bin/allure" ]; then
  ALLURE_BIN="$TESTS_DIR/node_modules/.bin/allure"
  success "allure → node_modules/.bin/allure"
elif command -v allure &>/dev/null; then
  ALLURE_BIN="allure"
  success "allure → $(command -v allure)"
else
  warn "allure CLI absent — rapport HTML ignoré"
  warn "Pour l'installer : npm install -g allure-commandline"
fi

# =============================================================
header "2/5 — Installation des dépendances Node.js"
# =============================================================

cd "$TESTS_DIR"

if [ ! -d node_modules ]; then
  info "npm install..."
  npm install
else
  info "node_modules présent — skip install"
fi

# Re-check allure dans node_modules après install
if [ -z "$ALLURE_BIN" ] && [ -f "$TESTS_DIR/node_modules/.bin/allure" ]; then
  ALLURE_BIN="$TESTS_DIR/node_modules/.bin/allure"
fi

info "Installation des navigateurs Playwright (chromium)..."
npx playwright install chromium --with-deps 2>/dev/null || npx playwright install chromium
success "Dépendances Node.js OK"

# =============================================================
header "3/5 — Démarrage de l'application"
# =============================================================

if [ "$SKIP_APP" = false ]; then
  cd "$PROJECT_DIR"
  info "Build + démarrage Docker Compose..."
  docker compose up -d --build app

  info "Attente que l'app réponde sur $APP_URL ..."
  RETRY=0
  until curl -sf "$APP_URL/health" >/dev/null 2>&1; do
    RETRY=$((RETRY + 1))
    [ $RETRY -ge 24 ] && { error "Timeout — app non joignable"; docker compose logs app; exit 1; }
    printf "."
    sleep 5
  done
  echo ""
  success "Application prête ✓"
else
  warn "--skip-app : vérification que l'app est déjà lancée..."
  curl -sf "$APP_URL/health" >/dev/null 2>&1 || { error "App non joignable sur $APP_URL"; exit 1; }
  success "App détectée ✓"
fi

# =============================================================
header "4/5 — Exécution des tests Cucumber + Playwright"
# =============================================================

cd "$TESTS_DIR"
rm -rf "$ALLURE_RESULTS" && mkdir -p "$ALLURE_RESULTS"

info "Lancement de Cucumber.js..."
echo ""

TESTS_OK=true
APP_URL="$APP_URL" npx cucumber-js --config cucumber.config.js 2>&1 | tee /tmp/cucumber-out.txt \
  || TESTS_OK=false

echo ""

SUMMARY=$(grep -E "^[0-9]+ scenario" /tmp/cucumber-out.txt | tail -1 || true)
[ -n "$SUMMARY" ] && info "Résumé : $SUMMARY"

if [ "$TESTS_OK" = true ]; then
  success "Tous les tests sont passés ✓"
else
  warn "Des tests ont échoué — voir le rapport Allure"
fi

# =============================================================
header "5/5 — Génération du rapport Allure"
# =============================================================

if [ -n "$ALLURE_BIN" ]; then
  rm -rf "$ALLURE_REPORT"
  info "Génération du rapport HTML Allure..."
  "$ALLURE_BIN" generate "$ALLURE_RESULTS" --clean -o "$ALLURE_REPORT"
  success "Rapport généré : $ALLURE_REPORT"
  echo ""
  echo -e "  ${BOLD}Ouvrir le rapport :${RESET}"
  echo -e "  ${CYAN}$ALLURE_BIN open $ALLURE_REPORT${RESET}"
  echo -e "  ${CYAN}  — ou —${RESET}"
  echo -e "  ${CYAN}$ALLURE_BIN serve $ALLURE_RESULTS${RESET}"

  if [ "$OPEN_REPORT" = true ]; then
    info "Ouverture du rapport..."
    "$ALLURE_BIN" open "$ALLURE_REPORT"
  fi
else
  warn "Rapport HTML non généré (allure CLI absent)"
fi

# =============================================================
echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Pipeline de tests terminé !${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════${RESET}"
echo ""
echo -e "  Résultats Allure : ${CYAN}$ALLURE_RESULTS${RESET}"
echo -e "  Rapport HTML     : ${CYAN}$ALLURE_REPORT${RESET}"
echo -e "  Application      : ${CYAN}$APP_URL${RESET}"
echo ""

[ "$TESTS_OK" = true ] && exit 0 || exit 1
