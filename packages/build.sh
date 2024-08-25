#!/bin/bash

# Cyb3rhq package builder
# Copyright (C) 2015, Cyb3rhq Inc.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.
set -e

build_directories() {
  local build_folder=$1
  local cyb3rhq_dir="$2"
  local future="$3"

  mkdir -p "${build_folder}"
  cyb3rhq_version="$(cat cyb3rhq*/src/VERSION| cut -d 'v' -f 2)"

  if [[ "$future" == "yes" ]]; then
    cyb3rhq_version="$(future_version "$build_folder" "$cyb3rhq_dir" $cyb3rhq_version)"
    source_dir="${build_folder}/cyb3rhq-${BUILD_TARGET}-${cyb3rhq_version}"
  else
    package_name="cyb3rhq-${BUILD_TARGET}-${cyb3rhq_version}"
    source_dir="${build_folder}/${package_name}"
    cp -R $cyb3rhq_dir "$source_dir"
  fi
  echo "$source_dir"
}

# Function to handle future version
future_version() {
  local build_folder="$1"
  local cyb3rhq_dir="$2"
  local base_version="$3"

  specs_path="$(find $cyb3rhq_dir -name SPECS|grep $SYSTEM)"

  local major=$(echo "$base_version" | cut -dv -f2 | cut -d. -f1)
  local minor=$(echo "$base_version" | cut -d. -f2)
  local version="${major}.30.0"
  local old_name="cyb3rhq-${BUILD_TARGET}-${base_version}"
  local new_name=cyb3rhq-${BUILD_TARGET}-${version}

  local new_cyb3rhq_dir="${build_folder}/${new_name}"
  cp -R ${cyb3rhq_dir} "$new_cyb3rhq_dir"
  find "$new_cyb3rhq_dir" "${specs_path}" \( -name "*VERSION*" -o -name "*changelog*" \
        -o -name "*.spec" \) -exec sed -i "s/${base_version}/${version}/g" {} \;
  sed -i "s/\$(VERSION)/${major}.${minor}/g" "$new_cyb3rhq_dir/src/Makefile"
  sed -i "s/${base_version}/${version}/g" $new_cyb3rhq_dir/src/init/cyb3rhq-{server,client,local}.sh
  echo "$version"
}

# Function to generate checksum and move files
post_process() {
  local file_path="$1"
  local checksum_flag="$2"
  local source_flag="$3"

  if [[ "$checksum_flag" == "yes" ]]; then
    sha512sum "$file_path" > /var/local/checksum/$(basename "$file_path").sha512
  fi

  if [[ "$source_flag" == "yes" ]]; then
    mv "$file_path" /var/local/cyb3rhq
  fi
}

# Main script body

# Script parameters
export REVISION="$1"
export JOBS="$2"
debug="$3"
checksum="$4"
future="$5"
legacy="$6"
src="$7"

build_dir="/build_cyb3rhq"

source helper_function.sh

set -x

# Download source code if it is not shared from the local host
if [ ! -d "/cyb3rhq-local-src" ] ; then
    curl -sL https://github.com/cyb3rhq/cyb3rhq/tarball/${CYB3RHQ_BRANCH} | tar zx
    short_commit_hash="$(curl -s https://api.github.com/repos/cyb3rhq/cyb3rhq/commits/${CYB3RHQ_BRANCH} \
                          | grep '"sha"' | head -n 1| cut -d '"' -f 4 | cut -c 1-11)"
else
    if [ "${legacy}" = "no" ]; then
      short_commit_hash="$(cd /cyb3rhq-local-src && git rev-parse --short HEAD)"
    else
      # Git package is not available in the CentOS 5 repositories.
      hash_commit=$(cat /cyb3rhq-local-src/.git/$(cat /cyb3rhq-local-src/.git/HEAD|cut -d" " -f2))
      short_commit_hash="$(cut -c 1-11 <<< $hash_commit)"
    fi
fi

# Build directories
source_dir=$(build_directories "$build_dir/${BUILD_TARGET}" "cyb3rhq*" $future)

cyb3rhq_version="$(cat $source_dir/src/VERSION| cut -d 'v' -f 2)"
# TODO: Improve how we handle package_name
# Changing the "-" to "_" between target and version breaks the convention for RPM or DEB packages.
# For now, I added extra code that fixes it.
package_name="cyb3rhq-${BUILD_TARGET}-${cyb3rhq_version}"
specs_path="$(find $source_dir -name SPECS|grep $SYSTEM)"

setup_build "$source_dir" "$specs_path" "$build_dir" "$package_name" "$debug"

set_debug $debug $sources_dir

# Installing build dependencies
cd $sources_dir
build_deps $legacy
build_package $package_name $debug "$short_commit_hash" "$cyb3rhq_version"

# Post-processing
get_package_and_checksum $cyb3rhq_version $short_commit_hash $src
