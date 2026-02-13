#!/bin/bash
# PORTMASTER: songo5.zip, Songo5.sh

# PortMaster preamble
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

# Adjust these to your paths and desired godot version
GAMEDIR=/$directory/ports/songo5

runtime="sbc_4_3_rcv8"
#godot_executable="godot43.$DEVICE_ARCH"
pck_filename="Songo5.pck"
gptk_filename="songo5.gptk"

# Logging
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Check for ROCKNIX running with libMali driver.
if [[ "$CFW_NAME" = "ROCKNIX" ]]; then
	GODOT_OPTS=${GODOT_OPTS//-f/}
    if ! glxinfo | grep "OpenGL version string"; then
    pm_message "This Port does not support the libMali graphics driver. Switch to Panfrost to continue."
    sleep 5
    exit 1
    fi
fi

echo "LOOKING FOR CFW_NAME ${CFW_NAME}"
export CFW_NAME
echo "LOOKING FOR DEVICE ID ${DEVICE_NAME}"
export DEVICE_NAME

# Create directory for save files
CONFDIR="$GAMEDIR/conf/"
$ESUDO mkdir -p "${CONFDIR}"

# For knulli lid switch override
sh "${GAMEDIR}/runtime/setup_batocera_override" "${GAMEDIR}/runtime"

# Setup volume indicator
USE_SONGO_VOL_TCP_SERVER="0"
SONGO_CFW_NAME="NONE"
if [[ "$CFW_NAME" = "muOS" ]] || [[ "$CFW_NAME" = "knulli" ]] || [[ "$CFW_NAME" = "ROCKNIX" ]]; then
	SONGO_CFW_NAME="${CFW_NAME}"
fi
if [[ "$CFW_NAME" = "TrimUI" ]]; then
	if [ -f /mnt/SDCARD/.system/version.txt ] && grep -q "NextUI" /mnt/SDCARD/.system/version.txt; then
		SONGO_CFW_NAME="NextUI"
	fi
fi

if [[ "$SONGO_CFW_NAME" != "NONE" ]]; then
	USE_SONGO_VOL_TCP_SERVER="1"
fi
export USE_SONGO_VOL_TCP_SERVER
sh "${GAMEDIR}/runtime/volume-indicator/setup_vol_indicator" "${SONGO_CFW_NAME}"
cd $GAMEDIR


# Set the XDG environment variables for config & savefiles
export XDG_DATA_HOME="$CONFDIR"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

echo "XDG_DATA_HOME"
echo $XDG_DATA_HOME

export SONGO_BINARIES_DIR="$GAMEDIR/runtime"

#  If XDG Path does not work
# Use _directories to reroute that to a location within the ports folder.
#bind_directories ~/.portfolder $GAMEDIR/conf/.portfolder 

# Setup Godot

#godot_dir="$HOME/godot"
#godot_file="runtime/${runtime}.squashfs"
#$ESUDO mkdir -p "$godot_dir"
#$ESUDO umount "$godot_file" || true
#$ESUDO mount "$godot_file" "$godot_dir"
#PATH="$godot_dir:$PATH"

# By default FRT sets Select as a Force Quit Hotkey, with this we disable that.
# export FRT_NO_EXIT_SHORTCUTS=FRT_NO_EXIT_SHORTCUTS 

$GPTOKEYB "$GAMEDIR/runtime/$runtime" -c "$GAMEDIR/$gptk_filename" &
sleep 0.6 # For TSP only, do not move/modify this line.
pm_platform_helper "$GAMEDIR/runtime/$runtime"
"$GAMEDIR/runtime/$runtime" $GODOT_OPTS --main-pack "gamedata/Songo5.pck"

if [ -f "${CONFDIR}godot/app_userdata/Songo #5/reset_values.sh" ]; then
	echo "reset_values.sh found, resetting cfw config options to user preference"
    sh "${CONFDIR}godot/app_userdata/Songo #5/reset_values.sh"
else
	echo "reset_values.sh not found"
fi


#if [[ "$PM_CAN_MOUNT" != "N" ]]; then
#$ESUDO umount "${godot_dir}"
#fi

# Teardown volume indicator
sh "${GAMEDIR}/runtime/volume-indicator/teardown_vol_indicator" "${SONGO_CFW_NAME}"

# Remove lid switch overrides if applied (EG: for rg35xx-SP)
TARGETS=(
	"/boot/boot/batocera.board.capability" # Knulli approach to lid inhibit
    "/sys/class/power_supply/axp2202-battery/hallkey" # RG35xx-SP, RG34xx-SP
    "/sys/devices/platform/hall-mh248/hallvalue"      # Miyoo Flip
)

for TARGET in "${TARGETS[@]}"; do
    # Skip if the target doesn't exist
    [ -e "$TARGET" ] || continue

    # Loop until no mounts remain at this target
    while mountpoint -q "$TARGET"; do
        # Lazy unmount to handle busy sysfs
        if umount -l "$TARGET" 2>/dev/null; then
            echo "Unmounted hallkey override: $TARGET"
        else
            echo "Failed to unmount (maybe not mounted or busy): $TARGET"
            break
        fi
    done
done

pm_finish
