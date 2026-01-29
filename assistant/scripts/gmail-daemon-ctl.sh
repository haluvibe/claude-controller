#!/bin/bash
#
# Gmail Daemon Control Script
# Control the Gmail unsubscribe daemon via launchd
#
# Usage: gmail-daemon-ctl.sh [start|stop|restart|status|install|uninstall|logs|tail]
#

set -e

# Configuration
PLIST_NAME="com.paulhayes.gmail-daemon"
PLIST_SOURCE="$(dirname "$0")/com.paulhayes.gmail-daemon.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
LOG_DIR="$HOME/Library/Logs/gmail-daemon"
DAEMON_DIR="$(dirname "$0")/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if the daemon is installed
is_installed() {
    [ -f "$PLIST_DEST" ]
}

# Check if the daemon is running
is_running() {
    launchctl list 2>/dev/null | grep -q "$PLIST_NAME"
}

# Get the PID if running
get_pid() {
    launchctl list "$PLIST_NAME" 2>/dev/null | awk 'NR==2 {print $1}'
}

# Install the daemon
cmd_install() {
    log_info "Installing Gmail Daemon..."

    # Check if source plist exists
    if [ ! -f "$PLIST_SOURCE" ]; then
        log_error "Plist file not found: $PLIST_SOURCE"
        exit 1
    fi

    # Create log directory
    mkdir -p "$LOG_DIR"
    log_success "Created log directory: $LOG_DIR"

    # Create LaunchAgents directory if needed
    mkdir -p "$HOME/Library/LaunchAgents"

    # Copy plist to LaunchAgents
    cp "$PLIST_SOURCE" "$PLIST_DEST"
    log_success "Installed plist to: $PLIST_DEST"

    # Build the TypeScript if needed
    if [ ! -f "$DAEMON_DIR/dist/index.js" ]; then
        log_info "Building TypeScript..."
        (cd "$DAEMON_DIR" && npm run build)
        log_success "Build complete"
    fi

    # Load the daemon
    launchctl load "$PLIST_DEST"
    log_success "Gmail Daemon installed and started"

    echo ""
    log_info "Logs available at:"
    echo "  stdout: $LOG_DIR/stdout.log"
    echo "  stderr: $LOG_DIR/stderr.log"
    echo "  app:    $DAEMON_DIR/config/daemon.log"
}

# Uninstall the daemon
cmd_uninstall() {
    log_info "Uninstalling Gmail Daemon..."

    if is_running; then
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
        log_success "Daemon stopped"
    fi

    if [ -f "$PLIST_DEST" ]; then
        rm "$PLIST_DEST"
        log_success "Removed plist file"
    fi

    log_success "Gmail Daemon uninstalled"
    log_info "Note: Logs preserved at $LOG_DIR"
}

# Start the daemon
cmd_start() {
    if ! is_installed; then
        log_error "Daemon not installed. Run 'install' first."
        exit 1
    fi

    if is_running; then
        log_warn "Daemon is already running"
        cmd_status
        return
    fi

    log_info "Starting Gmail Daemon..."
    launchctl load "$PLIST_DEST"
    sleep 1

    if is_running; then
        log_success "Gmail Daemon started"
        cmd_status
    else
        log_error "Failed to start daemon. Check logs for details."
        exit 1
    fi
}

# Stop the daemon
cmd_stop() {
    if ! is_running; then
        log_warn "Daemon is not running"
        return
    fi

    log_info "Stopping Gmail Daemon..."
    launchctl unload "$PLIST_DEST"
    sleep 1

    if ! is_running; then
        log_success "Gmail Daemon stopped"
    else
        log_error "Failed to stop daemon"
        exit 1
    fi
}

# Restart the daemon
cmd_restart() {
    log_info "Restarting Gmail Daemon..."
    cmd_stop || true
    sleep 2
    cmd_start
}

# Show daemon status
cmd_status() {
    echo ""
    echo "=========================================="
    echo "       Gmail Daemon Status"
    echo "=========================================="
    echo ""

    if is_installed; then
        echo -e "Installed:    ${GREEN}Yes${NC}"
        echo "Plist:        $PLIST_DEST"
    else
        echo -e "Installed:    ${RED}No${NC}"
        echo ""
        log_info "Run '$0 install' to install the daemon"
        return
    fi

    echo ""

    if is_running; then
        PID=$(get_pid)
        echo -e "Status:       ${GREEN}Running${NC}"
        echo "PID:          $PID"

        # Get exit status from launchctl
        EXIT_STATUS=$(launchctl list "$PLIST_NAME" 2>/dev/null | awk 'NR==2 {print $2}')
        if [ "$EXIT_STATUS" != "-" ] && [ -n "$EXIT_STATUS" ]; then
            echo "Last Exit:    $EXIT_STATUS"
        fi
    else
        echo -e "Status:       ${RED}Stopped${NC}"
    fi

    echo ""

    # Show daemon state if available
    STATE_FILE="$DAEMON_DIR/config/daemon-state.json"
    if [ -f "$STATE_FILE" ]; then
        echo "--- Daemon Statistics ---"
        STATS=$(cat "$STATE_FILE" | jq -r '.stats')
        LAST_CHECK=$(cat "$STATE_FILE" | jq -r '.lastCheck')
        echo "Last Check:   $LAST_CHECK"
        echo "Total:        $(echo "$STATS" | jq -r '.totalProcessed') processed"
        echo "Unsubscribed: $(echo "$STATS" | jq -r '.unsubscribed')"
        echo "Skipped:      $(echo "$STATS" | jq -r '.skipped')"
        echo "Errors:       $(echo "$STATS" | jq -r '.errors')"
    fi

    echo ""
    echo "--- Log Files ---"
    echo "stdout:       $LOG_DIR/stdout.log"
    echo "stderr:       $LOG_DIR/stderr.log"
    echo "app log:      $DAEMON_DIR/config/daemon.log"
    echo ""
}

# Show logs
cmd_logs() {
    LOG_TYPE="${1:-all}"

    case "$LOG_TYPE" in
        stdout)
            cat "$LOG_DIR/stdout.log" 2>/dev/null || echo "No stdout log found"
            ;;
        stderr)
            cat "$LOG_DIR/stderr.log" 2>/dev/null || echo "No stderr log found"
            ;;
        app)
            cat "$DAEMON_DIR/config/daemon.log" 2>/dev/null || echo "No app log found"
            ;;
        all|*)
            echo "=== Application Log ==="
            tail -50 "$DAEMON_DIR/config/daemon.log" 2>/dev/null || echo "No app log found"
            echo ""
            echo "=== Stderr Log ==="
            tail -20 "$LOG_DIR/stderr.log" 2>/dev/null || echo "No stderr log found"
            ;;
    esac
}

# Tail logs in real-time
cmd_tail() {
    LOG_FILE="$DAEMON_DIR/config/daemon.log"
    if [ -f "$LOG_FILE" ]; then
        log_info "Tailing $LOG_FILE (Ctrl+C to stop)"
        tail -f "$LOG_FILE"
    else
        log_error "Log file not found: $LOG_FILE"
        exit 1
    fi
}

# Run a single check (for testing)
cmd_run_once() {
    log_info "Running single inbox check..."
    (cd "$DAEMON_DIR" && node dist/index.js)
}

# Show help
cmd_help() {
    echo "Gmail Daemon Control Script"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  install     Install and start the daemon (runs at login)"
    echo "  uninstall   Stop and remove the daemon"
    echo "  start       Start the daemon"
    echo "  stop        Stop the daemon"
    echo "  restart     Restart the daemon"
    echo "  status      Show daemon status and statistics"
    echo "  logs        Show recent logs"
    echo "  tail        Follow logs in real-time"
    echo "  run-once    Run a single inbox check (for testing)"
    echo "  help        Show this help message"
    echo ""
    echo "Log Locations:"
    echo "  System:     $LOG_DIR/"
    echo "  App:        $DAEMON_DIR/config/daemon.log"
    echo ""
}

# Main command router
case "${1:-help}" in
    install)
        cmd_install
        ;;
    uninstall)
        cmd_uninstall
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs "$2"
        ;;
    tail)
        cmd_tail
        ;;
    run-once|runonce|once)
        cmd_run_once
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        cmd_help
        exit 1
        ;;
esac
