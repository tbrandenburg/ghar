#!/usr/bin/env bash
set -euo pipefail

VERBOSE=${VERBOSE:-false}
DRY_RUN=${DRY_RUN:-false}

usage() {
  echo "Usage: run-opencode-sandbox.sh [OPTIONS]"
  echo
  echo "Run OpenCode in a sandboxed environment."
  echo "Creates a temporary clone of the repository to prevent any changes"
  echo "from affecting your working directory."
  echo
  echo "Options:"
  echo "  --run-name NAME       Name for the run (default: opencode-run)"
  echo "  --command CMD         Command to execute"
  echo "  --prompt TEXT         Prompt text to send to OpenCode"
  echo "  --prompt-file FILE    File containing the prompt"
  echo "  --model MODEL         Model to use (default: claude-sonnet-4)"
  echo "  --agent AGENT         Agent to use"
  echo "  --help               Show this help message"
  echo
  echo "Environment Variables:"
  echo "  VERBOSE=true      Show detailed output including clone progress"
  echo "  DRY_RUN=true      Show what would be executed without running"
  echo "  GH_TOKEN          GitHub token (will use 'gh auth token' if not set)"
  echo
  echo "Examples:"
  echo "  run-opencode-sandbox.sh --command 'fix-tests' --model 'claude-sonnet-4'"
  echo "  run-opencode-sandbox.sh --prompt 'Add unit tests' --agent 'test-writer'"
  echo "  run-opencode-sandbox.sh --prompt-file 'prompts/refactor.txt'"
  echo "  VERBOSE=true run-opencode-sandbox.sh --command 'lint-fix'"
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    echo "Please install $1 to continue." >&2
    exit 1
  fi
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
      echo "Cleaning up temporary directory: $TMP_DIR"
    fi
    rm -rf "$TMP_DIR"
  fi
}

log() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "$@"
  fi
}

# Parse command line arguments
RUN_NAME="opencode-run"
COMMAND=""
PROMPT=""
PROMPT_FILE=""
MODEL="claude-sonnet-4"
AGENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --run-name)
      RUN_NAME="$2"
      shift 2
      ;;
    --command)
      COMMAND="$2"
      shift 2
      ;;
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --prompt-file)
      PROMPT_FILE="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --agent)
      AGENT="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      echo "Error: Unknown option $1" >&2
      usage
      ;;
  esac
done

# Validate that at least one of command, prompt, or prompt-file is provided
if [[ -z "$COMMAND" && -z "$PROMPT" && -z "$PROMPT_FILE" ]]; then
  echo "Error: At least one of '--command', '--prompt', or '--prompt-file' must be provided" >&2
  usage
fi

# Check required commands
require_cmd git
require_cmd opencode
require_cmd gh

# Validate we're in a git repository
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository."
  echo "Please run this script from within a git repository."
  exit 1
}

# Get and validate GitHub token
if [[ -z "${GH_TOKEN:-}" ]]; then
  if ! GH_TOKEN="$(gh auth token 2>/dev/null)"; then
    echo "Error: failed to obtain GitHub token."
    echo "Please authenticate with GitHub: gh auth login"
    echo "Or set the GH_TOKEN environment variable."
    exit 1
  fi
fi

if [[ -z "$GH_TOKEN" ]]; then
  echo "Error: GitHub token is empty."
  echo "Please authenticate with GitHub: gh auth login"
  echo "Or set the GH_TOKEN environment variable."
  exit 1
fi

# Extract repository information from git remote
REPO_URL="$(git remote get-url origin 2>/dev/null || echo "")"
if [[ "$REPO_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
  REPO_OWNER="${BASH_REMATCH[1]}"
  REPO_NAME="${BASH_REMATCH[2]}"
  GITHUB_REPOSITORY="$REPO_OWNER/$REPO_NAME"
else
  echo "Warning: Could not extract GitHub repository info from remote URL: $REPO_URL"
  echo "Some OpenCode features may not work correctly."
  GITHUB_REPOSITORY=""
fi

log "Detected repository: $GITHUB_REPOSITORY"

# Validate prompt file exists if specified
if [[ -n "$PROMPT_FILE" && ! -f "$PROMPT_FILE" ]]; then
  echo "Error: prompt file not found: $PROMPT_FILE"
  exit 1
fi

# Create temporary directory with cleanup trap
TMP_DIR="$(mktemp -d)"
trap cleanup EXIT

CLONE_DIR="$TMP_DIR/repo"

# Handle dry run mode
if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY RUN MODE - No actual execution"
  echo ""
  echo "Would execute:"
  echo "  Repository: $REPO_ROOT"
  echo "  Temporary clone: $CLONE_DIR"
  echo "  Run name: $RUN_NAME"
  echo "  Model: $MODEL"
  [[ -n "$AGENT" ]] && echo "  Agent: $AGENT"
  [[ -n "$COMMAND" ]] && echo "  Command: $COMMAND"
  [[ -n "$PROMPT" ]] && echo "  Prompt: $PROMPT"
  [[ -n "$PROMPT_FILE" ]] && echo "  Prompt file: $PROMPT_FILE"
  echo "  Output: $RUN_NAME-results.txt"
  echo ""
  echo "To run for real, execute without DRY_RUN=true"
  exit 0
fi

echo "Creating clean repository clone..."
log "Cloning $REPO_ROOT to $CLONE_DIR"

if [[ "$VERBOSE" == "true" ]]; then
  git clone "$REPO_ROOT" "$CLONE_DIR"
else
  git clone "$REPO_ROOT" "$CLONE_DIR" >/dev/null 2>&1
fi

cd "$CLONE_DIR"

# Fix git remote to point to GitHub instead of local path
if [[ -n "$GITHUB_REPOSITORY" && -n "$REPO_URL" ]]; then
  log "Setting git remote to GitHub URL: $REPO_URL"
  git remote set-url origin "$REPO_URL"
  
  # Verify the remote was set correctly
  if [[ "$VERBOSE" == "true" ]]; then
    echo "Git remote after update:"
    git remote -v
  fi
fi

echo
echo "Running OpenCode in sandboxed environment:"
echo "  📁 Repository: $(basename "$REPO_ROOT")"
echo "  🤖 Run name:   $RUN_NAME"
echo "  🧠 Model:      $MODEL"
[[ -n "$AGENT" ]] && echo "  🎭 Agent:      $AGENT"
[[ -n "$COMMAND" ]] && echo "  ⚡ Command:    $COMMAND"
[[ -n "$PROMPT" ]] && echo "  💭 Prompt:     ${PROMPT:0:50}${PROMPT:50:+...}"
[[ -n "$PROMPT_FILE" ]] && echo "  📄 Prompt file: $PROMPT_FILE"
echo "  🏠 Sandbox:    $CLONE_DIR"
if [[ -n "$GITHUB_REPOSITORY" ]]; then
  echo "  📋 GitHub:     $GITHUB_REPOSITORY"
fi
echo "  📝 Output:     $RUN_NAME-results.txt"
echo

log "Preparing OpenCode execution"

# Build the OpenCode command arguments
OPENCODE_ARGS=("run")
[[ -n "$MODEL" ]] && OPENCODE_ARGS+=("--model" "$MODEL")
[[ -n "$AGENT" ]] && OPENCODE_ARGS+=("--agent" "$AGENT")
[[ -n "$COMMAND" ]] && OPENCODE_ARGS+=("--command" "$COMMAND")

# Prepare environment for OpenCode
ENV_CLEAN=("env" "-i")
ENV_CLEAN+=("PATH=$HOME/.opencode/bin:$PATH")
ENV_CLEAN+=("HOME=$HOME")
ENV_CLEAN+=("GH_TOKEN=$GH_TOKEN")

# Execute OpenCode with appropriate input handling
if [[ -n "$COMMAND" ]]; then
  if [[ -n "$PROMPT" ]]; then
    log "Running with command and prompt"
    echo "$PROMPT" | "${ENV_CLEAN[@]}" opencode "${OPENCODE_ARGS[@]}" > "$RUN_NAME-results.txt"
  elif [[ -n "$PROMPT_FILE" ]]; then
    log "Running with command and prompt file"
    PROMPT_CONTENT=$(cat "$PROMPT_FILE")
    echo "$PROMPT_CONTENT" | "${ENV_CLEAN[@]}" opencode "${OPENCODE_ARGS[@]}" > "$RUN_NAME-results.txt"
  else
    log "Running with command only"
    "${ENV_CLEAN[@]}" opencode "${OPENCODE_ARGS[@]}" > "$RUN_NAME-results.txt"
  fi
elif [[ -n "$PROMPT" ]]; then
  log "Running with prompt only"
  echo "$PROMPT" | "${ENV_CLEAN[@]}" opencode "${OPENCODE_ARGS[@]}" > "$RUN_NAME-results.txt"
elif [[ -n "$PROMPT_FILE" ]]; then
  log "Running with prompt file only"
  PROMPT_CONTENT=$(cat "$PROMPT_FILE")
  echo "$PROMPT_CONTENT" | "${ENV_CLEAN[@]}" opencode "${OPENCODE_ARGS[@]}" > "$RUN_NAME-results.txt"
else
  echo "Error: At least one of 'command', 'prompt', or 'prompt-file' must be provided" >&2
  exit 1
fi

echo
echo "✅ OpenCode execution completed successfully!"
echo "📄 Results saved to: $RUN_NAME-results.txt"
echo "💡 All changes were isolated to the temporary clone and have been cleaned up."

# Copy results back to original directory
if [[ -f "$RUN_NAME-results.txt" ]]; then
  cp "$RUN_NAME-results.txt" "$REPO_ROOT/"
  echo "📋 Results copied back to: $REPO_ROOT/$RUN_NAME-results.txt"
fi