#!/usr/bin/env bash

cmd_lint() {
  lint_cmd "$@"
}

wgx_command_main() {
  cmd_lint "$@"
}
