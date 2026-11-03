#!/usr/bin/env bash
# Tests for ppp-run.sh and setup-ppp-user.sh. Sourced by run.sh after lib.sh.

RUN="$SCRIPTS_DIR/ppp-run.sh"
SETUP="$SCRIPTS_DIR/setup-ppp-user.sh"
TEST_KEY="sk-or-v1-test-track-key"

# keys [mode]: a key dir with both track keys, a budget-left OpenRouter reply,
# and host mode allowed for the current user.
keys() {
  export PPP_KEY_DIR="$T/keys"
  mkdir -p "$PPP_KEY_DIR"
  for track in track-1 track-2; do
    printf '%s\n' "$TEST_KEY" > "$PPP_KEY_DIR/$track.key"
    chmod "${1:-600}" "$PPP_KEY_DIR/$track.key"
  done
  echo '{"data":{"limit_remaining":30}}' > "$STUB_FIXTURES/curl.json"
  export PPP_USER
  PPP_USER="$(id -un)"
}

test_usage_no_args() {
  run_cmd "$RUN"
  assert_status 2 "$STATUS"
  assert_contains "$ERR" "usage: ppp-run.sh"
}

test_unknown_track_refused() {
  keys
  run_cmd "$RUN" track-3 -- true
  assert_status 2 "$STATUS"
}

test_no_command_refused() {
  keys
  run_cmd "$RUN" track-2 --
  assert_status 2 "$STATUS"
}

test_host_mode_refused_for_other_users() {
  keys
  PPP_USER=someone-else run_cmd "$RUN" track-2 -- true
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "host mode runs only as someone-else"
}

test_key_with_wrong_mode_refused() {
  keys 644
  run_cmd "$RUN" track-2 -- true
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "track-2.key must exist with mode 600"
}

test_missing_key_refused() {
  keys
  rm "$PPP_KEY_DIR/track-1.key"
  run_cmd "$RUN" track-1 -- true
  assert_status 1 "$STATUS"
}

test_stored_credential_refused() {
  keys
  mkdir -p "$PPP_KEY_DIR/pi-agent-track-2"
  echo '{"openrouter":{"type":"oauth"}}' > "$PPP_KEY_DIR/pi-agent-track-2/auth.json"
  run_cmd "$RUN" track-2 -- true
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "auth.json holds a credential"
}

test_empty_auth_json_allowed() {
  keys
  mkdir -p "$PPP_KEY_DIR/pi-agent-track-2"
  echo '{}' > "$PPP_KEY_DIR/pi-agent-track-2/auth.json"
  run_cmd "$RUN" track-2 -- true
  assert_status 0 "$STATUS"
}

test_models_json_api_key_refused() {
  keys
  mkdir -p "$PPP_KEY_DIR/pi-agent-track-2"
  echo '{"providers":{"openrouter":{"apiKey":"x"}}}' > "$PPP_KEY_DIR/pi-agent-track-2/models.json"
  run_cmd "$RUN" track-2 -- true
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "models.json names an apiKey"
}

test_rejected_key_refused() {
  keys
  touch "$STUB_FIXTURES/curl-fail"
  run_cmd "$RUN" track-2 -- true
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "OpenRouter rejected the track-2 key"
}

test_spent_key_refused() {
  keys
  echo '{"data":{"limit_remaining":0}}' > "$STUB_FIXTURES/curl.json"
  run_cmd "$RUN" track-2 -- true
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "no budget left"
}

test_key_reaches_curl_on_stdin_not_argv() {
  keys
  run_cmd "$RUN" track-2 -- true
  assert_status 0 "$STATUS"
  assert_not_contains "$(cat "$STUB_CALLS")" "$TEST_KEY" "curl argv"
  assert_contains "$(cat "$STUB_FIXTURES/curl.stdin")" "Authorization: Bearer $TEST_KEY"
}

test_host_mode_environment_is_rebuilt() {
  keys
  ANTHROPIC_API_KEY=leak SSH_AUTH_SOCK=/tmp/agent OPENROUTER_API_KEY=personal \
    run_cmd "$RUN" track-2 -- env
  assert_status 0 "$STATUS"
  assert_contains "$OUT" "OPENROUTER_API_KEY=$TEST_KEY"
  assert_contains "$OUT" "PI_CODING_AGENT_DIR=$PPP_KEY_DIR/pi-agent-track-2"
  assert_contains "$OUT" "PI_TELEMETRY=0"
  assert_not_contains "$OUT" "ANTHROPIC_API_KEY"
  assert_not_contains "$OUT" "SSH_AUTH_SOCK"
  assert_not_contains "$OUT" "personal"
  assert_not_contains "$OUT" "GH_TOKEN" "no token file"
}

test_github_token_passed_when_present() {
  keys
  echo "github_pat_test" > "$PPP_KEY_DIR/github.token"
  chmod 600 "$PPP_KEY_DIR/github.token"
  run_cmd "$RUN" track-2 -- env
  assert_status 0 "$STATUS"
  assert_contains "$OUT" "GH_TOKEN=github_pat_test"
}

test_github_token_with_wrong_mode_refused() {
  keys
  echo "github_pat_test" > "$PPP_KEY_DIR/github.token"
  chmod 644 "$PPP_KEY_DIR/github.token"
  run_cmd "$RUN" track-2 -- true
  assert_status 1 "$STATUS"
}

test_docker_mode_passes_values_by_name_only() {
  keys
  PPP_KEEP_ENV="STUB_CALLS STUB_FIXTURES" PPP_USER=someone-else run_cmd "$RUN" track-1 --docker --image test/pi -- pi -p hi < /dev/null
  assert_status 0 "$STATUS"
  calls="$(cat "$STUB_CALLS")"
  assert_contains "$calls" "-e OPENROUTER_API_KEY "
  assert_contains "$calls" "-e PI_CODING_AGENT_DIR=/pi"
  assert_contains "$calls" "-v $PWD:/workspace"
  assert_contains "$calls" "test/pi pi -p hi"
  assert_not_contains "$calls" "$TEST_KEY" "docker argv"
  assert_not_contains "$calls" ".pi/agent"
  assert_contains "$(cat "$STUB_FIXTURES/docker.env")" "OPENROUTER_API_KEY=$TEST_KEY"
}

test_setup_dry_run_lists_steps() {
  mkdir -p "$T/src" "$T/owner"
  chmod 750 "$T/owner"
  touch "$T/src/track-1.key" "$T/src/track-2.key"
  PPP_USER=ppp-test-nobody PPP_OWNER_HOME="$T/owner" PPP_SOURCE_DIR="$T/src" run_cmd "$SETUP" --dry-run
  assert_status 0 "$STATUS"
  assert_contains "$OUT" "useradd --create-home --shell /bin/bash --user-group ppp-test-nobody"
  assert_contains "$OUT" "loginctl enable-linger ppp-test-nobody"
  assert_contains "$OUT" "install -m 600 -o ppp-test-nobody -g ppp-test-nobody $T/src/track-2.key"
}

test_setup_refuses_open_owner_home() {
  mkdir -p "$T/src" "$T/owner"
  chmod 755 "$T/owner"
  touch "$T/src/track-1.key" "$T/src/track-2.key"
  PPP_USER=ppp-test-nobody PPP_OWNER_HOME="$T/owner" PPP_SOURCE_DIR="$T/src" run_cmd "$SETUP" --dry-run
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "others can enter it"
}

test_setup_refuses_missing_key() {
  mkdir -p "$T/src" "$T/owner"
  touch "$T/src/track-1.key"
  PPP_USER=ppp-test-nobody PPP_OWNER_HOME="$T/owner" PPP_SOURCE_DIR="$T/src" run_cmd "$SETUP" --dry-run
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "missing $T/src/track-2.key"
}
