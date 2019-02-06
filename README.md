# G

> Because G is shorter than GIT.

`g.sh` is just a bash script to shortcut some of your most frequently used git operations.

## Shorcuts

(also available as `g h`)

```
a   : (add)    git add -u
c $1: (commit) git commit -m $1, with ticket number detection
d   : (diff)   git diff + git diff --staged
D $1: (diff between branches) Shows the differences between HEAD and another branch
g $1: (go)     git checkout a (new or old) local branch or shows the local activities
G $1: (interactive go) Interactively change branch (matching *$1* when passed)
h   : help
m   : (master) checkouts the master branch and pulls
p   : (pull)   git pull
P   : (push)   git push -u ${G_REMOTE} current_branch_name
s   : (status) git status -s
```

Anything else passed as the first parameter will be directly proxied to `git`, so that–for example– `g grep stuff` will just run `git grep stuff`.

## Installation

I have copied it directly in my `~/bin` directory, as just `g`, but obviously YMMV.

`g` uses the `G_REMOTE` environment variable to know which remote to operate with, which defaults to `origin`.

## Special commands

Besides some simple "smart" aliasing, `g` also implements some special commands with a bit more interesting behaviour. Let's take a look at them.

### The `g` command (go)

The g's g command will move you to another branch, the name of which is passed as the first (and only) argument of it. If the branch is not passed, `g g` will show you the list of the most recent activities.

### The `c` command (commit)

The `c` command performs a commit, receiving the message as the first parameter (no multiline for now).

It will try to extract a token from the _current branch name_ which represents the "ticket number" that this commit refers to. In some corporate environments, all the commit messages must contain the number of the issue tracker ticket (we use Jira, for example). The token will be estracted when in the form of "XX-NNN", where "XX" is `A-Z` and "NNN" is `0-9`. The final commit message will be in the form: "[ticket number] original message"

There are 4 environment variables (with sensible defaults) that can change this behaviour:

- `G_C_TICKET_REGEXP`: The regexp to try to find the ticket number from the branch name. Defaults to `[A-Z]+-[0-9]+`
- `G_C_DEFAULT_TICKET`: What to use in case a ticket number is not found in the branch name. Defaults to ''
- `G_C_NEEDS_TICKET`: Wether the commit command must find the ticket number in the branch before proceeding (or bail). Accepts "1" or "0", defaults to "0" (no need for the ticket and will use G_C_DEFAULT_TICKET)
- `G_C_IS_SMART`: Probably not everybody wants a "smart commit" with automatic ticket extraction, and a quick alias to `git commit -m` would be enough. Set it to '0' in that case. Default is '1' (active)

If you want to play with the regexp extraction, you can use a snippet like this one (actual part of g.sh):

```sh
  regexp="(${G_C_TICKET_REGEXP})"
  git_branch=foobar
  branch_id=${G_C_DEFAULT_TICKET}
  if [[ ${git_branch} =~ ${regexp} ]]; then
    branch_id=${BASH_REMATCH[1]//_*}
  fi
  echo ${branch_id}
```

### The `G` command (go)

The `G` command will help you switch to a branch, interactively; more or less what you could already achieve with a nicely configured zsh or fish autocompletion.

You provide the command with part of the branch name, and the command will search for a match in the local and remote branches for that substring. It will then present all the results and ask you to chose the one you want to switch to. The matches are also sorted from the most recent (similarly to `g l`).

For this command we only consider `origin` as the remote name.

## Dependencies and limitations

`g` doesn't rely on anything else than bash (< 4 because macOs, right?) and other standard userland tools (sed, grep, head, uniq)
