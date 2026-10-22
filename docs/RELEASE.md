# Release process

Versioning and changelogs are driven by **conventional commits** via
[`commit-and-tag-version`](https://github.com/absolute-version/commit-and-tag-version).
Your commit messages are the only input — there is no changelog to maintain by
hand.

This mirrors
[catalyst-agentic-sdlc](https://github.com/TheBranchDriftCatalyst/catalyst-agentic-sdlc),
the canonical source for the pattern. Keep them aligned.

## One writer per artifact

This is the rule that keeps the system from eating itself. Each generated
artifact has exactly one tool allowed to write it:

| Artifact                    | Sole writer                                      |
| --------------------------- | ------------------------------------------------ |
| `CHANGELOG.md`              | `commit-and-tag-version`                         |
| version (in `package.json`) | `commit-and-tag-version`                         |
| `v*` git tags               | `commit-and-tag-version`                         |
| GitHub Release page         | the `release.yml` workflow, from an existing tag |

Two tools writing one artifact is not a style question — it corrupts state.
This repo previously ran `release-please` _and_ a local `build-release.sh`,
both bumping the version and both pushing `v*` tags. The result was a version
file at `0.1.1` while release-please's manifest said `0.1.0`, so it planned its
next release from `0.1.0` and would have proposed a version that already
existed. Both are gone.

The workflow deliberately only _publishes_ a tag it did not create. It never
computes a version, which is why there is no second writer in CI.

## The canonical path

```
 commit ──▶ yarn release ──▶ yarn release:push ──▶ release.yml ──▶ GitHub
 conventional   bump version        push commit + tag      reads notes      Release
 message        write CHANGELOG                            from CHANGELOG
                commit + tag
```

```sh
yarn release:dry     # preview — writes nothing
yarn release         # bump, write CHANGELOG.md, commit, tag
yarn release:push    # push commit + tag, triggering the Release workflow
```

Releases happen **locally**. The only thing CI does is turn the pushed tag into
a GitHub Release page.

Force a level when the commits don't imply what you want:

```sh
yarn release:patch
yarn release:minor
yarn release:major
```

### The prerelease gate

`package.json` sets:

```json
"commit-and-tag-version": { "scripts": { "prerelease": "yarn test" } }
```

So `yarn test` (format check, markdown lint, link check) runs _before_ anything
is bumped or tagged. A failing check aborts the release rather than producing a
tagged commit that CI then rejects.

### Version bump rules

| Commit                               | Bump  |
| ------------------------------------ | ----- |
| `fix:`, `perf:`, `revert:`           | patch |
| `feat:`                              | minor |
| `feat!:` / `BREAKING CHANGE:` footer | major |
| everything else                      | none  |

`feat!:` and `fix(api)!:` are accepted by the `commit-msg` hook. They were
previously **rejected** by a bespoke bash validator whose regex had no
provision for `!` — silently blocking the only documented route to a major
version bump. That validator is gone; `commitlint` replaced it.

## Changelog

`CHANGELOG.md` is generated. Sections, hidden types and link formats are all
configured under the `commit-and-tag-version` key in `package.json`:

```json
"types": [
  { "type": "feat", "section": "Features" },
  { "type": "chore", "section": "Chores", "hidden": true }
]
```

```sh
yarn release:dry     # preview the next entry without writing
yarn changelog       # regenerate the whole file from history
```

`release:dry` is the preview. There is no separate preview tool on purpose — a
second changelog generator would be a second writer of the same file. For the
same reason `CHANGELOG.md` sits in `.prettierignore`: formatting it would fight
the tool that owns it.

### Keep the type lists in sync

Two places define commit types, and they have to agree:

1. `package.json` → `commitlint` — what the hook **accepts**
2. `package.json` → `commit-and-tag-version.types` — what the changelog **shows**

Add a type to 1 but not 2 and you get commits that pass the hook and then land
in no changelog section at all.

## Commit format

```
type(scope)?: description

[body]

[footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`,
`build`, `ci`, `revert`.

```sh
git commit -m "feat: add user authentication"
git commit -m "fix(api): correct response status code"
git commit -m "feat!: require JWT instead of API keys"
```

Breaking changes take either the `!` or a footer:

```
feat: redesign authentication

BREAKING CHANGE: clients must send a JWT; API keys are rejected.
```

Enforced beyond the basic shape: `header-max-length` 100, lowercase types, no
capitalised subject, no trailing full stop, and no AI attribution trailers
(a separate `commit-msg` command).

## `bumpFiles` — syncing the version across files

The version lives in `package.json`. When a repo needs it in more places,
`bumpFiles` handles that, including formats with no built-in updater:

```json
"bumpFiles": [
  { "filename": "package.json", "type": "json" },
  { "filename": "plugins/foo/plugin.json", "type": "json" },
  { "filename": ".claude-plugin/marketplace.json", "updater": "scripts/marketplace-version-updater.cjs" }
]
```

This template only lists `package.json`. The canonical repo uses the custom
`updater` form — copy that pattern rather than inventing a bump script.

## Troubleshooting

**`yarn release` aborts before bumping.** The `prerelease` gate failed. Run
`yarn test` to see which check, fix, retry. Working as intended.

**A commit is missing from the changelog.** Non-conventional messages are
dropped, and types marked `hidden: true` (`chore`, `style`, `test`) never
appear. A commit made with `--no-verify` that skipped the hook won't show up —
rewrite the message before releasing.

**The tag pushed but no GitHub Release appeared.** `release.yml` triggers only
on tags matching `v*`. Check the tag name, and that the workflow has
`contents: write`.

**The Release body is just "Release v1.2.3".** The notes extractor couldn't
find that version's heading in `CHANGELOG.md` and fell back. Usually means the
tag and the changelog heading disagree.
