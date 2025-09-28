#!/usr/bin/env bash

cmd_send() {
  send_cmd "$@"
}

wgx_command_main() {
  cmd_send "$@"
}
