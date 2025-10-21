tmux_start() {
    # Argument 1: tmux session name (optional)
    local session_name="${1:-}"

    # If no name is given, auto-generate one
    if [[ -z "$session_name" ]]; then
        session_name="session_$(date +%H%M%S)"
        echo "No session name provided. Using auto-generated name: $session_name"
    fi

    # Check if the session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo "Session '$session_name' already exists. Attaching..."
        tmux attach -t "$session_name"
        return
    fi

    echo "Creating new tmux session: $session_name"

    # Use your current login shell (not hardcoded bash)
    local shell="${SHELL:-/bin/bash}"

    # Create a new detached session using the default shell
    tmux new-session -d -s "$session_name" "$shell"

    # Create a 2x2 pane layout
    tmux split-window -h -t "$session_name":0
    tmux split-window -v -t "$session_name":0.0
    tmux select-pane -t "$session_name":0.1
    tmux split-window -v -t "$session_name":0.1
    tmux select-layout -t "$session_name":0 tiled

    # Attach to the session
    tmux attach -t "$session_name"
}
