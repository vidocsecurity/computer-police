# Computer Police — site

A static, dependency-free landing page for Computer Police.

- `index.html` — single-page site (hero, problem, who-it's-for, how-it-works, design goals, privacy, coverage, CTA).
- `style.css` — light + dark themes, terminal-leaning typography. Inter + JetBrains Mono. Defaults to light.
- `script.js` — copy-to-clipboard for install blocks and theme toggle. Vanilla JS, no deps.
- `screenshot.png` — hero asset (copy of `../docs/screenshot.png`).
- `favicon.svg`, `favicon.ico`, `favicon-16.png`, `favicon-32.png`, `apple-touch-icon.png` — favicons. Sourced from `favicon.svg` (compact-Macintosh face, matches the menu-bar icon drawn by `StatusItemController.makeMenuBarOfficerImage` in the macOS app).
- `og.svg`, `og.png` — Open Graph / Twitter share card (1200×630). Sourced from `og.svg`.

## Regenerating favicons and OG image

Requires `rsvg-convert` and `magick` (ImageMagick). On macOS: `brew install librsvg imagemagick`.

```bash
cd site
rsvg-convert -w 1200 -h 630 og.svg       -o og.png
rsvg-convert -w 180  -h 180  favicon.svg -o apple-touch-icon.png
rsvg-convert -w 32   -h 32   favicon.svg -o favicon-32.png
rsvg-convert -w 16   -h 16   favicon.svg -o favicon-16.png
magick favicon-16.png favicon-32.png favicon.ico
```

No build step. No npm install. Just open `index.html`.

## Develop locally

Any static server works:

```bash
cd site
python3 -m http.server 4001
# open http://localhost:4001
```

Or:

```bash
npx --yes serve site
```

## Deploy

The site is static HTML, so any static host works.

### GitHub Pages (simplest)

In repo settings → Pages, set the source to the `main` branch and the folder to `/site`. Pages will publish at `https://vidocsecurity.github.io/computer-police/`.

### Cloudflare Pages or Vercel

Connect the repository, set the build output directory to `site/`, leave the build command empty.

### Custom domain

The canonical domain is `computer.police.dev`. Production is currently
served by Cloudflare Pages auto-deploying this `site/` folder on every push
to `main`. Point a `CNAME` record at the Cloudflare Pages target
(`computer-police.pages.dev`) at your DNS provider; no extra files are
required in this directory.

If you change the domain, update `og:url`, `og:image`, and the canonical
references inside `index.html`, the `self update` default URL in
`cmd/computer-police/main.go`, and the install one-liner in the root
`README.md` and `docs/RELEASING.md`.

### `/install` endpoint

The install one-liner advertised everywhere is:

```bash
curl -fsSL https://computer.police.dev/install | bash
```

`site/install` is a verbatim copy of `scripts/install.sh` checked into
the repo so the host (Cloudflare Pages today, any static host
tomorrow) can serve it as a plain file with no redirect hop. The Go
binary's `self update` flow downloads the same URL.

After editing `scripts/install.sh`, sync the copy and commit both:

```bash
cp scripts/install.sh site/install
git add scripts/install.sh site/install
```

CI enforces this: the `site` job in `.github/workflows/ci.yml` fails if
`site/install` ever drifts from `scripts/install.sh`.

## Updating content

The page is one HTML file with semantic section comments. Find the section you want (`<!-- 3. PROBLEM -->`, `<!-- 5. HOW IT WORKS -->`, etc.) and edit it directly. Keep the section count and order so the styling stays clean.

To refresh the hero screenshot, replace `screenshot.png` with a new export from the macOS menu-bar app:

```bash
cp ../docs/screenshot.png ./screenshot.png
```
