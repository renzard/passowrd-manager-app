"""
favicon.py
----------
Optional site-icon fetcher (like Bitwarden's website icons).

Privacy model:
  * OFF by default. Only runs when the user enables "Site icons" in Settings.
  * Each icon is requested straight from the entry's own website
    (https only), never from a third-party icon service.
  * Icons are cached on disk, so every site is contacted at most once
    (failures are remembered for a week).
  * Private / local addresses (192.168.x.x, localhost, ...) are never
    contacted, so a vault imported from elsewhere cannot make the app
    probe your home network.
"""

import os
import re
import socket
import time
import ipaddress
import urllib.request
import urllib.error
import urllib.parse
from html.parser import HTMLParser

MAX_HTML = 150 * 1024
MAX_ICON = 256 * 1024
TIMEOUT = 5
RETRY_AFTER = 7 * 24 * 3600
USER_AGENT = ("Mozilla/5.0 (X11; Ubuntu; Linux aarch64) "
              "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36")

_HOST_RE = re.compile(r"^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$")


def host_from_url(url):
    """'https://www.GitHub.com/login' -> 'github.com'. '' if unusable."""
    url = (url or "").strip()
    if not url:
        return ""
    if "://" not in url:
        url = "https://" + url
    try:
        host = (urllib.parse.urlparse(url).hostname or "").lower().rstrip(".")
    except ValueError:
        return ""
    if host.startswith("www."):
        host = host[4:]
    if "." not in host or not _HOST_RE.match(host) or len(host) > 253:
        return ""
    try:                       # bare IP addresses never get an icon
        ipaddress.ip_address(host)
        return ""
    except ValueError:
        pass
    return host


def _is_public_host(host):
    try:
        infos = socket.getaddrinfo(host, 443, proto=socket.IPPROTO_TCP)
    except OSError:
        return False
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        if (ip.is_private or ip.is_loopback or ip.is_link_local
                or ip.is_multicast or ip.is_reserved or ip.is_unspecified):
            return False
    return bool(infos)


def _allowed_url(url):
    p = urllib.parse.urlparse(url)
    return p.scheme == "https" and bool(p.hostname) and _is_public_host(p.hostname)


class _SafeRedirect(urllib.request.HTTPRedirectHandler):
    """Follow redirects only to public https URLs."""
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not _allowed_url(newurl):
            raise urllib.error.URLError("redirect blocked")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


_opener = urllib.request.build_opener(_SafeRedirect)


def _get(url, limit):
    if not _allowed_url(url):
        return None
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with _opener.open(req, timeout=TIMEOUT) as r:
            return r.read(limit + 1)[:limit] if r.status == 200 else None
    except Exception:
        return None


def _image_ext(data):
    """Only formats Qt can show without extra plugins. SVG is refused on
    purpose (it can carry scripts and needs the svg plugin)."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if data[:4] == b"\x00\x00\x01\x00":
        return "ico"
    if data[:3] == b"\xff\xd8\xff":
        return "jpg"
    if data[:6] in (b"GIF87a", b"GIF89a"):
        return "gif"
    return None


class _LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.icons = []          # (priority, href)

    def handle_starttag(self, tag, attrs):
        if tag != "link":
            return
        a = dict(attrs)
        rel = (a.get("rel") or "").lower().split()
        href = a.get("href")
        if not href or "icon" not in " ".join(rel):
            return
        prio = 0 if "apple-touch-icon" in rel else 1
        self.icons.append((prio, href))


def _candidates(host):
    base = "https://%s/" % host
    urls = []
    html = _get(base, MAX_HTML)
    if html:
        parser = _LinkParser()
        try:
            parser.feed(html.decode("utf-8", "ignore"))
        except Exception:
            pass
        for _, href in sorted(parser.icons, key=lambda x: x[0]):
            full = urllib.parse.urljoin(base, href)
            if full not in urls:
                urls.append(full)
    urls.append(base + "favicon.ico")
    return urls[:4]


# ---- cache -----------------------------------------------------------------

def cached_path(cache_dir, host):
    """Path of the cached icon for `host`, or '' if there is none."""
    if not host:
        return ""
    for ext in ("png", "ico", "jpg", "gif"):
        p = os.path.join(cache_dir, "%s.%s" % (host, ext))
        if os.path.isfile(p):
            return p
    return ""


def needs_fetch(cache_dir, host):
    if not host or cached_path(cache_dir, host):
        return False
    miss = os.path.join(cache_dir, host + ".none")
    try:
        return time.time() - os.path.getmtime(miss) > RETRY_AFTER
    except OSError:
        return True


def fetch(cache_dir, host):
    """Download the icon of `host` into the cache. True on success."""
    for url in _candidates(host):
        data = _get(url, MAX_ICON)
        ext = _image_ext(data) if data else None
        if ext:
            path = os.path.join(cache_dir, "%s.%s" % (host, ext))
            tmp = path + ".part"
            with open(tmp, "wb") as f:
                f.write(data)
            os.replace(tmp, path)
            return True
    try:                         # remember the failure
        with open(os.path.join(cache_dir, host + ".none"), "w") as f:
            f.write("")
    except OSError:
        pass
    return False
