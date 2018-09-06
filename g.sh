#!/usr/bin/env bash
# Simple shortcut wrapper to your most common git commands
# Easy to extend, and passes all the unrecognized command through the
# `git` command itself (i.e. `g rebase master` => `git rebase master`)

# Traps any error (see https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
set -e -o pipefail -u

type git >/dev/null 2>&1 || { echo >&2 "😟 I can't find the git executable."; exit 1; }

ghelp () {
  cat <<EOT
c \$1: git commit \$1
d: git diff && git diff --staged
g \$1: git checkout a local branch (or ask to create it) \$1
G [\$1]: Interactively change branch (matching *\$1*)
m: checkouts master && pulls
l: Shows most recent branch activities
L \$1: Git difference between HEAD and another branch
p: git pull
P: git push -u origin current_branch_name
s: git status -s
*: git *
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
      echo "⚠️ You already are in master; just pulling"
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
    git push -u origin ${git_branch}
    ;;

  # Git diff
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

  # Git 'latest'
  l)
    assert_no_params
    git for-each-ref --sort='-committerdate' --format='%(refname)%09%(committerdate)' refs/heads | head -n 15 | sed -e 's-refs/heads/--'
    ;;

  # Git difference between HEAD and another branch
  L)
    assert_one_param
    git log --oneline HEAD...origin/${2}
    ;;

  # Git 'smart' commit
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

  # Interactively change branch matching $1
  G)
    assert_not_dirty
    branch_name=${2-''}
    if [[ -z ${branch_name} ]]; then
      branches=$(git for-each-ref --sort='-committerdate' --format='%(refname)' refs/heads --count 15 | sed -e 's-refs/heads/--')
    else
      branches=$(git for-each-ref --sort='-committerdate' --format='%(refname)' refs/heads refs/remotes | grep ${branch_name} | sed 's/refs\/remotes\/origin\///' | sed 's/refs\/heads\///' | uniq)
    fi

    if [[ "${branches}" == "" ]]; then
      echo "🔍 No branches found"
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
