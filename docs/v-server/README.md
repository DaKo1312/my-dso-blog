# V-Server

This page documents how I set up the virtual server for the DevSecOps V-Server project:
key based SSH access, a disabled password login, NGINX serving a custom entry point
instead of the packaged welcome screen, and a git configuration that can talk to GitHub
from the server itself.

The machine runs Ubuntu 24.04.5 LTS and answers on `2.31.92.203`. Beyond the checklist,
it also serves this documentation site from a container, at the root of the host; the
static page describing the machine is served from disk below
[`/server/`](http://2.31.92.203/server/).

## TOC

- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Usage](#usage)
- [Description](#description)
  - [Generating the key pair](#generating-the-key-pair)
  - [Deploying the public key](#deploying-the-public-key)
  - [Disabling the password login](#disabling-the-password-login)
  - [NGINX with a custom entry point](#nginx-with-a-custom-entry-point)
  - [Git configuration](#git-configuration)
  - [GitHub access from the server](#github-access-from-the-server)
  - [Serving this site from the server](#serving-this-site-from-the-server)
- [Verification](#verification)
- [Security notes](#security-notes)
- [Checklist](#checklist)
- [Further References](#further-references)

import GithubLinkAdmonition from '@site/src/components/GithubLinkAdmonition';

<GithubLinkAdmonition
    link="https://github.com/DaKo1312/my-dso-blog"
    title="Github Tip"
    type="tip"
>
Checkout this repository to see the configuration files described below
</GithubLinkAdmonition>

The two files that were deployed to the server are kept next to this page, in
`docs/v-server/files/`: `index.html` is the page NGINX serves, `v-server.conf` is the
site configuration that points at it.

## Prerequisites

- A virtual server running a current Ubuntu, reachable over the network, and an account
  on it that is a member of the `sudo` group. The machine documented here runs
  Ubuntu 24.04.5 LTS.
- Its IP address and the user name of that account. A password is needed exactly once,
  to deploy the first public key; everything after that runs over the key.
- An SSH client on the workstation. `ssh`, `ssh-keygen`, `ssh-copy-id` and `scp` ship
  with Linux and macOS, and on Windows with Git for Windows.
- A GitHub account, if the server is to interact with repositories.

## Quickstart

1. Generate a key pair **on your own machine**, never on the server.
2. Copy the public key to the server and confirm that a key based login works.
3. Only then switch password authentication off and restart the SSH daemon.
4. Install NGINX, put your own page below `/var/www`, and enable a site configuration
   that points at it.
5. Set `user.name` and `user.email` in git on the server and give the server its own
   key pair for GitHub.

## Usage

Connect to the server. The entry in `~/.ssh/config` shown below supplies the user and
the key, so the address is enough:

```bash
ssh 2.31.92.203
```

What lives where on the machine:

| Path | Contents |
| --- | --- |
| `/var/www/v-server/index.html` | the static page, served at `/server/` |
| `/etc/nginx/sites-available/v-server` | the site configuration, symlinked into `sites-enabled` |
| `/etc/ssh/sshd_config.d/99-hardening.conf` | the drop-in that switches password logins off |
| `/var/log/nginx/v-server.*.log` | access and error log of this site |
| `/opt/docusaurus/repo` | the clone this site is built from |

Changing the page means copying a new file over it and nothing else, as NGINX reads it
per request:

```bash
scp index.html 2.31.92.203:/tmp/
ssh 2.31.92.203 'sudo cp /tmp/index.html /var/www/v-server/index.html'
```

Changing the site configuration needs a test and a reload. `reload` replaces the worker
processes without dropping connections, which `restart` would:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

## Description

### Generating the key pair

The key pair belongs to the workstation, so it is created there. A key generated on the
server would have to travel to the client at some point, which defeats the purpose of
asymmetric authentication.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/vserver_da -C "v-server"
```

`ed25519` is the current default: short keys, fast verification, and no parameter choices
that can be made badly. The private key stays in `~/.ssh/vserver_da`, the public key in
`~/.ssh/vserver_da.pub`.

A matching entry in `~/.ssh/config` makes every later command shorter and pins the
identity, so the SSH client does not offer unrelated keys to the server:

```
Host 2.31.92.203
    HostName 2.31.92.203
    User daniel-korbmacher
    IdentityFile ~/.ssh/vserver_da
    IdentitiesOnly yes
```

### Deploying the public key

`ssh-copy-id` appends the public key to `~/.ssh/authorized_keys` on the server and fixes
the permissions on the way:

```bash
ssh-copy-id -i ~/.ssh/vserver_da.pub daniel-korbmacher@2.31.92.203
```

This is the one step that still needs the password, because it is the last moment at
which the server has no other way to recognise the client. If a shell on the server is
already open, the same result can be achieved by appending the public key by hand:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAA... v-server' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

The permissions matter: `sshd` ignores `authorized_keys` when the file or its directory
is writable by anyone but the owner.

### Disabling the password login

The login with the key has to be verified **before** passwords are switched off,
otherwise a mistake in the configuration locks the account out of the machine. The check
is one command, and it has to succeed without asking for anything:

```bash
ssh -o PasswordAuthentication=no daniel-korbmacher@2.31.92.203 'echo ok'
```

```
ok
```

`PasswordAuthentication=no` is what makes this a real test rather than a habit: it tells
the client not to fall back to a password prompt, so the command can only succeed through
the key. A password prompt instead of `ok` means the key is not in place, and the rest of
this section has to wait.

Ubuntu reads `/etc/ssh/sshd_config.d/*.conf` from an `Include` at the very top of
`sshd_config`, and `sshd` keeps the first value it sees for an option. A drop-in file
therefore overrides the defaults without editing the packaged configuration, which keeps
later package upgrades free of conflicts:

```
# /etc/ssh/sshd_config.d/99-hardening.conf
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
```

`KbdInteractiveAuthentication` is disabled as well. Left on, PAM can still offer an
interactive password dialogue, and the password login would only appear to be closed.

The syntax is checked before the daemon is restarted. `sshd -T` prints the configuration
as it will actually be applied, which is the more useful of the two checks:

```bash
sudo sshd -t
sudo sshd -T | grep -E "passwordauthentication|pubkeyauthentication"
sudo systemctl restart ssh
```

Restarting the daemon does not drop existing sessions, as each connection is served by
its own process.

### NGINX with a custom entry point

```bash
sudo apt-get update && sudo apt-get install -y nginx
```

The package ships a server block that serves the welcome page, enabled through
`/etc/nginx/sites-enabled/default`. Rather than editing that file, the project gets a
site configuration of its own:

```nginx
# /etc/nginx/sites-available/v-server
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /var/www/v-server;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    server_tokens off;

    access_log /var/log/nginx/v-server.access.log;
    error_log  /var/log/nginx/v-server.error.log;
}
```

`default_server` makes this block answer every request that matches no other
`server_name`, which is what happens when the site is called by IP address. The packaged
default site claims the same role, so it has to be disabled: two `default_server` blocks
on the same port are a configuration error and NGINX refuses to start.

`server_tokens off` removes the exact version number from error pages and from the
`Server` header. That is not a security measure in itself, but there is no reason to tell
every visitor which patch level is running.

```bash
sudo mkdir -p /var/www/v-server
sudo cp index.html /var/www/v-server/index.html
sudo ln -s /etc/nginx/sites-available/v-server /etc/nginx/sites-enabled/v-server
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

`nginx -t` validates the configuration before it is applied; `reload` then replaces the
worker processes without dropping connections. A separate file can be tested on its own
with `nginx -t -c path/to/config`.

### Git configuration

Most Ubuntu server images carry git already, but not all of them, so it is installed
before it is configured. `apt-get` leaves an existing installation untouched, which makes
the command safe to run either way:

```bash
sudo apt-get update && sudo apt-get install -y git
git --version
```

The identity on the server matches the one on the workstation and the one GitHub knows,
so commits made on the server are attributed to the same account:

```bash
git config --global user.name "DaKo1312"
git config --global user.email "korbmacher.d@outlook.de"
git config --global init.defaultBranch main
```

### GitHub access from the server

The server gets a key pair of its own instead of a copy of the workstation key. A key
that exists in one place only can be withdrawn in one place only, which is what makes a
lost machine a contained problem:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/github_vserver -C "v-server github"
```

The public key is registered under *Settings, SSH and GPG keys* on GitHub. An entry in
the server's `~/.ssh/config` points git at that key:

```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_vserver
    IdentitiesOnly yes
```

### Serving this site from the server

This part goes beyond the checklist. The documentation site itself also runs on the
machine, built into a container image and published at the root of the host. The static
page described above is served from disk below `/server/`.

The repository is cloned to `/opt/docusaurus/repo` over SSH, which is what the key from
the previous section is for. The image is built from the `Dockerfile` in the repository
root: a `node` stage runs `npm ci && npm run build`, and only the resulting `build`
directory is copied into an `nginx` image, so the published image carries no sources,
no toolchain and no dependencies.

```bash
docker build --build-arg BASE_URL=/ -t docusaurus-blog:latest .
docker run -d --name docusaurus-blog --restart unless-stopped \
  -p 127.0.0.1:3000:80 docusaurus-blog:latest
```

Two details carry the whole setup:

`BASE_URL` is needed at **build** time, not at run time, because Docusaurus writes
absolute paths into the generated HTML. The site answers at the root here, so `/` is
correct; served below a prefix it would have to be built for that prefix, or the browser
would ask for `/assets/...` and never find the stylesheets.

`-p 127.0.0.1:3000:80` binds the published port to the loopback interface. Written as
`-p 3000:80`, Docker would open port 3000 to the internet and add a rule to `iptables`
that a host firewall does not necessarily catch. The container is reachable through the
proxy and in no other way.

The proxy itself is part of the site configuration:

```nginx
location / {
    proxy_pass http://127.0.0.1:3000/;
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

location /server/ {
    alias /var/www/v-server/;
    index index.html;
    try_files $uri $uri/ =404;
}
```

Both blocks can coexist because NGINX picks the **longest matching prefix**, not the
first one written: a request for `/server/` is answered from disk and never reaches the
proxy, everything else goes to the container. `alias` rather than `root` is what maps
`/server/` onto a directory that is not named after the URL. A separate
`location = /server { return 301 /server/; }` catches the address without the trailing
slash, which `location /server/` does not match.

Publishing a new version means pulling, rebuilding and replacing the container:

```bash
cd /opt/docusaurus/repo && git pull
docker build --build-arg BASE_URL=/ -t docusaurus-blog:latest .
docker rm -f docusaurus-blog
docker run -d --name docusaurus-blog --restart unless-stopped \
  -p 127.0.0.1:3000:80 docusaurus-blog:latest
```

The site remains available while the new image builds, as the running container is only
replaced once the build has succeeded.

## Verification

The key based login works:

```bash
ssh 2.31.92.203 'echo ok'
```

The password login is refused. Public key authentication is switched off for this test,
so the client has nothing else to offer:

```bash
ssh -o PubkeyAuthentication=no daniel-korbmacher@2.31.92.203
```

```
daniel-korbmacher@2.31.92.203: Permission denied (publickey).
```

The list in the parentheses is the point: it names the methods the server still accepts.
As long as `password` is missing from it, the password login is closed.

The web server answers with the project page rather than the NGINX welcome screen:

```bash
curl -I http://2.31.92.203/
```

```
HTTP/1.1 200 OK
Server: nginx
```

The connection from the server to GitHub is confirmed with `ssh -T git@github.com`.

The documentation site answers at the root, the static page below its prefix, and the
container's own port stays closed to the outside:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://2.31.92.203/
curl -s -o /dev/null -w "%{http_code}\n" http://2.31.92.203/server/
curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://2.31.92.203:3000/
```

```
200
200
000
```

## Security notes

- No private key, no password and no host specific secret is part of this repository.
  Only public keys, configuration files and commands are documented here.
- The workstation key was created without a passphrase so that the setup could be
  automated. A key that protects something worth protecting should carry one and be
  unlocked through `ssh-agent` once per session.
- The firewall (`ufw`) is inactive on this machine. Only SSH and NGINX listen on a public
  port — the blog container is bound to the loopback interface — so nothing is exposed
  that should not be, but a rule set limited to ports 22 and 80 would be the obvious next
  step. It would also catch the case this setup currently avoids by hand: Docker writes
  its own `iptables` rules and can publish a port past a firewall that only knows about
  `ufw`.

## Checklist

The project checklist is part of this repository:
[Git + V-Server Checkliste](./checklist-v-server.pdf).

## Further References

- [OpenSSH manual pages](https://www.openssh.com/manual.html)
- [Ubuntu Server documentation: OpenSSH](https://documentation.ubuntu.com/server/how-to/security/openssh-server/)
- [NGINX: Serving static content](https://docs.nginx.com/nginx/admin-guide/web-server/serving-static-content/)
- [GitHub Docs: Connecting to GitHub with SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
