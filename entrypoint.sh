#!/bin/sh
set -e

export PATH="/home/sopel/.local/bin:${PATH}"

# Define functions
change_uid () {
  NEW_UID="${1}"
  echo -en "\033[44mSetting UID for user sopel to ${NEW_UID}... \033[0m"
  (usermod -u "${NEW_UID}" sopel && echo -e "\033[92;44mDone.\033[0m") || {
    RC=$?
    echo -e "\033[41mFAILED!\033[0m" && return $RC
  }
}

change_gid () {
  NEW_GID="${1}"
  echo -en "\033[44mSetting GID for user sopel to ${NEW_GID}... \033[0m"
  (groupmod -g "${NEW_GID}" sopel && echo -e "\033[92;44mDone.\033[0m") || {
    RC=$?
    echo -e "\033[41mFAILED!\033[0m" && return $RC
  }
}

install_pip_package () {
  PACKAGE="${1}"
  echo -e "\033[44mInstalling package \"${PACKAGE}\" with pip...\033[0m"
  pip install --user "${PACKAGE}" || {
    RC=$?
    echo -e "\033[41mFAILED!\033[0m" && return $RC
  }
}

install_apk_packages () {
  PACKAGES="${@}"
  echo -e "\033[44mInstalling apk packages: ${PACKAGES}...\033[0m"
  apk add --no-cache ${PACKAGES} || {
    RC=$?
    echo -e "\033[41mFAILED!\033[0m" && return $RC
  }
}

clear_pid_file () {
  for f in /home/sopel/.sopel/*.pid; do
    [ -e "${f}" ] || break
    echo -en "\033[100mExisting .pid file(s) found... Removing...\033[0m"
    if [ "$(ls /home/sopel/.sopel/*.pid  2> /dev/null | wc -l)" -gt "1" ]; then
      echo -e "\033[31;100mFAILED! Multiple .pid files found.\033[0m" && return 1
    fi
    (rm -f /home/sopel/.sopel/*.pid && echo -e "\033[92;100mDone.\033[0m") || {
      RC=$?
      echo -e "\033[41mFAILED!\033[0m" && return $RC
    }
    break
  done
}

# Check if IDs need to be changed
[ -n "${PUID}" ] && change_uid "${PUID}"
[ -n "${PGID}" ] && change_gid "${PGID}"

# Set arguments/flags for sopel command
if [ "${#}" -eq 0 ] || [ "${1#-}" != "${1}" ]; then
  set -- sopel "${@}"
fi

# Run sopel
if [ "${1}" = "sopel" ]; then
  # Install extra apk packages first to satisfy pip requirements
  [ -f "/apk_packages.txt" ] && install_apk_packages $(cat /apk_packages.txt | grep -v '^#' | grep -v '^$' | tr $'\n' ' ')

  [ -n "${EXTRA_APK_PACKAGES}" ] && install_apk_packages ${EXTRA_APK_PACKAGES}

  # Install extra pypi packages
  if [ -f "/pypi_packages.txt" ]; then
    cat /pypi_packages.txt | grep -v '^#' | grep -v '^$' | \
      while read line; do
        [ "${line}" = "\#*" ] && continue
        install_pip_package "${line}"
      done
  fi

  if [ -n "${EXTRA_PYPI_PACKAGES}" ]; then
    for package in ${EXTRA_PYPI_PACKAGES}; do install_pip_package "${package}"; done
  fi

  # Run sopel
  clear_pid_file
  exec "${@}"
fi

# Run arbitrary command, as specific user
if [ -n "${USER}" ]; then
  set -- su-exec "${USER}" "${@}"
fi

# Run arbitrary command, as root
exec "${@}"
