#!/usr/bin/env bash

# This is a simple shortcut wrapper to your most common git commands
# Easy to extend, and passes all the unrecognized command through the
# `git` command itself (i.e. `g rebase main` => `git rebase main`)
#
# MIT License
# Copyright (c) 2023 Claudio Cicali <claudio.cicali@gmail.com>
# Version 1.1

# Traps any error (see https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
set -e -o pipefail -u

type git >/dev/null 2>&1 || { echo >&2 "😟  I can't find the git executable."; exit 1; }

G_C_TICKET_REGEXP=${G_C_TICKET_REGEXP:-[a-z]+-[0-9]+}
# What to use in case a ticket number is not found in the branch name
# Defaults to ''
G_C_DEFAULT_TICKET=${G_C_DEFAULT_TICKET:-}
# Wether the commit command must find the ticket number in the branch before proceeding (or bail)
# Accepts "1" or "0", defaults to "0" (no need for the ticket and will use G_C_DEFAULT_TICKET)
G_C_NEEDS_TICKET=${G_C_NEEDS_TICKET:-0}
# Probably not everybody wants a "smart commit", and a quick alias to `git commit -m` would be enough
G_C_IS_SMART=${G_C_IS_SMART:-1}
G_C_DEFAULT_BRANCH=${G_C_DEFAULT_BRANCH:-main}
G_REMOTE=${G_REMOTE:-origin}

argc=${#}

main() {
  validate_environment
  execute_command "${@}"
}

ghelp () {
  cat <<EOT
a    : git add -u (with a second parameter also commits)
A \$1: git add \$1
b \$1: Smart 'branch'. Creates a branch from a description
c \$1: git commit -m \$1, with ticket number detection
d    : git diff + git diff --staged
D \$1: Shows the differences between HEAD and another branch
g \$1: git checkout a (old or new) local branch, or show the most recent activities
G \$1: Interactively change branch (matching *\$1* when passed)
h    : This help
i    : inspect the configuration options
m    : checkouts the ${G_C_DEFAULT_BRANCH} branch and pulls
p    : git pull
P    : git push -u ${G_REMOTE} current_branch_name
s    : git status -s
t    : Shows the ticket number extracted from the branch name
*    : git *
EOT
  exit 0
}

assert_no_params () {
  if [[ ${argc} -ne 1 ]]; then
    echo "🚫  This command doesn't want a parameter"
    ghelp
  fi
}

assert_one_param () {
  if [[ ${argc} -ne 2 ]]; then
    echo "🚫  This command needs one and one only parameter"
    ghelp
  fi
}

assert_one_or_zero_params () {
  if [[ ${argc} -gt 2 ]]; then
    echo "🚫  This command needs one or zero parameters only"
    ghelp
  fi
}

assert_not_dirty () {
  local git_dirty=$(git diff-index --name-only HEAD --)

  if [[ -n "${git_dirty}" ]]; then
    echo '🚫  This command cannot run on a dirty index (use "g s" to see what is changed)'
    exit 1
  fi
}

validate_environment() {
  if [[ ${argc} -eq 0 ]]; then
    ghelp
  fi

  if [[ -z "$(git rev-parse --git-dir 2> /dev/null)" ]]; then
    echo "😊  I work better when run from inside a git repository."
    exit 1
  fi

  {
    git_branch=$(git symbolic-ref HEAD | sed 's/refs\/heads\///')
  } || {
    echo "😬  Sorry, operation not supported when in detached state."
    exit 1
  }
}

execute_command() {
  case ${1} in
    a) # Git add -u
      assert_one_or_zero_params
      shift
      command_a "${@-}"
      ;;

    A) # Git add
      assert_one_param
      shift
      command_A "${@}"
      ;;

    b) # Git 'smart' branch
      assert_one_param
      shift
      command_b "${@}"
      ;;

    c) # Git 'smart' commit
      assert_one_param
      shift
      command_c "${@}"
      ;;

    d) # Git diff (warning: it also looks into already staged files)
      assert_no_params
      command_d
      ;;

    D) # Git difference between HEAD and another branch
      assert_one_param
      shift
      command_D "${@}"
      ;;

    h)
      ghelp
      ;;

    i) # Inspect configuration
      assert_no_params
      command_i
      ;;

    g) # Git checkout a local branch (or creates it)
      assert_one_or_zero_params
      shift
      command_g "${@-}"
      ;;

    G) # Interactively changes branch matching $1
      assert_no_params
      command_G
      ;;

    m) # Checking out G_C_DEFAULT_BRANCH
      assert_no_params
      command_m
      ;;

    p) # Git pull
      assert_no_params
      command_p
      ;;

    P) # Git push
      assert_no_params
      command_P
      ;;

    s) # Git status
      assert_no_params
      command_s
      ;;

    t) # Shows the ticket number extracted from the branch name
      assert_no_params
      command_t
      ;;

    *) # Pass-through any command to git
      git ${*}
      ;;
  esac
}

command_a() {
  git add -u
  # Check if we have untracked changes too
  untracked=$(git ls-files --others --exclude-standard)
  if [[ -n "${untracked}" ]]; then
    echo "⚠️  Done, but you may have untracked files to add too (use \`g s\` to see them)."
  fi

  if [[ "${1-}" != "" ]]; then
    command_c "${1}"
  fi
}

command_A() {
  git add "${1}"
}

command_b() {
  # assert_not_dirty
  branch_name=${1}
  # slugify the branch name
  branch_name=$(echo "${branch_name}" | sed -e 's/[^[:alnum:]|//]/-/g' | tr -s '-' | tr A-Z a-z)
  # remove multiple -
  branch_name=$(echo "${branch_name}" | tr -s '-')
  # remove leading and trailing -
  branch_name=${branch_name#-}
  branch_name=${branch_name%-}
  # cut the branch name to the maximum length
  branch_name=${branch_name:0:50}

  echo "🔀 Creating branch ${branch_name}"
  # Create the branch if it doesn't exist
  if [[ -z $(git rev-parse --verify --quiet ${branch_name}) ]]; then
    git checkout -b ${branch_name}
  else
    echo "🤔 Branch ${branch_name} already exists"
    # Switch to the branch
    git checkout ${branch_name}
  fi
}

command_c() {
  if [[ "${G_C_IS_SMART}" != "1" ]]; then
    git commit -m "${1}"
  else
    # Extracts and use a ticket id from a branch name in one of these forms:
    # 'claudioc/IT-123_something_something'
    # 'IT-123_something_something'
    # 'something_something_IT-123'
    # 'something_something' (produces '')
    # It will fail with 'something_something_ANDMOREIT-123'
    regexp="(${G_C_TICKET_REGEXP})"
    branch_id=${G_C_DEFAULT_TICKET}
    if [[ ${git_branch} =~ ${regexp} ]]; then
      # Bash doesn't support non-greedy RE, so we need to remove the final part of the match
      branch_id=${BASH_REMATCH[1]//_*}
    else
      if [[ "${G_C_NEEDS_TICKET}" != "0" ]]; then
        echo "🔍  A ticket number was not found analyzing the branch name."
        exit 1
      fi
    fi
    if [[ "${branch_id}" != "" ]]; then
      git commit -m "[${branch_id}] ${1}"
    else
      git commit -m "${1}"
    fi
  fi
}

command_d() {
  git diff
  git diff --staged
}

command_D() {
  git log --oneline HEAD...${G_REMOTE}/${1}
}

command_g() {
  if [[ "${1-}" == "" ]]; then
    git for-each-ref --sort='-committerdate' --format='%(refname)%09%(committerdate)' refs/heads | head -n 15 | sed -e 's-refs/heads/--'
  else
    assert_not_dirty
    branch_name=${1}
    if [[ "${git_branch}" == "${branch_name}" ]]; then
      echo "🤔  You already are in ${branch_name}"
    else
      if [[ -n $(git rev-parse --verify --quiet ${branch_name}) ]]; then
        git checkout ${1}
      else
        read -r -n 1 -p "❓ Do you want to create the branch \"${branch_name}\" (y/N)? "
        if [[ "${REPLY}" == "y" ]]; then
          echo
          git checkout -b ${branch_name}
        fi
      fi
    fi
  fi
}

command_G() {
  assert_not_dirty
  branch_name=${1-''}

  if [[ -z ${branch_name} ]]; then
    branches=$(git for-each-ref --sort='-committerdate' --format='%(refname)' refs/heads --count 15 | sed -e 's-refs/heads/--')
  else
    branches=$(git for-each-ref --sort='-committerdate' --format='%(refname)' refs/heads refs/remotes | grep "${branch_name}" | sed "s/refs\/remotes\/${G_REMOTE}\///" | sed 's/refs\/heads\///' | uniq || true)
  fi

  if [[ -z "${branches}" ]]; then
    echo "🔍  No branches found matching '${branch_name}'"
    exit 0
  fi

  PS3="Select a branch (or ^C): "
  declare -a branches=(${branches})
  select opt in "${branches[@]}"; do
    if [[ "${opt}" != "" ]]; then
      git checkout ${opt}
    fi
    break
  done
}

command_i() {
  inspect_configuration
}

command_m() {
  if [[ ${git_branch} != "${G_C_DEFAULT_BRANCH}" ]]; then
    git checkout ${G_C_DEFAULT_BRANCH}
    git pull
  else
    echo "⚠️  You already are in ${G_C_DEFAULT_BRANCH}; just pulling"
    git pull
  fi
}

command_p() {
  git pull
}

command_P() {
  git push -u ${G_REMOTE} ${git_branch}
}

command_s() {
  git status -s
}

command_t() {
  regexp="(${G_C_TICKET_REGEXP})"
  branch_id=${G_C_DEFAULT_TICKET}
  if [[ ${git_branch} =~ ${regexp} ]]; then
    # Bash doesn't support non-greedy RE, so we need to remove the final part of the match
    branch_id=${BASH_REMATCH[1]//_*}
  fi
  echo "${branch_id}"
}

# Echoes all the configuration options
inspect_configuration() {
  echo "G_C_TICKET_REGEXP=${G_C_TICKET_REGEXP}"
  echo "G_C_DEFAULT_TICKET=${G_C_DEFAULT_TICKET}"
  echo "G_C_NEEDS_TICKET=${G_C_NEEDS_TICKET}"
  echo "G_C_IS_SMART=${G_C_IS_SMART}"
  echo "G_C_DEFAULT_BRANCH=${G_C_DEFAULT_BRANCH}"
  echo "G_REMOTE=${G_REMOTE}"
}


main "${@-}"
