#!/usr/bin/env bash
# Website: https://github.com/FaigerSYS/MCPE-Server-Scripts
# Version: 1.1

# Fix for files/folders with spaces
IFS=$'\n'

# Directory of the server
DIR="$(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# Priority: which forder is first to scan for binary and kernel
# local: the folder where the script is located | global: the folder in which you are now
PRIORITY="local"

# Enable auto-restart when the server stops (no/yes)
AUTO_RESTART="no"

# Wait pause after server restart
WAIT_PAUSE=3

while getopts "rw:locp:k:f:i:g-:" OPTION 2> /dev/null; do
	case ${OPTION} in
		r | l)
			AUTO_RESTART="y"
		;;
		w    )
			WAIT_PAUSE=$OPTARG
		;;
		o    )
			AUTO_RESTART="n"
		;;
		c    )
			CLEAN_PORT="y"
		;;
		p    )
			PHP_BINARY="$OPTARG"
		;;
		k | f)
			TMP=$(basename $OPTARG)
			TMP2=$(pwd)
			cd $(dirname $OPTARG)
			KERNEL="$(pwd)/$TMP"
			cd $TMP2
		;;
		i    )
			TMP=$(basename $OPTARG)
			TMP2=$(pwd)
			cd $(dirname $OPTARG)
			CD_TO="$(pwd)/$TMP"
			cd $TMP2
		;;
		g    )
			PRIORITY="global"
		;;
		-    )
			break
		;;
		\?   )
			echo "Usage: $0 [options]"
			echo "  -r, -l         Enable auto-restart"
			echo "  -w [sec]       Set wait pause for auto-restart"
			echo "  -o             Disable auto-restart"
			echo "  -c             Clean port"
			echo "  -p [path]      Set path to PHP binary"
			echo "  -k, -f [path]  Set path to kernel"
			echo "  -i             Set path to root folder of the server"
			echo "  -g             First look for binary and kernel in the folder in which you are now"
			exit 1
		;;
	esac
done
OPTS=($@)

if [ "$PRIORITY" == "global" ]; then
	PATH_1=$(pwd)
	PATH_2=$DIR
else
	PATH_1=$DIR
	PATH_2=$(pwd)
fi

function defineBinary {
	if [ -z "$PHP_BINARY" ]; then
		if [ -f $PATH_1/bin/php7/bin/php ]; then
			PHP_BINARY="$PATH_1/bin/php7/bin/php"
		elif [ -f $PATH_2/bin/php7/bin/php ]; then
			PHP_BINARY="$PATH_2/bin/php7/bin/php"
		elif [[ ! -z $(type php) ]]; then
			PHP_BINARY=$(type -p php)
		else
			echo "[!] Couldn't find a working PHP binary. To install you can use our installer: "
			echo "[!] https://github.com/FaigerSYS/MCPE-Server-Scripts/wiki/Installer"
			exit 1
		fi
	else
		if [ ! -f $PHP_BINARY ]; then
			echo "[!] Couldn't find a working PHP binary at \"$PHP_BINARY\". Aborting"
			exit 1
		fi
	fi
}

function cleanPort {
	if [ -f server.properties ]; then
		port=$(grep 'server-port=' server.properties | sed 's/^.*=//' | sed 's/.$//' | sed 's/\r//')
		fuser -k $port/udp >/dev/null 2>&1
	fi
}

function searchKernel {
	SEARCH_PATH=$1
	
	if [ -f $SEARCH_PATH/PocketMine-MP*.phar ]; then
		KERNEL="PocketMine-MP*.phar"
		
	elif [ -f $SEARCH_PATH/Tesseract*.phar ]; then
		KERNEL="Tesseract*.phar"
		
	elif [ -f $SEARCH_PATH/ClearSky*.phar ]; then
		KERNEL="ClearSky*.phar"
		
	elif [ -f $SEARCH_PATH/Genisys*.phar ]; then
		KERNEL="Genisys*.phar"
		
	elif [ -f $SEARCH_PATH/src/pocketmine/PocketMine.php ]; then
		KERNEL="src/pocketmine/PocketMine.php"
		
	else
		return 1
	fi
	
	KERNEL="$SEARCH_PATH/$(basename $SEARCH_PATH/$KERNEL)"
	return 0
}

function defineKernel {
	if [ -z "$KERNEL" ]; then
		echo "[*] Searching for server in \"$PATH_1\"..."
		if searchKernel $PATH_1; then
			cd $PATH_1
		else
			if [ ! $PATH_1 == $PATH_2 ]; then
				echo "[*] Not found. Searching for server in \"$PATH_2\"..."
				if searchKernel $PATH_2; then
					cd $PATH_2
				fi
			fi
		fi
		
		if [ -z "$KERNEL" ]; then
			echo "[!] Couldn't find a valid kernel installation. To install you can use our installer: "
			echo "[!] https://github.com/FaigerSYS/MCPE-Server-Scripts/wiki/Installer"
			exit 1
		fi
	else
		if [ ! -f $KERNEL ]; then
			echo "[!] Couldn't find kernel \"$KERNEL\""
			exit 1
		fi
	fi
	
	[ -n "$CD_TO" ] && cd $CD_TO
	
	echo "[*] Selected \"$KERNEL\""
}

function startServer {
	if [ "$CLEAN_PORT" == "yes" ] || [ "$CLEAN_PORT" == "y" ]; then
		cleanPort
	fi
	
	if [ "$AUTO_RESTART" == "yes" ] || [ "$AUTO_RESTART" == "y" ]; then
		while [ true ]; do
			WAIT_CACHE=$WAIT_PAUSE
			echo
			echo "[*] Press Ctrl+Z during the countdown to stop the server"
			
			echo -n "[*] Wait "
			while [ "$WAIT_CACHE" -gt "0" ]; do
				echo -n "$WAIT_CACHE..."
				((WAIT_CACHE--))
				sleep 1
			done
			
			echo
			echo "[*] Restarted server!"
			echo
			
			$PHP_BINARY $KERNEL ${OPTS[@]}
		done
	else
		$PHP_BINARY $KERNEL ${OPTS[@]}
	fi
}

defineBinary
defineKernel
set +e
startServer
