# G

> Because G is shorter than GIT.

`g.sh` is just a bash script to shortcut some of your most frequently used git operations.

## Shorcuts

(also available as `g h`)

```
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
```

## Installation

I have copied it directly in my `~/bin` directory, as just `g`, but obviously YMMV.

## Dependencies and limitations

`g` doesn't rely on anything else than bash (< 4 because macOs, right?) and other standard userland tools (sed, grep, head, uniq)

Please notice that:

- for the `G` command we only consider `origin` as the remote name.
- the `c` command is customised on my own personal conventions. It might be also useful to anyone having to prefix each one of their commit with a specific value (in my case is the ID of the Jira ticket).
