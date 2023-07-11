#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: v1.3.1
# Description: One click Install Trojan Panel server
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/trojanpanel/install-script

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  # Docker
  DOCKER_MIRROR='"https://registry.docker-cn.com","https://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn"'

  # Project Directory
  TP_DATA="/tpdata/"

  STATIC_HTML="https://github.com/trojanpanel/install-script/releases/download/v1.0.0/html.tar.gz"

  # Caddy
  CADDY_DATA="/tpdata/caddy/"
  CADDY_Caddyfile="/tpdata/caddy/Caddyfile"
  CADDY_SRV="/tpdata/caddy/srv/"
  CADDY_ACME="/tpdata/caddy/acme/"
  DOMAIN_FILE="/tpdata/caddy/domain.lock"
  domain=""
  caddy_remote_port=8863
  your_email="123456@qq.com"
  crt_path=""
  key_path=""
  ssl_option=1

  # MariaDB
  MARIA_DATA="/tpdata/mariadb/"
  mariadb_ip="127.0.0.1"
  mariadb_port=9507
  mariadb_user="root"
  mariadb_pas=""

  #Redis
  REDIS_DATA="/tpdata/redis/"
  redis_host="127.0.0.1"
  redis_port=6378
  redis_pass=""

  # Trojan Panel
  TROJAN_PANEL_DATA="/tpdata/trojan-panel/"
  TROJAN_PANEL_WEBFILE="/tpdata/trojan-panel/webfile/"
  TROJAN_PANEL_LOGS="/tpdata/trojan-panel/logs/"

  # Trojan Panel UI
  TROJAN_PANEL_UI_DATA="/tpdata/trojan-panel-ui/"
  # Nginx
  NGINX_DATA="/tpdata/nginx/"
  NGINX_CONFIG="/tpdata/nginx/default.conf"
  trojan_panel_ui_port=8888
  https_enable=1

  # Trojan Panel Core
  TROJAN_PANEL_CORE_DATA="/tpdata/trojan-panel-core/"
  TROJAN_PANEL_CORE_LOGS="/tpdata/trojan-panel-core/logs/"
  database="trojan_panel_db"
  account_table="account"
}

echo_content() {
  case $1 in
  "red")
    ${ECHO_TYPE} "\033[31m$2\033[0m"
    ;;
  "green")
    ${ECHO_TYPE} "\033[32m$2\033[0m"
    ;;
  "yellow")
    ${ECHO_TYPE} "\033[33m$2\033[0m"
    ;;
  "blue")
    ${ECHO_TYPE} "\033[34m$2\033[0m"
    ;;
  "purple")
    ${ECHO_TYPE} "\033[35m$2\033[0m"
    ;;
  "skyBlue")
    ${ECHO_TYPE} "\033[36m$2\033[0m"
    ;;
  "white")
    ${ECHO_TYPE} "\033[37m$2\033[0m"
    ;;
  esac
}

mkdir_tools() {
  # 项目目录
  mkdir -p ${TP_DATA}

  # Caddy
  mkdir -p ${CADDY_DATA}
  touch ${CADDY_Caddyfile}
  mkdir -p ${CADDY_SRV}
  mkdir -p ${CADDY_ACME}

  # MariaDB
  mkdir -p ${MARIA_DATA}

  # Redis
  mkdir -p ${REDIS_DATA}

  # Trojan Panel
  mkdir -p ${TROJAN_PANEL_DATA}
  mkdir -p ${TROJAN_PANEL_LOGS}

  # Trojan Panel UI
  mkdir -p ${TROJAN_PANEL_UI_DATA}
  # # Nginx
  mkdir -p ${NGINX_DATA}
  touch ${NGINX_CONFIG}

  # Trojan Panel Core
  mkdir -p ${TROJAN_PANEL_CORE_DATA}
  mkdir -p ${TROJAN_PANEL_CORE_LOGS}
}

can_connect() {
  ping -c2 -i0.3 -W1 "$1" &>/dev/null
  if [[ "$?" == "0" ]]; then
    return 0
  else
    return 1
  fi
}

check_sys() {
  if [[ $(command -v yum) ]]; then
    package_manager='yum'
  elif [[ $(command -v dnf) ]]; then
    package_manager='dnf'
  elif [[ $(command -v apt) ]]; then
    package_manager='apt'
  elif [[ $(command -v apt-get) ]]; then
    package_manager='apt-get'
  fi

  if [[ -z "${package_manager}" ]]; then
    echo_content red "The system is not supported at this time"
    exit 0
  fi

  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
    release="debian"
  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
    release="ubuntu"
  fi

  if [[ -z "${release}" ]]; then
    echo_content red "Only CentOS 7+/Ubuntu 18+/Debian 10+ systems are supported"
    exit 0
  fi

  if [[ $(arch) =~ ("x86_64"|"amd64"|"arm64"|"aarch64"|"arm"|"s390x") ]]; then
    get_arch=$(arch)
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "Only support amd64/arm64/arm/s390x processor architecture"
    exit 0
  fi
}

depend_install() {
  if [[ "${package_manager}" != 'yum' && "${package_manager}" != 'dnf' ]]; then
    ${package_manager} update -y
  fi
  ${package_manager} install -y \
    curl \
    wget \
    tar \
    lsof \
    systemd
}

# Install Docker
install_docker() {
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content green "---> Install Docker"

    # turn off firewall
    if [[ "$(firewall-cmd --state 2>/dev/null)" == "running" ]]; then
      systemctl stop firewalld.service && systemctl disable firewalld.service
    fi

    # Time zone
    timedatectl set-timezone Asia/Shanghai

    can_connect www.google.com
    [[ "$?" == "0" ]] && can_google=1

    if [[ ${can_google} == 0 ]]; then
      sh <(curl -sL https://get.docker.com) --mirror Aliyun
      # Setting up Docker domestic sources
      mkdir -p /etc/docker &&
        cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors":[${DOCKER_MIRROR}],
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"50m",
      "max-file":"3"
  }
}
EOF
    else
      sh <(curl -sL https://get.docker.com)
    fi

    systemctl enable docker &&
      systemctl restart docker

    if [[ $(docker -v 2>/dev/null) ]]; then
      echo_content skyBlue "---> Docker installation completed"
    else
      echo_content red "---> Docker installation failed"
      exit 0
    fi
  else
    echo_content skyBlue "---> You already have Docker installed"
  fi
}

# 安装Caddy TLS
install_caddy_tls() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> Installing Caddy TLS"

    wget --no-check-certificate -O ${CADDY_DATA}html.tar.gz ${STATIC_HTML} &&
      tar -zxvf ${CADDY_DATA}html.tar.gz -C ${CADDY_SRV}

    read -r -p "Please enter the forwarding port of Caddy (for certificate application, default: 8863): " caddy_remote_port
    [[ -z "${caddy_remote_port}" ]] && caddy_remote_port=8863

    while read -r -p "Enter your domain name (required): " domain; do
      if [[ -z "${domain}" ]]; then
        echo_content red "Domain name cannot be empty"
      else
        break
      fi
    done

    mkdir "${CADDY_ACME}${domain}"

    while read -r -p "Please select the way to set the certificate? (1/Automatic application and renewal of certificate 2/Manual setting of certificate path Default:1/Automatic application and renewal of certificate): " ssl_option; do
      if [[ -z ${ssl_option} || ${ssl_option} == 1 ]]; then

        echo_content yellow "Domain name is being detected, please wait..."
        ping_ip=$(ping "${domain}" -s1 -c1 | grep "ttl=" | head -n1 | cut -d"(" -f2 | cut -d")" -f1)
        curl_ip=$(curl ifconfig.io)
        if [[ "${ping_ip}" != "${curl_ip}" ]]; then
          echo_content yellow "Your domain name is not resolved to the local IP, please try again later"
          echo_content red "---> Caddy installation failed"
          exit 0
        fi

        read -r -p "Please enter your email address (for certificate application, default: 123456@qq.com): " your_email
        [[ -z "${your_email}" ]] && your_email="123456@qq.com"

        cat >${CADDY_Caddyfile} <<EOF
http://${domain}:80 {
    redir https://${domain}:${caddy_remote_port}{url}
}
https://${domain}:${caddy_remote_port} {
    gzip
    tls ${your_email}
    root ${CADDY_SRV}
}
EOF
        break
      else
        if [[ ${ssl_option} != 2 ]]; then
          echo_content red "No characters other than 1 and 2 can be entered"
        else

          while read -r -p "Please enter the .crt file path of the certificate (required): " crt_path; do
            if [[ -z "${crt_path}" ]]; then
              echo_content red "path cannot be empty"
            else
              if [[ ! -f "${crt_path}" ]]; then
                echo_content red "The .crt file path for the certificate does not exist"
              else
                cp "${crt_path}" "${CADDY_ACME}${domain}/${domain}.crt"
                break
              fi
            fi
          done

          while read -r -p "Please enter the .key file path of the certificate (required): " key_path; do
            if [[ -z "${key_path}" ]]; then
              echo_content red "path cannot be empty"
            else
              if [[ ! -f "${key_path}" ]]; then
                echo_content red "The .key file path of the certificate does not exist"
              else
                cp "${key_path}" "${CADDY_ACME}${domain}/${domain}.key"
                break
              fi
            fi
          done

          cat >${CADDY_Caddyfile} <<EOF
http://${domain}:80 {
    redir https://${domain}:${caddy_remote_port}{url}
}
https://${domain}:${caddy_remote_port} {
    gzip
    tls /root/.caddy/acme/acme-v02.api.letsencrypt.org/sites/${domain}/${domain}.crt /root/.caddy/acme/acme-v02.api.letsencrypt.org/sites/${domain}/${domain}.key
    root ${CADDY_SRV}
}
EOF
          break
        fi
      fi
    done

    if [[ -n $(lsof -i:80,443 -t) ]]; then
      kill -9 "$(lsof -i:80,443 -t)"
    fi

    docker pull teddysun/caddy:1.0.5 &&
      docker run -d --name trojan-panel-caddy --restart always \
        --network=host \
        -v ${CADDY_Caddyfile}:"/etc/caddy/Caddyfile" \
        -v ${CADDY_ACME}:"/root/.caddy/acme/acme-v02.api.letsencrypt.org/sites/" \
        -v ${CADDY_SRV}:${CADDY_SRV} \
        teddysun/caddy:1.0.5

    if [[ -n $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
      cat >${DOMAIN_FILE} <<EOF
${domain}
EOF
      echo_content skyBlue "---> Caddy installation complete"
    else
      echo_content red "---> Caddy installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    domain=$(cat "${DOMAIN_FILE}")
    echo_content skyBlue "---> You have installed Caddy"
  fi
}

# 安装MariaDB
install_mariadb() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-mariadb$") ]]; then
    echo_content green "---> Install MariaDB"

    read -r -p "Please enter the port of the database (default: 9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "Please enter the username of the database (default: root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "Please enter the password for the database (required): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "Password cannot be empty"
      else
        break
      fi
    done

    if [[ "${mariadb_user}" == "root" ]]; then
      docker pull mariadb:10.7.3 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=host \
          -e MYSQL_DATABASE="trojan_panel_db" \
          -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" \
          -e TZ=Asia/Shanghai \
          mariadb:10.7.3 \
          --port ${mariadb_port}
    else
      docker pull mariadb:10.7.3 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=host \
          -e MYSQL_DATABASE="trojan_panel_db" \
          -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" \
          -e MYSQL_USER="${mariadb_user}" \
          -e MYSQL_PASSWORD="${mariadb_pas}" \
          -e TZ=Asia/Shanghai \
          mariadb:10.7.3 \
          --port ${mariadb_port}
    fi

    if [[ -n $(docker ps -q -f "name=^trojan-panel-mariadb$" -f "status=running") ]]; then
      echo_content skyBlue "---> MariaDB installation completed"
      echo_content yellow "---> MariaDB root's database password (please save it properly): ${mariadb_pas}"
      if [[ "${mariadb_user}" != "root" ]]; then
        echo_content yellow "---> MariaDB ${mariadb_user}The password for the database (please keep it safe): ${mariadb_pas}"
      fi
    else
      echo_content red "---> MariaDB installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You already have MariaDB installed"
  fi
}

# 安装Redis
install_redis() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content green "---> Installing Redis"

    read -r -p "Please enter the port of Redis (default: 6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "Please enter your Redis password (required): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "Password cannot be empty"
      else
        break
      fi
    done

    docker pull redis:6.2.7 &&
      docker run -d --name trojan-panel-redis --restart always \
        --network=host \
        redis:6.2.7 \
        redis-server --requirepass "${redis_pass}" --port ${redis_port}

    if [[ -n $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
      echo_content skyBlue "---> Redis installation complete"
      echo_content yellow "---> Database password for Redis (please keep it safe): ${redis_pass}"
    else
      echo_content red "---> Redis installation failed or is running abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You already have Redis installed"
  fi
}

# 安装TrojanPanel
install_trojan_panel() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
    echo_content green "---> Installing Trojan Panel"

    read -r -p "Please enter the IP address of the database (default: local database): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
    read -r -p "Please enter the port of the database (default: 9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "Please enter the username of the database (default: root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "Please enter the password for the database (required): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "Password cannot be empty"
      else
        break
      fi
    done

    if [[ "${mariadb_ip}" == "127.0.0.1" ]]; then
      docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "drop database trojan_panel_db;" &&
        docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "create database trojan_panel_db;"
    else
      docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "drop database trojan_panel_db;" &>/dev/null &&
        docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "create database trojan_panel_db;" &>/dev/null
    fi

    read -r -p "Please enter the IP address of Redis (default: local Redis): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
    read -r -p "Please enter the port of Redis (default: 6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "Please enter your Redis password (required): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "Password cannot be empty"
      else
        break
      fi
    done

    if [[ "${redis_host}" == "127.0.0.1" ]]; then
      docker exec trojan-panel-redis redis-cli -a "${redis_pass}" -e "flushall" &>/dev/null
    else
      docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null
    fi

    docker pull jonssonyan/trojan-panel &&
      docker run -d --name trojan-panel --restart always \
        --network=host \
        -v ${CADDY_SRV}:${TROJAN_PANEL_WEBFILE} \
        -v ${TROJAN_PANEL_LOGS}:${TROJAN_PANEL_LOGS} \
        -v /etc/localtime:/etc/localtime \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        jonssonyan/trojan-panel

    if [[ -n $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel backend installation completed"
    else
      echo_content red "---> Trojan Panel backend failed to install or run abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed the Trojan Panel backend"
  fi

  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-ui$") ]]; then
    read -r -p "Please enter the Trojan Panel front-end port (default: 8888): " trojan_panel_ui_port
    [[ -z "${trojan_panel_ui_port}" ]] && trojan_panel_ui_port="8888"

    while read -r -p "Please select whether Trojan Panel front-end is https enabled or not?(0/off 1/on default:1/on): " https_enable; do
      if [[ -z ${https_enable} || ${https_enable} == 1 ]]; then
        # 配置Nginx
        cat >${NGINX_CONFIG} <<-EOF
server {
    listen       ${trojan_panel_ui_port} ssl;
    server_name  ${domain};

    #Forced ssl
    ssl on;
    ssl_certificate      ${CADDY_ACME}${domain}/${domain}.crt;
    ssl_certificate_key  ${CADDY_ACME}${domain}/${domain}.key;
    #Cache expiration date
    ssl_session_timeout  5m;
    #Optional encryption protocol for secure links
    ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
    #Encryption algorithms
    ssl_ciphers  ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    #Use the server-side preferred algorithm
    ssl_prefer_server_ciphers  on;

    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   ${TROJAN_PANEL_UI_DATA};
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://127.0.0.1:8081;
    }

    #error_page  404              /404.html;
    #497 http->https
    error_page  497              https://\$host:${trojan_panel_ui_port}\$uri?\$args;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
        break
      else
        if [[ ${https_enable} != 0 ]]; then
          echo_content red "No characters other than 0 and 1 can be entered"
        else
          cat >${NGINX_CONFIG} <<-EOF
server {
    listen       ${trojan_panel_ui_port};
    server_name  localhost;

    location / {
        root   ${TROJAN_PANEL_UI_DATA};
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://127.0.0.1:8081;
    }

    error_page  497              http://\$host:${trojan_panel_ui_port}\$uri?\$args;

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
          break
        fi
      fi
    done

    docker pull jonssonyan/trojan-panel-ui &&
      docker run -d --name trojan-panel-ui --restart always \
        --network=host \
        -v ${NGINX_CONFIG}:/etc/nginx/conf.d/default.conf \
        -v ${CADDY_ACME}"${domain}":${CADDY_ACME}"${domain}" \
        jonssonyan/trojan-panel-ui

    if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel front-end installation completed"
    else
      echo_content red "---> Trojan Panel front-end installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed the Trojan Panel frontend"
  fi

  https_flag=$([[ -z ${https_enable} || ${https_enable} == 1 ]] && echo "https" || echo "http")

  echo_content red "\n=============================================================="
  echo_content skyBlue "Trojan Panel installed successfully"
  echo_content yellow "MariaDB ${mariadb_user}password (please keep it safe): ${mariadb_pas}"
  echo_content yellow "Redis password (please keep it safe): ${redis_pass}"
  echo_content yellow "Admin panel address: ${https_flag}://${domain}:${trojan_panel_ui_port}"
  echo_content yellow "System administrator Default username: sysadmin Default password: 123456 Please log in the management panel to change your password in time"
  echo_content yellow "Trojan Panel Private Key and Certificate Catalog: ${CADDY_ACME}${domain}/"
  echo_content red "\n=============================================================="
}

# 安装Trojan Panel Core
install_trojan_panel_core() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
    echo_content green "---> Installing Trojan Panel Core"

    read -r -p "Please enter the IP address of the database (default: local database): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
    read -r -p "Please enter the port of the database (default: 9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "Please enter the username of the database (default: root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "Please enter the password for the database (required): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "Password cannot be empty"
      else
        break
      fi
    done
    read -r -p "Please enter the database name (default: trojan_panel_db): " database
    [[ -z "${database}" ]] && database="trojan_panel_db"
    read -r -p "Please enter the name of the user table in the database (default: account): " account_table
    [[ -z "${account_table}" ]] && account_table="account"

    read -r -p "Please enter the IP address of Redis (default: local Redis): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
    read -r -p "Please enter the port of Redis (default: 6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "Please enter your Redis password (required): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "Password cannot be empty"
      else
        break
      fi
    done

    domain=$(cat "${DOMAIN_FILE}")

    docker pull jonssonyan/trojan-panel-core &&
      docker run -d --name trojan-panel-core --restart always \
        --network=host \
        -v ${TROJAN_PANEL_CORE_DATA}bin/xray/config:${TROJAN_PANEL_CORE_DATA}bin/xray/config \
        -v ${TROJAN_PANEL_CORE_DATA}bin/trojango/config:${TROJAN_PANEL_CORE_DATA}bin/trojango/config \
        -v ${TROJAN_PANEL_CORE_DATA}bin/hysteria/config:${TROJAN_PANEL_CORE_DATA}bin/hysteria/config \
        -v ${TROJAN_PANEL_CORE_DATA}bin/naiveproxy/config:${TROJAN_PANEL_CORE_DATA}bin/naiveproxy/config \
        -v ${TROJAN_PANEL_CORE_LOGS}:${TROJAN_PANEL_CORE_LOGS} \
        -v ${CADDY_ACME}:${CADDY_ACME} \
        -v ${CADDY_SRV}:${CADDY_SRV} \
        -v /etc/localtime:/etc/localtime \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "database=${database}" \
        -e "account-table=${account_table}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        -e "crt_path=${CADDY_ACME}${domain}/${domain}.crt" \
        -e "key_path=${CADDY_ACME}${domain}/${domain}.key" \
        jonssonyan/trojan-panel-core
    if [[ -n $(docker ps -q -f "name=^trojan-panel-core$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel Core安装完成"
    else
      echo_content red "---> Trojan Panel Core backend installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed Trojan Panel Core"
  fi
}

# 更新Trojan Panel
update_trojan_panel() {
  # 判断Trojan Panel是否安装
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
    echo_content red "---> Please install Trojan Panel first"
    exit 0
  fi

  echo_content green "---> Update Trojan Panel"

  read -r -p "Please enter the IP address of the database (default: local database): " mariadb_ip
  [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
  read -r -p "Please enter the port of the database (default: 9507): " mariadb_port
  [[ -z "${mariadb_port}" ]] && mariadb_port=9507
  read -r -p "Please enter the username of the database (default: root): " mariadb_user
  [[ -z "${mariadb_user}" ]] && mariadb_user="root"
  while read -r -p "Please enter the password for the database (required): " mariadb_pas; do
    if [[ -z "${mariadb_pas}" ]]; then
      echo_content red "Password cannot be empty"
    else
      break
    fi
  done

  if [[ "${mariadb_ip}" == "127.0.0.1" ]]; then
    docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "drop database trojan_panel_db;"
    docker exec trojan-panel-mariadb mysql -p"${mariadb_pas}" -e "create database trojan_panel_db;"
  else
    docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "drop database trojan_panel_db;" &>/dev/null
    docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "create database trojan_panel_db;" &>/dev/null
  fi

  read -r -p "Please enter the IP address of Redis (default: local Redis): " redis_host
  [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
  read -r -p "Please enter the port of Redis (default: 6378): " redis_port
  [[ -z "${redis_port}" ]] && redis_port=6378
  while read -r -p "Please enter your Redis password (required): " redis_pass; do
    if [[ -z "${redis_pass}" ]]; then
      echo_content red "Password cannot be empty"
    else
      break
    fi
  done

  if [[ "${redis_host}" == "127.0.0.1" ]]; then
    docker exec trojan-panel-redis redis-cli -a "${redis_pass}" -e "flushall" &>/dev/null
  else
    docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null
  fi

  docker rm -f trojan-panel &&
    docker rmi -f jonssonyan/trojan-panel &&
    rm -rf ${TROJAN_PANEL_DATA}

  docker rm -f trojan-panel-ui &&
    docker rmi -f jonssonyan/trojan-panel-ui &&
    rm -rf ${TROJAN_PANEL_UI_DATA}

  docker pull jonssonyan/trojan-panel &&
    docker run -d --name trojan-panel --restart always \
      --network=host \
      -v ${CADDY_SRV}:${TROJAN_PANEL_WEBFILE} \
      -v ${TROJAN_PANEL_LOGS}:${TROJAN_PANEL_LOGS} \
      -v /etc/localtime:/etc/localtime \
      -e "mariadb_ip=${mariadb_ip}" \
      -e "mariadb_port=${mariadb_port}" \
      -e "mariadb_user=${mariadb_user}" \
      -e "mariadb_pas=${mariadb_pas}" \
      -e "redis_host=${redis_host}" \
      -e "redis_port=${redis_port}" \
      -e "redis_pass=${redis_pass}" \
      jonssonyan/trojan-panel

  if [[ -n $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
    echo_content skyBlue "---> Trojan Panel back-end update completed"
  else
    echo_content red "---> Trojan Panel backend failed to update or run abnormally, please try to repair or uninstall and reinstall"
  fi

  docker pull jonssonyan/trojan-panel-ui &&
    docker run -d --name trojan-panel-ui --restart always \
      --network=host \
      -v ${NGINX_CONFIG}:/etc/nginx/conf.d/default.conf \
      -v ${CADDY_ACME}"${domain}":${CADDY_ACME}"${domain}" \
      jonssonyan/trojan-panel-ui

  if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
    echo_content skyBlue "---> Trojan Panel front-end update completed"
  else
    echo_content red "---> Trojan Panel front-end update failed or run abnormally, please try to repair or uninstall and reinstall"
  fi
}

# 更新Trojan Panel Core
update_trojan_panel_core() {
  # 判断Trojan Panel Core是否安装
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
    echo_content red "---> Please install Trojan Panel Core first"
    exit 0
  fi

  echo_content green "---> Update Trojan Panel Core"

  read -r -p "Please enter the IP address of the database (default: local database): " mariadb_ip
  [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
  read -r -p "Please enter the port of the database (default: 9507): " mariadb_port
  [[ -z "${mariadb_port}" ]] && mariadb_port=9507
  read -r -p "Please enter the username of the database (default: root): " mariadb_user
  [[ -z "${mariadb_user}" ]] && mariadb_user="root"
  while read -r -p "Please enter the password for the database (required): " mariadb_pas; do
    if [[ -z "${mariadb_pas}" ]]; then
      echo_content red "Password cannot be empty"
    else
      break
    fi
  done
  read -r -p "Please enter the database name (default: trojan_panel_db): " database
  [[ -z "${database}" ]] && database="trojan_panel_db"
  read -r -p "Please enter the name of the user table in the database (default: account): " account_table
  [[ -z "${account_table}" ]] && account_table="account"

  read -r -p "Please enter the IP address of Redis (default: local Redis): " redis_host
  [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
  read -r -p "Please enter the port of Redis (default: 6378): " redis_port
  [[ -z "${redis_port}" ]] && redis_port=6378
  while read -r -p "Please enter your Redis password (required): " redis_pass; do
    if [[ -z "${redis_pass}" ]]; then
      echo_content red "Password cannot be empty"
    else
      break
    fi
  done

  docker rm -f trojan-panel-core &&
    docker rmi -f jonssonyan/trojan-panel-core &&
    rm -rf ${TROJAN_PANEL_CORE_DATA}

  docker pull jonssonyan/trojan-panel-core &&
    docker run -d --name trojan-panel-core --restart always \
      --network=host \
      -v ${TROJAN_PANEL_CORE_DATA}bin:${TROJAN_PANEL_CORE_DATA}bin \
      -v ${TROJAN_PANEL_CORE_LOGS}:${TROJAN_PANEL_CORE_LOGS} \
      -v ${CADDY_ACME}:${CADDY_ACME} \
      -v /etc/localtime:/etc/localtime \
      -e "mariadb_ip=${mariadb_ip}" \
      -e "mariadb_port=${mariadb_port}" \
      -e "mariadb_user=${mariadb_user}" \
      -e "mariadb_pas=${mariadb_pas}" \
      -e "database=${database}" \
      -e "account-table=${account_table}" \
      -e "redis_host=${redis_host}" \
      -e "redis_port=${redis_port}" \
      -e "redis_pass=${redis_pass}" \
      jonssonyan/trojan-panel-core

  if [[ "$?" == "0" ]]; then
    echo_content skyBlue "---> Trojan Panel Core update completed"
  else
    echo_content red "---> Trojan Panel Core update failed"
  fi
}

# 卸载Caddy TLS
uninstall_caddy_tls() {
  # 判断Caddy TLS是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> Uninstall Caddy TLS"

    docker rm -f trojan-panel-caddy &&
      rm -rf ${CADDY_DATA}

    echo_content skyBlue "---> Caddy TLS uninstallation complete"
  else
    echo_content red "---> Please install Caddy first TLS"
  fi
}

# 卸载MariaDB
uninstall_mariadb() {
  # 判断MariaDB是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-mariadb$") ]]; then
    echo_content green "---> Uninstalling MariaDB"

    docker rm -f trojan-panel-mariadb &&
      rm -rf ${MARIA_DATA}

    echo_content skyBlue "---> MariaDB uninstallation completed"
  else
    echo_content red "---> Please install MariaDB first"
  fi
}

# 卸载Redis
uninstall_redis() {
  # 判断Redis是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content green "---> Uninstalling Redis"

    docker rm -f trojan-panel-redis &&
      rm -rf ${REDIS_DATA}

    echo_content skyBlue "---> Redis uninstallation complete"
  else
    echo_content red "---> Please install Redis first"
  fi
}

# 卸载Trojan Panel
uninstall_trojan_panel() {
  # 判断Trojan Panel是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
    echo_content green "---> Uninstall Trojan Panel"

    docker rm -f trojan-panel &&
      docker rmi -f jonssonyan/trojan-panel &&
      rm -rf ${TROJAN_PANEL_DATA}

    docker rm -f trojan-panel-ui &&
      docker rmi -f jonssonyan/trojan-panel-ui &&
      rm -rf ${TROJAN_PANEL_UI_DATA} &&
      rm -rf ${NGINX_DATA}

    echo_content skyBlue "---> Trojan Panel uninstallation is complete"
  else
    echo_content red "---> Please install Trojan first Panel"
  fi
}

# 卸载Trojan Panel Core
uninstall_trojan_panel_core() {
  # 判断Trojan Panel Core是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
    echo_content green "---> Uninstall Trojan Panel Core"

    docker rm -f trojan-panel-core &&
      docker rmi -f jonssonyan/trojan-panel-core &&
      rm -rf ${TROJAN_PANEL_CORE_DATA}

    echo_content skyBlue "---> Trojan Panel Core uninstallation complete"
  else
    echo_content red "---> Please install Trojan first Panel Core"
  fi
}

# 卸载全部Trojan Panel相关的容器
uninstall_all() {
  echo_content green "---> Uninstall all Trojan Panel related containers"

  docker rm -f $(docker ps -a -q -f "name=^trojan-panel") &&
    docker rmi -f $(docker images | grep "^jonssonyan/trojan-panel" | awk '{print $3}') &&
    rm -rf ${TP_DATA}

  echo_content skyBlue "---> Uninstall all Trojan Panel related containers to finish"
}

# 刷新Redis缓存
redis_flush_all() {
  # 判断Redis是否安装
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content red "---> Please install Redis first"
    exit 0
  fi

  if [[ -z $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
    echo_content red "---> Redis is running abnormally"
    exit 0
  fi

  echo_content green "---> Refresh Redis cache"

  read -r -p "Please enter the IP address of Redis (default: local Redis): " redis_host
  [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
  read -r -p "Please enter the port of Redis (default: 6378): " redis_port
  [[ -z "${redis_port}" ]] && redis_port=6378
  while read -r -p "Please enter the Redis password (required): " redis_pass; do
    if [[ -z "${redis_pass}" ]]; then
      echo_content red "Password cannot be empty"
    else
      break
    fi
  done

  if [[ "${redis_host}" == "127.0.0.1" ]]; then
    docker exec trojan-panel-redis redis-cli -a "${redis_pass}" -e "flushall" &>/dev/null
  else
    docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null
  fi

  echo_content skyBlue "---> Redis cache flush complete"
}

# 故障检测
failure_testing() {
  echo_content green "---> Fault detection starting..."
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content red "---> Troubleshooting Docker Run Exceptions"
  else
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
      if [[ -z $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
        echo_content red "---> Caddy TLS operation exception"
      fi
      domain=$(cat "${DOMAIN_FILE}")
      if [[ -z $(cat "${DOMAIN_FILE}") || ! -d "${CADDY_ACME}${domain}" || ! -f "${CADDY_ACME}${domain}/${domain}.crt" ]]; then
        echo_content red "---> The certificate application is abnormal, please try to restart the server to reapply for the certificate or rebuild and select the custom certificate option"
      fi
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-mariadb$") && -z $(docker ps -q -f "name=^trojan-panel-mariadb$" -f "status=running") ]]; then
      echo_content red "---> MariaDB runs abnormally"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-redis$") && -z $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
      echo_content red "---> Redis is running abnormally"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") && -z $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
      echo_content red "---> Trojan The backend of Panel runs abnormally"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-ui$") && -z $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
      echo_content red "---> Trojan The front end of the Panel runs abnormally"
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-core$") && -z $(docker ps -q -f "name=^trojan-panel-core$" -f "status=running") ]]; then
      echo_content red "---> Trojan Panel Core running abnormally"
    fi
  fi
  echo_content green "---> Troubleshooting Finished."
}

log_query() {
  while :; do
    echo_content skyBlue "The applications that can query the log are as follows:"
    echo_content yellow "1. Trojan Panel"
    echo_content yellow "2. Trojan Panel Core"
    echo_content yellow "3. Exit"
    read -r -p "Please select application(default:1): " select_log_query_type
    [[ -z "${select_log_query_type}" ]] && select_log_query_type=1

    case ${select_log_query_type} in
    1)
      log_file_path=${TROJAN_PANEL_LOGS}trojan-panel.log
      ;;
    2)
      log_file_path=${TROJAN_PANEL_CORE_LOGS}trojan-panel-core.log
      ;;
    3)
      break
      ;;
    *)
      echo_content red "There is no such option"
      continue
      ;;
    esac

    read -r -p "Please enter the number of rows for the query (default: 20): " select_log_query_line_type
    [[ -z "${select_log_query_line_type}" ]] && select_log_query_line_type=20

    if [[ -f ${log_file_path} ]]; then
      echo_content skyBlue "Log files are as follows:"
      tail -n ${select_log_query_line_type} ${log_file_path}
    else
      echo_content red "No log file exists"
    fi
  done
}

main() {
  cd "$HOME" || exit 0
  init_var
  mkdir_tools
  check_sys
  depend_install
  clear
  echo_content red "\n=============================================================="
  echo_content skyBlue "System Required: CentOS 7+/Ubuntu 18+/Debian 10+"
  echo_content skyBlue "Version: v1.3.1"
  echo_content skyBlue "Description: One click Install Trojan Panel server"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/trojanpanel"
  echo_content skyBlue "Docs: https://trojanpanel.github.io"
  echo_content red "\n=============================================================="
  echo_content yellow "1. Install Trojan Panel"
  echo_content yellow "2. Install Trojan Panel Core"
  echo_content yellow "3. ّInstall Caddy TLS"
  echo_content yellow "4. ّInstall MariaDB"
  echo_content yellow "5. ّInstall Redis"
  echo_content green "\n=============================================================="
  echo_content yellow "6. Uninstall Trojan Panel"
  echo_content yellow "7. Uninstall Trojan Panel Core"
  echo_content yellow "8. Uninstall Caddy TLS"
  echo_content yellow "9. Uninstall MariaDB"
  echo_content yellow "10. Uninstall Redis"
  echo_content yellow "11. Uninstall All Trojan Panel Related Applications"
  echo_content green "\n=============================================================="
  echo_content yellow "12. Clear Redis Cache"
  echo_content yellow "13. Troubleshoot"
  echo_content yellow "14. Log query"
  read -r -p "Please select:" selectInstall_type
  case ${selectInstall_type} in
  1)
    install_docker
    install_caddy_tls
    install_mariadb
    install_redis
    install_trojan_panel
    ;;
  2)
    install_docker
    install_caddy_tls
    install_trojan_panel_core
    ;;
  3)
    install_docker
    install_caddy_tls
    ;;
  4)
    install_docker
    install_mariadb
    ;;
  5)
    install_docker
    install_redis
    ;;
  6)
    uninstall_trojan_panel
    ;;
  7)
    uninstall_trojan_panel_core
    ;;
  8)
    uninstall_caddy_tls
    ;;
  9)
    uninstall_mariadb
    ;;
  10)
    uninstall_redis
    ;;
  11)
    uninstall_all
    ;;
  12)
    redis_flush_all
    ;;
  13)
    failure_testing
    ;;
  14)
    log_query
    ;;
  *)
    echo_content red "There is no such option"
    ;;
  esac
}

main
