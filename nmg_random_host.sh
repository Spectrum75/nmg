#!/usr/bin/env bash
rand_hn() {
  local new_hostname=$(tr -cd 'a-z0-9' < /dev/urandom | head -c 15)
  hostnamectl set-hostname "$new_hostname"
  sudo sed -i "2s/.*/127.0.1.1\t$new_hostname/" /etc/hosts #need sudo here for running without password, if exception is added that is
}
rand_hn
