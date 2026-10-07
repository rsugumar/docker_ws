# BookOrbit

Self-hosted library management and reading platform, running on a Raspberry Pi 4
with a Calibre library kept in sync with Google Drive.

- Upstream: <https://bookorbit.app>
- Reachable at `https://bookorbit.myhome.me` (Caddy, internal CA)

Paths below use a shorthand:

```bash
export BOOKORBIT=~/docker_compose/bookorbit
```

---

## How storage works

**Google Drive is not mounted.** There is no FUSE layer and no daemon watching
the filesystem. The Pi keeps a real local copy and copies to and from Drive on a
schedule.

```
Google Drive  ──rclone copy (timer, 6h)──>  /home/rsukumar/books  <── BookOrbit reads
     ^                                                    |
     └─────────── rclone copy (manual) ───────────────────┘
```

This was chosen over a read-only FUSE mount because books need to be addable
from the Pi. Writing into a mounted Drive crosses the API on every write, which
is slow and fragile. Copying makes uploads a deliberate step and lets BookOrbit
read local disk at full speed.

Cost: ~2.9 GB of local disk.

### Deletions never propagate

Both scripts use `rclone copy`, which is **additive only**. It never deletes on
the destination.

- Deleting a book in BookOrbit removes it locally, and the next pull **restores
  it from Drive**.
- To actually remove a book from Drive, delete it in the Drive web UI.

Drive is the archive and the safety net. Local is a working copy.

---

## Layout on the Pi

| Path | Purpose |
| --- | --- |
| `~/docker_compose/` | git clone of `docker_ws` (symlink to `~/my_workspace/docker_ws/docker_compose`) |
| `~/docker_compose/bookorbit/` | compose project |
| `~/docker_compose/bookorbit/.env` | **untracked**, Pi-specific, `chmod 600` |
| `~/docker_compose/bookorbit/.env.example` | tracked template |
| `~/docker_compose/bookorbit/.env` → `BOOKS_HOST_PATH` | `/home/rsukumar/books` |
| `~/books/` | the local library that BookOrbit reads |
| `bookorbit/scripts/` | sync and auth scripts |
| `~/.config/rclone/rclone.conf` | Drive remote, `chmod 600` |

Docker layout:

- `~/docker_compose/bookorbit/data/postgres` — Postgres data
- `~/docker_compose/bookorbit/data/app` — app data, including the Book Dock at
  `/data/book-dock`
- `/home/rsukumar/books` → `/books` in the app container (read-write)

---

## Daily use

### Add books

Upload through BookOrbit's Book Dock, or drop files into `/home/rsukumar/books`.

Then push to Drive:

```bash
$BOOKORBIT/scripts/bookorbit-push.sh --dry-run   # preview
$BOOKORBIT/scripts/bookorbit-push.sh             # upload
```

Push is **manual on purpose**. The timer only pulls, so a book added on the Pi
can never be overwritten before it has been backed up.

### Pick up books added elsewhere

Automatic every 6 hours. To force it:

```bash
$BOOKORBIT/scripts/bookorbit-sync.sh
```

**Never run two syncs at once.** rclone takes no lock, so a concurrent run means
several processes writing the same files and a partially-written `.epub` could be
read by BookOrbit mid-scan.

```bash
# check before starting another
pgrep -af bookorbit-sync.sh
```

---

## Scripts

All in `scripts/` beside the compose project, so they are version-controlled
alongside everything they operate on. The systemd units live in
`~/.config/systemd/user/`; copies sit here for reference and are git-ignored.

| Script | Direction | When |
| --- | --- | --- |
| `bookorbit-sync.sh` | Drive → local | timer, every 6h |
| `bookorbit-push.sh` | local → Drive | manual |
| `bookorbit-auth.sh` | OAuth login | one-time, re-auth only |
| `set-rclone-token.sh` | writes a token blob | used by re-auth |

Both sync scripts accept `--dry-run` and pass extra flags through to rclone.

`REMOTE_PATH` and `LOCAL_PATH` are defined at the top of each script.

### systemd timer

```
~/.config/systemd/user/bookorbit-sync.service
~/.config/systemd/user/bookorbit-sync.timer
```

Both `ExecStart` and `Documentation` point at the script inside the repo. If the
scripts move, update the unit and re-run `systemctl --user daemon-reload`.

```bash
systemctl --user status bookorbit-sync.timer
systemctl --user list-timers | grep bookorbit
systemctl --user start --now bookorbit-sync.timer    # enable
journalctl --user -u bookorbit-sync.service -n 50     # recent runs
```

`TimeoutStartSec=2h` is deliberate — a full library copy over a slow link
exceeds systemd's 90s default and would otherwise be killed mid-transfer.

`loginctl enable-linger rsukumar` was run so the timer fires without an active
login session.

---

## Known characteristics

### Sync is slow

The initial pull ran at roughly 12 files/min — the Drive API throttles many
small files (covers, `.opf` sidecars) and the SD card is slow at small writes.
A full 1,371-file library takes over an hour. This is a **one-time cost**:
later runs only fetch new files.

### `metadata.db` is excluded

Both scripts pass `--exclude 'metadata.db*'`. Calibre's SQLite database stays
per-machine. BookOrbit ignores it entirely, and it is the most conflict-prone
file to share between two machines.

**Consequence:** BookOrbit and Calibre are separate catalogs over the same
files. Metadata edits made in BookOrbit do **not** reach Calibre.

To bulk-transfer metadata, use BookOrbit's migration wizard
(Settings → Maintenance → Import from Calibre-Web Automated). Run it before any
manual edits — migration overwrites metadata, and author, narrator, genre and
tag links that the source provides.

### Keep Calibre and the Pi from editing simultaneously

Drive is a poor sync target for concurrent writes.

---

## Configuration

`.env` is **untracked and per-machine** — it is in `.gitignore`, and only
`.env.example` is committed. The macOS copy keeps its Google Drive File Stream
path; the Pi copy uses `/home/rsukumar/books`.

Real secrets were generated for the Pi (`openssl rand`); the committed template
only holds placeholders.

Key values:

| Variable | Value |
| --- | --- |
| `BOOKS_HOST_PATH` | `/home/rsukumar/books` |
| `LIBRARY_BROWSE_ROOT` | `/books` |
| `PUID` / `PGID` | `1000` (matches `rsukumar`) |
| `APP_URL` | `https://bookorbit.myhome.me` |

The `/books` bind mount is **read-write** (the `:ro` flag was removed) so uploads,
Book Dock finalization and metadata write-back all work. `read_only: true` on
the container root is unaffected.

---

## Setup history

Recorded because several decisions look arbitrary otherwise.

### Google Drive authorization

The Pi is headless. `rclone authorize` starts a local callback server on
`127.0.0.1:53682`, reachable from the workstation via an SSH tunnel:

```bash
ssh -N -L 53682:127.0.0.1:53682 rsukumar@192.168.4.125
```

then open the printed URL in a browser. No HDMI needed — answer `n` to "Use auto
config?" if prompted.

`rclone.conf` uses **rclone's shared OAuth client**: it has no `client_id` or
`client_secret`.

Two earlier attempts failed:

1. A custom client in project `gen-lang-client-0472388410` was in **Testing**
   status. Google blocked sign-in ("Access blocked: rclone has not completed the
   Google verification process"). Worse, Testing status expires refresh tokens
   **after 7 days** for apps requesting sensitive scopes like `drive` — that
   would have meant re-authorising weekly.
2. `gcloud` cannot fix this. The only CLI path, `gcloud iap oauth-brands`, was
   deprecated and **shut down on 19 March 2026**. Test users and publishing
   status are console-only, now under **Google Auth Platform → Audience**.

The shared client is already published, so there is **no 7-day expiry**.

> The old custom client's secret was exposed in process listings during setup.
> That client is unused and should be deleted at
> <https://console.cloud.google.com/apis/credentials?project=gen-lang-client-0472388410>.

### Library path

The Drive library is `Backups/BookOrbit/Calibre Library` (1,372 objects,
2.89 GiB, 300 author folders).

There was a second library, `Backups/Calibre Orig Library` (1,675 objects,
3.57 GiB, 268 authors). It is *not* synced.

`rclone` presents the Drive root directly — there is no `My Drive/` prefix.

### Disk cleanup

Started at 8.9 GB free on a 29 GB card. Removed:

- `nextcloud_nextcloud`, `nextcloud_db` — never initialised, no `config.php`
- `adguard_data` — superseded by `adguard_adguard_data`
- systemd journal (vacuumed to ~200 MB), apt cache

Ended at **16 GB free**.

Deliberately kept:

- `plex_server_plex-server-data` (3.1 GB) — populated movie library
- `jellyfin_jellyfin-config` (916 MB) — deleted deliberately, service no longer used
- `adguard_adguard_data` (1.8 GB) — live

`docker image prune -a` was skipped: zero dangling images, and all images are in
use.

---

## Troubleshooting

### Library scans as empty

Check the mount is real, not an empty directory:

```bash
ls /home/rsukumar/books | head
docker compose -f ~/docker_compose/bookorbit/docker-compose.yml exec app ls /books | head
```

If the host path is empty, the sync has not run — check
`journalctl --user -u bookorbit-sync.service`.

### Permission errors

```bash
ls -ldn /home/rsukumar/books     # must be readable by uid 1000
id rsukumar                      # PUID/PGID in .env must match
```

### SSH hostname resolution fails

`raspberrypi.local` is unreliable here (mDNS vs AdGuard). The Pi is at
**`192.168.4.125`**. Add a hosts entry if this keeps biting.

### Token expires anyway

`rclone config reconnect GDrive:` then re-run `$BOOKORBIT/scripts/bookorbit-auth.sh`. If the
token dies quickly, the config has regained a `client_id` — remove those lines.

---

## Operations

```bash
cd ~/docker_compose/bookorbit
docker compose ps
docker compose logs -f app
docker compose up -d          # start
docker compose pull && docker compose up -d    # update
```

Health endpoint: `curl -s http://localhost:3000/api/v1/health`

Initial setup needs `SETUP_BOOTSTRAP_TOKEN` from `.env`.

---

## Repo

Branch `bookorbit-gdrive` carries the `.env` split and the writable-mount change
(commit `816c34e`). It was not pushed — the repo is public, so check before
sharing.

`.env` was tracked before that commit. The ignore rule already matched the nested
path; the file simply had to be untracked, since `.gitignore` has no effect on
tracked files.