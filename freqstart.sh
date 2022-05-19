#!/bin/bash
clear
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

readonly freqtrade_repo=('freqtrade' 'freqtrade/freqtrade')
readonly nfi_repo=('NostalgiaForInfinity' 'iterativv/NostalgiaForInfinity')
readonly proxy_repo=('binance-proxy' 'nightshift2k/binance-proxy')
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

function _path {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	path="${1}"
	if [[ -z $(echo "${path}" | grep -o '/') ]]; then
		# because we are lazy; set the scriptpath
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
			
			# we only return 0
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
			# less verbose; echo '# INFO: "'"${path_name}"'" version "'"${path_version}"'" already downloaded.'
			return 0
		fi
	fi
}

function _git_latest {
	path_latest=$(ls -d "${scriptpath}"/"${path_name}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)
	path_latest_version=$(basename "${path_latest}" | sed 's#.*_##')

	_git_latest_version
	if [[ "$?" -eq 0 ]]; then
		if [[ "${path_latest_version}" == "${git_latest_version}" ]]; then
			echo '# INFO: "'"${path_name}"'" latest version "'"${git_latest_version}"'" already downloaded.'
			
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
			
			if [[ ! -z "${browser_download_url}" ]]; then
				local git_latest_file="${browser_download_url}"
			else
				local git_latest_file="${tarball_url}"
			fi
				
			_git_download "${git_latest_file}"
		fi	
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
			echo '# INFO: "'"${path_name}"'" version "'"${path_version}"'" downloaded.'
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
				if [[ "${path_latest_version}" != "${git_latest_version}" ]]; then
					echo '# INFO: Newer "'"${path_name}"'" version "'"${git_latest_version}"'" available.'
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
		
		# update your environment
		sudo apt update && \
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

			sudo chmod +x "${path}/setup.sh"
			
			echo '# INFO: Installing "'"${path_name}"'" may take some time, please be patient...'
			cd "${path}"
			yes $'no' | sudo ./setup.sh -i >/dev/null 2>&1
				
			echo '# INFO: Installing "pandas-ta" may take some time, please be patient...'
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
				sudo rm -rf "${path}"
				echo '# ERROR: "'"${path_name}"'" not installed. Restart script!'
				exit 1
			else
				echo '# INFO: "'"${path_name}"'" install finished.'
				return 0
			fi
		else
			# less verbose; echo '# INFO: "'"${path_name}"'" is already installed.'
			return 0
		fi
	else
		return 1
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
			echo '# ERROR: Config "'"${config}"'" not found.'
			return 1
		else
			return 0
		fi
	fi
}

function _tmux {
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
			echo '# INFO: "'"${path_name}"'" config created.'
			return 0
		fi
	else
		# less verbose; echo '# INFO: "'"${path_name}"'" config found.'
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
			echo '# INFO: New "'"${path_name}"'" tmux session startet.'
			return 0
		fi
	else
		# less verbose; echo '# INFO: "'"${path_name}"'" tmux session is running.'
		return 0
	fi
}

function _proxy {
	_path "${proxy}"
	if [ "$?" -eq 0 ] ; then

		if [[ ! -z "${git_latest_version}" ]] && [[ "${git_latest_version}" != "${path_latest_version}" ]]; then
			echo '# INFO: New "'"${path_name}"'" "'"${path_version}"'" has been downloaded.'
			
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
	# dont run any bots on unsynced servers, also perfer UTC for binance
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
	_proxy
	
	local autostart="${scriptpath}/autostart.txt"
	local freqtrade=$(ls -d "${scriptpath}"/freqtrade_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)

	if [[ ! -f "${autostart}" ]]; then
		string=''
		string+='# EXAMPLE:\n'
		string+='# freqtrade trade --dry-run --db-url sqlite:///example-dryrun.sqlite --strategy=NostalgiaForInfinityX --strategy-path='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000 -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/pairlist-volume-binance-usdt.json -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/blacklist-binance.json -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/exampleconfig.json -c='"${scriptpath}"'/proxy.json\n'		
		string+='# INFO: To test new strategies including dryrun, create a sandbox account with API credentials -> https://testnet.binance.vision/'
		printf "${string}" > "${autostart}"
		
		if [[ ! -f "${autostart}" ]]; then
			echo '# ERROR: '"${autostart}"' does not exist.'
			exit 1
		fi
	fi

	set -f; readarray -t bots < "${autostart}"

	string=''
	string+='-----\n'
	string+='# Starting FREQTRADE bots...\n'
	string+='-----\n'
	string+='# Type "tmux a" to attach to latest TMUX session.\n'
	string+='# Use "ctrl+b s" to switch between TMUX sessions.\n'
	string+='# Use "ctrl+b d" to return to shell.\n'
	string+='# Type "'"${scriptname}"' -k" to disable all bots and service.\n'
	string+='-----\n'
	printf -- "${string}"
	
	local count=0
	for bot in "${bots[@]}"; do		
		local error=0
	
		if [[ ! -z $(echo "${bot}" | grep -o -E '^freqtrade') ]]; then
			local bot_name=$(echo "${bot}" | grep -o -E 'sqlite(.*)sqlite' | sed 's#.sqlite##' | sed 's#sqlite:///##')
			
			string=''
			string+='# FREQTRADE:\n'
			string+='-\n'
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
				sudo /usr/bin/tmux new -s "${bot_name}" -d	
				sudo /usr/bin/tmux send-keys -t "${bot_name}" "cd ${freqtrade}" Enter
				sudo /usr/bin/tmux send-keys -t "${bot_name}" ". .env/bin/activate" Enter
				sudo /usr/bin/tmux send-keys -t "${bot_name}" "exec ${bot}" Enter
				
				_tmux_session "${bot_name}"
				if [ "$?" -eq 0 ] ; then
					local count=$((count+1))
					echo '# INFO: Freqtrade "'"${bot_name}"'" started.'
				fi
			fi
			
			echo '-----'
		fi
	done
	
	if [[ "${count}" == 0 ]]; then
		echo '# WARNING: No freqtrate active bots found. Edit "'"${autostart}"'" file.'
	else
		echo '# INFO: There are "'"${count}"'" active freqtrade bots.'
	fi
	echo '-----'
	_stats
}

function _kill {
	tmux kill-session -t "${proxy}"
	while [[ ! -z $(tmux list-panes -F "#{pane_id}" 2>/dev/null) ]]; do
		# trying to gracefully stop all bots; https://unix.stackexchange.com/a/568928 
		tmux list-panes -F "#{pane_id}" | xargs -I {} tmux send-keys -t {} C-c &
		((c++)) && ((c==100)) && break
		sleep 0.1
	done
	if [[ ! -z $(tmux list-panes -F "#{pane_id}" 2>/dev/null) ]]; then
		# kill the rest
		tmux kill-server 2>/dev/null
	fi
	_service_disable
	echo "# INFO: All bots stopped and restart service disabled."
}

function _stats {
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
	_start
fi

exit 0