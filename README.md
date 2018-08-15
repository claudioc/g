G
=

>Because G is shorter than GIT.

`g.sh` is just a bash script to shortcut some of your most frequently used git operations.

## Installation

I have copied it directly in my `~/bin` directory, as just `g`, but obviously YMMV.

## Dependencies

I use "git latest", as `git for-each-ref --sort='-committerdate' --format='%(refname)%09%(committerdate)' refs/heads | head -n 15 | sed -e 's-refs/heads/--'`, (put again in `~/bin` as `git-latest`).

## Customization

I have left in the script a small commit automation I use. It might be useful to anyone having to prefix each one of their commit with a specific value (in my case is the ID of the Jira ticket)
