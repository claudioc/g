#!/usr/bin/env bash
# Simple shortcut wrapper to your most common git commands
# Easy to extend, and passes all the unrecognized command through the
# `git` command itself (i.e. `g rebase master` => `git rebase master`)

# Traps any error (see https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
set -e -o pipefail -u

type git >/dev/null 2>&1 || { echo >&2 "😟 I can't find the git executable."; exit 1; }

ghelp () {
  cat <<EOT
m: checkouts master && pulls
p: git pull
P: git push -u origin current_branch_name
d: git diff && git diff --staged
s: git status
l: git latest (not native)
L \$1: git log --oneline HEAD...origin/\$1
c \$1: git commit \$1
g \$1: git checkout \$1
*: git *
EOT
exit 0
}

assert_no_params () {
  if [[ ${argc} -ne 1 ]]; then
    echo "🚫 This command doesn't want a parameter
    "
    ghelp
  fi
}

assert_one_param () {
  if [[ ${argc} -ne 2 ]]; then
    ghelp
  fi
}

argc=${#}
if [[ ${argc} -eq 0 ]]; then
  ghelp
fi

cmd=${1}

if [[ -z "$(git rev-parse --git-dir 2>/dev/null)" ]]; then
  echo "😊 I work better when run from inside a git repository."
  exit 1
fi

git_branch=$(git symbolic-ref HEAD | sed 's/refs\/heads\///')

case ${cmd} in
  h)
    ghelp
    ;;

  m)
    assert_no_params
    if [[ ${git_branch} != "master" ]]; then
      git checkout master
      git pull
    else
      echo "⚠️ You already are in master; just pulling"
      git pull
    fi
    ;;

  p)
    assert_no_params
    git pull
    ;;

  P)
    assert_no_params
    git push -u origin ${git_branch}
    ;;

  d)
    assert_no_params
    git diff
    git diff --staged
    ;;

  s)
    assert_no_params
    git status -s
    ;;

  l)
    assert_no_params
    git latest
    ;;
  L)
    assert_one_param
    git log --oneline HEAD...origin/${2}
    ;;
  c)
    assert_one_param
    # Extracts the jira id from a branch name in the form:
    # 'claudioc/IT-123_something_something'
    REGEXP="\/(.+)\_"
    branch_id='NOJIRA'
    if [[ ${git_branch} =~ ${REGEXP} ]]; then
      # Bash doesn't support non-greedy RE, so we need to remove the final part of the match
      branch_id=${BASH_REMATCH[1]//_*}
    fi
    git commit -m "[${branch_id}] ${2}"
    ;;
  g)
    assert_one_param
    branch_name=${2}
    if [[ ${git_branch} == "${branch_name}" ]]; then
      echo "🤔 You already are in ${branch_name}"
    else
      if [[ -n $(git rev-parse --verify --quiet ${branch_name}) ]]; then
        git checkout ${2}
      else
        read -r -n 1 -p "❓ Do you want to create the branch \"${branch_name}\" (y/N)? "
        if [[ "${REPLY}" == "y" ]]; then
          git checkout -b ${branch_name}
        fi
      fi
    fi
    ;;
  *)
    git ${*}
    ;;
esac
