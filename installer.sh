#!/usr/bin/env bash
# Website: https://github.com/FaigerSYS/MCPE-Server-Scripts

# Installer version
VERSION="2.0.1"

# Fix for files/folders with spaces
IFS=$'\n'

# Path to log file
LOG_FILE="$(pwd)/install.log"

# Install data version (for updater)
INSTALL_DATA_VERSION="2"

# Install data file (for updater)
INSTALL_DATA_FILE="$(pwd)/.install_data"

function get_date {
	date -u '+%Y-%m-%d_%H-%M-%S'
}

function get_time {
	date -u '+%H:%M:%S'
}

function log {
	$@ >> $LOG_FILE 2>> $LOG_FILE
	return $?
}

function log_p1 {
	$@ >> $LOG_FILE
	return $?
}

function log_p2 {
	$@ 2>> $LOG_FILE
	return $?
}

function log_echo {
	log echo -e "[$(get_time)] $@"
}

function notice {
	echo -e "[*] $@"
	log_echo "Console notice: $@"
}

function ask {
	[ "$2" == "" ] && echo -e "[?] $1" || echo -ne "[?] $1"
	log_echo "Console ask: $1"
	if [ -n "$2" ]; then
		read "$2"
		log_echo "Console input: ${!2}"
	fi
}

function error {
	echo -e "[!] $@"
	log_echo "An error occurred during the installation!"
	log_echo "Error message: '$@'"
	log_echo "If you can't fix it, send this log to https://github.com/FaigerSYS/MCPE-Server-Scripts/issues" 
	exit 1
}

function get_json_value {
	JSON="$1"
	VALUE="$2"
	echo -n $JSON | sed -n 's/.*"'$VALUE'" \{0,\}: \{0,\}"\{0,1\}\(.*\).*/\1/p' | sed 's/\("\| \|,\|]\|}\).*//'
}

function check_packages_soft {
	for PACKAGE in "$@"; do
		if ! type "$PACKAGE" >/dev/null 2>&1; then
			return 1
		fi
	done
}

function check_packages {
	for PACKAGE in "$@"; do
		[ -z "$NEXT" ] && PACKAGES="'$PACKAGE" && NEXT="y" || PACKAGES="$PACKAGES' or '$PACKAGE"
		type "$PACKAGE" >/dev/null 2>&1 && IS_OKAY="y"
	done
	PACKAGES="$PACKAGES'"
	
	[ -z "$IS_OKAY" ] && error "You need to have installed $PACKAGES! Aborting"
}

function check_res_availability {
	log_echo "Checking '$1' using '$DWN_TYPE'..."
	
	if [ "$DWN_TYPE" == "curl" ]; then
		HEADER=$(curl --head --location $1 | grep 'HTTP/')
	else
		HEADER=$(wget --no-check-certificate --spider --server-response $1 2>&1 | grep 'HTTP/')
	fi
	
	if [ -n "$(echo -n $HEADER | grep '2[0-9][0-9]')" ]; then
		log_echo "Link exists"
		return 0
	else
		log_echo "Link not exists"
		return 1
	fi
}

function get_contents {
	log_echo "Getting contents of '$1' using '$DWN_TYPE'"
	
	if [ "$DWN_TYPE" == "curl" ]; then
		log_p2 curl --globoff --location --insecure "$1"
	else
		log_p2 wget --no-check-certificate --output-document - "$1"
	fi
	
	return $?
}

function download {
	backup "$2"
	
	if get_contents "$1" > "$2"; then
		log_echo "Contents saved to '$2'"
		return 0
	else
		rm "$2"
		log_echo "An error occurred while downloading the file!"
		return 1
	fi
}

function backup {
	FROM="$1"
	if [ -f $FROM ] || [ -d $FROM ]; then
		mkdir -p old_files
		
		DATE=$(get_date)
		FILE_NAME=$(basename $FROM)
		
		TO="old_files/old-$DATE-$FILE_NAME"
		
		log mv "$FROM" "$TO"
	fi
}

echo "### MCPE kernel installer (v$VERSION) ###"
echo

log echo -e "\n\nStarted MCPE kernel installer v$VERSION ($(get_date))\n"

while getopts "p:ukbsc?" OPT 2> /dev/null; do
	case ${OPT} in
		p)
			if [ -f "$OPTARG" ]; then
				error "\"$OPTARG\" is a file, must be directory! Aborting"
			else
				mkdir -p "$OPTARG"
				cd "$OPTARG"
			fi
		;;
		u)
			IS_UPDATE=y
		;;
		c)
			FORCE_CURL=y
		;;
		k)
			ONLY_KERNEL=y
		;;
		b)
			ONLY_BINARY=y
		;;
		s)
			ONLY_START=y
		;;
		\?)
			echo "Usage: $0 [options]"
			echo "  -p [path]  Provide custom install path"
			echo "  -u         Update installed kernel"
			echo "  -k         Install only kernel"
			echo "  -b         Install only PHP binary"
			echo "  -s         Install only start script"
			echo "  -c         Force use 'curl' for downloading"
			exit 1
		;;
		esac
done

log_echo "Choosed '$(pwd)' as install path"

function checkDependencies {
	OS="$(uname)"
	log_echo "Detected OS: $OS"
	if [ ! "$OS" == "Linux" ]; then
		error "Script supports only Linux!"
	fi
	
	BIT="$(getconf LONG_BIT)"
	log_echo "Detected long_bit: $BIT"
	
	check_packages "wget" "curl"
	
	if check_packages_soft "wget" && [ -z "$FORCE_CURL" ]; then
		DWN_TYPE="wget"
	else
		DWN_TYPE="curl"
	fi
	
}

function canProcess {
	if [ "$1" == "BINARY" ] && [ -z "$ONLY_BINARY" ]; then
		if [ -n "$ONLY_START" ] || [ -n "$ONLY_KERNEL" ] || [ -n "$IS_UPDATE" ]; then
			return 1
		fi
	elif [ "$1" == "KERNEL" ] && [ -z "$ONLY_KERNEL" ] && [ -z "$IS_UPDATE" ]; then
		if [ -n "$ONLY_START" ] || [ -n "$ONLY_BINARY" ]; then
			return 1
		fi
	elif [ "$1" == "START" ] && [ -z "$ONLY_START" ]; then
		if [ -n "$ONLY_BINARY" ] || [ -n "$ONLY_KERNEL" ] || [ -n "$IS_UPDATE" ]; then
			return 1
		fi
	fi
}

function installBinary {
	notice "Installing PHP binary..."
	
	if [ "$BIT" == "64" ]; then
		BINARY="https://jenkins.pmmp.io/job/PHP-PocketMine-Linux-x86_64/lastSuccessfulBuild/artifact/PHP_Linux-x86_64.tar.gz"
		if ! check_res_availability "$BINARY"; then
			BINARY="https://raw.githubusercontent.com/FaigerSYS/PHP-Binaries/master/PHP_Linux_x64.tar.gz"
		fi
	else
		BINARY="https://jenkins.pmmp.io/job/PHP-PocketMine-Linux-x86/lastSuccessfulBuild/artifact/PHP_Linux-x86.tar.gz"
		if ! check_res_availability "$BINARY"; then
			BINARY="https://raw.githubusercontent.com/FaigerSYS/PHP-Binaries/master/PHP_Linux_x86.tar.gz"
		fi
	fi
	
	backup "bin"
	
	TMP_DIR=$(mktemp -d)
	download "$BINARY" "$TMP_DIR/binary.tgz"
	log tar -xzf "$TMP_DIR/binary.tgz" -C "$TMP_DIR"
	log mv "$TMP_DIR/bin" "bin"
	log rm -rf "$TMP_DIR"
	log chmod -R 755 "bin"
	
	notice "Done!\n"
}

function installStartScript {
	notice "Installing start script..."
	
	download "https://raw.githubusercontent.com/FaigerSYS/MCPE-Server-Scripts/master/start.sh" "start.sh"
	chmod 755 "start.sh"
	
	notice "Done!\n"
}

function askBranch {
	ask "Select branch to install ($DEFAULT_BRANCH): " BRANCH
	case $BRANCH in
		"" | $DEFAULT_BRANCH)
			if ! check_res_availability "https://api.github.com/repos/$GITHUB/branches/$DEFAULT_BRANCH"; then
				error "Default branch not found... Maybe it was changed. Aborting"
			else
				BRANCH="$DEFAULT_BRANCH"
				notice "Selected default branch\n"
			fi
		;;
		*)
			if ! check_res_availability "https://api.github.com/repos/$GITHUB/branches/$BRANCH"; then
				error "Choosen branch does not exists! Aborting"
			else
				notice "Selected branch \"$BRANCH\"\n"
			fi
		;;
	esac
}

function askBuildType {
	ask "Available kernel types:"
	ask "    1) Source code ('src' folder)"
	ask "    2) Packed kernel ('.phar' file)"
	ask "Choose type (1): " KERNEL_TYPE
	case $KERNEL_TYPE in
		"" | 1 | src | source)
			notice "Selected source type\n"
			KERNEL_TYPE="1"
		;;
		2 | phar | pack | packed)
			notice "Selected packed type\n"
			KERNEL_TYPE="2"
		;;
		*)
			error "Undefined type ($KERNEL_TYPE). Restart script and try again"
		;;
	esac
}

function installKernel {
	if [ -z "$KERNEL" ]; then
		if [ -n "$IS_UPDATE" ]; then
			if [ -f "$INSTALL_DATA_FILE" ]; then
				DATA_VERSION="$(sed '2q;d' $INSTALL_DATA_FILE)"
				if [ ! "$DATA_VERSION" == "$INSTALL_DATA_VERSION" ]; then
					error "Install data is incompatible with this script. Please reinstall kernel with this version to fix this"
				fi
				KERNEL="$(sed '3q;d' $INSTALL_DATA_FILE)"
				BRANCH="$(sed '4q;d' $INSTALL_DATA_FILE)"
				KERNEL_TYPE="$(sed '5q;d' $INSTALL_DATA_FILE)"
			else
				error "Install data not found! You must install kernel using this installer before updating kernel!"
			fi
		else
			ask "Available kernels:"
			ask "    1) PocketMime-MP (pmmp)"
			ask "    2) Tesseract"
			ask "Choose kernel (1): " KERNEL
		fi
	fi
	
	[ -z "$IS_UPDATE" ] && INSTALLING="Installing" || INSTALLING="Updating"
	
	case $KERNEL in
		"" | 1 | "pmmp" | "PMMP" | "PocketMine-MP" | "pocketMine-mp")
			notice "Choosed PocketMine-MP kernel\n"
			installKernel_PMMP
		;;
		2 | "Tesseract" | "tesseract" | "tess")
			notice "Choosed Tesseract kernel\n"
			installKernel_Tesseract
		;;
		*)
			error "Undefined kernel ($KERNEL). Restart script and try again"
	esac
	
	echo "### PLEASE DO NOT CHANGE THIS FILE ###" > $INSTALL_DATA_FILE
	echo $INSTALL_DATA_VERSION >> $INSTALL_DATA_FILE
	echo $KERNEL >> $INSTALL_DATA_FILE
	echo $BRANCH >> $INSTALL_DATA_FILE
	echo $KERNEL_TYPE >> $INSTALL_DATA_FILE
	chmod 640 $INSTALL_DATA_FILE
	
	notice "Done!\n"
}

function installKernel_PMMP {
	KERNEL="PocketMine-MP"
	OWNER="pmmp"
	REPO="PocketMine-MP"
	GITHUB="$OWNER/$REPO"
	DEFAULT_BRANCH="master"
	
	[ -z "$BRANCH" ] && askBranch
	[ -z "$KERNEL_TYPE" ] && [ "$BRANCH" == "$DEFAULT_BRANCH" ] && askBuildType
	
	if [ "$KERNEL_TYPE" == "1" ]; then
		check_packages "git"
		
		notice "$INSTALLING PocketMine-MP..."
		
		backup "src"
		TMP_DIR=$(mktemp -d)
		log git clone --recursive -b "$BRANCH" "https://github.com/$GITHUB.git" "$TMP_DIR"
		log mv "$TMP_DIR/src" "."
		log mv "$TMP_DIR/.git" "."
		log rm -rf "$TMP_DIR"
	else
		notice "Searching for latest build info..."
		
		BUILD_DATA=$(get_contents "https://jenkins.pmmp.io/job/PocketMine-MP/lastSuccessfulBuild/api/json?tree=artifacts[fileName],number")
		BUILD_FILE=$(get_json_value "$BUILD_DATA" "fileName")
		BUILD_NUM=$(get_json_value "$BUILD_DATA" "number")
		
		if [ -n "$BUILD_FILE" ] && [ -n "$BUILD_NUM" ]; then
			notice "$INSTALLING PocketMine-MP (Jenkins build #$BUILD_NUM)..."
			download "https://jenkins.pmmp.io/job/PocketMine-MP/$BUILD_NUM/artifact/$BUILD_FILE" "PocketMine-MP.phar"
		else
			error "Build not founded or server may not be available at the moment. Try later or choose another kernel/kernel type"
		fi
	fi
}

function installKernel_Tesseract {
	KERNEL="Tesseract"
	OWNER="TesseractTeam"
	REPO="Tesseract"
	GITHUB="$OWNER/$REPO"
	DEFAULT_BRANCH="master"
	
	[ -z "$BRANCH" ] && askBranch
	[ -z "$KERNEL_TYPE" ] && askBuildType
	
	if [ "$KERNEL_TYPE" == "1" ]; then
		notice "$INSTALLING Tesseract..."
		
		backup "src"
		
		TMP_DIR=$(mktemp -d)
		if check_packages_soft "git"; then
			log git clone --recursive -b "$BRANCH" "https://github.com/$GITHUB.git" "$TMP_DIR"
			log mv "$TMP_DIR/src" "."
			log mv "$TMP_DIR/.git" "."
		else
			download "https://codeload.github.com/$GITHUB/tar.gz/$BRANCH" "$TMP_DIR/kernel.tgz"
			log tar -xzf "$TMP_DIR/kernel.tgz" -C "$TMP_DIR"
			log mv "$TMP_DIR/$REPO-$BRANCH/src" "."
		fi
		log rm -rf "$TMP_DIR"
	else
		notice "Searching for latest build info..."
		
		BUILD_DATA=$(get_contents "https://circleci.com/api/v1.1/project/github/TesseractTeam/Tesseract/latest/artifacts?branch=$BRANCH")
		BUILD_URL=$(get_json_value "$BUILD_DATA" "url")
		
		if [ -n "$BUILD_URL" ]; then
			notice "$INSTALLING Tesseract..."
			download "$BUILD_URL" "Tesseract.phar"
		else
			error "Build not founded or server may not be available at the moment. Try later or choose another kernel/kernel type"
		fi
	fi
}

checkDependencies

canProcess KERNEL && installKernel
canProcess START && installStartScript
canProcess BINARY && installBinary

notice "Script done! Thanks for using :)"
