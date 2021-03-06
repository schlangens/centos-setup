#!/bin/bash
#
# centos-8-setup.sh
#
# (c) Niki Kovacs 2019 <info@microlinux.fr>
#
# /!\ WORK IN PROGRESS /!\ 

# Enterprise Linux version
VERSION="el8"

# Current directory
CWD=$(pwd)

# Defined users
USERS="$(ls -A /home)"

# Install these packages
EXTRA=$(egrep -v '(^\#)|(^\s+$)' ${CWD}/${VERSION}/yum/extra-packages.txt)

# Mirrors
ELREPO="http://mirrors.ircam.fr/pub/elrepo/elrepo/${VERSION}/x86_64/RPMS"
CISOFY="https://packages.cisofy.com"

# Log
LOG="/tmp/$(basename "${0}" .sh).log"
echo > ${LOG}

usage() {
  echo "Usage: ${0} OPTION"
  echo 'CentOS 8.x post-install configuration for servers.'
  echo 'Options:'
  echo '  -1, --shell    Configure shell: Bash, Vim, console, etc.'
  echo '  -2, --repos    Setup official and third-party repositories.'
  echo '  -3, --extra    Install enhanced base system.'
  echo "Logs are written to ${LOG}."
}

configure_shell() {
  # Install custom command prompts and a handful of nifty aliases.
  echo 'Configuring Bash shell for root.'
  cat ${CWD}/${VERSION}/bash/bashrc-root > /root/.bashrc
  echo 'Configuring Bash shell for users.'
  cat ${CWD}/${VERSION}/bash/bashrc-users > /etc/skel/.bashrc
  # Existing users might want to use it.
  if [ ! -z "${USERS}" ]
  then
    for USER in ${USERS}
    do
      cat ${CWD}/${VERSION}/bash/bashrc-users > /home/${USER}/.bashrc
      chown ${USER}:${USER} /home/${USER}/.bashrc
    done
  fi
  # Add a handful of nifty system-wide options for Vim.
  echo 'Configuring Vim.'
  cat ${CWD}/${VERSION}/vim/vimrc > /etc/vimrc
  # Set english as main system language.
  if ! rpm -q glibc-langpack-en > /dev/null 2>&1
  then
    echo 'Installing system locale.'
    yum -y install glibc-langpack-en >> ${LOG} 2>&1
  fi
  echo 'Configuring system locale.'
  localectl set-locale LANG=en_US.UTF8
  # Set console resolution
  if [ -f /boot/grub2/grub.cfg ]
  then
    echo 'Configuring console resolution.'
    sed -i -e 's/rhgb quiet/nomodeset quiet vga=791/g' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg >> ${LOG} 2>&1
  fi
}

configure_repos() {
  # Enable BaseOS package repository with a priority of 1.  
  echo 'Configuring BaseOS package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-Base.repo > /etc/yum.repos.d/CentOS-Base.repo
  sed -i -e 's/installonly_limit=3/installonly_limit=2/g' /etc/yum.conf
  # Enable AppStream package repository with a priority of 1.  
  echo 'Configuring AppStream package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-AppStream.repo > /etc/yum.repos.d/CentOS-AppStream.repo
  # Enable Extras package repository with a priority of 1.  
  echo 'Configuring Extras package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-Extras.repo > /etc/yum.repos.d/CentOS-Extras.repo
  # Enable CR package repository with a priority of 1.  
  echo 'Configuring Continuous Release package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-CR.repo > /etc/yum.repos.d/CentOS-CR.repo
  # Enable Fasttrack package repository with a priority of 1.  
  echo 'Configuring Fasttrack package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-fasttrack.repo > /etc/yum.repos.d/CentOS-fasttrack.repo
  # Enable PowerTools package repository with a priority of 1.  
  echo 'Configuring PowerTools package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-PowerTools.repo > /etc/yum.repos.d/CentOS-PowerTools.repo
  # Disable CentOSPlus package repository.
  echo 'Configuring CentOSPlus package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-centosplus.repo > /etc/yum.repos.d/CentOS-centosplus.repo
  # Disable DebugInfo package repository.
  echo 'Configuring DebugInfo package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-Debuginfo.repo > /etc/yum.repos.d/CentOS-Debuginfo.repo
  # Disable Sources package repository.
  echo 'Configuring Sources package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-Sources.repo > /etc/yum.repos.d/CentOS-Sources.repo
  # Disable Media package repository.
  echo 'Configuring Media package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-Media.repo > /etc/yum.repos.d/CentOS-Media.repo
  # Initial update
  echo 'Performing initial update.'
  echo 'This might take a moment...'
  yum -y update >> ${LOG} 2>&1
  # Enable [epel] repo with a priority of 10.
  if ! rpm -q epel-release > /dev/null 2>&1
  then
    echo 'Configuring EPEL package repositories.' 
    yum -y install epel-release >> ${LOG} 2>&1
    cat ${CWD}/${VERSION}/yum/epel.repo > /etc/yum.repos.d/epel.repo
    cat ${CWD}/${VERSION}/yum/epel-testing.repo > /etc/yum.repos.d/epel-testing.repo
    cat ${CWD}/${VERSION}/yum/epel-playground.repo > /etc/yum.repos.d/epel-playground.repo
  fi
  # Configure [elrepo] and [elrepo-kernel] repos without activating them.
  if ! rpm -q elrepo-release > /dev/null 2>&1
  then
    echo 'Configuring ELRepo package repositories.'
    yum -y localinstall \
    ${ELREPO}/elrepo-release-8.0-2.${VERSION}.elrepo.noarch.rpm >> ${LOG} 2>&1
    cat ${CWD}/${VERSION}/yum/elrepo.repo > /etc/yum.repos.d/elrepo.repo
  fi
  # Enable [lynis] repo with a priority of 5.
  if [ ! -f /etc/yum.repos.d/lynis.repo ]
  then
    echo 'Configuring Lynis package repository.'
    rpm --import ${CISOFY}/keys/cisofy-software-rpms-public.key >> ${LOG} 2>&1
    cat ${CWD}/${VERSION}/yum/lynis.repo > /etc/yum.repos.d/lynis.repo
  fi
}

install_extras() {
  echo 'Fetching missing packages from Core package group.' 
  yum -y group mark remove "Core" >> ${LOG} 2>&1
  yum -y group install "Core" >> ${LOG} 2>&1
  echo 'Core package group installed on the system.'
  for PACKAGE in ${EXTRA}
  do
    if ! rpm -q ${PACKAGE} > /dev/null 2>&1
    then
      echo "Installing package: ${PACKAGE}"
      yum -y install ${PACKAGE} >> ${LOG} 2>&1
    fi
  done
  echo 'All additional packages installed on the system.'
}

# Make sure the script is being executed with superuser privileges.
if [[ "${UID}" -ne 0 ]]
then
  echo 'Please run with sudo or as root.' >&2
  exit 1
fi

# Check parameters.
if [[ "${#}" -ne 1 ]]
then
  usage
  exit 1
fi
OPTION="${1}"
case "${OPTION}" in
  -1|--shell) 
    configure_shell
    ;;
  -2|--repos) 
    configure_repos
    ;;
  -3|--extra) 
    install_extras
    ;;
  -h|--help) 
    usage
    exit 0
    ;;
  ?*) 
    usage
    exit 1
esac

exit 0

