# How to publish updates to the Pioneer School site

Live site: <https://theoscholar.github.io/pioneer-school/>
Repository: <https://github.com/theoscholar/pioneer-school>

This folder **is** the Git working copy. There is no separate clone to keep in
sync — edit here (or edit the originals in `..\Pioneer School\`), then run the
publish script.

---

## One-time setup

1. **Install Git for Windows** — <https://git-scm.com/download/win>
   Accept the defaults. This includes Git Credential Manager, which handles
   GitHub sign-in through the browser, so no personal access token is needed.

2. **Allow scripts to run** (PowerShell, once per machine):

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

3. **First push signs you in.** The first time `publish.ps1` pushes, a browser
   window opens asking you to authorise GitHub. Approve it once; the credential
   is stored in Windows Credential Manager and reused thereafter.

The repository itself is already initialised, pointed at `origin`, and
configured with the correct commit identity
(`theoscholar@users.noreply.github.com` — GitHub rejects pushes that expose a
private email).

---

## Publishing an update

```powershell
cd "C:\Users\ThomS\OneDrive\Theo Library\pioneer-school-site"
.\publish.ps1
```

That will:

1. Copy every study-note file from `..\Pioneer School\` into this folder under
   its published name, using `name-map.tsv`.
2. Show you exactly what changed.
3. Commit and push to `main`.

GitHub Pages redeploys in roughly one minute.

Useful variations:

```powershell
.\publish.ps1 -WhatIf                          # preview only, pushes nothing
.\publish.ps1 -Message "Fix citation on 7b"    # custom commit message
```

---

## Adding a new study guide

1. Save the new file into `..\Pioneer School\`.
2. Add one line to `name-map.tsv`, **tab-separated**:

   ```
   Unit 19a - Some New Title - Study Notes.html	unit-19a-some-new-title.html
   ```

3. Add a link to it in `index.html`.
4. Run `.\publish.ps1`.

If a file in `Pioneer School` has no map entry, the script warns you and skips
it rather than publishing something with a messy filename.

---

## Troubleshooting

**`git push` rejected — email privacy.** The commit used the wrong address. Fix
the identity and retry:

```powershell
git config user.email "theoscholar@users.noreply.github.com"
git commit --amend --reset-author --no-edit
git push origin main
```

**`Unable to create '.git/index.lock': File exists`.** A stale lock, usually
left by an interrupted process. `publish.ps1` now clears these automatically
when no git process is running. To clear them by hand:

```powershell
Remove-Item ".git\index.lock", ".git\HEAD.lock", ".git\objects\maintenance.lock" -Force -ErrorAction SilentlyContinue
Get-ChildItem ".git\objects" -Recurse -Filter "tmp_obj_*" | Remove-Item -Force
```

**Every file suddenly shows as modified.** Line endings. `.gitattributes` sets
`* -text` to prevent this; confirm that file still exists, then:

```powershell
git config core.autocrlf false
```

**OneDrive conflict files appear inside `.git`.** Rare, but if OneDrive creates
a `...-copy.pack` or similar inside `.git`, delete the conflict copy. If the
repository is damaged beyond that, nothing is lost — the site content is safe
on GitHub. Re-clone into a fresh folder:

```powershell
git clone https://github.com/theoscholar/pioneer-school.git
```

**The site looks stale.** Pages caches hard. Force-refresh with `Ctrl+F5`, and
check the **Actions** tab on the repo to confirm the deployment succeeded.

---

## Note on search engines

Every page carries `<meta name="robots" content="noindex, nofollow">`. Keep that
tag in any new page so the notes stay out of search results.
