#!/usr/bin/env bash

# Simple shortcut wrapper to your most common git commands
# Easy to extend, and passes all the unrecognized command through the
# `git` command itself (i.e. `g rebase master` => `git rebase master`)
#
# MIT License
# Copyright (c) 2018 Claudio Cicali <claudio.cicali@gmail.com>
# Version 1.1

# Traps any error (see https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
set -e -o pipefail -u

type git >/dev/null 2>&1 || { echo >&2 "😟 I can't find the git executable."; exit 1; }

G_C_TICKET_REGEXP=${G_C_TICKET_REGEXP:-[A-Z]+-[0-9]+}
# What to use in case a ticket number is not found in the branch name
# Defaults to 'NOJIRA'
G_C_DEFAULT_TICKET=${G_C_DEFAULT_TICKET:-NOJIRA}
# Wether the commit command must find the ticket number in the branch before proceeding (or bail)
# Accepts "1" or "0", defaults to "0" (no need for the ticket and will use G_C_DEFAULT_TICKET)
G_C_NEEDS_TICKET=${G_C_NEEDS_TICKET:-0}
# Probably not everybody wants a "smart commit", and a quick alias to `git commit -m` would be enough
G_C_IS_SMART=${G_C_IS_SMART:-1}
G_REMOTE=${G_REMOTE:-origin}

ghelp () {
  cat <<EOT
a    : git add -u
c \$1: git commit -m \$1, with ticket number detection
d    : git diff + git diff --staged
g \$1: git checkout a local branch (or ask to create it)
G \$1: Interactively change branch (matching *\$1* when passed)
m    : checkouts the master branch and pulls
l    : Shows the most recent branch activities
L \$1: Shows the differences between HEAD and another branch
p    : git pull
P    : git push -u ${G_REMOTE} current_branch_name
s    : git status -s
*    : git *
EOT
  exit 0
}

assert_no_params () {
  if [[ ${argc} -ne 1 ]]; then
    echo "🚫 This command doesn't want a parameter"
    ghelp
  fi
}

assert_one_param () {
  if [[ ${argc} -ne 2 ]]; then
    echo "🚫 This command needs a parameter"
    ghelp
  fi
}

assert_not_dirty () {
  local git_dirty=$(git diff-index --name-only HEAD --)

  if [[ -n "${git_dirty}" ]]; then
    echo '🚫 This command cannot run on a dirty index (use "g s" to see what is changed)'
    exit 1
  fi
}

argc=${#}
if [[ ${argc} -eq 0 ]]; then
  ghelp
fi

cmd=${1}

if [[ -z "$(git rev-parse --git-dir 2> /dev/null)" ]]; then
  echo "😊 I work better when run from inside a git repository."
  exit 1
fi

git_branch=$(git symbolic-ref HEAD | sed 's/refs\/heads\///')

case ${cmd} in
  # Git add -u
  a)
    assert_no_params
    git add -u
    # Check if we have untracked changes too
    untracked=$(git ls-files --others --exclude-standard)
    if [[ -n "${untracked}" ]]; then
      echo "⚠️  Done, but you may have untracked files to add too (use \`g s\` to see them)."
    fi
    ;;

  h)
    ghelp
    ;;

  # Checking out master
  m)
    assert_no_params
    if [[ ${git_branch} != "master" ]]; then
      git checkout master
      git pull
    else
      echo "⚠️  You already are in master; just pulling"
      git pull
    fi
    ;;

  # Git pull
  p)
    assert_no_params
    git pull
    ;;

  # Git push
  P)
    assert_no_params
    git push -u ${G_REMOTE} ${git_branch}
    ;;

  # Git diff (warning: it also looks into already staged files)
  d)
    assert_no_params
    git diff
    git diff --staged
    ;;

  # Git status
  s)
    assert_no_params
    git status -s
    ;;

  # Git 'latest': shows the most recent branches you've worked in
  l)
    assert_no_params
    git for-each-ref --sort='-committerdate' --format='%(refname)%09%(committerdate)' refs/heads | head -n 15 | sed -e 's-refs/heads/--'
    ;;

  # Git difference between HEAD and another branch
  L)
    assert_one_param
    git log --oneline HEAD...${G_REMOTE}/${2}
    ;;

  # Git 'smart' commit
  c)
    assert_one_param
    if [[ "${G_C_IS_SMART}" != "1" ]]; then
      git commit -m "[${branch_id}] ${2}"
    else
      # Extracts and use a ticket id from a branch name in one of these forms:
      # 'claudioc/IT-123_something_something'
      # 'IT-123_something_something'
      # 'something_something_IT-123'
      # 'something_something' (produces 'NOJIRA')
      # It will fail with 'something_something_ANDMOREIT-123'
      regexp="(${G_C_TICKET_REGEXP})"
      branch_id=${G_C_DEFAULT_TICKET}
      if [[ ${git_branch} =~ ${regexp} ]]; then
        # Bash doesn't support non-greedy RE, so we need to remove the final part of the match
        branch_id=${BASH_REMATCH[1]//_*}
      else
        if [[ "${G_C_NEEDS_TICKET}" != "0" ]]; then
          echo "🔍 A ticket number was not found analyzing the branch name."
          exit 1
        fi
      fi
      git commit -m "[${branch_id}] ${2}"
    fi
    ;;

  # Git checkout a local branch (or creates it)
  g)
    assert_one_param
    assert_not_dirty
    branch_name=${2}
    if [[ "${git_branch}" == "${branch_name}" ]]; then
      echo "🤔 You already are in ${branch_name}"
    else
      if [[ -n $(git rev-parse --verify --quiet ${branch_name}) ]]; then
        git checkout ${2}
      else
        read -r -n 1 -p "❓ Do you want to create the branch \"${branch_name}\" (y/N)? "
        if [[ "${REPLY}" == "y" ]]; then
          echo
          git checkout -b ${branch_name}
        fi
      fi
    fi
    ;;

  # Interactively changes branch matching $1
  G)
    assert_not_dirty
    branch_name=${2-''}

    if [[ -z ${branch_name} ]]; then
      branches=$(git for-each-ref --sort='-committerdate' --format='%(refname)' refs/heads --count 15 | sed -e 's-refs/heads/--')
    else
      branches=$(git for-each-ref --sort='-committerdate' --format='%(refname)' refs/heads refs/remotes | grep "${branch_name}" | sed "s/refs\/remotes\/${G_REMOTE}\///" | sed 's/refs\/heads\///' | uniq || true)
    fi

    if [[ -z "${branches}" ]]; then
      echo "🔍 No branches found matching '${branch_name}'"
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
    ;;

  # Pass-through any command to git
  *)
    git ${*}
    ;;
esac
