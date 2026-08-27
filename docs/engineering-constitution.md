# Engineering Constitution

The constitution now ships **inside the skill that owns it**, so it travels with
the skill wherever it is installed:

> [`skills/engineering-constitution/references/engineering-constitution.md`](../skills/engineering-constitution/references/engineering-constitution.md)

It moved because 16 skills cited `docs/engineering-constitution.md` as a
relative path. Installed into `~/.claude/skills/`, that path resolved against
whatever project was open — so the citation was dead in every use outside this
repo. Bundling it into the skill directory is the same fix already applied to
`recording-decisions` and its scripts.
