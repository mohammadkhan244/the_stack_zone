# The Stack Zone

RedZone for Substack Lives and YouTube livestreams. Anyone can start a **zone**, paste in links, and share it. Viewers watch a 4×2 multiview with a HEADLINES ticker, paid-sub score bugs and a hype guy who yells "HE COULD GO ALL THE WAY!"

*Unofficial fan project. Not affiliated with Substack or YouTube.*

## How it works
- **Zones**: anyone creates one (no login). The creator gets two links:
  - **Viewer link** `/z/<zone-id>` to share on Notes
  - **Co-host link** `/z/<zone-id>#key=…`, private, for adding Lives, ending them, posting headlines and hitting **+1 PAID**
- **+1 PAID** bumps that box's score bug and fires the hype guy for *every* viewer in real time.
- Lives auto-expire after 2 hours, and co-hosts can tap **END** sooner. Up to 16 per zone, 8 shown in the grid.
- **Directory**: zones marked "listed" show on the homepage, sorted by how many Lives are on. Unlisted zones are link-only.
- **YouTube links** embed inline — every box autoplays muted. Tap a box (or its header bar) to give it audio. Only one box has audio at a time. The yellow border and 🔊 badge show which one. The **🔇 Muted** button in the header mutes all.
- **Substack links** can't be embedded (Substack blocks cross-origin iframes), so those boxes show a **WATCH ↗** card that opens the stream in a new tab.
- The URL type (`youtube` / `substack` / `link`) is auto-detected server-side and stored in the `kind` column.

## Deploy (about 10 minutes)
1. **Supabase**: create a free project at supabase.com → SQL Editor → paste and run `supabase/schema.sql`.
2. In Supabase, go to Project Settings → API and copy the **Project URL** and the **anon public** key into `config.js`.
3. **Vercel**: import this GitHub repo → Framework: *Other* → no build command → Deploy.
4. Open your site, create a zone, paste a Live, and share the link.

## Files
| File | What it does |
|---|---|
| `index.html` | Home: create a zone and browse the directory |
| `zone.html` | The multiview (served at `/z/<id>`) |
| `common.js` | Supabase client, helpers, hype guy (horn + speech) |
| `styles.css` | RedZone styling |
| `supabase/schema.sql` | Tables, row-level security and the edit-key functions |
| `vercel.json` | Clean URLs + `/z/:id` route |

## Security notes
- The anon key is public by design. All writes go through database functions that check the zone's edit key, which is stored only as a SHA-256 hash in a table nobody can read.
- Anyone can create zones. If spam shows up, add a captcha (e.g. Cloudflare Turnstile) to the create form.
