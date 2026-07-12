#!/bin/bash
# Claude Code status line (column-aligned lines)
# Line 1: 🤖 model | ⚡ effort | 🧠 thinking | 📊 ctx progress bar
# Line 2: 🔗 GitHub repo (clickable, links to current branch) | 🌱 branch | 📄 Files staged/modified | 📝 Lines +/- [ | 🌿 worktree when in one ]
# Line 3 (only when the branch has an open PR): 🔀 PR link (clickable) | review status (approved/pending/changes_requested/draft)
# Line 4: ⏱️ session time | 💰 cost (clickable → usage) | 🚦 rate limit bars with ↻ reset times (5h / 7d)
export LC_ALL=en_US.UTF-8

input=$(cat)

IFS=$'\t' read -r MODEL DIR COST CTX EFFORT THINKING RL5 RL5_RESET RL7 RL7_RESET DURATION_MS PR_NUM PR_URL PR_REVIEW <<< "$(jq -r '[
  (.model.display_name // "Claude"),
  (.workspace.current_dir // .cwd // "."),
  (.cost.total_cost_usd // 0),
  (.context_window.used_percentage // "-"),
  (.effort.level // "-"),
  (if .thinking.enabled == true then "enabled" elif .thinking.enabled == false then "disabled" else "-" end),
  (.rate_limits.five_hour.used_percentage // "-"),
  (.rate_limits.five_hour.resets_at // "-"),
  (.rate_limits.seven_day.used_percentage // "-"),
  (.rate_limits.seven_day.resets_at // "-"),
  (.cost.total_duration_ms // 0),
  (.pr.number // "-"),
  (.pr.url // "-"),
  (.pr.review_state // "-")
] | map(tostring) | join("\t")' <<< "$input")"

# ANSI colors
C_MODEL=$'\e[1;36m'; C_TREE=$'\e[1;32m'; C_COST=$'\e[1;33m'; C_EFFORT=$'\e[1;35m'; C_RL=$'\e[1;95m'
C_TIME=$'\e[1;38;5;214m'; C_REPO=$'\e[1;38;5;39m'; C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'; C_RESET=$'\e[0m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'
C_THINK_ON=$'\e[1;34m'   # bright blue when thinking is enabled
C_THINK_OFF=$'\e[31m'    # red when thinking is disabled
SEP=" ${C_DIM}|${C_RESET} "

vlen() {
  printf '%s' "$1" | perl -CS -0777 -ne '
    s/\e\]8;;[^\a]*\a//g;
    s/\e\[[0-9;]*m//g;
    my $w = 0;
    for my $c (split //) {
      my $o = ord $c;
      next if $o == 0xFE0F;
      $w += (($o >= 0x1F000 && $o <= 0x1FAFF) || $o == 0x26A1 || $o == 0x23F1) ? 2 : 1;
    }
    print $w'
}

widths=()

measure() {
  local i w
  for ((i = 0; i < $#; i++)); do
    w=$(vlen "${@:$((i + 1)):1}")
    [ "${widths[$i]:-0}" -lt "$w" ] && widths[$i]=$w
  done
}

join() {
  local out="" i cell w pad last=$(($# - 1))
  for ((i = 0; i < $#; i++)); do
    cell="${@:$((i + 1)):1}"
    if [ "$i" -lt "$last" ]; then
      w=$(vlen "$cell")
      pad=$(( ${widths[$i]:-0} - w ))
      [ "$pad" -gt 0 ] && cell="$cell$(printf '%*s' "$pad" '')"
    fi
    out="${out:+$out$SEP}$cell"
  done
  printf '%s\n' "$out"
}

# bar <pct-int> — prints a 10-segment ▓/░ bar
bar() {
  local filled=$(( $1 / 10 )) b="" i
  [ "$filled" -gt 10 ] && filled=10
  for ((i = 0; i < 10; i++)); do
    if [ "$i" -lt "$filled" ]; then b+="▓"; else b+="░"; fi
  done
  printf '%s' "$b"
}

# pct_color <pct-int> — green <50, yellow 50-79, red >=80
pct_color() {
  if   [ "$1" -ge 80 ]; then printf '%s' "$C_RED"
  elif [ "$1" -ge 50 ]; then printf '%s' "$C_YELLOW"
  else printf '%s' "$C_GREEN"; fi
}

cd "$DIR" 2>/dev/null

# ---------- Line 1: model | effort | thinking | context ----------
line1=()
line1+=("🤖 ${C_MODEL}${MODEL}${C_RESET}")

[ "$EFFORT" != "-" ] && line1+=("⚡ ${C_EFFORT}$(printf '%s' "${EFFORT:0:1}" | tr '[:lower:]' '[:upper:]')${EFFORT:1}${C_RESET}")

case "$THINKING" in
  enabled)  line1+=("🧠 ${C_THINK_ON}Thinking enabled${C_RESET}") ;;
  disabled) line1+=("🧠 ${C_THINK_OFF}Thinking disabled${C_RESET}") ;;
esac

if [ "$CTX" != "-" ]; then
  CTX_INT=${CTX%%.*}
  CC=$(pct_color "$CTX_INT")
  line1+=("📊 ${C_BOLD}ctx${C_RESET} ${CC}$(bar "$CTX_INT") ${CTX_INT}%${C_RESET}")
else
  line1+=("📊 ${C_BOLD}ctx${C_RESET} ${C_DIM}░░░░░░░░░░ -%${C_RESET}")
fi

# ---------- Line 2: project name (+ worktree when in one) ----------
line2=()

# Branch name (short SHA when detached)
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)

REMOTE=$(git remote get-url origin 2>/dev/null | sed -e 's#^git@github.com:#https://github.com/#' -e 's#\.git$##')
if [ -n "$REMOTE" ]; then
  REPO=$(basename "$REMOTE")
  REPO_URL="$REMOTE"
  [ -n "$BRANCH" ] && REPO_URL="$REMOTE/tree/$BRANCH"
  case "$REMOTE" in
    https://*) line2+=("🔗 $(printf '\e]8;;%s\a' "$REPO_URL")${C_REPO}${REPO}${C_RESET}$(printf '\e]8;;\a')") ;;
    *)         line2+=("🔗 ${C_REPO}${REPO}${C_RESET}") ;;
  esac
fi

[ -n "$BRANCH" ] && line2+=("🌱 ${C_TREE}${BRANCH}${C_RESET}")

# Staged (green ●) and modified-unstaged (yellow ✚) file counts
STATUS=$(git status --porcelain 2>/dev/null)
if [ -n "$STATUS" ]; then
  STAGED=$(grep -c '^[MADRC]' <<< "$STATUS")
  MODIFIED=$(grep -c '^.[MD]' <<< "$STATUS")
  dirty=""
  [ "$STAGED" -gt 0 ]   && dirty="${C_GREEN}● ${STAGED}${C_RESET}"
  [ "$MODIFIED" -gt 0 ] && dirty="${dirty:+$dirty }${C_YELLOW}✚ ${MODIFIED}${C_RESET}"
  [ -n "$dirty" ] && line2+=("📄 ${C_BOLD}Files${C_RESET} $dirty")

  read -r ADDED DELETED <<< "$(git diff HEAD --numstat 2>/dev/null | awk '{a+=$1; d+=$2} END {printf "%d %d", a, d}')"
  if [ "${ADDED:-0}" -gt 0 ] || [ "${DELETED:-0}" -gt 0 ]; then
    line2+=("📝 ${C_BOLD}Lines${C_RESET} ${C_GREEN}+${ADDED}${C_RESET}/${C_RED}-${DELETED}${C_RESET}")
  fi
fi

GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
case "$GIT_DIR" in
  */worktrees/*) line2+=("🌿 ${C_TREE}${GIT_DIR##*/}${C_RESET}") ;;
esac

# ---------- PR line: clickable PR link | review status ----------
linepr=()

if [ "$PR_NUM" != "-" ] && [ "$PR_URL" != "-" ]; then
  linepr+=("🔀 $(printf '\e]8;;%s\a%s\e]8;;\a' "$PR_URL" "PR #$PR_NUM")")
  case "$PR_REVIEW" in
    approved)          linepr+=("${C_GREEN}approved${C_RESET}") ;;
    pending)           linepr+=("${C_YELLOW}pending${C_RESET}") ;;
    changes_requested) linepr+=("${C_RED}changes requested${C_RESET}") ;;
    draft)             linepr+=("${C_DIM}draft${C_RESET}") ;;
  esac
fi

# ---------- Line 3: rate limit bars | cost (last) ----------
line3=()

DURATION_S=$(( ${DURATION_MS%%.*} / 1000 ))
DUR_H=$(( DURATION_S / 3600 )); DUR_M=$(( (DURATION_S % 3600) / 60 )); DUR_SS=$(( DURATION_S % 60 ))
if [ "$DUR_H" -gt 0 ]; then
  SESSION_TIME="${DUR_H}h ${DUR_M}m"
elif [ "$DUR_M" -gt 0 ]; then
  SESSION_TIME="${DUR_M}m ${DUR_SS}s"
else
  SESSION_TIME="${DUR_SS}s"
fi
line3+=("⏱️ ${C_TIME}${SESSION_TIME}${C_RESET}")

USAGE_URL="https://claude.ai/projects#settings/usage"
line3+=("💰 $(printf '\e]8;;%s\a' "$USAGE_URL")${C_COST}$(printf '$%.2f' "$COST")${C_RESET}$(printf '\e]8;;\a')")

RL_PREFIX="🚦 "
if [ "$RL5" != "-" ]; then
  P=$(printf '%.0f' "$RL5")
  RC=$(pct_color "$P")
  RL5_CELL="${RL_PREFIX}${C_RL}5h${C_RESET} ${RC}$(bar "$P") ${P}%${C_RESET}"
  [ "$RL5_RESET" != "-" ] && RL5_CELL="$RL5_CELL ${C_DIM}↻ $(date -r "${RL5_RESET%%.*}" +%H:%M)${C_RESET}"
  line3+=("$RL5_CELL")
  RL_PREFIX=""
fi
if [ "$RL7" != "-" ]; then
  P=$(printf '%.0f' "$RL7")
  RC=$(pct_color "$P")
  RL7_CELL="${RL_PREFIX}${C_RL}7d${C_RESET} ${RC}$(bar "$P") ${P}%${C_RESET}"
  [ "$RL7_RESET" != "-" ] && RL7_CELL="$RL7_CELL ${C_DIM}↻ $(date -r "${RL7_RESET%%.*}" +'%a %H:%M')${C_RESET}"
  line3+=("$RL7_CELL")
fi

measure "${line1[@]}"
[ "${#line2[@]}" -gt 0 ] && measure "${line2[@]}"
[ "${#linepr[@]}" -gt 0 ] && measure "${linepr[@]}"
measure "${line3[@]}"

join "${line1[@]}"
[ "${#line2[@]}" -gt 0 ] && join "${line2[@]}"
[ "${#linepr[@]}" -gt 0 ] && join "${linepr[@]}"
join "${line3[@]}"
exit 0
