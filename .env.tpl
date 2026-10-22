# Secret REFERENCES only — safe to commit. Values live in 1Password.
# Dev-side analog of an ExternalSecret manifest: declare what this repo
# needs; `use_onepassword` (direnv, from home-manager) materializes env.
#
# NOTE: op inject templates COMMENTS too — never write a literal
# scheme-prefixed example here. Convention (scheme omitted on purpose):
#   dev/<repo-name>/<kebab-field>       per-project secret
#   dev/<repo-name>/<section>/<field>   optional grouping
#   dev/shared/<field>                  cross-project (registry creds…)
# dev is the LAPTOP vault. catalyst-eso is the cluster's — External Secrets
# Operator reads it via 1Password Connect, and nothing here should point at
# it: same pattern either side, separate vaults, so a local experiment can
# never reach into what the cluster is running on.
#
# A repo created FROM this template renames the item segment below to its own
# repo name, per the convention above. Lookups are soft-fail: an item that
# does not exist yet warns on direnv entry, it does not break the shell.

DEMO_SECRET="op://dev/git-repo-template/demo-secret"
DATABASE_URL="op://dev/git-repo-template/db/url"
