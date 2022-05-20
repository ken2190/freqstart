#!/bin/bash
clear
# https://github.com/berndhofer/freqstart
#
# Since this is a small project where I taught myself some bash scripts,
# you are welcome to improve the code. If you just use the script and like it,
# remember that it took a lot of time, testing and also money for infrastructure.
# You can contribute by donating to the following wallets.
# Thank you very much for that!
#
# BTC 1M6wztPA9caJbSrLxa6ET2bDJQdvigZ9hZ
# ETH 0xb155f0F64F613Cd19Fb35d07D43017F595851Af5
# BSC 0xb155f0F64F613Cd19Fb35d07D43017F595851Af5
#
readonly scriptname=$(realpath $0); readonly scriptpath=$(dirname "${scriptname}")
readonly service='freqstart.service'
readonly proxy='binance-proxy'
readonly autostart="${scriptpath}"'/autostart.txt'

# freqstart does not include any forked code and we grab the latest or specific version from each git repo as needed
readonly freqtrade_repo=('freqtrade' 'freqtrade/freqtrade') # https://github.com/freqtrade/freqtrade
readonly nfi_repo=('NostalgiaForInfinity' 'iterativv/NostalgiaForInfinity') # https://github.com/iterativv/NostalgiaForInfinity
readonly proxy_repo=('binance-proxy' 'nightshift2k/binance-proxy') # https://github.com/nightshift2k/binance-proxy
readonly git_repos=(
  freqtrade_repo[@]
  nfi_repo[@]
  proxy_repo[@]
)

function _hash {
	echo $(cat /dev/urandom \
		| tr -dc 'a-zA-Z0-9' \
		| fold -w 32 \
		| head -n 1)
}

function _date {
	echo $(date +%y%m%d%H)
}

function _invalid {
	echo '# ERROR: Invalid response! Better stop here if you can not read anyway...'
}

function _path {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	path="${1}"
	if [[ -z $(echo "${path}" | grep -o '/') ]]; then
		# because we are lazy, set the scriptpath if no directory is found
		path="${scriptpath}"'/'"${path}"
	fi
	path_name=$(basename "${path}" | sed 's#_.*##')
	path_version=$(basename "${path}" | grep -o '_.*' | sed 's#_##')	

	_git_repo
	if [[ "$?" -eq 0 ]]; then
		# if there is a version set, we try to get it from the git archive
		if [[ ! -z "${path_version}" ]]; then
			_git_archive
			if [[ "$?" -eq 0 ]]; then
				return 0
			else
				return 1
			fi
		else
		# if there is no version, we grep it from a cached json
			_git_latest
			if [[ "$?" -eq 0 ]]; then
				return 0
			else
				return 1
			fi
		fi
	else
		# maybe i add more strategies, should work with any, recommend some
		echo '# ERROR: "'"${path_name}"'" git repo not found.'
		return 1
	fi
}

function _git_repo {	
	local count=${#git_repos[@]}
	for ((i=0; i<$count; i++)); do
		local git_name=${!git_repos[i]:0:1}
		local git_value=${!git_repos[i]:1:1}

		if [[ "${path_name}" == "${git_name}" ]]; then
			git_latest='https://api.github.com/repos/'"${git_value}"'/releases/latest'
			git_latest_tmp='/tmp/'"${path_name}"'_'"$(_date)"'.json'
			git_archive='https://github.com/'"${git_value}"'/archive/refs/tags/'"${path_version}"'.tar.gz'
			
			# we only return 0 and that cost me 3h to figure it out
			return 0
		fi
	done
}

function _git_archive {
	if [[ ! -d "${path}" ]]; then
		_git_download "${git_archive}"
	else
		if [[ -z "$(ls -A ${path})" ]]; then
			rm -rf "${path}"
			_git_download "${git_archive}"
		else
			# less verbose; echo '# "'"${path_name}"'" version "'"${path_version}"'" already downloaded.'
			return 0
		fi
	fi
}

function _git_latest {
	path_latest=$(ls -d "${path}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)
	# somethimes you quit an installation and want to resume it
	path_previous=''
	if [[ ! -z "${path_latest}" ]]; then
		path_previous=$(ls -d "${path}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -2 | tail -1)
	fi	
	path_latest_version=$(basename "${path_latest}" | sed 's#.*_##')

	_git_latest_version
	if [[ "$?" -eq 0 ]]; then
		# what is an easier version check if a string just has to be the same
		if [[ "${path_latest_version}" == "${git_latest_version}" ]]; then
			echo '# "'"${path_name}"'" latest version "'"${git_latest_version}"'" already downloaded.'
			
			path_version="${path_latest_version}"
			path="${path}"'_'"${path_version}"
			
			return 0
		else
			path_version="${git_latest_version}"
			path="${path}"'_'"${path_version}"
			
			local browser_download_url=$(cat "${git_latest_tmp}" \
				| grep -o -E '"browser_download_url": "(.*)Linux_x86_64.tar.gz"' \
				| sed 's/"browser_download_url": "//' \
				| sed 's/"//')
			local tarball_url=$(cat "${git_latest_tmp}" \
				| grep -o '"tarball_url": ".*"' \
				| sed 's/"tarball_url": "//' \
				| sed 's/"//')
			
			# downloading the precompiled linux version if available as a workaround for the proxy
			if [[ ! -z "${browser_download_url}" ]]; then
				local git_latest_file="${browser_download_url}"
			else
				local git_latest_file="${tarball_url}"
			fi
				
			_git_download "${git_latest_file}"
		fi
	# so basically we could not get a new version but we try it with the one that worked before
	elif [[ ! -z "${path_latest_version}" ]]; then
		echo '# WARNING: "'"${path_name}"'" latest git version not found. Trying local version "${path_latest_version}" instead.'

		path_version="${path_latest_version}"
		path="${path}"'_'"${path_version}"
		
		return 0
	else
		echo '# ERROR: "'"${path_name}"'" latest git not reachable. Retry again!'
		exit 1
	fi
}

function _git_latest_version {
	# we chache that info for 1h to avoid spamming git
	if [[ ! -f "${git_latest_tmp}" ]]; then
		curl -o "${git_latest_tmp}" -s -L "${git_latest}"
	fi
	
	if [[ -f "${git_latest_tmp}" ]]; then
		git_latest_version=$(cat "${git_latest_tmp}" \
			| grep -o '"tag_name": ".*"' \
			| sed 's/"tag_name": "//' \
			| sed 's/"//')
		return 0
	else
		return 1
	fi
}

function _git_download {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	local file="${1}"
	local tmp="/tmp/${path_name}_${path_version}_$(_hash)"

	if [[ $(wget -S --spider "${file}" 2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
		mkdir -p "${tmp}"
		wget -qO- "${file}" \
			| tar xz -C "${tmp}"
		mkdir -p "${path}"
				
		if [[ "$(find ${tmp} -maxdepth 1 -printf %y)" = "dd" ]]; then
			# only one subdir, i hate cp; https://stackoverflow.com/a/32429482
			local tmp_sub=$(find ${tmp} -mindepth 1 -maxdepth 1 -type d)
			cp -R "${tmp_sub}"/. "${path}"
		else
			cp -R "${tmp}"/. "${path}"
		fi
		
		# keep tmp clean, save the environment
		rm -rf "${tmp}"
		# switched to 1h checks; rm -f "${git_latest_tmp}"

		if [[ -d "${path}" && ! -z "$(ls -A ${path})" ]]; then
			echo '# "'"${path_name}"'" version "'"${path_version}"'" downloaded.'
			return 0
		else
			echo '# FATAL: "'"${path_name}"'" version "'"${path_version}"'" download failed. Retry again!'
			rm -rf "${path}"
			exit 1
		fi
	else
		echo '# ERROR: "'"${path_name}"'" version "'"${path_version}"'" file not found. Retry again!'
		return 1
	fi
}

function _strategy {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	local strategy=$(echo "${1}" | grep -e '--strategy-path=.*' | sed 's#--strategy-path=##')
	if [[ ! -z "${strategy}" ]]; then
		_path "${strategy}"
		if [[ "$?" -eq 0 ]]; then
			_git_latest_version
			if [[ "$?" -eq 0 ]]; then
				# we are all to lazy to check some git repo for a newer version that plays with our money
				if [[ "${path_latest_version}" != "${git_latest_version}" ]]; then
					echo '# Newer "'"${path_name}"'" version "'"${git_latest_version}"'" available.'
				fi
			fi
			return 0
		else
			return 1
		fi
	fi
}

function _env_deactivate {
	if [ -n "${VIRTUAL_ENV}" ]; then
		deactivate
    fi
}

function _apt {
	if [[ ! -f "${scriptpath}/update.txt" ]]; then
		string=''
		string+='Installed unattended-upgrades. Remove file to update server again.'
		printf "${string}" > "${scriptpath}/update.txt";
		
		# update your environment for safety and get prerequisites, thanks to TheJuice
		sudo apt update && \
		sudo apt install -y python3-pip python3-venv python3-dev python3-pandas git curl && \
		sudo apt -o Dpkg::Options::="--force-confdef" dist-upgrade -y && \
		sudo apt install -y unattended-upgrades && \
		sudo apt autoremove -y && \
		if sudo test -f /var/run/reboot-required; \
		then read -p "A reboot is required to finish installing updates. Press [ENTER] to reboot now, or [CTRL+C] to cancel and reboot later." && \
		sudo reboot; \
		else echo "A reboot is not required. Exiting..."; fi
	fi
}

function _freqtrade {
	_path 'freqtrade'
	if [[ "$?" -eq 0 ]]; then
		_freqtrade_installed
		if [[ "$?" -eq 1 ]]; then
			if [[ ! -z "${path_latest_version}" ]]; then
				while true; do
					echo '-----'
					read -p '# Stop all bots and install newer "'"${path_name}"'" version "'"${git_latest_version}"'" and copy sqlite databases? (y/n) ' _yn
					case ${_yn} in 
						[yY])
							# if you have any custom stuff done, you better check manually
							_freqtrade_update
							break;;
						[nN])
							break;;
						*)
							_invalid
							;;
					esac
				done
			fi
			_freqtrade_setup
		else
			# less verbose; echo '# "'"${path_name}"'" is already installed.'
			return 0
		fi
	else
		return 1
	fi
}

function _freqtrade_update {
	_kill
	
	# get that precious sqlite databases into the newest install
	if [[ ! -z "${path_previous}" ]]; then
		local path_latest="${path_previous}"
	fi
	
	if [[ ! -z $(find "${path_latest}" -type f | grep 'sqlite$') ]]; then
		echo '# Copy sqlite databases from "'"${path_latest}"'" to "'"${path}"'" now:'

		for sqlite_path in $(find "${path_latest}" -type f | grep 'sqlite$'); do

			# copy files with -a so they keep their metadata
			cp -a "${sqlite_path}" "${path}"
			
			local sqlite_file=$(basename "${sqlite_path}")
			
			# check if copy actually exists and exit if there is a problem
			if [[ -f "${path}/${sqlite_file}" ]]; then
				echo '- "'"${sqlite_file}"'" copied...'
			else				
				sudo rm -rf "${path}"
				echo '# ERROR: Can not popy sqlite databases. Retry again!'
				exit 1
			fi
		done
		return 0
	else
		# so you installed it and did not do anything until this release, better git pull freqstart too
		echo '# No sqlite databases in "'"${path_latest}"'" found.'
		return 0
	fi
}

function _freqtrade_setup {
	# i prefer it bare instead of docker
	sudo chmod +x "${path}/setup.sh"
	
	echo '# Installing "'"${path_name}"'" may take some time, please be patient...'
	cd "${path}"
	# yes means no and no means i dont want that extra stuff to be installed
	yes $'no' | sudo ./setup.sh -i >/dev/null 2>&1
	
	# actually dont know if pandas-ta comes with the setup, but try to install it anyway
	echo '# Installing "pandas-ta" may take some time, please be patient...'
	
	cd "${path}"
	_env_deactivate
	python3 -m venv .env >/dev/null 2>&1
	source .env/bin/activate
	python3 -m pip install --upgrade pip >/dev/null 2>&1
	python3 -m pip install -e . >/dev/null 2>&1
	pip install pandas-ta >/dev/null 2>&1
	_env_deactivate
			
	_freqtrade_installed
	if [[ "$?" -eq 1 ]]; then	
		# if somethings not right, better delete it
		sudo rm -rf "${path}"
		echo '# ERROR: "'"${path_name}"'" not installed. Retry again!'
		exit 1
	else
		# phew, we made it
		echo '# "'"${path_name}"'" version "'"${path_version}"'" successfully installed.'
		echo '-'		
		return 0
	fi
}

function _freqtrade_installed {
	# -x command doesnt work, this does
	if [[ ! -z $(cd "${path}"; source .env/bin/activate 2>/dev/null; freqtrade --version 2>/dev/null | sed 's/freqtrade //') ]]; then
		return 0
	else
		return 1
	fi
}

function _config {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi

	local config="${1}"

	if [[ ! -z $(echo "${config}" | grep -e '-c=' -e '--config=') ]]; then
		local config=$(echo "${config}" | sed 's#-c=##' | sed 's#--config=##')
		if [[ ! -f "${config}" ]]; then
			# so you basically dont know where you saved your api keys on a foreign could infrastructure, great...
			echo '# ERROR: Config "'"${config}"'" not found.'
			return 1
		else
			return 0
		fi
	fi
}

function _tmux {
	# screen is lame
	if [[ ! -x "$(command -v tmux)" ]]; then
		sudo apt-get update -y >/dev/null
		sudo apt-get install -y tmux >/dev/null
		
		if [[ ! -x "$(command -v tmux)" ]]; then
			echo "# ERROR: TMUX not installed."
			exit 1
		fi
	fi
}

function _tmux_session {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi

	tmux has-session -t "${1}" 2>/dev/null
	if [[ "$?" -eq 0 ]]; then
		return 0
	else
		return 1
	fi
}

function _proxy_json {
	if [[ ! -f "${scriptpath}/proxy.json" ]]; then
		string=$(cat <<-END
			{
			    "exchange": {
			        "name": "binance",
			        "ccxt_config": {
			            "enableRateLimit": false,
			            "urls": {
			                "api": {
			                    "public": "http://127.0.0.1:8090/api/v3"
			                }
			            }
			        },
			        "ccxt_async_config": {
			            "enableRateLimit": false
			        }
			    }
			}
		END
		)
		
		printf "${string}" > "${scriptpath}/proxy.json";
		
		if [[ ! -f "${scriptpath}/proxy.json" ]]; then
			echo '# ERROR: Can not create "'"${path_name}"'" config.'
			exit 1
		else
			echo '# "'"${path_name}"'" config created.'
			return 0
		fi
	else
		# less verbose; echo '# "'"${path_name}"'" config found.'
		return 0
	fi
}

function _proxy_tmux {
	_tmux_session "${path_name}"
	if [[ "$?" -eq 1 ]]; then
		/usr/bin/tmux new -s "${path_name}" -d
		/usr/bin/tmux send-keys -t "${path_name}" "${path}/${path_name} -v" Enter
		
		_tmux_session "${path_name}"
		if [[ "$?" -eq 1 ]]; then
			echo '# ERROR: Can not start "'"${path_name}"'" tmux session.'
			return 1
		else
			echo '# New "'"${path_name}"'" tmux session startet.'
			return 0
		fi
	else
		# less verbose; echo '# "'"${path_name}"'" tmux session is running.'
		return 0
	fi
}

function _proxy {
	_path "${proxy}"
	if [ "$?" -eq 0 ] ; then

		if [[ ! -z "${git_latest_version}" ]] && [[ "${git_latest_version}" != "${path_latest_version}" ]]; then
			echo '# New "'"${path_name}"'" "'"${path_version}"'" has been downloaded.'
			
			if [[ ! -x "${path}"'/'"${path_name}" ]]; then
				sudo chmod +x "${path}"'/'"${path_name}"
			fi
			
			_tmux_session "${path_name}"
			if [ "$?" -eq 0 ] ; then
				echo '# WARNING: Restarting "'"${path_name}"'" tmux session. Review all running bots!'
				tmux kill-session -t "${path_name}"
			fi
		fi
		_proxy_tmux
		_proxy_json
	fi
}

function _service_disable {
	# on your own now, cowboy
	if [[ ! -z "${service}" ]]; then			
		sudo rm -f "${scriptpath}/${service}"
		sudo systemctl stop "${service}" &>/dev/null
		sudo systemctl disable "${service}" &>/dev/null
		sudo rm -f "/etc/systemd/system/${service}"
		sudo systemctl daemon-reload &>/dev/null
		sudo systemctl reset-failed &>/dev/null
	fi
}

function _service_enable {
	# we keep it running, hopefully
	if [[ ! -z "${service}" ]]; then			
		sudo systemctl daemon-reload &>/dev/null
		sudo systemctl reset-failed &>/dev/null
		sudo systemctl enable "${service}" &>/dev/null
		
		systemctl is-enabled --quiet "${service}"
		if [[ ! "${?}" -eq 0 ]]; then
			echo '# ERROR: Service "'"${service}"'" is not enabled.'
			exit 1
		fi
	fi
}

function _service {
	if [[ ! -z "${service}" ]]; then
		# removing service everytime in case there is an update
		_service_disable
		
		if [ ! -f "${scriptpath}/${service}" ]; then
			string=$(cat <<-END
			[Unit]
			Description=freqstart
			After=network.target

			[Service]
			Environment=DISPLAY=:0
			Type=forking
			ExecStartPre=/bin/sleep 5
			ExecStart=${scriptpath}/freqstart.sh -a
			KillMode=control-group

			[Install]
			WantedBy=default.target
			END
			)
			printf "${string}" > "${scriptpath}/${service}"
			
			sudo systemctl link "${scriptpath}/${service}" &>/dev/null
		fi	

		_service_enable
	fi
}

function _ntp {
	# dont run any bots on unsynced servers, also perfer UTC for binance and im forcing you to it now
	local timentp=$(timedatectl | grep -q 'NTP service: active')
	local timeutc=$(timedatectl | grep -q 'Time zone: UTC (UTC, +0000)')
	local timesyn=$(timedatectl | grep -q 'System clock synchronized: yes')
	if [[ ! -z "${timentp}" ]] || [[ ! -z  "${timeutc}" ]] || [[ ! -z  "${timesyn}" ]]; then
		sudo apt-get update
		sudo apt-get install -y chrony
		sudo systemctl stop chronyd
		sudo timedatectl set-timezone 'UTC'
		sudo systemctl start chronyd
		sudo timedatectl set-ntp true
		sudo systemctl restart chronyd
	fi
	if [[ ! -z "${timentp}" ]] || [[ ! -z  "${timeutc}" ]] || [[ ! -z  "${timesyn}" ]]; then
		echo "# ERROR: NTP not active or not synchronized."
	fi
}

function _autostart {
	# a proxy a day, keeps the ip ban away
	_proxy
	
	# we grab the latest local freqtrade version, do not alter those folder names and version numbers
	local freqtrade=$(ls -d "${scriptpath}"/freqtrade_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)

	if [[ ! -f "${autostart}" ]]; then
		string=''
		string+='# EXAMPLE:\n'
		string+='# freqtrade trade --dry-run --db-url sqlite:///example-dryrun.sqlite --strategy=NostalgiaForInfinityX --strategy-path='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000 -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/pairlist-volume-binance-usdt.json -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/blacklist-binance.json -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/exampleconfig.json -c='"${scriptpath}"'/proxy.json\n'		
		string+='# To test new strategies including dryrun, create a sandbox account with API credentials -> https://testnet.binance.vision/'
		printf "${string}" > "${autostart}"
		
		if [[ ! -f "${autostart}" ]]; then
			echo '# ERROR: '"${autostart}"' does not exist.'
			exit 1
		fi
	fi
	
	# grab that list of bots
	set -f; readarray -t bots < "${autostart}"

	string=''
	string+='-----\n'
	string+='# Starting Freqtrade Trading Bots...\n'
	string+='-----\n'
	string+='# Type "tmux a" to attach to latest TMUX session.\n'
	string+='# Use "ctrl+b s" to switch between TMUX sessions.\n'
	string+='# Use "ctrl+b d" to return to shell.\n'
	string+='# Type "'$(basename "${scriptname}")' -k" to disable all bots and restart service.\n'
	string+='-----\n'
	printf -- "${string}"
	
	# since you probably did some nono, we double check it for you
	for bot in "${bots[@]}"; do		
		local error=0
	
		if [[ ! -z $(echo "${bot}" | grep -o -E '^freqtrade') ]]; then
			local bot_name=$(echo "${bot}" | grep -o -E 'sqlite(.*)sqlite' | sed 's#.sqlite##' | sed 's#sqlite:///##')
			
			string=''
			string+='# '"${bot}"'\n'
			string+='-\n'
			printf -- "${string}"  

			set -f; local arguments=("${bot}") # its working, dont know why; https://stackoverflow.com/a/15400047
			for argument in ${arguments[@]}; do

				_config "${argument}"
				if [ "$?" -eq 1 ] ; then
					local error=1
				fi
				
				_strategy "${argument}"
				if [ "$?" -eq 1 ] ; then
					local error=1
				fi
			done
			
			if [[ -z "${bot_name}" ]]; then
				echo '# ERROR: Override trades database URL.'
				local error=1
			fi
			
			if [[ "${bot_name}" =~ ['!@#$%^&*()_+.'] ]]; then
				echo '# ERROR: Do not use special characters in database URL name.'
				local error=1
			fi
			
			if [[ -z $(echo "${bot}" | grep -e '--strategy-path=') ]]; then
				echo "# ERROR: --strategy-path is missing."
				local error=1
			fi
			
			if [[ -z $(echo "${bot}" | grep -e '--strategy=') ]]; then
				echo "# ERROR: --strategy is missing."
				local error=1
			fi
						
			_tmux_session "${bot_name}"
			if [ "$?" -eq 0 ] ; then
				echo '# WARNING: Sqlite "'"${bot_name}"'" already active. Rename database URL name!'
				local count=$((count+1))
				local error=1
			fi

			if [[ "${error}" -eq 0 ]]; then
				# exec bot to close session if script stops 
				/usr/bin/tmux new -s "${bot_name}" -d	
				/usr/bin/tmux send-keys -t "${bot_name}" "cd ${freqtrade}" Enter
				/usr/bin/tmux send-keys -t "${bot_name}" ". .env/bin/activate" Enter
				/usr/bin/tmux send-keys -t "${bot_name}" "exec ${bot}" Enter
				
				_tmux_session "${bot_name}"
				if [[ "$?" -eq 0 ]]; then
					# double check if tmux session started, no guarantee that the bot is actually running
					echo '# Bot "'"${bot_name}"'" started.'
				fi
			fi
			
			echo '-----'
		fi
	done
	
	# tripple check if bot and proxy tmux sessions actually started, because even software can tell you lies
	_autostart_check
	
	echo '-----'
	_stats
}

function _autostart_check {
	# count the number of bot and proxy tmux sessions, so you dont have to stress your fingers
	local count_bots=$(tmux list-panes | wc -l)
	local count_bots="$((count_bots))"

	_tmux_session "${proxy}"
	if [[ "$?" -eq 0 ]]; then
		local check_proxy=' and 1 "'"${proxy}"'"'
		local count_bots="$((count_bots - 1))"
	fi	
	if (( "$((count_bots))" <= 0 )); then
		echo '# WARNING: No active bots found. Review "'"${autostart}"'" file and remeber: one bot per line!'
		return 1
	else
		echo '# There are "'"$((count_bots))"'" active freqtrade bots'"${check_proxy}"'.'
		return 0
	fi
}

function _kill {
	tmux kill-session -t "${proxy}" 2>/dev/null
	while [[ ! -z $(tmux list-panes -F "#{pane_id}" 2>/dev/null) ]]; do
		# trying to gracefully stop all bots; https://unix.stackexchange.com/a/568928 
		tmux list-panes -F "#{pane_id}" | xargs -I {} tmux send-keys -t {} C-c &
		# a hundred tries are enough
		((c++)) && ((c==100)) && break
		# give it a little bit of time
		sleep 0.1
	done
	if [[ ! -z $(tmux list-panes -F "#{pane_id}" 2>/dev/null) ]]; then
		# kill the rest
		tmux kill-server 2>/dev/null
	fi
	_service_disable
	echo "# WARNING: All bots stopped and restart service is disabled."
}

function _stats {
	# some handy stats to get you an impression how your server compares to the current possibly best location for binance
	local ping=$(ping -c 1 -w15 api3.binance.com | awk -F '/' 'END {print $5}')
	local mem_free=$(free -m | awk 'NR==2{print $4}')
	local mem_total=$(free -m | awk 'NR==2{print $2}')
	local time=$((time curl -X GET "https://api.binance.com/api/v3/exchangeInfo?symbol=BNBBTC") 2>&1 > /dev/null \
		| grep -o 'real.*s' \
		| sed 's#real	##')
	echo '# Ping avg. (Binance): '"${ping}"'ms | Vultr "Tokyo" Server avg.: 1.290ms'
	echo '# Time to API (Binance): '"${time}"' | Vultr "Tokyo" Server avg.: 0m0.039s'
	echo '# Free memory (Server): '"${mem_free}"'MB  (max. '"${mem_total}"'MB) | Vultr "Tokyo" Server avg.: 2 bots with 100MB free memory (1GB)'
	echo '# Get closer to Binance? Try Vultr "Tokyo" Server and get $100 usage for free: https://www.vultr.com/?ref=9122650-8H'
	echo '-----'
}

function _start {
	# the sequence does matter for apt and autostart
	_apt
	_tmux
	_ntp
	_freqtrade
	_service
	_autostart
}

if [[ ! -z "$*" ]]; then
	for i in "$@"; do
		case $i in
			-a|--autostart)
				_autostart
			;;
			-k|--kill)
				_kill
			;;
			-*|--*)
				echo_block "# ERROR: Unknown option ${i}"
				exit 1
			;;
			*)
				echo_block "# ERROR: Unknown option ${i}"
				exit 1
			;;
		esac
	done
else
	# so here we are, even starting it automatically for you, so you dont have to even type some additional commands
	_start
fi

exit 0