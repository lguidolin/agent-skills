# Changelog

## [0.8.0](https://github.com/lguidolin/agent-skills/compare/v0.7.0...v0.8.0) (2026-08-31)


### ⚠ BREAKING CHANGES

* the skill `verification-gate-and-automation` is now named `merge-gates-and-automation`. Re-run scripts/install.sh to pick up the new name; it prunes the stale symlink.

### Features

* align house skills with superpowers workflows ([#18](https://github.com/lguidolin/agent-skills/issues/18)) ([e4a98d5](https://github.com/lguidolin/agent-skills/commit/e4a98d53bee95b673cd24ccd7ae96a21c3577534))

## [0.7.0](https://github.com/lguidolin/agent-skills/compare/v0.6.0...v0.7.0) (2026-08-26)


### ⚠ BREAKING CHANGES

* .github/skills/ is no longer a skill pool in this repo. Install superpowers via the Claude Code marketplace and addyosmani/agent-skills from its own repo. skill-add.sh now reads skills-available/, and the /setup-repo command invokes init-repo-CI (was repo-automation-setup).

### Code Refactoring

* make plugins the source of truth and drop the profile system ([#16](https://github.com/lguidolin/agent-skills/issues/16)) ([a4b6d9e](https://github.com/lguidolin/agent-skills/commit/a4b6d9eb15de2a713ea73729ee4e8d25ecc58b38))

## [0.6.0](https://github.com/lguidolin/agent-skills/compare/v0.5.0...v0.6.0) (2026-06-13)


### Features

* add engineering constitution skills ([#13](https://github.com/lguidolin/agent-skills/issues/13)) ([ca8d854](https://github.com/lguidolin/agent-skills/commit/ca8d854fcf997e67cdba460a9e0395fb4f63feff))

## [0.5.0](https://github.com/lguidolin/agent-skills/compare/v0.4.0...v0.5.0) (2026-05-05)


### Features

* centralized tool pool with per-project profile activation ([#11](https://github.com/lguidolin/agent-skills/issues/11)) ([00f40c3](https://github.com/lguidolin/agent-skills/commit/00f40c327d120eb4c6ea90c72292843ac7d1ac4e))

## [0.4.0](https://github.com/lguidolin/agent-skills/compare/v0.3.1...v0.4.0) (2026-05-01)


### Features

* add token-efficient context management toolkit ([#9](https://github.com/lguidolin/agent-skills/issues/9)) ([85e8e4e](https://github.com/lguidolin/agent-skills/commit/85e8e4ebc2cb4f9f9469fbfd6b6163fddc241eb7))

## [0.3.1](https://github.com/lguidolin/agent-skills/compare/v0.3.0...v0.3.1) (2026-04-16)


### Bug Fixes

* update release-please-action from deprecated google-github-actions to googleapis ([#6](https://github.com/lguidolin/agent-skills/issues/6)) ([0caf1ea](https://github.com/lguidolin/agent-skills/commit/0caf1ea9d92609fa087cb500a2daeae9063c4076))

## [0.3.0](https://github.com/lguidolin/agent-skills/compare/v0.2.0...v0.3.0) (2026-04-16)


### Features

* add branch-push-pr skill for full git workflow cycle ([30110e6](https://github.com/lguidolin/agent-skills/commit/30110e6e28abb18ee3366e1c1bb2df327d1d4fd3))
* add branch-push-pr skill for full git workflow cycle ([303dd5d](https://github.com/lguidolin/agent-skills/commit/303dd5db9d90da13c179524fa9b7d7b771187ebf))

## [0.2.0](https://github.com/lguidolin/agent-skills/compare/v0.1.0...v0.2.0) (2026-04-15)


### ⚠ BREAKING CHANGES

* agent persona files removed. Install addyosmani/agent-skills and obra/superpowers directly for agents.

### Features

* improve skills with engineering patterns from addyosmani/agent-skills ([cf5da6e](https://github.com/lguidolin/agent-skills/commit/cf5da6edfa442e7e33ad3ae49a939b925c4f9246))
* initial skills and agent personas ([9347703](https://github.com/lguidolin/agent-skills/commit/9347703489487d03945fb29d4141c1cbbe8f80f5))


### Miscellaneous Chores

* remove copied agents, add GPLv3 license, list upstream repos as dependencies ([1ae91a9](https://github.com/lguidolin/agent-skills/commit/1ae91a9fb515ac8f59b0083097f9920a7a4df750))
