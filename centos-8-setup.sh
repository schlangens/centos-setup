#!/bin/bash
#
# centos-8-setup.sh
#
# (c) Niki Kovacs 2019 <info@microlinux.fr>
#
# /!\ WORK IN PROGRESS /!\ 

# Enterprise Linux version
VERSION="el7"

# Current directory
CWD=$(pwd)

# Defined users
USERS="$(ls -A /home)"

# Log
LOG="/tmp/$(basename "${0}" .sh).log"
echo > ${LOG}

usage() {
  echo "Usage: ${0} OPTION"
  echo 'CentOS 8.x post-install configuration for servers.'
  echo 'Options:'
  echo '  -1, --shell    Configure shell: Bash, Vim, console, etc.'
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
  -h|--help) 
    usage
    exit 0
    ;;
  ?*) 
    usage
    exit 1
esac

exit 0

