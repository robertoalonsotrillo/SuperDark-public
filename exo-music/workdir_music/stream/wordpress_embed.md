# Putting the player on robertoalonsotrillo.com

The site is **self-hosted WordPress** (WPML, WooCommerce, Contact Form 7,
Jetpack). So the player goes in as a page, not a file upload, and nothing about
the site's hosting or DNS changes.

**One thing not to lose sight of: WooCommerce means this domain takes payments.**
The whole plan touches it exactly once — a single A record for a subdomain. No
nameserver change, no plugin, no theme edit, no changes to any existing record.

---

## Step 1 — the DNS record (do this once, when the server exists)

At whoever runs DNS for the domain (registrar or host control panel), add:

```
type   A
name   stream                       (i.e. stream.robertoalonsotrillo.com)
value  <the server's IP>
TTL    default
```

That is the entire DNS change. It creates a new name; it modifies nothing
existing. Your site, your mail and WooCommerce are untouched, because none of
them resolve through `stream.`.

---

## Step 2 — the page

WordPress admin → **Pages → Add New**. Title it whatever you like. Add a
**Custom HTML** block (the `+` button, search "custom html") and paste the
contents of `player.html` — everything from `<style>` onward, dropping the
`<!DOCTYPE html>`, `<html>`, `<head>` and `<body>` wrappers, since WordPress
supplies those.

Set the two constants near the bottom of the script first:

```js
const STREAM = "https://stream.robertoalonsotrillo.com/superdark.mp3";
const STATUS = "https://stream.robertoalonsotrillo.com/status-json.xsl";
```

**`https`, not `http`.** Your site is served over HTTPS, and browsers silently
refuse to play an HTTP audio stream inside an HTTPS page. It fails with no error
the listener can see, which is the worst way for it to fail.

### If the JavaScript gets stripped

Some security plugins remove `<script>` from post content. If the player shows
but does nothing, use this instead — it needs no JavaScript at all and cannot be
stripped:

```html
<div style="max-width:620px;font:16px/1.5 'Helvetica Neue',Helvetica,Arial,sans-serif">
  <p style="margin:0 0 2px;font-weight:700">superdark</p>
  <p style="margin:0 0 24px;color:#404040">a music factory, running continuously</p>

  <audio controls preload="none" style="width:100%">
    <source src="https://stream.robertoalonsotrillo.com/superdark.mp3" type="audio/mpeg">
    Your browser cannot play this stream.
  </audio>

  <p style="margin:20px 0 0;color:#404040">
    This is not a recording. It is an instrument that has been running on its
    own, selecting its own material and writing its own behaviours. What you
    hear is whatever state it is in at the moment you arrive, including the
    states where it is doing badly. It does not begin or end.
  </p>
</div>
```

You lose the uptime and listener count and the honest "stream unreachable"
message; you keep a working player. Worth trying the full version first.

### WPML

If the site is multilingual you will want the page in each active language, or
excluded from translation. WPML treats it like any other page; nothing about the
player is language-specific except the prose.

---

## Step 3 — check it from outside

Once it is live, test from a phone on mobile data rather than from your own
network. That catches two things a desktop test on your own wifi will not: a
certificate that only validates internally, and a mixed-content block that some
browsers report only in the console.

---

## What is deliberately not here

No plugin. No theme change. No `functions.php` edit. No FTP. No caching rules.
A streaming page that needed any of those on a live WooCommerce site would be a
bad trade for what it delivers.
