#!/bin/bash
# Docker Compose wrapper that ensures prerequisites are met before starting services
# Usage: ./docker-compose-wrapper.sh up -d
#        ./docker-compose-wrapper.sh down
#        ./docker-compose-wrapper.sh [any docker-compose command]

set -e

# Get the data directory from environment or use default
DATA_DIR="${DATA_DIR:-./data}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to ensure directories exist
ensure_directories() {
    echo "📁 Ensuring data directories exist in: $DATA_DIR"
    mkdir -p "$DATA_DIR/logs" "$DATA_DIR/uploads" "$DATA_DIR/config"
    echo "   ${GREEN}✅ All data directories ready${NC}"
}

# Function to validate .env file
validate_env() {
    if [ ! -f .env ]; then
        echo -e "${RED}❌ ERROR: .env file not found${NC}"
        echo "Please create .env with required configuration."
        exit 1
    fi

    # Source .env to get values (with error handling)
    set -a
    source .env
    set +a

    echo "🔍 Validating .env configuration..."

    # Check for placeholder values
    PLACEHOLDERS=(
        "your_secure_postgres_password"
        "your_secure_redis_password"
        "CHANGE_THIS"
    )

    for placeholder in "${PLACEHOLDERS[@]}"; do
        if grep -q "$placeholder" .env 2>/dev/null; then
            echo -e "${RED}   ❌ Found placeholder '$placeholder' in .env${NC}"
            echo -e "${YELLOW}   ⚠️  Please edit .env and replace all placeholder values${NC}"
            exit 1
        fi
    done

    # Validate secret lengths only if variables are set
    if [ -n "$SESSION_SECRET" ] && [ ${#SESSION_SECRET} -lt 32 ]; then
        echo -e "${RED}   ❌ SESSION_SECRET must be at least 32 characters (got ${#SESSION_SECRET})${NC}"
        exit 1
    fi

    if [ -n "$JWT_SECRET" ] && [ ${#JWT_SECRET} -lt 32 ]; then
        echo -e "${RED}   ❌ JWT_SECRET must be at least 32 characters (got ${#JWT_SECRET})${NC}"
        exit 1
    fi

    if [ -n "$ADMIN_PASSWORD" ] && [ ${#ADMIN_PASSWORD} -lt 12 ]; then
        echo -e "${RED}   ❌ ADMIN_PASSWORD must be at least 12 characters (got ${#ADMIN_PASSWORD})${NC}"
        exit 1
    fi

    if [ -n "$POSTGRES_PASSWORD" ] && [ ${#POSTGRES_PASSWORD} -lt 12 ]; then
        echo -e "${RED}   ❌ POSTGRES_PASSWORD must be at least 12 characters${NC}"
        exit 1
    fi

    echo -e "   ${GREEN}✅ Environment validation passed${NC}"
}

# Show deployment info
show_info() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Contexus IoT Platform"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  🔑 Default Admin Credentials:"
    echo "     Username: iotevadmin"
    echo "     Password: (from ADMIN_PASSWORD in .env)"
    echo ""
    echo "  🌐 Access the app at: http://localhost:15000"
    echo ""
    echo "  📋 Useful Commands:"
    echo "     docker-compose logs -f contexus   # View app logs"
    echo "     docker-compose ps                 # Check status"
    echo "     ./docker-compose-wrapper.sh down -v # Stop and remove data"
    echo ""
}

# Main execution
case "$1" in
    up|start|restart)
        ensure_directories
        validate_env
        ;;
    down)
        ;;
    *)
        # For other commands (ps, logs, etc.), skip validation
        ;;
esac

# Pass all arguments to docker-compose
docker-compose "$@"

# Show info after successful 'up' command
if [[ "$1" == "up" ]] && [[ "$2" == "-d" ]]; then
    show_info
fi
