#!/bin/bash
clear
readonly scriptname=$(realpath $0); readonly scriptpath=$(dirname "${scriptname}")

function _git_validate {
  if [[ $(wget -S --spider $1 2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
    return 0
  else
    return 1
  fi
}
sudo apt install unattended-upgrades

function _apt {
	if [[ ! -f "${scriptpath}/autoupdate.txt" ]]; then
		sudo apt update && sudo apt -o Dpkg::Options::="--force-confdef" dist-upgrade -y && sudo apt install -y unattended-upgrades && sudo apt autoremove -y && if sudo test -f /var/run/reboot-required; then read -p "A reboot is required to finish installing updates. Press [ENTER] to reboot now, or [CTRL+C] to cancel and reboot later." && sudo reboot; else echo "A reboot is not required. Exiting..."; fi
		
		string=''
		string+='Installed unattended-upgrades. Remove file to update server again.'

		printf "${string}" > "${scriptpath}/autoupdate.txt";
	fi
}


function _tmux {
	if [[ ! -x "$(command -v tmux)" ]]; then
		sudo apt-get update -y >/dev/null
		sudo apt-get install -y tmux >/dev/null
		
		if [[ ! -x "$(command -v tmux)" ]]; then
			echo "ERROR: Can not install TMUX."
			exit 1
		fi
	fi
}

function _freqtrade {
	local name="freqtrade"
	local path=$(ls -d "${scriptpath}"/"${name}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)
	local path_new=''
	local version=$(basename "${path}" | sed 's#.*_##')
	local installed=''
	local git_latest="https://api.github.com/repos/freqtrade/freqtrade/releases/latest"
	local git_version=$(curl -s "${git_latest}" | grep -o '"tag_name": ".*"' \
		| sed 's/"tag_name": "//' \
		| sed 's/"//')
	local git_url=''
	
	if [[ ! -z "${git_version}" ]]; then
		if [[ "${git_version}" != "${version}" ]]; then
			local path_new="${scriptpath}/${name}_${git_version}"
			if [[ ! -d "${path_new}" ]]; then
				local git_url=$(curl -s "${git_latest}" \
					| grep -o '"tarball_url": ".*"' \
					| sed 's/"tarball_url": "//' \
					| sed 's/"//')

				if _git_validate "${git_url}"; then
					mkdir -p "${path_new}"
					wget -qO- "${git_url}" \
						| tar xz -C "${path_new}" --strip-components=1
					if [[ -f "${path_new}/setup.sh" ]]; then
						echo 'INFO: New version "'"${git_version}"'" has been downloaded.'
						sudo chmod +x "${path_new}/setup.sh"
						$(cd "${path_new}"; \
							source .env/bin/activate 2>/dev/null; \
							yes $'no' | sudo ./setup.sh -i 2>/dev/null)
						$(cd "${path_new}"; \
						source .env/bin/activate 2>/dev/null; \
						pip install pandas-ta; \
						deactivate)
						
						local path="${path_new}"
					fi
				else
					echo 'ERROR: Download "'"${git_latest}"'" does not exist.'
				fi
			fi		
		fi
	else
		echo 'ERROR: Can not get latest git version.'
	fi
	
	
	if [[ ! -x $(cd "${path}"; \
		source .env/bin/activate 2>/dev/null; \
		command -v freqtrade) ]]; then
		
		echo "ERROR: Freqtrade not installed."
		exit 1		
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
			echo 'WARNING: Proxy config does not exist.'
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
						echo 'INFO: New proxy "'"${git_version}"'" has been downloaded.'

						sudo chmod +x "${proxy_new_path}/${proxy_name}"
						local proxy_path="${proxy_new_path}"
						
						tmux has-session -t "${proxy_name}" 2>/dev/null
						if [ "$?" -eq 0 ] ; then
							tmux kill-session -t "${proxy_name}"
							echo 'WARNING: Restarting "'"${proxy_name}"'" tmux session. Review all running bots!'
						fi
					fi
				else
					echo 'ERROR: Download "'"${git_latest}"'" does not exist.'
				fi
			fi		
		fi
	else
		echo 'ERROR: Can not get latest git version.'
	fi
	
	if [[ -f "${proxy_path}/${proxy_name}" ]]; then
		tmux has-session -t "${proxy_name}" 2>/dev/null
		if [ ! "$?" -eq 0 ] ; then
			sudo /usr/bin/tmux new -s "${proxy_name}" -d
			sudo /usr/bin/tmux send-keys -t "${proxy_name}" "${proxy_path}/${proxy_name}" Enter
			
			tmux has-session -t "${proxy_name}" 2>/dev/null
			if [ ! "$?" -eq 0 ] ; then
				echo 'ERROR: Can not start "'"${proxy_name}"'" tmux session.'
			fi
		fi
	fi
}

function _service {
	local service="/etc/systemd/system/freqstart.service"
	if [[ -z $(systemctl is-active -q freqstart.service) ]]; then
		if [ ! -f "${service}" ]; then
			string=''
			string+='[Unit]\n'
			string+='Description=freqstart\n'
			string+='After=network.target\n'
			string+='\n'
			string+='[Service]\n'
			string+='Type=forking\n'
			string+='Environment=DISPLAY=:0\n'
			string+='ExecStartPre=/bin/sleep 10\n'
			string+='ExecStart='"${scriptpath}"'/freqstart.sh\n'
			string+='\n'
			string+='ExecStop='"${scriptpath}"'/freqstart.sh -k\n'
			string+='KillMode=control-group\n'
			string+='RestartSec=2\n'
			string+='\n'
			string+='[Install]\n'
			string+='WantedBy=default.target'

			printf "${string}" > "${service}";
			
			if [[ ! -f "${service}" ]]; then
				echo 'ERROR: '"${service}"' does not exist.'
				exit 1
			fi
		fi

		systemctl daemon-reload -q
		systemctl reset-failed -q
		systemctl enable -q freqstart.service
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
		echo "ERROR: NTP not active or not synchronized."
	fi
}

function _autostart {
	_apt
	_tmux
	_ntp
	_proxy
	_freqtrade
	_service

	local autostart="${scriptpath}/autostart.txt"
	local freqtrade=$(ls -d "${scriptpath}"/freqtrade_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)

	rm -f "${autostart}"

	if [[ ! -f "${autostart}" ]]; then
		string=''
		string+='# Example:\n'
		string+='# freqtrade trade --dry-run --db-url sqlite:///example-dryrun.sqlite --strategy=NostalgiaForInfinityX --strategy-path='"${scriptpath}"'/NostalgiaForInfinity_v11.0.700 -c='"${scriptpath}"'/NostalgiaForInfinity_v11.0.700/configs/pairlist-volume-binance-usdt.json -c='"${scriptpath}"'/NostalgiaForInfinity_v11.0.700/configs/blacklist-binance.json -c='"${scriptpath}"'/NostalgiaForInfinity_v11.0.700/configs/exampleconfig.json -c='"${scriptpath}"'/proxy.json\n'

		printf "${string}" > "${autostart}"
		
		if [[ ! -f "${autostart}" ]]; then
			echo 'ERROR: '"${autostart}"' does not exist.'
			exit 1
		fi
	fi

	readarray bots < "${autostart}"
	
	for bot in "${bots[@]}"; do		
		local error=0
	
		if [[ ! -z $(echo "${bot}" | grep -o -E '^freqtrade') ]]; then

			local botname=$(echo "${bot}" | grep -o -E 'sqlite(.*)sqlite' | sed 's#.sqlite##' | sed 's#sqlite:///##')
			
			if [[ -z "${botname}" ]]; then
				echo 'ERROR: Override trades database URL.'
				local error=1
			elif [[ "${botname}" =~ ['!@#$%^&*()_+.'] ]]; then
				echo 'ERROR: Do not use special characters in database URL name.'
				local error=1
			fi
			
			if [[ -z $(echo "${bot}" | grep -e '--strategy-path=') ]]; then
				echo "ERROR: --strategy-path is missing."
				local error=1
			fi
			
			if [[ -z $(echo "${bot}" | grep -e '--strategy=') ]]; then
				echo "ERROR: --strategy is missing."
				local error=1
			fi
						
			tmux has-session -t "${botname}" 2>/dev/null
			if [ "$?" -eq 0 ] ; then
				echo 'ERROR: "'"${botname}"'" already active. Rename database URL name!'
				local error=1
			fi
			
			set -f; local arguments=("${bot}") # credits: https://stackoverflow.com/a/15400047
			for argument in ${arguments[@]}; do

				if [[ ! -z $(echo "${argument}" | grep -e '-c=' -e '--config=') ]]; then
					local config=$(echo "${argument}" | sed 's#-c=##' | sed 's#--config=##')
					if [[ ! -f "${config}" ]]; then
						echo 'ERROR: Config "'"${config}"'" not found.'
						local error=1
					fi
				fi
			
				if [[ ! -z $(echo "${argument}" | grep -e '--strategy-path=') ]]; then
					local nfi_path="$(echo "${argument}" | sed 's#--strategy-path=##')"
					local nfi_version="$(basename ${nfi_path} | sed 's#.*_##')"
					local nfi_git="https://github.com/iterativv/NostalgiaForInfinity/archive/refs/tags/${nfi_version}.tar.gz"
					
					if [[ ! -z "${nfi_version}" ]]; then
						if [[ ! -d "${nfi_path}" || -z "$(ls -A ${nfi_path})" ]]; then
							if _git_validate "${nfi_git}"; then
								mkdir -p "${nfi_path}"
								wget -qO- "${nfi_git}" \
									| tar xz -C "${nfi_path}" --strip-components=1
								if [[ -d "${nfi_path}" || ! -z "$(ls -A ${nfi_path})" ]]; then
									echo 'INFO: Strategy "'"${nfi_version}"'" has been downloaded.'
								fi
							else
								echo 'ERROR: Strategy "'"${nfi_version}"'" not found.'
								local error=1
							fi
						fi
					else
						echo 'ERROR: Strategy version is not set. Example: NostalgiaForInfinity_v00.0.000'
						local error=1
					fi
				fi
			done

			if [[ "${error}" -eq 0 ]]; then
				sudo /usr/bin/tmux new -s "${botname}" -d	
				sudo /usr/bin/tmux send-keys -t "${botname}" "cd ${freqtrade}" Enter
				sudo /usr/bin/tmux send-keys -t "${botname}" ". .env/bin/activate" Enter
				sudo /usr/bin/tmux send-keys -t "${botname}" "$(echo -e ${bot})" Enter
				
				sudo tmux has-session -t "${botname}" 2>/dev/null
				if [ "$?" -eq 0 ] ; then
					echo 'INFO: Freqtrade "'"${botname}"'" started.'
				fi
			fi
		fi
	done
}

function _kill {
  for _pane in $(tmux list-panes -F '#P'); do
    tmux send-keys -t ${_pane} "$@"
  done
}


for i in "$@"; do
	case $i in
		-k|--kill)
			_kill
		;;
		-*|--*)
			echo_block "ERROR: Unknown option ${i}"
			exit 1
		;;
		*)
			echo_block "ERROR: Unknown option ${i}"
			exit 1
		;;
	esac
done

if [[ -z "$*" ]]; then
	_autostart
fi

exit 0