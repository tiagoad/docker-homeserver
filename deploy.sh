#!/bin/bash

set -e
shopt -s dotglob

# This is the main deploy script for my infrastructure.
#
# When running in ssh mode, it will open an SSH socket 
# and reuse the same connection for all commands.
#
# All the settings are configured through environment variables
#
# Usage: ./deploy <all|service1,service2> <up|down>
#
# TODO: Separate the SSH part from the deploy script to allow
#   for use in other management scripts.

: "${DDEPLOY_MODE:=ssh}" # ssh, local
: "${DDEPLOY_SSH_USER:="root"}"
: "${DDEPLOY_SSH_HOST:="omv.qqq.pt"}"
: "${DDEPLOY_SSH_PORT:="22"}"
: "${DDEPLOY_REMOTE_TMP_DIR:="/opt/compose"}"
: "${DDEPLOY_SECRETS_FILE:="secrets.env"}"
: "${DDEPLOY_ENV_FILE:="production.env"}"

: "${DDEPLOY_SETUP_FILENAME:="_setup.sh"}"

SSH_SOCK=".sshsocket"
SSH_COMMAND="ssh -S $SSH_SOCK -p $DDEPLOY_SSH_PORT"

TOOL_MODE=$2
: "${TOOL_MODE:="pretend"}"

# move to script directory
cd "$(dirname "$(realpath "$0")")"

# go to stacks dir
cd "stacks"

# help
if [ $# -eq 0 ]
then
    echo "Usage: $0 <stack,...|all> [up|down]"
    exit 1
fi

# checks if a string contains another
function contains() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# log a header to command line
function log() {
    LOG='| '$*' |'
    DASHES=+$(jot -s '' -b - $((${#LOG} - 2)))+

    echo "$DASHES"
    echo "$LOG"
    echo "$DASHES"
}

function start_ssh() {
    ssh -o 'IPQoS lowdelay throughput' -fMN -S "$SSH_SOCK" -p "$DDEPLOY_SSH_PORT" "$DDEPLOY_SSH_USER@$DDEPLOY_SSH_HOST"
    trap stop_ssh EXIT
}

function stop_ssh() {
    log Closing SSH master connection
    ssh -S "$SSH_SOCK" -O exit master
}

# run on remote shell
function raw_shell() {
    if [ "$DDEPLOY_MODE" == "ssh" ]; then
      ssh -S "$SSH_SOCK" -o LogLevel=QUIET master -t "$@"
    elif [ "$DDEPLOY_MODE" == "local" ]; then
      eval "$@"
    fi
}

# run on remote shell as root
function raw_sushell() {
    if [ "$USER" == "root" ]; then
      eval "$@"
    else
      raw_shell sudo -- sh -c \""$*"\"
    fi
}

# run on remote shell, setting workdir to the compose dir
function shell() {
    raw_shell cd "$DDEPLOY_REMOTE_TMP_DIR" \; "$@"
}

# run on remote shell as root, setting workdir to the compose dir
function sushell() {
    raw_sushell cd "$DDEPLOY_REMOTE_TMP_DIR" \; "$@"
}

# connect to ssh if ssh mode
if [ "$DDEPLOY_MODE" == "ssh" ]; then
  # start SSH master
  log Opening SSH master connection
  start_ssh
elif [ "$DDEPLOY_MODE" == "local" ]; then
  log Using local connection
else
  log "$DDEPLOY_MODE is an invalid DDEPLOY_MODE."
  exit 1
fi

# get list of stacks
log "Getting list of stacks"
if [ "$1" == "all" ]; then
  STACKS=()
  while IFS='' read -r l;
    do STACKS+=("$l"); 
  done < <(find * -type f -maxdepth 1 -name 'docker-compose.yml' -print0 | xargs -0 -I {} dirname {})
else
  IFS=',' read -ra STACKS <<< "$1"
fi

# create base dir
log "Creating base directory"

if [ "$DDEPLOY_MODE" == "ssh" ]; then
  raw_sushell mkdir -p "$DDEPLOY_REMOTE_TMP_DIR" \&\& chown "$DDEPLOY_SSH_USER" "$DDEPLOY_REMOTE_TMP_DIR"
elif [ "$DDEPLOY_MODE" == "local" ]; then
  raw_sushell mkdir -p "$DDEPLOY_REMOTE_TMP_DIR"
fi

# send relevant files to remote directory
(IFS=' '; log "Uploading stacks ${STACKS[*]} to $DDEPLOY_SSH_HOST as $DDEPLOY_SSH_USER.")
if [ $DDEPLOY_MODE == "ssh" ]; then
  rsync \
    --archive \
    --copy-dirlinks \
    --stats \
    --delete \
    -e "$SSH_COMMAND" \
    "_setup.sh" \
    "${STACKS[@]}" \
    "$DDEPLOY_SSH_USER@$DDEPLOY_SSH_HOST:$DDEPLOY_REMOTE_TMP_DIR"
elif [ $DDEPLOY_MODE == "local" ]; then
  rsync \
    --archive \
    --copy-dirlinks \
    --stats \
    --delete \
    "_setup.sh" \
    "${STACKS[@]}" \
    "$DDEPLOY_REMOTE_TMP_DIR"
fi


# create string with all the environment variables
remote_env=$(sed -E '/^(#.+|\s*)$/! s/^/export /' \
  "../$DDEPLOY_ENV_FILE" \
  "../$DDEPLOY_SECRETS_FILE")

# run global setup
if [ $TOOL_MODE == "up" ]; then
  log Running global setup

  echo "$remote_env" | sushell . /dev/stdin \&\& "./${DDEPLOY_SETUP_FILENAME}" \|\| true
fi

# deploy stacks
for stack in "${STACKS[@]}"; do
  log Deploying "'$stack'"
  
  if [ $TOOL_MODE == "up" ]; then
    # 1. add export to environment file variables and pipe into "." (source)
    # 2. docker stack deploy
    echo "$remote_env" | sushell . /dev/stdin \&\& cd "$stack" \&\& "./${DDEPLOY_SETUP_FILENAME}" \|\| true \&\& cat ../global.yml docker-compose.yml \> docker-compose-merged.yml \&\& docker stack deploy --prune --compose-file "docker-compose-merged.yml" "$stack"
  elif [ $TOOL_MODE == "down" ]; then
    # 1. docker stack rm
    sushell cd "$stack" \&\& docker stack rm "$stack"
  elif [ $TOOL_MODE == "pretend" ]; then
    echo "Doing nothing for $stack"
  fi
  
done
