#!/usr/bin/env bash

# run_cmd (from archiv/wgx)
run_cmd() {
    profile::run_task "$@"
}

cmd_run() {
    run_cmd "$@"
}
