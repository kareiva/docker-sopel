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

install_package () {
  PACKAGE="${1}"
  echo -e "\033[44mInstalling package \"${PACKAGE}\" with pip...\033[0m"
  su-exec sopel pip install --user "${PACKAGE}" || {
    RC=$?
    echo -e "\033[41mFAILED!\033[0m" && return $RC
  }
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
  if [ -f "/pypi_packages.txt" ]; then
    cat /pypi_packages.txt | grep -v '^#' | grep -v '^$' | \
      while read line; do
        [ "${line}" = "\#*" ] && continue
        install_package "${line}"
      done
  fi

  if [ -n "${EXTRA_PYPI_PACKAGES}" ]; then
    for package in ${EXTRA_PYPI_PACKAGES}; do install_package "${package}"; done
  fi

  exec su-exec sopel "${@}"
fi

# Run arbitrary command, as specific user
if [ -n "${USER}" ]; then
  set -- su-exec "${USER}" "${@}"
fi

# Run arbitrary command, as root
exec "${@}"