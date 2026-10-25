# Contributing

## Branches

- `dev` is the default branch. Every push builds a staging APK (Actions → *Staging build*, artifacts only).
- Releases are published from the *Release Build* workflow (run it manually). Bump `verCode` in
  `TMessagesProj/build.gradle` first; the release tag is `v<APP_VERSION_NAME>-<verCode>` and the in-app
  updater compares that version code.

## Syncing upstream

This fork tracks [DrKLO/Telegram](https://github.com/DrKLO/Telegram). Upstream marks each release with a commit
titled `update to X.Y.Z (build)`. The *Upstream check* workflow opens an issue when a newer one appears.

The fork does not share git history with upstream. Each sync is a three-way merge whose base is the upstream
commit of the version the fork is currently on, recorded below. Update the table after every sync.

| Fork version | Upstream commit (merge base for the next sync) |
|---|---|
| 12.10.0 (7031) | `4e1a61eca` |
| 13.0.3 (7183) | `0aae95980` |

```bash
git fetch --shallow-since=<date before the base commit> https://github.com/DrKLO/Telegram master:refs/remotes/upstream/master
BASE=<last row of the table>
NEW=<upstream "update to" commit>

# Dry run: list conflicts without touching the working tree.
git -c merge.renameLimit=20000 merge-tree --write-tree --name-only --merge-base=$BASE HEAD $NEW

# Write the merged tree (with conflict markers) into the working tree.
TREE=$(git -c merge.renameLimit=20000 merge-tree --write-tree --merge-base=$BASE HEAD $NEW | head -1)
git read-tree --reset -u $TREE
```

Then resolve the conflict markers, keep upstream's behaviour and re-apply the fork's change on top, and commit the
result as a normal commit titled `update to X.Y.Z (build)`.

- Upstream app variants (`TMessagesProj_App*`, `TMessagesProj_AppTests`) are not used by the fork; delete them again
  if a sync brings them back.
- Fork changes to submodule code live in `patches/<name>/*.patch` and are applied at build time. If upstream bumps
  a submodule and a patch stops applying, the build fails; refresh the patch against the new submodule commit.
