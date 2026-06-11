# Branding Transform — upstream → tunan

The local `tunan` plugin is a rebranded fork of `everyinc/compound-engineering-plugin`.
When porting an upstream change, apply the upstream diff to the corresponding
local file, then re-apply every transform below so no upstream identifier leaks
into the ported content. Apply transforms only to text that is genuinely an
identifier/branding token — never rewrite prose that merely contains the word
"compound" in a different sense.

## Path / name mapping

| Upstream | Local (tunan) |
|---|---|
| `plugins/compound-engineering/skills/ce-<name>/` | `plugins/skills/<name>/` |
| skill dir + `name:` frontmatter `ce-<name>` | `<name>` (drop the `ce-` prefix) |
| agent file / `name:` `<agent>` | `<agent>` (already bare — no change) |

`lfg` is the one upstream skill with no `ce-` prefix; it maps to local `lfg`
unchanged.

## Token substitutions (apply inside file contents)

| Upstream token | Local token |
|---|---|
| `ce-<skill>` (cross-references between skills) | `<skill>` |
| `/compound-engineering:<x>` or `/ce:<x>` (slash command) | `/tunan:<x>` |
| `compound-engineering:<agent>` (subagent_type) | `tunan:<agent>` |
| GitHub label / marker prefix `ce:` or `compound-engineering:` (`ce:req`, `ce:plan`, `ce:solution`, `ce:idea`, `ce:pulse`, `ce:retro`) | `tunan:` (`tunan:req`, …) |
| marker comment `<!-- ce:plan -->` etc. | `<!-- tunan:plan -->` etc. |
| `github.com/everyinc/compound-engineering-plugin` | `github.com/raptoravis/tunan` |
| repo slug `everyinc/compound-engineering-plugin` | `raptoravis/tunan` |
| `gh api repos/everyinc/compound-engineering-plugin/...` | `gh api repos/raptoravis/tunan/...` |
| config dir `.compound-engineering/` | the repo's `tunan:config` GitHub issue — tunan keeps no local config dir; port any local-config read/write to the config issue (see the config-issue storage contract in the `setup` skill) |
| plugin display name "Compound Engineering" / "compound-engineering" / "ce" | "tunan" |

## Residual-token sweep

After porting, search the changed files for any leaked upstream identifier. The
sweep must come back empty:

```bash
grep -rnE 'ce-[a-z]|compound-engineering|everyinc|\.compound-engineering|ce:(req|plan|solution|idea|pulse|retro)|yunxing' <changed-files>
```

`yunxing` is the fork's previous name (renamed to `tunan`); it must never
reappear from an old reference. Any hit is a missed transform — fix it before
reporting the port complete.

## Do NOT transform

- Source prose describing the upstream project by name in a historical note
  (e.g. a CHANGELOG entry crediting upstream) — sync-ups does not port upstream
  CHANGELOG/README/manifests at all, so this rarely arises.
- The word "compound" used in its plain-English or domain sense (e.g.
  "compound your team's knowledge", the `compound` skill name itself) — only
  `compound-engineering` as a plugin identifier is a branding token.
