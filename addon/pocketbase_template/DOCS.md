# PocketBase Template

A [PocketBase](https://pocketbase.io) backend: REST API, realtime subscriptions and an admin UI
on one port, with the project's collections and access rules already set up.

## Install

1. **Settings → Add-ons → Add-on store**, then **⋮ → Repositories**.
2. Add the URL of the GitHub repository that contains this add-on and close the dialog.
3. Open **PocketBase Template** in the store and click **Install**. Home Assistant builds the
   image on the device; this takes a minute or two.
4. Optional: change the login emails on the **Configuration** tab (below). The defaults work.
5. Click **Start**, then open the **Log** tab. The first start prints, once:

   ```text
   ==================================================================
    PocketBase Template ready (credentials shown ONCE)
    admin UI    : http://homeassistant.local:8090/_/
    admin login : admin@example.invalid / <generated>
    app login   : app@example.invalid / <generated>
    API base    : http://homeassistant.local:8090/api/
    saved to    : /data/initial-credentials.txt (mode 600)
   ==================================================================
   ```

6. **The sidebar panel** (or **Open web UI**) opens the PocketBase dashboard and, with
   `auto_login` on, signs you in as the admin: no second password. Change the passwords in the
   dashboard if you like; later starts never reset them. Through the port (`:8090/_/`) you sign in
   with the admin login.
7. Point your app or client at the API base with the app login.

Passwords are always generated randomly on the first start; there is no password option. Later
starts only say where the credentials file is. It lives in the add-on's private `/data`
(included in Home Assistant backups) and is not reachable from the network. If the log has
scrolled away before you saved the passwords, uninstall and reinstall the add-on: that starts
over with new credentials and an **empty database**.

## Options

| option | default | meaning |
|---|---|---|
| `admin_email` | `admin@example.invalid` | PocketBase superuser (admin UI) |
| `app_email` | `app@example.invalid` | the app login (a `users` record) |
| `public_url` | empty | URL shown in the banner; default `http://homeassistant.local:<port>` |
| `auto_login` | `true` | signed in to Home Assistant = signed in to the dashboard, from the sidebar panel only |
| `ha_user_ids` | empty | optional comma-separated Home Assistant user ids allowed to auto-login (empty: any) |

Changing an email later creates that login with a new random password, printed once in the log.

More logins: admin UI → **Collections → users → New record**, with email, password and
**Verified**. Public sign-up is switched off.

## Network and security

- Port `8090/tcp` carries the REST API, the realtime stream and the admin UI. Change the host
  port in the **Network** section of the Configuration tab.
- **Sidebar and auto-login:** the panel goes through Home Assistant ingress. Auto-login is
  granted only when the connection comes from Supervisor's ingress proxy (172.30.32.2) with a
  Home Assistant user id; the same headers sent to the published port are refused. Turn it off
  with `auto_login: false`, or limit it with `ha_user_ids`.
- Apps and devices use the published port directly (ingress only admits a signed-in Home
  Assistant browser session).
- The port speaks plain HTTP. That is fine on a home network. For use from outside, do not
  forward the port: put it behind HTTPS (a reverse proxy with a certificate, or a tunnel/VPN)
  so logins and data are encrypted.

## Without Home Assistant

The same image runs standalone with `docker compose up --build` from the repository root
(options then come from environment variables, and the log says `Mode: standalone`). See the
repository README.

## Data

`/data/pb_data` holds the PocketBase database. `/data/initial-credentials.txt` holds the
generated passwords (mode 600).
