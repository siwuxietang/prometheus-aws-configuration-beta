#!/usr/bin/env bash
set -eu

for file in "$@"; do
  lint=$(terraform fmt -write=true -diff=true -list=true "${file}")
  failed=""

  if [ ! -z "${lint}" ]; then
    failed="yes"
    echo -e "Your code is not in a canonical format:\n"
    echo "${lint}"
    echo -e "To apply these changes do 'terraform fmt ${file}'\n"
  fi

  if [ "$failed" == "yes" ];then
    exit 1
  fi
done
