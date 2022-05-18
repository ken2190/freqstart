#!/bin/bash
clear
#
# Since this is a small project where I taught myself some bash scripts,
# you are welcome to improve the code. If you just use the script and like it,
# remember that it took a lot of time, testing and also money for infrastructure.
# You can contribute by donating to the following wallets.
# Thank you very much for that!

# BTC 1M6wztPA9caJbSrLxa6ET2bDJQdvigZ9hZ
# ETH 0xb155f0F64F613Cd19Fb35d07D43017F595851Af5
# BSC 0xb155f0F64F613Cd19Fb35d07D43017F595851Af5
#
readonly scriptname=$(realpath $0); readonly scriptpath=$(dirname "${scriptname}")
readonly service='freqstart.service'
readonly freqtrade_repo="freqtrade/freqtrade"
readonly nfi_repo="iterativv/NostalgiaForInfinity"

function _hash {
	echo $(cat /dev/urandom \
		| tr -dc 'a-zA-Z0-9' \
		| fold -w 32 \
		| head -n 1)
}

function _path {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	path="${1}"
	path_name=$(basename "${path}" | sed 's#_.*##')
	path_version=$(basename "${path}" | grep -o '_.*' | sed 's#_##')	
	path_latest=$(ls -d "${scriptpath}"/"${path_name}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)
	path_latest_version=$(basename "${path_latest}" | sed 's#.*_##')
	git_repo=$(_git_repo)
	git_latest='https://api.github.com/repos/'"${git_repo}"'/releases/latest'
	git_latest_tmp='/tmp/'"${path_name}"'_'"$(_hash)"'.json'
	git_latest_file=''
	git_latest_version=''
	git_archive='https://github.com/'"${git_repo}"'/archive/refs/tags/'"${path_version}"'.tar.gz'

	if [[ ! -z "${git_repo}" ]]; then
		if [[ ! -z "${path_version}" ]]; then
			_git_archive
			if [[ "$?" -eq 0 ]]; then
				return 0
			else
				return 1
			fi
		else
			_git_latest
			if [[ "$?" -eq 0 ]]; then
				return 0
			else
				return 1
			fi
		fi
	else
		echo '# ERROR: "'"${path_name}"'" git repo not found.'
		return 1
	fi
}

function _git_repo {
	if [[ "${path_name}" == 'NostalgiaForInfinity' ]]; then
		echo "${nfi_repo}"
	elif [[ "${path_name}" == 'freqtrade' ]]; then
		echo "${freqtrade_repo}"
	else
		echo ''
	fi
}

function _git_validate {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	local file="${1}"
	if [[ $(wget -S --spider "${file}" 2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
		return 0
	else
		return 1
	fi
}

function _git_download {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	local file="${1}"

	_git_validate "${file}"
	if [[ "$?" -eq 0 ]]; then
		echo "file ------ ${file}"
		if [[ ! -z "${git_latest_version}" ]]; then
			path_version="${git_latest_version}"
		fi
		
		path="${scriptpath}"'/'"${path_name}"'_'"${path_version}"

		mkdir -p "${path}"
		wget -qO- "${file}" \
			| tar xz -C "${path}" --strip-components=1
			
			if [[ -d "${path}" && ! -z "$(ls -A ${path})" ]]; then
				return 0
			else
				rm -rf "${path}"
				return 1
			fi
	else
		echo '# ERROR: "'"${path_name}"'" version "'"${path_version}"'" does not exist.'
		return 1
	fi
}

function _git_archive {
	if [[ ! -d "${path}" ]]; then
		_git_download "${git_archive}"
		if [[ "$?" -eq 0 ]]; then
			echo '# INFO: "'"${path_name}"'" version "'"${path_version}"'" downloaded.'
			return 0
		else
			echo '# ERROR: "'"${path_name}"'" version "'"${path_version}"'" not downloaded.'
			return 1
		fi
	else
		echo '# INFO: "'"${path_name}"'" version "'"${path_version}"'" already downloaded.'
		return 0
	fi
}

function _git_latest_version {
	git_latest_version=$(cat "${git_latest_tmp}" \
		| grep -o '"tag_name": ".*"' \
		| sed 's/"tag_name": "//' \
		| sed 's/"//')
		
	if [[ ! -z "${git_latest_version}" ]] && [[ "${path_latest_version}" != "${git_latest_version}" ]]; then
		return 0
	else
		return 1
	fi
}

function _git_latest_tmp {
	curl -o "${git_latest_tmp}" -s -L "${git_latest}"
	if [[ -f "${git_latest_tmp}" ]]; then
		return 0
	else
		return 1
	fi
}

function _git_latest {
	_git_latest_tmp
	if [[ "$?" -eq 0 ]]; then
		_git_latest_version
		if [[ "$?" -eq 0 ]]; then
			_git_latest_file
			if [[ "$?" -eq 0 ]]; then
				_git_download "${git_latest_file}"
				if [[ "$?" -eq 0 ]]; then
					echo '# INFO: "'"${path_name}"'" latest version "'"${git_latest_version}"'" downloaded.'
					return 0
				else
					echo '# ERROR: "'"${path_name}"'" latest version "'"${git_latest_version}"'" not downloaded.'
					return 1
				fi
			else
				echo '# ERROR: "'"${path_name}"'" latest version "'"${git_latest_version}"'" file not found.'
				return 1
			fi
		else
			echo '# INFO: "'"${path_name}"'" latest version "'"${git_latest_version}"'" already downloaded.'
			return 0
		fi
	else
		echo '# ERROR: "'"${path_name}"'" latest version "'"${git_latest_version}"'" not found.'
		return 1
	fi
}

function _git_latest_file {
	local browser_download_url=$(cat "${git_latest_tmp}" \
		| grep -o -E '"browser_download_url": "(.*)Linux_x86_64.tar.gz"' \
		| sed 's/"browser_download_url": "//' \
		| sed 's/"//')
	local tarball_url=$(cat "${git_latest_tmp}" \
		| grep -o '"tarball_url": ".*"' \
		| sed 's/"tarball_url": "//' \
		| sed 's/"//')
	
	if [[ ! -z "${browser_download_url}" ]]; then
		git_latest_file="${browser_download_url}"
	else
		git_latest_file="${tarball_url}"
	fi
		
	_git_validate "${git_latest_file}"
	if [[ "$?" -eq 0 ]]; then
		return 0
	else
		return 1
	fi
}






function _strategy {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	local strategy="${1}"
	
	if [[ ! -z $(echo "${strategy}" | grep -e '--strategy-path=') ]]; then
		_path "${strategy}"
		if [[ "$?" -eq 0 ]]; then
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

function _freqtrade_installed {
	if [[ ! -x $(cd "${path}"; \
		source .env/bin/activate 2>/dev/null; \
		command -v freqtrade) ]]; then
		return 0
	else
		return 1
	fi
}

function _freqtrade {
	_path 'freqtrade'
	if [[ "$?" -eq 0 ]]; then
		
		_freqtrade_installed
		if [[ "$?" -eq 1 ]]; then

			sudo chmod +x "${path}/setup.sh"
			
			echo '# INFO: Installing "'"${path_name}"'" may take some time...'
			cd "${path}"
			yes $'no' | sudo ./setup.sh -i >/dev/null 2>&1
				
			echo '# INFO: Installing "pandas-ta" may take some time...'
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
				echo '# ERROR: "'"${path_name}"'" not installed. Restart and try again.'
				sudo rm -rf "${path}"
				exit 1
			else
				echo '# INFO: "'"${path_name}"'" installed.'
				return 0
			fi
		else
			return 0
		fi
	else
		exit 1
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

function _nfi {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	local nfi="${1}"
	
	if [[ ! -z $(echo "${nfi}" | grep -e '--strategy-path=') ]]; then
		local nfi_name='NostalgiaForInfinity'
		local nfi_path=$(echo "${nfi}" | sed 's#--strategy-path=##')
		local nfi_version=$(basename "${nfi_path}" | sed 's#.*_##')
		local nfi_git="https://github.com/iterativv/NostalgiaForInfinity/archive/refs/tags/${nfi_version}.tar.gz"
		local nfi_latest="https://api.github.com/repos/iterativv/NostalgiaForInfinity/releases/latest"
		
		if [[ ! -z $(echo "${nfi}" | grep -o -E '.*'"${nfi_name}"'.*') ]]; then
			local nfi_latest_version=$(curl -s "${nfi_latest}" | grep -o '"tag_name": ".*"' \
				| sed 's/"tag_name": "//' \
				| sed 's/"//')

			if [[ ! -z "${nfi_version}" ]]; then
				if [[ ! -d "${nfi_path}" || -z "$(ls -A ${nfi_path})" ]]; then
					if _git_validate "${nfi_git}"; then
						mkdir -p "${nfi_path}"
						wget -qO- "${nfi_git}" \
							| tar xz -C "${nfi_path}" --strip-components=1
						if [[ -d "${nfi_path}" || ! -z "$(ls -A ${nfi_path})" ]]; then
							echo '# INFO: Strategy "'"${nfi_version}"'" has been downloaded.'
						fi
					else
						echo '# ERROR: Strategy "'"${nfi_version}"'" not found. Try latest "'"${nfi_latest_version}"'" version.'
						return 1
					fi
				fi
			else
				echo '# ERROR: Strategy version is not set. Example: NostalgiaForInfinity_v00.0.000'
				return 1
			fi
			
			if [[ ! -z "${nfi_latest_version}" ]]; then
				if [[ "${nfi_latest_version}" != "${nfi_version}" ]]; then
					echo '# INFO: Newer strategy "'"${nfi_latest_version}"'" available. Always test new strategy versions first!'
				fi
			else
				echo '# WARNING: Can not get latest strategy version.'
			fi
		else
			if [[ ! -d "${nfi_path}" ]]; then
				echo '# ERROR: Strategy "'"${nfi_path}"'" not found.'
				return 1
			else
				echo '# INFO: Strategy does not contain "'"${nfi_name}"'" and must be manually verified.'
			fi
		fi
	fi
}

function _proxy {
	local proxy_name="binance-proxy"
	local proxy_path=$(ls -d "${scriptpath}"/"${proxy_name}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)
	local proxy_new_path=''
	local proxy_version=$(basename "${proxy_path}" | sed 's#.*_##')
	local git_latest="https://api.github.com/repos/nightshift2k/binance-proxy/releases/latest"
	local git_version=$(curl -s "${git_latest}" | grep -o '"tag_name": ".*"' \
		| sed 's/"tag_name": "//' \
		| sed 's/"//')
	local git_url=''

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
			echo '# WARNING: Proxy config does not exist.'
		fi
	fi

	if [[ ! -z "${git_version}" ]]; then
		if [[ "${git_version}" != "${proxy_version}" ]]; then
			local proxy_new_path="${scriptpath}/${proxy_name}_${git_version}"
			if [[ ! -d "${proxy_new_path}" ]]; then
				local git_url=$(curl -s "${git_latest}" \
					| grep -o -E '"browser_download_url": "(.*)Linux_x86_64.tar.gz"' \
					| sed 's/"browser_download_url": "//' \
					| sed 's/"//')
				if _git_validate "${git_url}"; then
					mkdir -p "${proxy_new_path}"
					wget -qO- "${git_url}" \
						| tar xz -C "${proxy_new_path}"
					if [[ -f "${proxy_new_path}/${proxy_name}" ]]; then
						echo '# INFO: New proxy "'"${git_version}"'" has been downloaded.'

						sudo chmod +x "${proxy_new_path}/${proxy_name}"
						local proxy_path="${proxy_new_path}"
						
						tmux has-session -t "${proxy_name}" 2>/dev/null
						if [ "$?" -eq 0 ] ; then
							tmux kill-session -t "${proxy_name}"
							echo '# WARNING: Restarting "'"${proxy_name}"'" tmux session. Review all running bots!'
						fi
					fi
				else
					echo '# ERROR: Can not download latest "'"${proxy_name}"'" file.'
				fi
			fi		
		fi
	else
		echo '# ERROR: Can not get latest "'"${proxy_name}"'" version.'
	fi
	
	if [[ -f "${proxy_path}/${proxy_name}" ]]; then
		tmux has-session -t "${proxy_name}" 2>/dev/null
		if [ ! "$?" -eq 0 ] ; then
			sudo /usr/bin/tmux new -s "${proxy_name}" -d
			sudo /usr/bin/tmux send-keys -t "${proxy_name}" "exec ${proxy_path}/${proxy_name} -v" Enter
			
			tmux has-session -t "${proxy_name}" 2>/dev/null
			if [ ! "$?" -eq 0 ] ; then
				echo '# ERROR: Can not start "'"${proxy_name}"'" tmux session.'
			fi
		fi
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
	_tmux
	_ntp
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
	
	_stats
	
	local count=0
	for bot in "${bots[@]}"; do		
		local error=0
	
		if [[ ! -z $(echo "${bot}" | grep -o -E '^freqtrade') ]]; then
			local botname=$(echo "${bot}" | grep -o -E 'sqlite(.*)sqlite' | sed 's#.sqlite##' | sed 's#sqlite:///##')
			
			string=''
			string+='# FREQTRADE:\n'
			string+='-\n'
			string+='# '"${bot}"'\n'
			string+='-\n'
			printf -- "${string}"  

			set -f; local arguments=("${bot}") #https://stackoverflow.com/a/15400047
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
			
			if [[ -z "${botname}" ]]; then
				echo '# ERROR: Override trades database URL.'
				local error=1
			fi
			
			if [[ "${botname}" =~ ['!@#$%^&*()_+.'] ]]; then
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
						
			tmux has-session -t "${botname}" 2>/dev/null
			if [ "$?" -eq 0 ] ; then
				echo '# ERROR: Sqlite "'"${botname}"'" already active. Rename database URL name!'
				local count=$((count+1))
				local error=1
			fi

			if [[ "${error}" -eq 0 ]]; then

				sudo /usr/bin/tmux new -s "${botname}" -d	
				sudo /usr/bin/tmux send-keys -t "${botname}" "cd ${freqtrade}" Enter
				sudo /usr/bin/tmux send-keys -t "${botname}" ". .env/bin/activate" Enter
				#sudo /usr/bin/tmux send-keys -t "${botname}" "exec ${bot}" Enter
				
				sudo tmux has-session -t "${botname}" 2>/dev/null
				if [ "$?" -eq 0 ] ; then
					local count=$((count+1))
					echo '# INFO: Freqtrade "'"${botname}"'" started.'
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
}

function _kill {
	while [[ ! -z $(tmux list-panes -F "#{pane_id}" 2>/dev/null) ]]; do
		#https://unix.stackexchange.com/a/568928
		tmux list-panes -F "#{pane_id}" | xargs -I {} tmux send-keys -t {} C-c &
		sleep 0.1
	done
	_service_disable
	echo "# INFO: All bots stopped and restart service disabled."
}

function _start {
	_apt
	_freqtrade
	#_service
	#_autostart
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
	echo '# Free memory (Server): '"${mem_free}"'MB from '"${mem_total}"'MB | Vultr "Tokyo" Server avg.: 2 bots with 77MB free memory (1GB)'
	echo '# Get closer to Binance? Try Vultr "Tokyo" Server and get $100 usage for free: https://www.vultr.com/?ref=9122650-8H'
	echo '-----'
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