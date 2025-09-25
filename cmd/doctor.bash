#!/usr/bin/env bash

cmd_doctor() {
  command -v git >/dev/null || die "git fehlt."
  git_is_repo_root || die "nicht im Git-Repo."
  git_has_remote || log_warn "Kein origin-Remote."
  log_info "WGX Doctor OK."
}
