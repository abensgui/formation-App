#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#   Formation App — Script de lancement
#   Mini-Projet DevOps · EST Salé
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

banner() {
  echo -e "${CYAN}"
  echo "  ███████╗ ██████╗ ██████╗ ███╗   ███╗ █████╗ ████████╗██╗ ██████╗ ███╗  "
  echo "  ██╔════╝██╔═══██╗██╔══██╗████╗ ████║██╔══██╗╚══██╔══╝██║██╔═══██╗████╗ "
  echo "  █████╗  ██║   ██║██████╔╝██╔████╔██║███████║   ██║   ██║██║   ██║██╔██╗"
  echo "  ██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║██╔══██║   ██║   ██║██║   ██║██║╚██"
  echo "  ██║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║  ██║   ██║   ██║╚██████╔╝██║ ╚█"
  echo "  ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  "
  echo -e "${NC}"
  echo -e "  ${BOLD}Mini-Projet DevOps — EST Salé · Université Mohammed V${NC}\n"
}

check_docker() {
  command -v docker >/dev/null 2>&1    || err "Docker non trouvé → https://docs.docker.com/get-docker/"
  docker info >/dev/null 2>&1          || err "Docker daemon non démarré → lance Docker Desktop"
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 \
    || err "Docker Compose non trouvé"
  ok "Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
  ok "Docker Compose $(docker compose version --short)"
}

# ── MODE 1: Docker seul ─────────────────────────────────────────────
run_docker() {
  echo -e "\n${BOLD}Mode: Docker simple${NC}\n"
  log "Build de l'image..."
  docker build -t formation-app:latest . || err "Échec du build"
  ok "Image formation-app:latest construite"

  # Arrêter si déjà lancé
  docker rm -f formation-app 2>/dev/null && log "Conteneur précédent supprimé" || true

  log "Lancement du conteneur..."
  docker run -d \
    --name formation-app \
    -p 3000:5000 \
    -v formation_data:/data \
    --restart unless-stopped \
    formation-app:latest
  ok "Conteneur démarré"

  wait_app "http://localhost:3000"
  echo -e "\n${GREEN}${BOLD}✓ Application disponible sur: http://localhost:3000${NC}\n"
}

# ── MODE 2: Docker Compose complet ─────────────────────────────────
run_compose() {
  echo -e "\n${BOLD}Mode: Docker Compose (app + nginx + db + adminer)${NC}\n"
  log "Build et lancement..."
  docker compose up -d --build
  ok "Tous les services lancés"

  wait_app "http://localhost:3000"

  echo ""
  echo -e "${GREEN}${BOLD}✓ Services disponibles:${NC}"
  echo -e "  🌐  Application  →  ${CYAN}http://localhost:3000${NC}   (Flask direct)"
  echo -e "  🔀  Via Nginx    →  ${CYAN}http://localhost:80${NC}    (reverse proxy)"
  echo -e "  🗃️   Adminer DB  →  ${CYAN}http://localhost:8080${NC}  (PostgreSQL UI)"
  echo ""
}

# ── MODE 3: Dev local (sans Docker) ────────────────────────────────
run_local() {
  echo -e "\n${BOLD}Mode: Développement local (Python)${NC}\n"
  command -v python3 >/dev/null 2>&1 || err "Python3 non trouvé"

  if [ ! -d "venv" ]; then
    log "Création du virtualenv..."
    python3 -m venv venv
  fi
  source venv/bin/activate
  log "Installation des dépendances..."
  pip install -q -r app/requirements.txt
  ok "Dépendances installées"

  log "Lancement de Flask en mode dev..."
  export FLASK_ENV=development
  export DB_PATH=/tmp/formations_dev.db
  cd app && python app.py &
  APP_PID=$!
  echo "$APP_PID" > /tmp/formation-app.pid

  wait_app "http://localhost:5000"
  echo -e "\n${GREEN}${BOLD}✓ App dev sur: http://localhost:5000${NC}"
  echo -e "  PID: $APP_PID  (./run.sh stop pour arrêter)\n"
}

# ── Attendre que l'app réponde ──────────────────────────────────────
wait_app() {
  local url="$1"
  local max=30
  log "Attente du démarrage de l'application..."
  for i in $(seq 1 $max); do
    if curl -sf "$url/health" >/dev/null 2>&1; then
      ok "Application opérationnelle (${i}s)"
      return
    fi
    echo -ne "\r  ⏳ ${i}/${max}s..."
    sleep 1
  done
  echo ""
  warn "L'app prend du temps — vérifie avec: docker logs formation-app"
}

# ── Commandes utilitaires ──────────────────────────────────────────
cmd_stop() {
  log "Arrêt des services..."
  docker compose down 2>/dev/null && ok "Docker Compose arrêté" || true
  docker rm -f formation-app 2>/dev/null && ok "Conteneur Docker arrêté" || true
  [ -f /tmp/formation-app.pid ] && kill "$(cat /tmp/formation-app.pid)" 2>/dev/null \
    && ok "Flask local arrêté" && rm -f /tmp/formation-app.pid || true
}

cmd_logs() {
  docker compose logs -f 2>/dev/null || docker logs -f formation-app
}

cmd_status() {
  echo -e "\n${BOLD}Conteneurs en cours:${NC}"
  docker compose ps 2>/dev/null || docker ps --filter name=formation
}

cmd_clean() {
  warn "Suppression de tout (conteneurs + images + volumes)..."
  docker compose down -v --rmi all 2>/dev/null || true
  docker rm -f formation-app 2>/dev/null || true
  docker rmi formation-app:latest 2>/dev/null || true
  docker volume rm formation_data 2>/dev/null || true
  ok "Nettoyage terminé"
}

cmd_help() {
  echo -e "${BOLD}Usage:${NC} ./run.sh [commande]"
  echo ""
  echo -e "${BOLD}Commandes de lancement:${NC}"
  echo "  (aucune) / compose   Docker Compose complet (app+nginx+db+adminer)"
  echo "  docker               Docker simple (app seule, port 3000)"
  echo "  local                Lancement Python local sans Docker"
  echo ""
  echo -e "${BOLD}Gestion:${NC}"
  echo "  stop     Arrêter tous les services"
  echo "  logs     Voir les logs en temps réel"
  echo "  status   État des conteneurs"
  echo "  clean    Tout supprimer (images + volumes)"
  echo "  help     Afficher cette aide"
  echo ""
  echo -e "${BOLD}Exemples:${NC}"
  echo "  ./run.sh              # Lance tout avec Docker Compose"
  echo "  ./run.sh docker       # Lance avec Docker simple"
  echo "  ./run.sh local        # Lance Flask sans Docker"
  echo "  ./run.sh stop         # Arrête tout"
  echo "  ./run.sh logs         # Voir les logs"
}

# ═══════════════════════════════════════════════════════════════════
banner

case "${1:-compose}" in
  compose|"")  check_docker; run_compose ;;
  docker)      check_docker; run_docker  ;;
  local)       run_local ;;
  stop)        cmd_stop   ;;
  logs)        cmd_logs   ;;
  status)      cmd_status ;;
  clean)       cmd_clean  ;;
  help|-h)     cmd_help   ;;
  *)           err "Commande inconnue: $1  →  ./run.sh help" ;;
esac
