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
# This software is for educational purposes only. Do not risk money which you are afraid to lose. 
# USE THE SOFTWARE AT YOUR OWN RISK. THE AUTHORS AND ALL AFFILIATES ASSUME NO RESPONSIBILITY FOR YOUR TRADING RESULTS.
#
readonly scriptname=$(realpath $0); readonly scriptpath=$(dirname "${scriptname}")
readonly service='freqstart.service'
readonly proxy='binance-proxy'
readonly autostart="${scriptpath}"'/autostart.txt'
readonly nfi='NostalgiaForInfinity'
readonly server_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

function _hash {
	echo $(cat /dev/urandom \
		| tr -dc 'a-zA-Z0-9' \
		| fold -w 32 \
		| head -n 1)
}

function _cdown {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	secs="${1}"; shift; text="${@}"
		
	while [[ "${secs}" -gt -1 ]]; do
		if [[ "${secs}" -gt 0 ]]; then
			printf '\r\033[KWaiting '"${secs}"' seconds '"${text}"
			sleep 1
		else
			printf '\r\033[K'
		fi
		: $((secs--))
	done
}

function _date {
	echo $(date +%y%m%d%H)
}

function _passwd {
	echo $(sudo < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-16})
}

function _env_deactivate {
	if [ -n "${VIRTUAL_ENV}" ]; then
		deactivate
    fi
}

function _invalid {
	echo 'ERROR: Invalid response!'
}

function _tmp_path {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	local path="${1}"
	
	if [[ "$(find "${path}" -maxdepth 1 -printf %y)" = "dd" ]]; then
		echo $(find "${path}" -mindepth 1 -maxdepth 1 -type d)'/.'
	else
		echo "${path}"'/.'
	fi
}

function _git {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi

	local git="${1}"
	git_name=$(echo "${git}" | cut -d / -f 6)
	
	git_tmp='/tmp/'"${git_name}"'_'"$(_date)"'.json'
	
	if [[ ! -f "${git_tmp}" ]]; then
		curl -o "${git_tmp}" -s -L "${git}"
	fi
	git_version=$(cat "${git_tmp}" \
		| grep -o '"tag_name": ".*"' \
		| sed 's/"tag_name": "//' \
		| sed 's/"//')

	local browser_download_url=$(cat "${git_tmp}" \
		| grep -o -E '"browser_download_url": "(.*)Linux_x86_64.tar.gz"' \
		| sed 's/"browser_download_url": "//' \
		| sed 's/"//')
	local tarball_url=$(cat "${git_tmp}" \
		| grep -o '"tarball_url": ".*"' \
		| sed 's/"tarball_url": "//' \
		| sed 's/"//')
	
	# downloading the precompiled linux version as a workaround for binance-proxy
	if [[ ! -z "${browser_download_url}" ]]; then
		git_file="${browser_download_url}"
	else
		git_file="${tarball_url}"
	fi
		
	git_file_tmp='/tmp/'"${git_name}"'_'$(_hash)
}

function _apt {
	if [[ ! -f "${scriptpath}/update.txt" ]]; then
		string=''
		string+='Installed unattended-upgrades. Remove file to update server again.'
		printf "${string}" > "${scriptpath}/update.txt";
		
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
	local path="${scriptpath}"'/freqtrade'
	if [[ ! -d "${path}" ]]; then
		mkdir -p "${path}"
	fi

	local version=$(cd "${path}"; source .env/bin/activate 2>/dev/null; freqtrade --version 2>/dev/null | sed 's/freqtrade //')
	_git "https://api.github.com/repos/freqtrade/freqtrade/releases/latest"
	
	if [[ -z "${version}" ]]; then
		if [[ $(wget -S --spider "${git_file}" 2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
			echo 'INFO: freqtrade download latest version "'"${git_version}"'".'

			mkdir -p "${git_file_tmp}"
			wget -qO- "${git_file}" \
				| tar xz -C "${git_file_tmp}"
			
			rm -rf "${path}"
			mkdir -p "${path}"

			cp -R $(_tmp_path "${git_file_tmp}") "${path}"

			rm -rf "${git_file_tmp}"

			echo 'INFO: freqtrade install may take some time, please be patient...'
			sudo chmod +x "${path}/setup.sh"
			cd "${path}"
			_env_deactivate
			yes $'no' | sudo ./setup.sh -i >/dev/null 2>&1
			
			echo 'INFO: pandas-ta install may take some time, please be patient...'
			cd "${path}"
			_env_deactivate
			python3 -m venv .env >/dev/null 2>&1
			source .env/bin/activate
			python3 -m pip install --upgrade pip >/dev/null 2>&1
			python3 -m pip install -e . >/dev/null 2>&1
			pip install pandas-ta >/dev/null 2>&1
			_env_deactivate

			_freqtrade
		else
			echo 'ERROR: freqtrade git repo not reachable.'
		fi
	else
		if [[ ! -z "${git_version}" ]] && [[ "${git_version}" != "${version}" ]]; then
			while true; do
				read -p 'Do you want to install newer "'"${git_name}"'" version "'"${git_verion}"'"? (y/n) ' yn
				case "${yn}" in 
					[yY])
						echo 'INFO: freqtrade update from version "'"${version}"'" to "'"${git_version}"'". Restart all running bots!'
						sudo chmod +x "${path}/setup.sh"
						cd "${path}"
						_env_deactivate
						yes $'no' | sudo ./setup.sh -u >/dev/null 2>&1
						_env_deactivate
						
						_freqtrade

						break;;
					[nN])
						echo 'WARNING: Skip "freqtrade" update from version "'"${version}"'" to "'"${git_version}"'".'
						return 0;;
					*)
						_invalid
						;;
				esac
			done
		else
			echo 'INFO: freqtrade latest version "'"${version}"'" installed.'
			return 0
		fi
	fi
}

function _ufw {
	if [[ ! -x $(ufw status) ]]; then
			sudo apt-get update -y > /dev/null
			sudo apt-get install -y ufw > /dev/null
			#sudo ufw allow ssh/tcp > /dev/null
			#sudo ufw limit ssh/tcp > /dev/null
			sudo ufw logging medium > /dev/null
		if [[ -z $(ufw status | grep -qw active) ]]; then
			sudo ufw enable
		fi
	fi
}

function _frequi {
	if [[ ! -f "${scriptpath}/frequi.txt" ]]; then
		string=''
		string+='Frequi decision set. Remove file to install again.'
		printf "${string}" > "${scriptpath}/frequi.txt";

		local path="${scriptpath}"'/freqtrade'

		while true; do
			read -p 'Do you want to use FreqUI (Web Frontend)? (y/n) ' _yn
			case ${_yn} in 
				[yY])
					_kill
					_ufw
					_nginx
					
					while true; do
						read -p 'Do you want a secure the connection to the "frequi" api server? (y/n) ' yn
						case "${yn}" in 
							[yY])
								while true; do
									read -p 'Do you want to use LetsEncrypt for SSL? Domain required! (y/n) ' yn
									case "${yn}" in 
										[yY])
											_letsencrypt
											break;;
										[nN])
											_openssl
											break;;
										*)
											_invalid
											;;
									esac
								done
								break;;
							[nN])
								break;;
							*)
								_invalid
								;;
						esac
					done

					cd "${path}"
					_env_deactivate
					source .env/bin/activate
					freqtrade install-ui
					_env_deactivate
					
					break;;
				[nN])
					break;;
				*)
					_invalid
					;;
			esac
		done
	fi
}

function _openssl {
		_ssl openssl

		sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
		-keyout /etc/ssl/private/nginx-selfsigned.key \
		-out /etc/ssl/certs/nginx-selfsigned.crt
		sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096

		string=''
		string=$(cat <<-END
		ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
		ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
		END
		)
		printf "${string}" > '/etc/nginx/snippets/self-signed.conf'
		
		string=''
		string=$(cat <<-END
		ssl_protocols TLSv1.2;
		ssl_prefer_server_ciphers on;
		ssl_dhparam /etc/nginx/dhparam.pem;
		ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
		ssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0
		ssl_session_timeout  10m;
		ssl_session_cache shared:SSL:10m;
		ssl_session_tickets off; # Requires nginx >= 1.5.9
		ssl_stapling on; # Requires nginx >= 1.3.7
		ssl_stapling_verify on; # Requires nginx => 1.3.7
		resolver 8.8.8.8 8.8.4.4 valid=300s;
		resolver_timeout 5s;
		# Disable strict transport security for now. You can uncomment the following
		# line if you understand the implications.
		# add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
		add_header X-Frame-Options DENY;
		add_header X-Content-Type-Options nosniff;
		add_header X-XSS-Protection "1; mode=block";
		END
		)
		printf "${string}" > '/etc/nginx/snippets/ssl-params.conf'
		
}

function _letsencrypt {
	while true; do
		read -p 'Enter your domain (www.example.com): ' domain
		if [[ "${domain}" != '' ]]; then
			read -p 'Is the domain "'"${domain}"'" correct? (y/n) ' yn
		else
			yn='empty'
		fi
		case "${yn}" in 
			[yY])
				sudo apt-get update -y
				sudo apt-get install -y certbot python3-certbot-nginx
				
				_ssl letsencrypt "${domain}"

				sudo certbot --nginx -d "${domain}"
				
				break;;
			[nN])
				echo "one more chance..."
				;;
			'empty')
				echo "domain can not be empty!"
				;;
			*)
				_invalid
				;;
		esac
	done
}

function _nginx {
	sudo apt-get update -y 
	sudo apt-get install -y nginx

	local path='/etc/nginx/conf.d'
	local freqstart_conf="${path}"'/freqstart.conf'
	local nginx_conf="${path}"'/default.conf'
	local server_name="${server_ip}"

	string=$(cat <<-END
	server {
		listen 80;
		listen [::]:80;
		server_name ${server_name};
		location / {
			proxy_pass http://localhost:8080;
		}
	}
	END
	)
	printf "${string}" > "${freqstart_conf}"

	if [ -f "${nginx_conf}" ]; then sudo mv "${nginx_conf}" "${nginx_conf}"'.disabled'; fi
	
	sudo rm -f /etc/nginx/sites-enabled/default
	
	sudo nginx -s reload

	sudo pkill -f nginx & wait $!
	sudo systemctl start nginx
	#sudo systemctl restart nginx
	
	_api_json
}

function _ssl {
	local path='/etc/nginx/conf.d'
	local freqstart_conf="${path}"'/freqstart.conf'
	local nginx_conf="${path}"'/default.conf'
	
	local mode="${1}"
	local domain="${2}"
	if [[ ! -z "${domain}" ]]; then
		local server_name="${domain}"
	else
		local server_name="${server_ip}"
	fi
	
	string=''
	if [[ "${mode}" == 'openssl' ]]; then
		string=$(cat <<-END
		server {
		    listen 443 ssl;
		    listen [::]:443 ssl;
		    include snippets/self-signed.conf;
		    include snippets/ssl-params.conf;
		    server_name ${server_name};
		    location / {
		    proxy_pass http://localhost:8080/;
		    }
		}
		server {
		    listen 80;
		    listen [::]:80;
		    server_name ${server_name};
		    return 301 https://$server_name$request_uri;
		}
		END
		)
		sudo ufw allow https/tcp
	elif [[ "${mode}" == 'letsencrypt' ]]; then
		string=$(cat <<-END
		server {
		    listen 80;
		    listen [::]:80; 	
		    server_name ${server_name};
		    return 301 https://$host$request_uri;
		}
		server {
		    listen 443 ssl http2;
		    listen [::]:443 ssl http2; 	
		    server_name ${server_name};

		    ssl_certificate /etc/letsencrypt/live/${server_name}/fullchain.pem;
		    ssl_certificate_key /etc/letsencrypt/live/${server_name}/privkey.pem;
		    include /etc/letsencrypt/options-ssl-nginx.conf;
		    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
			
		    # Required for LE certificate enrollment using certbot
		    location '/.well-known/acme-challenge' {
		    default_type "text/plain";
		    root /var/www/html;
		    }
		    location / {
		    proxy_pass http://localhost:8080/;
		    }
		}
		END
		)
	fi
	printf "${string}" > "${freqstart_conf}"
	
	sudo ufw allow https/tcp
	
	sudo rm -f /etc/nginx/sites-enabled/default

	sudo nginx -s reload

	sudo pkill -f nginx & wait $!
	sudo systemctl start nginx
	#sudo systemctl restart nginx
	
	_api_json "${domain}"
}

function _api_json {
	local domain="${1}"
	local file="${scriptpath}"'/freqstart-api.json'
	local jwt_secret_key=$(_passwd)
	local username=$(_passwd)
	local password=$(_passwd)
	
	if [[ ! -f "${file}" ]]; then
		string=''
		string=$(cat <<-END
			{
			    "api_server": {
			        "enabled": true,
			        "listen_ip_address": "127.0.0.1",
			        "listen_port": 8080,
			        "verbosity": "error",
			        "enable_openapi": false,
			        "jwt_secret_key": "${jwt_secret_key}",
			        "CORS_origins": [],
			        "username": "${username}",
			        "password": "${password}"
			    }
			}
		END
		)
		printf "${string}" > "${file}";
		
		echo 'INFO: Save your login credentials or edit '"$(basename "${file}")"' file!'
		echo '-'
		echo 'USER: '"${username}"
		echo 'PASSWORD: '"${password}"
		echo '-'
	else
		echo 'INFO: '"$(basename "${file}")"' file already set.'
	fi
	
	if [[ ! -z "${domain}" ]]; then
		sed -i -e 's,"CORS_origins": \[.*\],"CORS_origins": \["https://'"${domain}"'"\],' "${file}"
	fi
}

function _strategy {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	if [[ "${unattended}" == 'true' ]]; then return 0; fi
	
	local strategy=$(echo "${1}" | grep -e '--strategy-path=.*' | sed 's#--strategy-path=##')
	if [[ ! -z "${strategy}" ]]; then
		if [[ "${strategy}" == *"${nfi}"* ]]; then
			local version=$(basename "${strategy}" | grep -o '_.*' | sed 's#_##')
			
			if [[ ! -z "${version}" ]]; then
				if [[ ! -d "${strategy}" ]]; then
					return 1
				else
					return 0
				fi
			else
				local version_file="${strategy}"'/freqstart-version.txt'
				if [[ -f "${version_file}" ]]; then
					local version="$(< "${version_file}")"
				fi

				_git "https://api.github.com/repos/iterativv/NostalgiaForInfinity/releases/latest"
				
				if [[ ! -z "${git_version}" ]] && [[ "${git_version}" != "${version}" ]]; then
					while true; do
						echo '-'
						read -p 'Do you want to install "'"${git_name}"'" version "'"${git_version}"'"? (y/n) ' yn
						case "${yn}" in 
							[yY])
								if [[ $(wget -S --spider "${git_file}" 2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
									mkdir -p "${git_file_tmp}"
									wget -qO- "${git_file}" \
										| tar xz -C "${git_file_tmp}"
									
									rm -rf "${strategy}"
									mkdir -p "${strategy}"

									cp -R $(_tmp_path "${git_file_tmp}") "${strategy}"
									
									rm -rf "${git_file_tmp}"
									
									string=''
									string+="${git_version}"
									printf "${string}" > "${version_file}"
									
									if [[ ! -f "${version_file}" ]]; then
										echo 'ERROR: '$(basename "${version_file}")' does not exist.'
										exit 1
									fi
									
									if [ ! -z "$(ls -A ${strategy})" ]; then
										echo 'INFO: '"${git_name}"' latest version "'"${git_version}"'" installed.'
										return 0
									else
										return 1
									fi
								else
									return 1
								fi

								break;;
							[nN])		
								break;;
							*)
								_invalid
								;;
						esac
					done
				fi
			fi
		elif [[ ! -d "${strategy}" ]]; then
			echo 'ERROR: Automated download for "'$(basename "${strategy}")'" is not implemented.'
			return 1
		else
			return 0
		fi
	fi
}

function _config {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	if [[ "${unattended}" == 'true' ]]; then return 0; fi

	local config="${1}"

	if [[ ! -z $(echo "${config}" | grep -e '-c=' -e '--config=') ]]; then
		local config=$(echo "${config}" | sed 's#-c=##' | sed 's#--config=##')
		if [[ ! -f "${config}" ]]; then
			echo 'ERROR: Config "'"${config}"'" not found.'
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
			echo "ERROR: TMUX is not installed."
			exit 1
		fi
	fi
}

function _tmux_session {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi
	
	local session="${1}"

	tmux has-session -t "${session}" 2>/dev/null
	if [[ "$?" -eq 0 ]]; then
		return 0
	else
		return 1
	fi
}

function _tmux_kill {
	if [[ "${#}" -eq 0 ]]; then exit 1; fi

	local session="${1}"
	#kill a specific session gracefully
	tmux send-keys -t "${session}" C-c 2>/dev/null
	sleep 1
	tmux send-keys -t "${session}" 'exit' C-m 2>/dev/null
	sleep 1
	tmux kill-session -t "${session}" 2>/dev/null
}

function _proxy_json {
	local path="${scriptpath}"'/'"${proxy}"'.json'

	if [[ ! -f "${path}" ]]; then
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
		printf "${string}" > "${path}"
		
		if [[ ! -f "${path}" ]]; then
			echo 'ERROR: Can not create "'"${proxy}"'.json" file.'
			exit 1
		else
			echo 'INFO: "'"${proxy}"'.json" file created.'
		fi
	fi
}

function _proxy_tmux {
	local path="${scriptpath}"'/'"${proxy}"
	local path_latest=$(ls -d "${path}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)
	local version=$(basename "${path_latest}" | grep -o '_.*' | sed 's#_##')
	
	_tmux_session "${proxy}"
	if [[ "$?" -eq 1 ]]; then
		/usr/bin/tmux new -s "${proxy}" -d
		/usr/bin/tmux send-keys -t "${proxy}" "${path_latest}"'/'"${proxy}" -v Enter
		
		_tmux_session "${proxy}"
		if [[ "$?" -eq 1 ]]; then
			echo 'ERROR: Can not start "'"${proxy}"'" tmux session.'
		else
			echo 'INFO: "'"${proxy}"'" version "'"${version}"'" tmux session startet.'
		fi
	else
		echo 'INFO: "'"${proxy}"'" version "'"${version}"'" tmux session is running.'
	fi
}

function _proxy {
	_proxy_json
	
	local path="${scriptpath}"'/'"${proxy}"
	local path_latest=$(ls -d "${path}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -1)
	#local path_previous=$(ls -d "${path}"_* 2>/dev/null | sort -nr -t _ -k 2 | head -2 | tail -1)
	local version=$(basename "${path_latest}" | grep -o '_.*' | sed 's#_##')
	
	_git "https://api.github.com/repos/nightshift2k/binance-proxy/releases/latest"

	if [[ ! -z "${git_version}" ]] && [[ "${git_version}" != "${version}" ]]; then
		while true; do
			read -p 'Do you want to install newer "'"${git_name}"'" version "'"${git_version}"'"? (y/n) ' yn
			case "${yn}" in 
				[yY])
					if [[ $(wget -S --spider "${git_file}" 2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
						echo 'INFO: '"${proxy}"' download latest version "'"${git_version}"'".'

						mkdir -p "${git_file_tmp}"
						wget -qO- "${git_file}" \
							| tar xz -C "${git_file_tmp}"
						
						mkdir -p "${path}"'_'"${git_version}"

						cp -R $(_tmp_path "${git_file_tmp}") "${path}"'_'"${git_version}"

						rm -rf "${git_file_tmp}"
						
						sudo chmod +x "${path}"'_'"${git_version}"'/'"${proxy}"
						
						_tmux_session "${proxy}"
						if [ "$?" -eq 0 ] ; then
							echo '# WARNING: Restart "'"${proxy}"'" tmux session. Review all running bots!'
							tmux kill-session -t "${proxy}"
						fi
					fi

					break;;
				[nN])		
					break;;
				*)
					_invalid
					;;
			esac
		done
	fi
	
	_proxy_tmux
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
		# removing service everytime in case there is a change in the service file
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
	# do not run any bots on unsynced servers
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

	local freqtrade="${scriptpath}"'/freqtrade'
	local count_bots=0

	if [[ ! -f "${autostart}" ]]; then
		string=''
		string+='# NFI example with version incl. proxy:\n'
		string+='# freqtrade trade --dry-run --db-url sqlite:///example-dryrun.sqlite --strategy=NostalgiaForInfinityX --strategy-path='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000 -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/pairlist-volume-binance-usdt.json -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/blacklist-binance.json -c='"${scriptpath}"'/NostalgiaForInfinity_v00.0.000/configs/exampleconfig.json -c='"${scriptpath}"'/freqstart-proxy.json\n'
		string+='# NFI example for latest version incl. proxy and frequi:\n'
		string+='# freqtrade trade --dry-run --db-url sqlite:///example-latest-dryrun.sqlite --strategy=NostalgiaForInfinityX --strategy-path='"${scriptpath}"'/NostalgiaForInfinity -c='"${scriptpath}"'/NostalgiaForInfinity/configs/pairlist-volume-binance-usdt.json -c='"${scriptpath}"'/NostalgiaForInfinity/configs/blacklist-binance.json -c='"${scriptpath}"'/NostalgiaForInfinity/configs/exampleconfig.json -c='"${scriptpath}"'/freqstart-proxy.json -c='"${scriptpath}"'/freqstart-api.json\n'
		string+='# To test new strategies on binbance including dryrun, create a sandbox account with API credentials -> https://testnet.binance.vision/'
		printf "${string}" > "${autostart}"
		
		if [[ ! -f "${autostart}" ]]; then
			echo '# ERROR: '"${autostart}"' does not exist.'
			exit 1
		fi
	fi
	
	readarray -t bots < "${autostart}"
	
	echo '-----'
	
	for bot in "${bots[@]}"; do		
		local error=0
	
		if [[ ! -z $(echo "${bot}" | grep -o -E '^freqtrade') ]]; then
			local bot_name=$(echo "${bot}" | grep -o -E 'sqlite(.*)sqlite' | sed 's#.sqlite##' | sed 's#sqlite:///##')
			local count_bots="$((count_bots + 1))"

			string=''
			string+='BOT ('"$((count_bots))"'):\n'
			string+="${bot}"'\n'
			printf -- "${string}"  

			local arguments=("${bot}") # its working, dont know why; set -f ? https://stackoverflow.com/a/15400047
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
				echo 'ERROR: Override trades database URL.'
				local error=1
			fi
			
			if [[ "${bot_name}" =~ ['!@#$%^&*()_+.'] ]]; then
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

			_tmux_session "${bot_name}"
			if [ "$?" -eq 0 ] ; then
				if [[ "${unattended}" == 'true' ]]; then
					_tmux_kill "${bot_name}"
				else
					while true; do
						echo '-'
						read -p 'Do you want to restart "'"${bot_name}"'" bot? (y/n) ' yn
						case "${yn}" in 
							[yY])
								_tmux_kill "${bot_name}"
								break;;
							[nN])		
								local error=1
								break;;
							*)
								_invalid
								;;
						esac
					done
				fi
			fi

			if [[ "${error}" -eq 0 ]]; then
				# exec bot to close session if script stops 
				/usr/bin/tmux new -s "${bot_name}" -d
				/usr/bin/tmux send-keys -t "${bot_name}" "cd ${freqtrade}" C-m
				/usr/bin/tmux send-keys -t "${bot_name}" ". .env/bin/activate" C-m	
				/usr/bin/tmux send-keys -t "${bot_name}" "exec ${bot}" C-m
				
				_cdown 10 'for any bot errors...'
				
				_tmux_session "${bot_name}"
				if [[ "$?" -eq 0 ]]; then
					echo '-'
					echo 'SUCCCESS: Bot "'"${bot_name}"'" started.'
				else
					echo '-'
					echo 'ERROR: Starting bot "'"${bot_name}"'" in debug mode.'
					echo '-'
					echo '1) Enter command: tmux a -t '"${bot_name}"
					echo '2) Look for missing parameters or potential proxy errors.'
					echo '3) Review your "'$(basename "${autostart}")'" file.'
					/usr/bin/tmux new -s "${bot_name}" -d
					/usr/bin/tmux send-keys -t "${bot_name}" "cd ${freqtrade}" C-m
					/usr/bin/tmux send-keys -t "${bot_name}" ". .env/bin/activate" C-m	
					/usr/bin/tmux send-keys -t "${bot_name}" "${bot}" C-m
				fi
			fi
			echo '-----'
		fi
	done
	_autostart_stats
}


function _kill {
	echo '# WARNING: Starting the purge, please be patient...'
	#kill all sessions gracefully
	tmux kill-session -t "${proxy}" 2>/dev/null
	while [[ ! -z $(tmux ls -F "#{session_name}" 2>/dev/null) ]]; do
		tmux ls -F "#{session_name}" | xargs -I {} tmux send-keys -t {} C-c 2>/dev/null
		sleep 0.1
		tmux ls -F "#{session_name}" | xargs -I {} tmux send-keys -t {} 'exit' C-m 2>/dev/null
		((c++)) && ((c==100)) && break
		sleep 0.1
	done
	tmux kill-server 2>/dev/null

	_service_disable
	echo "# WARNING: All bots stopped and restart service is disabled."
}

function _autostart_stats {
	# some handy stats to get you an impression how your server compares to the current possibly best location for binance
	local ping=$(ping -c 1 -w15 api3.binance.com | awk -F '/' 'END {print $5}')
	local mem_free=$(free -m | awk 'NR==2{print $4}')
	local mem_total=$(free -m | awk 'NR==2{print $2}')
	local time=$((time curl -X GET "https://api.binance.com/api/v3/exchangeInfo?symbol=BNBBTC") 2>&1 > /dev/null \
		| grep -o 'real.*s' \
		| sed 's#real	##')
	echo 'Ping avg. (Binance): '"${ping}"'ms | Vultr "Tokyo" Server avg.: 1.290ms'
	echo 'Time to API (Binance): '"${time}"' | Vultr "Tokyo" Server avg.: 0m0.039s'
	echo 'Free memory (Server): '"${mem_free}"'MB  (max. '"${mem_total}"'MB) | Vultr "Tokyo" Server avg.: 2 bots with 100MB free memory (1GB)'
	echo '-'
	echo 'Get closer to Binance? Try Vultr "Tokyo" Server and get $100 usage for free:'
	echo 'https://www.vultr.com/?ref=9122650-8H'
	echo '-----'
}

function _help {
	string=''
	string+='-----\n'
	string+='FREQSTART: Freqstart simplifies the usage of freqtrade with NostalgiaForInfinity strategies.\n'
	string+='-\n'
	string+='Type "tmux a" to attach to latest TMUX session.\n'
	string+='Use "ctrl+b s" to switch between TMUX sessions.\n'
	string+='Use "ctrl+b d" to return to shell from any TMUX session.\n'
	string+='Type "'$(basename "${scriptname}")' -k" to disable all bots and restart service.\n'
	string+='Type "'$(basename "${scriptname}")' -a" for unattended restart of all bots excl. any installations.\n'
	string+='-----\n'
	printf -- "${string}"
	
	_autostart_stats
}

function _start {
	_apt
	_tmux
	_ntp
	_freqtrade
	_frequi
	#_service
	_autostart
}

if [[ ! -z "$*" ]]; then
	for i in "$@"; do
		case $i in
			-a|--autostart)
				readonly unattended='true'
				_autostart
			;;
			-h|--help)
				_help
			;;
			-k|--kill)
				_kill
			;;
			-*|--*)
				echo "# ERROR: Unknown option ${i}"
				exit 1
			;;
			*)
				echo "# ERROR: Unknown option ${i}"
				exit 1
			;;
		esac
	done
else
	_start
fi
exit 0