#!/bin/sh -l

beginswith() {
    case "$2" in
        "$1"*) true ;;
        *) false ;;
    esac
}

exists_in_array() {
  local element="$1"
  local array_str="$2"
  for i in $array_str; do
    if [ "$i" = "$element" ]; then
      return 0
    fi
  done
  return 1
}

append_if_not_exists() {
  local element="$1"
  local array_str="$2"
  if exists_in_array "$element" "$array_str"; then
    echo "$array_str"
  else
    echo "$array_str $element"
  fi
}

icecon_command() {
    icecon --command "$1" "${SERVER_IP}:${SERVER_PORT}" "${RCON_PASSWORD}"
}

get_player_count() {
    response=$(curl -s --max-time 10 "${SERVER_IP}:${SERVER_PORT}/players.json")
    if [ $? -ne 0 ]; then
        echo "Failed to fetch player count"
        echo "1" # Default to 0 players if the request fails
    else
        player_count=$(echo "$response" | jq 'length')
        echo "$player_count"
    fi
}

RESTART_INDIVIDUAL_RESOURCES=$1
SERVER_IP=$2
SERVER_PORT=$3
RCON_PASSWORD=$4
RESOURCES_FOLDER=$5
RESTART_SERVER_WHEN_0_PLAYERS=$6
IGNORED_RESOURCES=$7

git config --global --add safe.directory /github/workspace

echo "RESOURCES_FOLDER: $RESOURCES_FOLDER"

REPO_NAME=$(basename "$GITHUB_REPOSITORY")
echo "REPO_NAME: $REPO_NAME"

if [ ${GITHUB_BASE_REF} ]; then
    # Pull Request
    git fetch origin ${GITHUB_BASE_REF} --depth=1
    export DIFF=$(git diff --name-only origin/${GITHUB_BASE_REF} ${GITHUB_SHA})
    echo "Diff between origin/${GITHUB_BASE_REF} and ${GITHUB_SHA}"
else
    # Push
    git fetch origin ${GITHUB_EVENT_BEFORE} --depth=1
    export DIFF=$(git diff --name-status ${GITHUB_EVENT_BEFORE} ${GITHUB_SHA})
    echo "Diff between ${GITHUB_EVENT_BEFORE} and ${GITHUB_SHA}"
fi

echo "DIFF: $DIFF"

resources_to_restart=$REPO_NAME

echo "Resources to restart: $resources_to_restart"

if [ -z "$resources_to_restart" ]; then
    echo "Nothing to restart"
else
    player_count=$(get_player_count)
    if [ "$RESTART_SERVER_WHEN_0_PLAYERS" = true ] && [ "$player_count" -eq 0 ]; then
        echo "Will restart the whole server due to 0 players"
        icecon_command "quit"
    elif [ "$RESTART_INDIVIDUAL_RESOURCES" = true ]; then
        echo "Will restart individual resources"
        for resource in $resources_to_restart; do
            if exists_in_array "${resource}" "${IGNORED_RESOURCES}"; then
                echo "Ignoring restart of the resource ${resource}"
            else
                echo "Restarting ${resource}"
                icecon_command "stop ${resource}"
                icecon_command "start ${resource}"
            fi
        done
    else
        echo "Will restart the whole server"
        icecon_command "quit"
    fi
fi
