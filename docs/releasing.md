# Releasing Remy (auto-updates with Sparkle)

## How updates reach people

- **Checking.** Remy checks the feed once a day: `appcast.xml` on `main`, served from `https://raw.githubusercontent.com/Deveshb15/remy/main/appcast.xml`. People can also check any time from the popover with **… → Check for Updates…**.
- **When an update is found:**
  1. Remy uses Sparkle's "gentle reminder" for menu bar apps. It shows up in the Dock with a **1** badge and posts a notification: "Remy 0.2.0 is available".
  2. Clicking the notification opens the update window, with the release notes from the feed.
  3. People can choose **Install Update**, **Remind Me Later**, or **Skip This Version**.
  4. They can also tick "Automatically download and install updates in the future".
- **Installing.** Remy installs the update and relaunches. Their to-dos, agent connections, and widget are all kept.
- **Security.** Every update is checked twice before it's installed:
  - Its **EdDSA signature** must match the public key built into the app (`SUPublicEDKey` in `project.yml`).
  - Its **code signature** must be the same Developer ID. A tampered or foreign DMG is rejected.

> **The feed needs a public repo.** `raw.githubusercontent.com` only serves public repositories. Until the repo is public, update checks quietly find nothing.
>
> **Only 0.1.2 and later have the updater.** Anyone on 0.1.0 or 0.1.1 has to install 0.1.2 by hand once.

## Shipping an update

```sh
git checkout main && git pull
$EDITOR build/notes.md        # what changed, written for users (see "Release notes" below)
scripts/release.sh 0.2.0 build/notes.md
```

`release.sh` runs these steps in order and stops at the first failure. Nothing is published until step 6, so if it stops earlier, reset with `git checkout project.yml appcast.xml` and run it again.

1. Checks that you're on a clean, up-to-date `main` and that the version is higher than the current one.
2. Bumps `MARKETING_VERSION` to the new version and adds 1 to `CURRENT_PROJECT_VERSION`. Sparkle compares the build number, so it must always go up.
3. Builds the universal app, signs it with Developer ID, notarizes and staples the app, then signs, notarizes, and staples the DMG. This is `scripts/make-dmg.sh` with `REMY_NOTARY_PROFILE=macd-notary`.
4. Signs the DMG for Sparkle (EdDSA, keychain account `remy`) and verifies the signature.
5. Adds the release to `appcast.xml`.
6. Publishes the GitHub release with the DMG.
7. Commits and pushes `project.yml` and `appcast.xml`. **This push is what makes the update go live.** It comes last on purpose, so no one is ever offered a download that doesn't exist yet.

The options can be combined:

| Option | Use it for |
|---|---|
| `--beta` | Only people who opted into betas get it, and the GitHub release is marked pre-release. Promote it later with `scripts/promote.sh 0.2.0`. |
| `--phased-hours 24` | A staged rollout. Sparkle splits users into 7 groups, offered one group every N hours. `24` reaches everyone in about a week. Manual "Check for Updates" always gets it right away. |
| `--critical` | Users can't skip it, and it's shown sooner. Never phased. |
| `--dry-run` | Builds, notarizes, and signs, and edits `appcast.xml` locally, but publishes nothing. Undo with `git checkout project.yml appcast.xml`. |

### Release notes

Keep them short and written for users. They're shown in the update window and on the GitHub release. The supported formatting is `### Heading`, `- bullets`, `**bold**`, and `` `code` ``.

```markdown
### New
- **Snooze from the widget.** Push a to-do to tomorrow without opening Remy.
### Fixed
- Checkmarks are visible on colorful wallpapers.
```

## When to ship what

| Kind | Version | When | How |
|---|---|---|---|
| **Bug fix** | `0.1.x` patch | As soon as it's fixed and you've used it for an hour. Keep it to about one per day. | `release.sh` |
| **New features** | `0.x.0` minor | Batch them. Every 1–2 weeks is a good rhythm; nobody likes an update every day. | `--beta` for 1–3 days on your own Mac, then `promote.sh` |
| **Big or risky change** (storage format, onboarding, agent connections, permissions) | minor | After a beta, with a staged rollout. | `--beta`, then promote, or ship with `--phased-hours 24` |
| **Emergency**: data loss, crash on launch, security hole, broken agent connections for everyone | patch | Immediately. | `--critical` (no phasing) |

**Timing:**
- Ship Tuesday to Thursday, in your morning, when you can watch for problems for the next few hours.
- Avoid Friday nights, weekends, and the day before you travel.
- After a release, watch GitHub issues for 24 hours, and try "Check for Updates…" yourself from the previous version.

### Try it on your own Mac first

- **Beta channel:** run `defaults write dev.devesh.remy RemyBetaUpdates -bool YES` on your Mac, then ship with `--beta`. Only you, and anyone else who opted in, will get it. `defaults delete dev.devesh.remy RemyBetaUpdates` turns it off.
- **Test an update before publishing:** run `release.sh <version> notes.md --dry-run`. Then point your installed Remy at a local copy of the feed with `defaults write dev.devesh.remy RemyFeedURL file:///path/to/appcast.xml`. Edit the enclosure `url` in that copy to `file:///…/build/Remy.dmg`, and use **Check for Updates…**. Remove the override afterwards with `defaults delete dev.devesh.remy RemyFeedURL`.

## If a release is bad

- You can't recall an update from people who already installed it. **Ship a fixed, higher version** as soon as possible, using `--critical` if the bad one loses data or won't launch.
- To stop it spreading while you work on the fix, delete its `<item>` from `appcast.xml` and push. People who haven't updated yet won't be offered it.
- Don't delete the GitHub release while its `<item>` is still in the feed. Sparkle would hit a 404.

## Never do these (they strand every existing user)

- Change the **bundle identifier** (`dev.devesh.remy`), the **signing team** (`728M4WMSGG`), or the **Sparkle key** without a migration release first.
- Lower or reuse a **build number** (`CURRENT_PROJECT_VERSION`).
- Rename the release asset. The feed points at `releases/download/v<version>/Remy.dmg`.

## Keys and credentials (one-time setup, already done)

| What | Where |
|---|---|
| Sparkle **private** key (signs updates) | Login keychain, account `remy`. The backup is at `~/.remy-sparkle/ed25519-private-key`. **Move it into your password manager and delete the file.** If it's lost, existing users can never be updated again. |
| Sparkle **public** key | `SUPublicEDKey` in `project.yml`. It's public, so this is fine. |
| Developer ID certificate | Keychain: "Developer ID Application: Pratyush Singh (728M4WMSGG)". |
| Notarization | `xcrun notarytool` keychain profile `macd-notary` (team 728M4WMSGG). Override with `REMY_NOTARY_PROFILE`. |

To set up a new Mac, import the key with `build/spm/artifacts/sparkle/Sparkle/bin/generate_keys --account remy -f <backup-file>`. Then check that `generate_keys --account remy -p` prints the same public key as `project.yml`.
