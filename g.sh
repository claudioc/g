#!/usr/bin/env bash
# Simple shortcut wrapper to your most common git commands
# Easy to extend, and passes all the unrecognized command through the
# `git` command itself (i.e. `g rebase master` => `git rebase master`)

# Traps any error (see https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
set -e -o pipefail -u

ghelp () {
  cat <<EOT
m: checkouts master && pulls
p: git pull
P: git push -u origin current_branch_name
d: git diff && git diff --staged
s: git status
l: git latest (not native)
L: git log --oneline HEAD...origin/another-branch
c: git commit (requires the message as the second arg)
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

argc=${#}
if [[ ${argc} -eq 0 ]]; then
  ghelp
fi

cmd=${1}

git_branch=$(git symbolic-ref HEAD | sed 's/refs\/heads\///')

case ${cmd} in
  h)
    ghelp
    ;;

  m)
    assert_no_params
    if [[ $git_branch != "master" ]]; then
      git checkout master
      git pull
    else
      echo "⚠️ You're already in master"
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
    if [[ ${#} -lt 2 ]]; then
      ghelp
    fi
    git log --oneline HEAD...origin/${2}
    ;;
  c)
    if [[ ${#} -lt 2 ]]; then
      ghelp
    fi
    # Extracts the jira id from a branch name in the form:
    # 'claudioc/IT-123_something_something'
    REGEXP="\/(.+)\_"
    branch_id='NOJIRA'
    if [[ $git_branch =~ ${REGEXP} ]]; then
      # Bash doesn't support non-greedy RE, so we need to remove the final part of the match
      branch_id=${BASH_REMATCH[1]//_*}
    fi
    git commit -m "[${branch_id}] ${2}"
    ;;
  *)
    git ${*}
    ;;
esac
