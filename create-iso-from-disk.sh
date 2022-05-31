#!/bin/bash
# create-iso-from-disk.sh
# create an ISO image file from a physical CD or DVD disk using dd(1) or (optional) other available tools
# see: https://www.thomas-krenn.com/de/wiki/ISO_Image_von_CD_oder_DVD_unter_Linux_erstellen

# TODO LICENSE ...

LANG=C
ME=${0##*/}
SPACE_REPL_CHAR='-'
BLOCK_SIZE_DEFAULT=2048
# declare -a ISO_INFO
# ISO_INFO=() # same
COPY_ACCEL=${CIFD_COPY_ACCEL:-1} # increasinf seems to have no impact on copying speed

# DONE remove everything isoinfo(1) related and use blkid(1) and/or lsblk(1) instead
# TODO replace gdbus with kdialog / knotify?
# DONE access device just once and store info in either an array or if this fails in a temporary file
# DONE some initial checks on device or file to ensure that we a valid ISO
# TODO tool(s) configuration: use foo(1) or bar(1) or not?
#      or: preferred tool to create image file
#      or: should WE allow fast-and-dump method (via dd) and(!) smart-but-slow method via some other tool
# TODO get progress from dd and connect with progress bar in kdialog
# TODO trap Ctrl-C and other kill signals and clean up image file

# declare a function to add some syntactic sugar for the sake of documentation in my functions
global()
{
	:
}

_init_trap_signals()
{
	:
}

_clean_up()
{
	:
}

_notify()
{
	# minimum of two arguments required
	[[ $# -ge 2 ]] || return
	
	local summary="$1"
	local body="$2"
	local icon="$3"
	local timeout=${4:-6000}
	local id=0
	
	gdbus call --session \
    --dest=org.freedesktop.Notifications \
    --object-path=/org/freedesktop/Notifications \
    --method=org.freedesktop.Notifications.Notify \
    "$ME" $id "$icon" "$summary" "$body" \
    '[]' '{"urgency": <1>}' $timeout \
    >/dev/null
}

_usage_and_exit()
{
	local usage_message="usage: $1"
	local exit_stat="$2"

	printf '%s\n' "$usage_message" >&2
	exit $exit_stat
}

_error_and_exit()
{
	local error_message="Error: $1"
	local exit_stat="$2"

	notify-send --expire-time=5000 "$ME" --icon="dialog-error" "$error_message"
	printf '%s\n' "$error_message" >&2
	exit $exit_stat
}

_user_canceled()
{
	local canceled_message="Image creation canceled"

	notify-send --expire-time=5000 "$ME" --icon="dialog-info" "$canceled_message"
	printf '%s\n' "$canceled_message" >&2
	exit 0
}

_warn()
{
	local warning_message="Warning: $1"

	notify-send --expire-time=2500 "$ME" --icon="dialog-info" "$warning_message"
	printf '%s\n' "$warning_message" >&2
}

# _isoinfo_is_installed()
# {
# 	local isoinfo=$(type -p isoinfo)
#
# 	[[ -n $isoinfo ]] && return 0
#
# 	return 1
# }

# _import_iso_info()
# {
# 	local device="$1"
# 	local error=1
#
# 	while read line; do
# 		ISO_INFO+=("$line")
# 	done < <(isoinfo -d -i "$device")
#
# 	# if we have at least one information we feel good
# 	[[ -n ${ISO_INFO[0]} ]] && error=0
#
# 	return $error
# }

_import_block_device_attributes()
{
	local device_path="$1"
	global FS_TYPE
	global VOLUME_SIZE
	global BLOCK_SIZE
	global VOLUME_UUID
	global VOLUME_LABEL
	[[ $# == 1 ]]  || _error_and_exit "internal: $LINENO" 99
	[[ $1 != "" ]] || _error_and_exit "internal: $LINENO" 99
	printf '%s\n' "reading block device attributes..." >&2
	read FS_TYPE \
	     VOLUME_SIZE \
	     BLOCK_SIZE \
	     VOLUME_UUID \
	     VOLUME_LABEL \
		< <(lsblk --bytes --output 'FSTYPE,SIZE,PHY-SEC,UUID,LABEL' --noheadings $device_path)
}

# _iso_info()
# {
# 	printf '%s\n' "${ISO_INFO[@]}"
# }

# _import_blkid_info() # device-path
# {
# 	[[ $# == 1 ]]  || _error_and_exit "internal: $LINENO" 99
# 	[[ $1 != "" ]] || _error_and_exit "internal: $LINENO" 99
# 	local device_path="$1"
# 	eval $(blkid $device_path | sed "s#${device_path}:##")
# }

# _import_lsblk_info()
# {
# 	[[ $# == 1 ]]  || _error_and_exit "internal: $LINENO" 99
# 	[[ $1 != "" ]] || _error_and_exit "internal: $LINENO" 99
# 	eval "VOLUME_SIZE=$(lsblk --bytes --output 'SIZE' $device_path | tail -1)"
# }

_is_iso9660_format()
{
	global FS_TYPE
# 	local device="$1"
#	isoinfo -d -i "$device" | grep '9660' >/dev/null
# 	_iso_info | grep '9660' >/dev/null
	test $FS_TYPE == "iso9660"
}

_get_device_block_size()
{
	global BLOCK_SIZE
# 	local device="$1"
#	isoinfo -d -i "$device" | grep -i 'block size' | cut -d: -f2 | tr -d ' '
# 	_iso_info | grep -i 'block size' | cut -d: -f2 | tr -d ' '
	printf '%s' $BLOCK_SIZE
}

_get_device_volume_size()
{
	global VOLUME_SIZE
# 	[[ $# == 1 ]]  || _error_and_exit "internal: $LINENO" 99
# 	[[ $1 != "" ]] || _error_and_exit "internal: $LINENO" 99
# 	local device_path="$1"
#	isoinfo -d -i "$device" | grep -i 'volume size' | awk -F ":" '{print $2}' | tr -d ' '
# 	_iso_info | grep -i 'volume size' | awk -F ":" '{print $2}' | tr -d ' '
# 	lsblk --bytes --output 'SIZE' $device_path | tail -1
	printf '%s' $VOLUME_SIZE
}

# _get_device_volume_id()
# {
# 	local device="$1"
# 	isoinfo -d -i "$device" | grep -i 'volume id' | awk -F ":" '{print $2}' | sed 's/^ *//i'
# 	_iso_info | grep -i 'volume id' | awk -F ":" '{print $2}' | sed 's/^ *//i'
# }

_get_device_volume_label_or_uuid()
{
	global VOLUME_LABEL
	global VOLUME_UUID
	printf '%s' "${VOLUME_LABEL:-$VOLUME_UUID}"
}

_get_device_volume_uuid()
{
	global VOLUME_UUID
	printf '%s' $VOLUME_UUID
}

_get_start_directory()
{
	for directory in "$HOME/Downloads" "$HOME/Download" "$HOME" "/tmp" ; do
		if [[ -d "$directory" ]]; then
			printf '%s' "$directory"
			break
		fi
	done
}

_get_iso_image_file_path_and_name()
{
	local start_directory="$1"
	local file_name="$2"
	
	# ask with kdialog for filename and path
	#kdialog --getsavefilename :label1 "application/x-cd-image"
	kdialog --getsavefilename "$start_directory"/"$file_name" "application/x-cd-image" 2>/dev/null
}

_create_iso()
{
	global COPY_ACCEL
	global VOLUME_LABEL

	local source="$1"
	local target="$2"
	local block_size=$3
	local volume_size=$4

	local copy_steps=$((volume_size/block_size))

	# NOTE https://www.thomas-krenn.com/de/wiki/ISO_Image_von_CD_oder_DVD_unter_Linux_erstellen
	# TODO connect with kdialog progress dialog
	# TODO can we handle Cancel?
	# TODO close shall not kill disk dump
	#notify-send --expire-time=5000 "$ME" --icon="dialog-success" "dd if=$source of=$target bs=$block_size count=$volume_size status=progress"
	dd_if="$source"
	dd_of="$target"
	dd_bs=$(( block_size * COPY_ACCEL ))
	dd_count=$(( copy_steps / COPY_ACCEL ))

	# sample output line from dd : 14268416 bytes (14 MB, 14 MiB) copied, 19 s, 750 kB/s
	time dd if="$dd_if" of="$dd_of" bs=$dd_bs count=$dd_count status=progress
}

_main()
{
	[[ $1 != "" ]] ||  _usage_and_exit "$ME <device-path>" 9

	local source_device="$1"

	global VOLUME_LABEL
	global COPY_ACCEL

	# check if source is readable
	[[ -n "$source_device" ]] || _error_and_exit "source not given" 1

	# check if source is readable
	[[ -r "$source_device" ]] || _error_and_exit "source not readable" 2

	# we later ask for directory to create the image in,
	# so we need a smart location to start with
	start_directory=$(_get_start_directory)

	# check if isoinfo(1) is installed. warn user if not
# 	_isoinfo_is_installed || _warn "isoinfo(1) is recommend to create smart named ISO images, but not installed"

	# access device just once and keep the data
# 	_import_iso_info "$source_device" || _error_and_exit "failed to read ISO info" 3
# 	_import_blkid_info "$source_device" || _error_and_exit "failed to read device info from blkid(1)" 3
# 	_import_lsblk_info "$source_device" || _error_and_exit "failed to read device info from lsblk(1)" 3
	_import_block_device_attributes "$source_device" || _error_and_exit "failed to read device info from lsblk(1)" 3

	# check if physical disk is ISO format
# 	_is_iso9660_format "$source_device" || _error_and_exit "source is not in ISO format" 4
	_is_iso9660_format || _error_and_exit "source is not in ISO format" 4

	# get physical block and volume size
	volume_size=$(_get_device_volume_size)
	block_size=$(_get_device_block_size)
	block_size=${block_size:-$BLOCK_SIZE_DEFAULT}

	# we like to propose a filename from image ISO info.
	# if we can not read it, we use a random file name
# 	declare -l proposed_file_name="$(_get_device_volume_id "$source_device" | tr ' ' $SPACE_REPL_CHAR)"
	declare -l proposed_file_name="$(_get_device_volume_label_or_uuid | tr ' ' $SPACE_REPL_CHAR)"
	proposed_file_name=${proposed_file_name:-image$RANDOM}

	# get file name and path
	target_path=$(_get_iso_image_file_path_and_name "$start_directory" "${proposed_file_name}.iso")
	[[ -n "$target_path" ]] || _user_canceled

	# check if filepath is valid (i.e. existing and writable)
	[[ -d "${target_path%/*}" ]] || _error_and_exit "directory to create ISO image in does not exists" 5
	# TODO how to detect cancel on file exist? $?=Canceled
	[[ "$?" =~ Canceled ]] && _user_canceled

	# dump device to file
	_notify "Copying disk:" "volume: $VOLUME_LABEL size: $volume_size, speed: ${COPY_ACCEL}x" "application-x-cd-image"
	_create_iso "$source_device" "$target_path" "$block_size" "$volume_size"
	
	#stat -c '%s %n' orig.iso copy.iso
	#sha1sum orig.iso copy.iso

	# notification that file has been created
	sleep 1
	#notify-send --expire-time=5000 "ISO image created:" --icon="dialog-success" "$target_path"
	_notify "ISO image created:" "${target_path##*/}" "application-x-cd-image"
}

_main "$1"

exit 0
