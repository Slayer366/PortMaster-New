#!/bin/bash
# ABOUTME: PortMaster launch script for Corsairs J2ME game.
# ABOUTME: Sets up environment, starts gptokeyb, and runs the game via JDK 11.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

get_controls

GAMEDIR="/$directory/ports/corsairs"
LOGFILE="$GAMEDIR/corsairs.log"
cd "$GAMEDIR"

exec > "$LOGFILE" 2>&1
set -x

# JDK 11 runtime managed by PortMaster
: "${HOME:=/root}"
RUNTIME="zulu11.48.21-ca-jdk11.0.11-linux_${DEVICE_ARCH}"
JAVA_HOME="$HOME/${RUNTIME}"
$ESUDO mkdir -p "${JAVA_HOME}"

if [ ! -f "$controlfolder/libs/${RUNTIME}.squashfs" ]; then
  if [ -f "$controlfolder/harbourmaster" ]; then
    $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${RUNTIME}.squashfs"
  fi
fi

if [ ! -f "$controlfolder/libs/${RUNTIME}.squashfs" ]; then
  pm_message "JDK 11 runtime not available. Check your internet connection and try again."
  sleep 5
  pm_finish
  exit 1
fi

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${JAVA_HOME}" 2>/dev/null
fi

$ESUDO mount "$controlfolder/libs/${RUNTIME}.squashfs" "${JAVA_HOME}"

JAVA="$JAVA_HOME/bin/java"
if [ ! -x "$JAVA" ]; then
  pm_message "JDK 11 runtime failed to mount. Try restarting."
  sleep 5
  $ESUDO umount "${JAVA_HOME}" 2>/dev/null
  pm_finish
  exit 1
fi

export LD_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}:$JAVA_HOME/lib:$JAVA_HOME/lib/server:$LD_LIBRARY_PATH"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

# SDL2 environment for KMSDRM
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export SDL_VIDEO_DRIVER=kmsdrm

# Start gptokeyb for gamepad-to-keyboard mapping
$GPTOKEYB "java" -c "$GAMEDIR/corsairs.gptk" &

pm_platform_helper "$JAVA"

GAME_JAR=""
EXPECTED_MD5="921bf6964df2d1668d75c946c2736062"

for f in "$GAMEDIR"/*.jar; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "corsairs-portmaster.jar" ] && continue
  if [ "$(md5sum "$f" | cut -d' ' -f1)" = "$EXPECTED_MD5" ]; then
    GAME_JAR="$f"
    break
  fi
done

if [ -z "$GAME_JAR" ] && [ -f "$GAMEDIR/corsairs.jar" ]; then
  GAME_JAR="$GAMEDIR/corsairs.jar"
fi

if [ -z "$GAME_JAR" ]; then
  pm_message "Game JAR not found. Place the original Corsairs JAR into ports/corsairs/"
  sleep 5
  $ESUDO umount "${JAVA_HOME}" 2>/dev/null
  pm_finish
  exit 1
fi

$JAVA \
  -Djava.awt.headless=true \
  -Djava.library.path="$GAMEDIR/libs.${DEVICE_ARCH}" \
  -Dcorsairs.data.dir="$GAMEDIR/savedata" \
  -cp "$GAMEDIR/corsairs-portmaster.jar:$GAME_JAR" \
  CorsairsPortmaster

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${JAVA_HOME}"
fi

pm_finish
