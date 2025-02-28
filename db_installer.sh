#!/bin/bash

usage() {
    cat <<EOM
====================================================================
Usage: $(basename "$0") [OPTIONS]

Version: 25.01.29

This script will perform installation of the Tantor DB on current host.
If the Tantor DB is already installed, no actions will be taken.

Available options:
  --help                    Show this help message.

--------------------------------------------------------------------
  --edition=                Set edition (be, se, se-1c, certified). "se" is default.
  --major-version=          Set major version (14, 15)
  --maintenance-version=    Set maintenance version (15.2.4).
                            By default latest version will be installed.

  --do-initdb               After installation run initdb with checksums.

  --package=                Set specific package (all, client, libpq5).
                            "all" is default.

--------------------------------------------------------------------
  --from-file=              Install package from local file (rpm, deb)
                            May be used with --do-initdb option

====================================================================
Example for commercial use
====================================================================

export NEXUS_USER="user_name"
export NEXUS_USER_PASSWORD="user_password"
export NEXUS_URL="nexus.tantorlabs.ru"

./db_installer.sh \\
    --do-initdb \\
    --major-version=15 \\
    --edition=se

====================================================================
Example for evaluation use (without login and password)
Only for Basic Edition
====================================================================

export NEXUS_URL="nexus-public.tantorlabs.ru"

./db_installer.sh \\
    --do-initdb \\
    --major-version=15 \\
    --edition=be

====================================================================
Examples how to install from file
====================================================================

./db_installer.sh \\
    --from-file=./packages/tantor-be-server-15_15.4.1.jammy_amd64.deb

./db_installer.sh \\
    --do-initdb \\
    --from-file=/tmp/tantor-be-server-15_15.4.1.jammy_amd64.deb

EOM
}

ARG_EDITION__="se"
ARG_PACKAGE__="all"
ARG_DO_INITDB__=0
ARG_MAJOR_VERSION__=15
ARG_MAINTENANCE_VERSION__=""
ARG_FROM_FILE__=""

for i in "$@"; do
    case $i in
    --help)
        usage
        exit 1
        ;;
    --edition=*)
        ARG_EDITION__="${i#*=}"
        shift
        ;;
    --package=*)
        ARG_PACKAGE__="${i#*=}"
        shift
        ;;
    --major-version=*)
        ARG_MAJOR_VERSION__="${i#*=}"
        shift
        ;;
    --maintenance-version=*)
        ARG_MAINTENANCE_VERSION__="${i#*=}"
        shift
        ;;
    --do-initdb)
        ARG_DO_INITDB__=1
        ;;
    --from-file=*)
        ARG_FROM_FILE__="${i#*=}"
        ;;
    *)
        echo "Unknown option: $i"
        usage
        exit 1
        ;;
    esac
done

PACKAGE_IS_ALL=0     # equal "--package=all"

if [ -n "$ARG_FROM_FILE__" ]; then
    # Check if the file exists
    if [ -f "$ARG_FROM_FILE__" ]; then
        # Extract the file extension
        file_extension="${ARG_FROM_FILE__##*.}"

        # Check if the file extension is 'rpm' or 'deb'
        if [ "$file_extension" = "rpm" ] || [ "$file_extension" = "deb" ]; then
            echo "Processing file: $ARG_FROM_FILE__"

            # Detect OS
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS_ID=$ID
                OS_VERSION_ID=$VERSION_ID
                OS_ARCH=$(uname -m)

                OS_INFO="${ID_LIKE} ${PRETTY_NAME}"
                OS_INFO=$(echo $OS_INFO | tr '[:upper:]' '[:lower:]')
            fi

            if [[ $OS_INFO == *"rhel"* ]] || [[ $OS_INFO == *"centos"* ]] || [[ $OS_INFO == *"fedora"* ]] || [[ $OS_INFO == *"oracle"* ]]; then

                get_package_manager() {
                    if [ -x "$(command -v dnf)" ]; then
                        echo "dnf"
                    else
                        echo "yum"
                    fi
                }

                PACKAGE_MANAGER=$(get_package_manager)

                if [ "$file_extension" != "rpm" ]; then
                    echo "Error: File $ARG_FROM_FILE__ can't be installed."
                    exit 1
                fi
                # Extracting package metadata for RPM
                PACKAGE_NAME=$(rpm -qp --queryformat '%{NAME}\n' "$ARG_FROM_FILE__")
                PACKAGE_VERSION=$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}\n' "$ARG_FROM_FILE__")

                if [ "$PACKAGE_MANAGER" == "dnf" ]; then
                    dnf install -y "$ARG_FROM_FILE__"
                else
                    yum install -y "$ARG_FROM_FILE__"
                fi
            fi

            if [[ $OS_INFO == *"alt"* ]]; then
                if [ "$file_extension" != "rpm" ]; then
                    echo "Error: File $ARG_FROM_FILE__ can't be installed."
                    exit 1
                fi
                # Extracting package metadata for RPM
                PACKAGE_NAME=$(rpm -qp --queryformat '%{NAME}\n' "$ARG_FROM_FILE__")
                PACKAGE_VERSION=$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}\n' "$ARG_FROM_FILE__")

                apt-get install -y $ARG_FROM_FILE__
            fi

            if [[ $OS_INFO == *"debian"* ]] || [[ $OS_INFO == *"ubuntu"* ]]; then
                if [ "$file_extension" != "deb" ]; then
                    echo "Error: File $ARG_FROM_FILE__ can't be installed."
                    exit 1
                fi
                # Extracting package metadata for DEB
                PACKAGE_NAME=$(dpkg-deb --show --showformat='${Package}\n' "$ARG_FROM_FILE__")
                PACKAGE_VERSION=$(dpkg-deb --show --showformat='${Version}\n' "$ARG_FROM_FILE__")

                apt-get install -y $ARG_FROM_FILE__
            fi

            ARG_MAJOR_VERSION__=$(echo "$PACKAGE_VERSION" | awk -F. '{print $1}')
            # echo "Package Name: $PACKAGE_NAME"
            # echo "Package Version: $PACKAGE_VERSION"

            if [[ $PACKAGE_NAME == *"-se-"* ]]; then
                ARG_EDITION__="se"
            fi

            if [[ $PACKAGE_NAME == *"-free-"* ]]; then
                ARG_EDITION__="free"
            fi

            if [[ $PACKAGE_NAME == *"-se-1c-"* ]]; then
                ARG_EDITION__="se-1c"
            fi

            if [[ $PACKAGE_NAME == *"-be-"* ]]; then
                ARG_EDITION__="be"
            fi

            if [[ $PACKAGE_NAME == *"-certified-"* ]]; then
                ARG_EDITION__="certified"
            fi

            if [[ "$ARG_FROM_FILE__" =~ "server" ]]; then
                PACKAGE_IS_ALL=1
            fi
        else
            echo "Error: File extension is not 'rpm' or 'deb'."
            exit 1
        fi
    else
        echo "Error: File $ARG_FROM_FILE__ does not exist."
        exit 1
    fi
else
    if [ -z "$NEXUS_URL" ]; then
        echo -e "\nNEXUS_URL variable does not exist\n"
        usage
        exit 1
    fi

    if [[ ! $NEXUS_URL =~ nexus-public.tantorlabs.ru ]]; then
        variables=(
            "NEXUS_USER"
            "NEXUS_USER_PASSWORD"
        )

        for var in "${variables[@]}"; do
            if [ -z "${!var:-}" ]; then
                echo -e "\n$var is not configured\n"
                echo -e "============> To configure env variables run:\n"
                echo 'export NEXUS_USER="user_name"'
                echo 'export NEXUS_USER_PASSWORD="password"'
                echo 'export NEXUS_URL="nexus.tantorlabs.ru"'
                echo ''
                exit 1
            fi
        done
    fi

    url_encode() {
        local string="$1"
        local strlen=${#string}
        local encoded=""
        local pos c o

        for ((pos = 0; pos < strlen; pos++)); do
            c=${string:$pos:1}
            case "$c" in
            [-_.~a-zA-Z0-9]) o="${c}" ;;
            *) printf -v o '%%%02x' "'$c" ;;
            esac
            encoded+="${o}"
        done
        echo "${encoded}"
    }

    if [[ $NEXUS_URL =~ ^http ]]; then
        echo "NEXUS_URL variable must not include 'http(s)'."
        exit 1
    fi

    NEXUS_USER_PASSWORD_ENCODED=$(url_encode "$NEXUS_USER_PASSWORD")
    NEXUS_URL_ORIG=$NEXUS_URL

    if [[ $NEXUS_URL =~ nexus-public.tantorlabs.ru ]]; then
        NEXUS_URL="https://${NEXUS_URL}"
    else
        NEXUS_URL="https://${NEXUS_USER}:${NEXUS_USER_PASSWORD_ENCODED}@${NEXUS_URL}"
    fi

    PUBLIC_KEY_URL="https://public.tantorlabs.ru/tantorlabs.ru.asc"

    valid_packages=("all" "client" "libpq5")
    if [[ ! " ${valid_packages[@]} " =~ " ${ARG_PACKAGE__} " ]]; then
        echo "Invalid package: $ARG_PACKAGE__. Valid options are 'all', 'client', 'libpq5'"
        exit 1
    fi

    valid_editions=("free" "be" "se" "se-1c" "certified")
    if [[ ! " ${valid_editions[@]} " =~ " ${ARG_EDITION__} " ]]; then
        echo "Invalid edition: $ARG_EDITION__. Valid options are 'be', 'se', 'se-1c', 'certified'"
        exit 1
    fi

    if [ "$ARG_DO_INITDB__" -eq 1 ] && [ "$ARG_PACKAGE__" != "all" ]; then
        echo "Cannot run initdb for package:" $ARG_PACKAGE__
        echo "Installation stopped!"
        exit 1
    fi


    if [ "$ARG_PACKAGE__" = "all" ]; then
        PACKAGE_IS_ALL=1
    fi

    unset OS_REPOS
    declare -A OS_REPOS

    OS_REPOS+=(
        ["ubuntu_18.04_x86_64"]="ubuntu-18.04 bionic main"
        ["ubuntu_20.04_x86_64"]="ubuntu-20.04 focal main"
        ["ubuntu_22.04_x86_64"]="ubuntu-22.04 jammy main"
        ["astra_4.7_arm_aarch64"]="astra-novorossiysk-4.7 novorossiysk main"
        ["astra_2.12.*_x86_64"]="astra-orel-2.12 orel main"
        ["astra_1.7_x86-64_x86_64"]="astra-smolensk-1.7 smolensk main"
        ["astra_1.8_x86-64_x86_64"]="astra-1.8 1.8_x86-64 main"
        ["debian_10_x86_64"]="debian-10 buster main"
        ["debian_11_x86_64"]="debian-11 bullseye main"
        ["debian_12_x86_64"]="debian-12 bookworm main"
        ["redos_7.3.2_x86_64"]="redos-7.3"
        ["redos_8.*_x86_64"]="redos-8"
        ["centos_7_x86_64"]="centos-7"
        ["rocky_8.*_x86_64"]="rocky-8"
        ["rocky_9.*_x86_64"]="rocky-9"
        ["altlinux_8.4_x86_64"]="altrepo_c9f2"
        ["altlinux_10_x86_64"]="altrepo_p10"
        ["altlinux_10.*_x86_64"]="altrepo_p10"
        ["ol_8.*_x86_64"]="oracle-8"
    )

    NEXUS_REPO_PATH=""
    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_VERSION_ID=$VERSION_ID
        OS_ARCH=$(uname -m)

        OS_INFO="${ID_LIKE} ${PRETTY_NAME}"
        OS_INFO=$(echo $OS_INFO | tr '[:upper:]' '[:lower:]')

        KEY="${OS_ID}_${OS_VERSION_ID}_${OS_ARCH}"

        MATCHED_REPO=""
        for pattern in "${!OS_REPOS[@]}"; do
            if [[ $KEY =~ $pattern ]]; then
                MATCHED_REPO="${OS_REPOS[$pattern]}"
                break
            fi
        done

        if [[ -n "$MATCHED_REPO" ]]; then
            NEXUS_REPO_PATH=$MATCHED_REPO
        else
            echo "Key not found in OS_REPOS: " $KEY
            exit 1
        fi
    fi

    # set -exu -o pipefail
    set -e

    if [[ $OS_INFO == *"debian"* ]] || [[ $OS_INFO == *"ubuntu"* ]]; then

        apt-get update

        if command -v dpkg >/dev/null; then
            echo "dpkg is installed (found in PATH)."
        else
            echo "dpkg is NOT installed or not in PATH."
        fi

        if [ "${ARG_MAJOR_VERSION__}" -ge 16 ]; then

            FRONTENDS=("dialog" "whiptail" "debconf-gtk" "debconf-kde")

            ANY_FRONTEND_INSTALLED=false

            for fe in "${FRONTENDS[@]}"; do
                if dpkg -s "$fe" &>/dev/null; then
                    # echo "Package '$fe' is installed."
                    ANY_FRONTEND_INSTALLED=true
                fi
            done

            if ! dpkg -s tzdata &>/dev/null && [ "$ANY_FRONTEND_INSTALLED" = 'false' ]; then
                echo "======================================================="
                echo "tzdata will be installed but no any front-end detected."
                echo "This may lead to debconf warnings during package installation."
                echo "To avoid this issue, you need install one of debconf frontends, e.g.:"
                echo "    apt install dialog"
                echo "    dpkg-reconfigure debconf"
                echo "======================================================="
            fi
        fi

        if ! command -v gpg >/dev/null; then
            apt-get install -y gnupg
        fi
        if ! command -v lsof >/dev/null; then
            apt-get install -y lsof
        fi

        if ! dpkg -l | grep -q apt-transport-https; then
            apt-get install -y apt-transport-https
        fi

        wget -qO - $PUBLIC_KEY_URL | apt-key add -

        REPO_ARCH=""
        if [ "$OS_ARCH" == "aarch64" ]; then
            REPO_ARCH="arm64"
        else
            REPO_ARCH="amd64"
        fi

        echo "deb [arch=${REPO_ARCH}] ${NEXUS_URL}/repository/${NEXUS_REPO_PATH}" |
            tee /etc/apt/sources.list.d/tantorlabs.list

        apt-get update

        if [ -z "$ARG_MAINTENANCE_VERSION__" ]; then

            if [[ $ARG_PACKAGE__ == "all" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}
            fi

            if [[ $ARG_PACKAGE__ == "client" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-client-${ARG_MAJOR_VERSION__}
            fi

            if [[ $ARG_PACKAGE__ == "libpq5" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-libpq5-${ARG_MAJOR_VERSION__}
            fi

        else
            if [[ $ARG_PACKAGE__ == "all" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}=${ARG_MAINTENANCE_VERSION__}
            fi

            if [[ $ARG_PACKAGE__ == "client" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-client-${ARG_MAJOR_VERSION__}=${ARG_MAINTENANCE_VERSION__}
            fi

            if [[ $ARG_PACKAGE__ == "libpq5" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-libpq5-${ARG_MAJOR_VERSION__}=${ARG_MAINTENANCE_VERSION__}
            fi
        fi
    fi

    if [[ $OS_INFO == *"rhel"* ]] || [[ $OS_INFO == *"centos"* ]] || [[ $OS_INFO == *"fedora"* ]] || [[ $OS_INFO == *"oracle"* ]]; then

	    get_package_manager() {
            if [ -x "$(command -v dnf)" ]; then
                echo "dnf"
            else
                echo "yum"
            fi
        }

        PACKAGE_MANAGER=$(get_package_manager)

        if ! command -v lsof >/dev/null; then
            if [ "$PACKAGE_MANAGER" == "dnf" ]; then
                dnf install -y lsof
            else
                yum install -y lsof
            fi
        fi

        rpm --import $PUBLIC_KEY_URL

        echo "[tantorlabs]
name=Tantor Labs Repository
baseurl=${NEXUS_URL}/repository/${NEXUS_REPO_PATH}
enabled=1
gpgcheck=1
gpgkey=https://public.tantorlabs.ru/tantorlabs.ru.asc" |
            tee /etc/yum.repos.d/tantorlabs.repo

        if [ "$PACKAGE_MANAGER" == "dnf" ]; then
            dnf --disablerepo="*" --enablerepo="tantorlabs" update -y
        else
            yum --disablerepo="*" --enablerepo="tantorlabs" update -y
        fi

        if [ -z "$ARG_MAINTENANCE_VERSION__" ]; then

            if [[ $ARG_PACKAGE__ == "all" ]]; then
                if [ "$PACKAGE_MANAGER" == "dnf" ]; then
                    dnf install -y tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}
                else
                    yum install -y tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}
                fi
            fi

            if [[ $ARG_PACKAGE__ == "client" ]]; then
                if [ "$PACKAGE_MANAGER" == "dnf" ]; then
                    dnf install -y tantor-${ARG_EDITION__}-client-${ARG_MAJOR_VERSION__}
                else
                    yum install -y tantor-${ARG_EDITION__}-client-${ARG_MAJOR_VERSION__}
                fi
            fi

            if [[ $ARG_PACKAGE__ == "libpq5" ]]; then
                if [ "$PACKAGE_MANAGER" == "dnf" ]; then
                    dnf install -y tantor-${ARG_EDITION__}-libpq5-${ARG_MAJOR_VERSION__}
                else
                    yum install -y tantor-${ARG_EDITION__}-libpq5-${ARG_MAJOR_VERSION__}
                fi
            fi

        else
            if [[ $ARG_PACKAGE__ == "all" ]]; then
                if [ "$PACKAGE_MANAGER" == "dnf" ]; then
                    dnf install -y tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}-${ARG_MAINTENANCE_VERSION__}-0
                else
                    yum install -y tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}-${ARG_MAINTENANCE_VERSION__}-0
                fi
            fi

            if [[ $ARG_PACKAGE__ == "client" ]]; then
                if [ "$PACKAGE_MANAGER" == "dnf" ]; then
                    dnf install -y tantor-${ARG_EDITION__}-client-${ARG_MAJOR_VERSION__}-${ARG_MAINTENANCE_VERSION__}-0
                else
                    yum install -y tantor-${ARG_EDITION__}-client-${ARG_MAJOR_VERSION__}-${ARG_MAINTENANCE_VERSION__}-0
                fi
            fi

            if [[ $ARG_PACKAGE__ == "libpq5" ]]; then
                if [ "$PACKAGE_MANAGER" == "dnf" ]; then
                    dnf install -y tantor-${ARG_EDITION__}-libpq5-${ARG_MAJOR_VERSION__}-${ARG_MAINTENANCE_VERSION__}-0
                else
                    yum install -y tantor-${ARG_EDITION__}-libpq5-${ARG_MAJOR_VERSION__}-${ARG_MAINTENANCE_VERSION__}-0
                fi
            fi
        fi
    fi

    _LOCAL_SU_EXT_PARAMS__=""

    if [[ $OS_INFO == *"alt"* ]]; then
        _LOCAL_SU_EXT_PARAMS__="-s /bin/bash"

        apt-get update

        if ! command -v gpg >/dev/null; then
            apt-get install -y gnupg
        fi
        if ! command -v wget >/dev/null; then
            apt-get install -y wget
        fi
        if ! command -v lsof >/dev/null; then
            apt-get install -y lsof
        fi

        apt-get install -y apt-https
        set -exu
        wget -qO /tmp/tantorlabs.pub.pgp $NEXUS_URL/repository/${NEXUS_REPO_PATH}/keys/tantorlabs.pub.pgp
        gpg --no-default-keyring --keyring /usr/lib/alt-gpgkeys/pubring.gpg --import /tmp/tantorlabs.pub.pgp

        echo "machine $NEXUS_URL_ORIG" >/etc/apt/auth-tantor.conf
        echo "login $NEXUS_USER" >>/etc/apt/auth-tantor.conf
        echo "password $NEXUS_USER_PASSWORD" >>/etc/apt/auth-tantor.conf
        echo "Acquire::https::${NEXUS_URL_ORIG}/repository/${NEXUS_REPO_PATH}::Auth-File \"/etc/apt/auth-tantor.conf\";" |
            tee /etc/apt/apt.conf.d/auth-tantor

        echo "rpm https://${NEXUS_URL_ORIG}/repository/${NEXUS_REPO_PATH} x86_64 tantor" |
            tee /etc/apt/sources.list.d/tantorlabs.list

        apt-get update

        if [ -z "$ARG_MAINTENANCE_VERSION__" ]; then

            if [[ $ARG_PACKAGE__ == "all" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}
            fi

            if [[ $ARG_PACKAGE__ == "client" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-client-${ARG_MAJOR_VERSION__}
            fi

            if [[ $ARG_PACKAGE__ == "libpq5" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-libpq5-${ARG_MAJOR_VERSION__}
            fi
        else

            if [[ $ARG_PACKAGE__ == "all" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}=${ARG_MAINTENANCE_VERSION__}
            fi

            if [[ $ARG_PACKAGE__ == "client" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-client-${ARG_MAJOR_VERSION__}=${ARG_MAINTENANCE_VERSION__}
            fi

            if [[ $ARG_PACKAGE__ == "libpq5" ]]; then
                apt-get install -y tantor-${ARG_EDITION__}-libpq5-${ARG_MAJOR_VERSION__}=${ARG_MAINTENANCE_VERSION__}
            fi
        fi
    fi
fi

if [ $ARG_DO_INITDB__ = 1 ] && [ $PACKAGE_IS_ALL = 1 ]; then
    _LOCAL_DATA_DIR__="/var/lib/postgresql/tantor-${ARG_EDITION__}-${ARG_MAJOR_VERSION__}/data"
    # _LOCAL_BIN_DIR__="/opt/tantor/db/${ARG_MAJOR_VERSION__}/bin"

    if [ -d "$_LOCAL_DATA_DIR__" ] && [ "$(ls -A $_LOCAL_DATA_DIR__)" ]; then
        echo ""
        echo "==============================================="
        echo "Data catalog '$_LOCAL_DATA_DIR__' is not empty! Stopping..."
        echo
        ls -lah $_LOCAL_DATA_DIR__
        echo
        echo "Rename this directory and repeat last command with db_installer.sh"
        echo
        exit 1
    else
        su - postgres $_LOCAL_SU_EXT_PARAMS__ -c "/opt/tantor/db/${ARG_MAJOR_VERSION__}/bin/initdb \
            --data-checksums \
            -D $_LOCAL_DATA_DIR__"
        systemctl enable tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}

        if lsof -Pi :5432 -sTCP:LISTEN -t >/dev/null; then
            sed -i 's/#port = 5432/port = 5434/g' \
                $_LOCAL_DATA_DIR__/postgresql.conf
        fi

        systemctl start tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__}
        systemctl_output=$(systemctl status tantor-${ARG_EDITION__}-server-${ARG_MAJOR_VERSION__})
        echo "$systemctl_output"

        psql_output=$(su - postgres $_LOCAL_SU_EXT_PARAMS__ -c "/opt/tantor/db/${ARG_MAJOR_VERSION__}/bin/psql \
            -U postgres -d postgres -c \"select tantor_version()\"")

        echo
        echo "$psql_output"
        echo

        if [[ $psql_output == *"tantor_version"* ]]; then
            echo -e "\nInstallation successfully completed.\n"
            exit 0
        else
            echo -e "\nInstallation failed.\n"
            exit 1
        fi
    fi
else
    if [[ ("${ARG_PACKAGE__}" == client && -f "/opt/tantor/db/${ARG_MAJOR_VERSION__}/bin/psql") ||
          ("${ARG_PACKAGE__}" == libpq5 && -e "/opt/tantor/db/${ARG_MAJOR_VERSION__}/lib/libpq.so") ||
          ("${ARG_PACKAGE__}" == all && -f "/opt/tantor/db/${ARG_MAJOR_VERSION__}/bin/postgres") ]]; then
        echo -e "\nInstallation successfully completed.\n"
        exit 0
    else
        echo -e "\nInstallation failed.\n"
        exit 1
    fi
fi
