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

The canonical domain is `computer.police.dev`. Add it in your host's settings and a `CNAME` file inside `site/`:

```bash
echo computer.police.dev > site/CNAME
```

Update `og:url`, `og:image`, and the canonical references inside `index.html` if you change the domain.

### `/install` endpoint

The install one-liner advertised on the site, in the root `README.md`, and in the CLI's `self update` default is:

```bash
curl -fsSL https://computer.police.dev/install | bash
```

`computer.police.dev/install` must serve `scripts/install.sh` from the repo root over HTTPS. The simplest setups:

- **Cloudflare Pages / Netlify / Vercel** — add a `_redirects` (or `vercel.json`) rule from `/install` to the raw GitHub URL with a `302` so `curl -fsSL` (which follows redirects) lands on the script. Example for Cloudflare/Netlify, place `site/_redirects`:

  ```
  /install   https://raw.githubusercontent.com/vidocsecurity/computer-police/main/scripts/install.sh   302
  ```

- **Self-hosted / nginx** — proxy `/install` to the same raw GitHub URL, or check `scripts/install.sh` into `site/install` directly so it's served as a static file.

Whichever path you choose, the response body at `/install` MUST be the contents of `scripts/install.sh` (or a redirect to it) so piping into `bash` works.

## Updating content

The page is one HTML file with semantic section comments. Find the section you want (`<!-- 3. PROBLEM -->`, `<!-- 5. HOW IT WORKS -->`, etc.) and edit it directly. Keep the section count and order so the styling stays clean.

To refresh the hero screenshot, replace `screenshot.png` with a new export from the macOS menu-bar app:

```bash
cp ../docs/screenshot.png ./screenshot.png
```
