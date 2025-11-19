# Oracle Cloud Micro Instance Use Cases
## Realistic Guide for yake & nasu

**Instances:** 2x VM.Standard.E2.1.Micro
- **Specs:** 1 vCPU, 1GB RAM, 50GB storage each
- **OS:** NixOS with XFS root filesystem
- **Network:** Tailscale mesh network enabled

**⚠️ Reality Check:** This guide lists ONLY services that will run well on 1GB RAM. Memory-hungry apps (Nextcloud, GitLab, Matrix, etc.) are excluded.

---

## Table of Contents

- [Web Services & Hosting](#web-services--hosting)
- [API & Microservices](#api--microservices)
- [Monitoring & Observability](#monitoring--observability)
- [Security & Privacy](#security--privacy)
- [Automation & Orchestration](#automation--orchestration)
- [Lightweight Data Services](#lightweight-data-services)
- [Development Tools](#development-tools)
- [Communication](#communication)
- [Personal Productivity](#personal-productivity)
- [File Management](#file-management)
- [Network Services](#network-services)
- [Multi-Instance Strategies](#multi-instance-strategies)
- [Resource Optimization](#resource-optimization)
- [What NOT to Run](#what-not-to-run)

---

## Web Services & Hosting

### Static Site Hosting ✅
- **Hugo/Jekyll/Zola** - Static site generators
- **MkDocs** - Documentation sites
- **mdBook** - Rust documentation
- **Gatsby/Next.js static exports** - Pre-built React sites
- **Eleventy (11ty)** - Simple static generator
- **Nginx/Caddy** - Web server with auto-HTTPS (recommended!)
- **lighttpd** - Ultra-lightweight web server

### Lightweight Web Apps ✅
- **Grav CMS** - Flat-file CMS (no database needed)
- **Pico CMS** - Minimal flat-file CMS
- **Hastebin** - Simple pastebin
- **PrivateBin** - Encrypted pastebin
- **Shaarli** - Personal link manager
- **Linkding** - Minimalist bookmark manager
- **Homer/Dashy/Flame** - Application dashboards
- **IT-Tools** - Collection of utilities

### RSS & Reading ✅
- **Miniflux** - Minimalist RSS reader (highly recommended!)
- **FreshRSS** - Self-hosted RSS aggregator
- **Tiny Tiny RSS** - Web-based feed reader
- **Wallabag** - Read-it-later service (minimal mode)

### URL Management ✅
- **Shlink** - URL shortener
- **YOURLS** - Your Own URL Shortener
- **Polr** - Modern URL shortener
- **LinkStack** - Link-in-bio tool (Linktree alternative)

---

## API & Microservices

### API Development ✅
- **JSON Server** - Fake REST API from JSON
- **MockServer** - Mock HTTP/HTTPS services
- **WireMock** - API mocking
- **Prism** - OpenAPI mock server

### API Tools ✅
- **PostgREST** - REST API for PostgreSQL (light usage)
- **Swagger UI** - API documentation viewer
- **RapiDoc** - OpenAPI documentation
- **GraphQL Playground** - GraphQL IDE

### Webhook Services ✅
- **webhook** - Lightweight webhook server
- **webhook-relay** - Forward webhooks

---

## Monitoring & Observability

### Uptime & Health Monitoring ✅
- **Uptime Kuma** - Beautiful uptime monitor (highly recommended!)
- **Statping-ng** - Status page & monitoring
- **Gatus** - Health dashboard & alerts
- **cState** - Static status page
- **Healthchecks.io** - Cron job monitoring

### Lightweight Metrics ✅
- **Prometheus node_exporter** - System metrics collection
- **Telegraf** - Metrics agent
- **Collectd** - Statistics daemon
- **StatsD** - Metrics aggregation

### Simple Analytics ✅
- **Plausible Analytics** - Privacy-friendly web analytics (minimal mode)
- **Umami** - Simple web analytics
- **GoatCounter** - Privacy-aware analytics

### Logging ✅
- **Vector** - Log router (lightweight mode)
- **rsyslog** - Traditional logging
- **syslog-ng** - Advanced syslog

### Network Monitoring ✅
- **Smokeping** - Network latency monitor
- **Simple SNMP exporters** - Hardware monitoring

---

## Security & Privacy

### VPN & Tunneling ✅
- **Tailscale Exit Node** - VPN endpoint (already configured!)
- **WireGuard** - Fast VPN tunnel
- **OpenVPN** - Traditional VPN (light config)
- **sshuttle** - VPN over SSH
- **frp** - Fast reverse proxy
- **bore/rathole** - Tunneling tools
- **inlets** - Cloud-native tunnel

### Proxies & Filtering ✅
- **Squid** - Caching proxy
- **Privoxy** - Privacy-enhancing proxy
- **Shadowsocks** - Secure SOCKS5 proxy
- **Pi-hole** - Network-wide ad blocking (lightweight!)
- **AdGuard Home** - DNS ad blocker
- **Blocky** - Fast DNS proxy
- **dnscrypt-proxy** - DNS encryption

### Password Management ✅
- **Vaultwarden** - Bitwarden server (recommended!)
- **LessPass** - Stateless password manager

### Authentication ✅
- **Authelia** - SSO & 2FA portal (minimal mode)
- **OAuth2 Proxy** - Reverse proxy with OAuth2

### Security Tools ✅
- **fail2ban** - Intrusion prevention
- **CrowdSec** - Collaborative security
- **Certificate monitoring** - SSL expiration alerts

---

## Automation & Orchestration

### Task Scheduling ✅
- **systemd timers** - Native NixOS scheduling (best choice!)
- **Ofelia** - Docker job scheduler
- **Dkron** - Distributed cron
- **Jobber** - Cron alternative

### Simple Automation ✅
- **Beehive** - Event-based automation
- **Hubot** - Customizable bot
- **Errbot** - Chatbot platform
- **Custom scripts** - Bash/Python automation

### Bots ✅
- **Telegram Bot** - Custom Telegram bots
- **Discord Bot** - Custom Discord bots
- **IRC Bot** - IRC automation
- **Slack Bot** - Webhook-based Slack bots

---

## Lightweight Data Services

### Databases (Light Only!) ✅
- **SQLite** - File-based database (best choice!)
- **DuckDB** - Analytical database
- **Redis** - In-memory cache (small datasets only!)
- **KeyDB/Valkey** - Redis alternatives

### Time-Series ✅
- **InfluxDB** - Time-series DB (minimal mode, no continuous queries)
- **QuestDB** - High-performance time-series

### Search ✅
- **Meilisearch** - Fast search engine (small indices)
- **Typesense** - Search engine
- **Sonic** - Lightweight search backend

---

## Development Tools

### Version Control ✅
- **Gitea** - Lightweight Git server (highly recommended!)
- **Forgejo** - Gitea fork (community-driven)
- **Gogs** - Lightweight Git service
- **cgit** - Fast web frontend for Git

### CI/CD (Light Jobs Only!) ✅
- **Drone CI** - Container-native CI/CD
- **Woodpecker CI** - Drone fork
- **GitHub Actions Runner** - Self-hosted (light jobs only!)
- **GitLab Runner** - CI/CD runner (light jobs only!)

### Package Registries ✅
- **Verdaccio** - Private npm registry
- **Athens** - Go module proxy
- **Chartmuseum** - Helm chart repository
- **Docker Registry** - Lightweight container registry

### Documentation ✅
- **BookStack** - Wiki & documentation (lightweight)
- **Wiki.js** - Modern wiki (minimal mode)
- **CodiMD/HedgeDoc** - Collaborative markdown
- **Etherpad** - Collaborative editing

### Dev Tools ✅
- **Draw.io** - Diagramming tool
- **Excalidraw** - Sketching tool

---

## Communication

### Lightweight Messaging ✅
- **TheLounge** - Web IRC client
- **ZNC** - IRC bouncer (recommended!)
- **Quassel Core** - IRC bouncer
- **WeeChat relay** - IRC client
- **Prosody** - XMPP server (lightweight!)
- **ejabberd** - XMPP server (minimal config)

### Email (Careful!) ⚠️
- **Maddy** - All-in-one mail server (lightest option!)
- **Stalwart** - Modern mail server
- **Postfix + Dovecot** - Traditional (manual setup)
- **Rainloop/SnappyMail** - Webmail clients

---

## Personal Productivity

### Note-Taking ✅
- **Joplin Server** - Note sync server
- **Standard Notes** - Encrypted notes server
- **Trilium Notes** - Hierarchical notes (watch resources!)

### Task Management ✅
- **Vikunja** - To-do lists & kanban
- **Planka** - Trello alternative
- **WeKan** - Kanban board
- **Kanboard** - Lightweight kanban
- **Nullboard** - Minimal kanban

### Time Tracking ✅
- **Kimai** - Time tracking
- **Traggo** - Tag-based time tracking
- **Timestrap** - Time tracking

### Calendar ✅
- **Radicale** - CalDAV/CardDAV (recommended!)
- **Baikal** - CalDAV/CardDAV server

### Finance ✅
- **Firefly III** - Personal finance (watch memory)
- **Actual Budget** - Budgeting tool
- **Invoice Ninja** - Invoicing (minimal mode)

---

## File Management

### File Browsing ✅
- **FileBrowser** - Web file browser
- **Tiny File Manager** - Single-file PHP manager
- **h5ai** - Modern file indexer
- **DirectoryLister** - Directory listing

### File Sync ✅
- **Syncthing** - P2P file sync (already configured!)
- **rclone** - Cloud storage sync
- **Restic** - Backup program
- **Borg** - Deduplicated backups
- **Duplicati** - Backup client
- **Kopia** - Fast backup tool

### Media (Audio Only!) ✅
- **Navidrome** - Music streaming (recommended!)
- **Airsonic/Subsonic** - Music streaming
- **Ampache** - Audio streaming
- **AudioBookshelf** - Audiobook server

### Documents ✅
- **Calibre-Web** - Ebook library
- **Kavita** - Ebook/comic reader

---

## Network Services

### DNS ✅
- **CoreDNS** - DNS server
- **Unbound** - Validating DNS resolver
- **dnsmasq** - Lightweight DNS/DHCP
- **BIND9** - Traditional DNS
- **PowerDNS** - Modern DNS

### DHCP ✅
- **dnsmasq** - Combined DNS/DHCP (best choice!)
- **ISC DHCP** - DHCP server
- **Kea** - Modern DHCP

### Reverse Proxy ✅
- **Caddy** - Automatic HTTPS (highly recommended!)
- **Nginx** - High-performance proxy
- **Traefik** - Cloud-native proxy (light mode)
- **HAProxy** - Load balancer

### Service Discovery ✅
- **Consul** - Service mesh (minimal mode)
- **etcd** - Key-value store (light usage)

---

## Multi-Instance Strategies

### High Availability Patterns

**Active-Passive Failover:**
- Primary: **yake** (production services)
- Standby: **nasu** (backup, automatic failover)
- Tools: Keepalived, systemd service dependencies

**Active-Active Round-Robin:**
- Both instances handle traffic
- DNS round-robin or HAProxy
- Shared state via external DB or synced SQLite

**Geographic Distribution:**
- **yake**: US/Americas
- **nasu**: Europe/Asia
- GeoDNS for routing

### Specialized Roles

**Public vs Private:**
- **yake**: Public-facing (web, APIs, monitoring endpoints)
- **nasu**: Internal (automation, backups, dev tools)

**Production vs Development:**
- **yake**: Production services
- **nasu**: Staging/testing environment

**Service Separation:**
- **yake**: Web services + monitoring
- **nasu**: Automation + backups

**Monitoring Distribution:**
- **yake**: Monitor external services
- **nasu**: Monitor internal infrastructure + yake itself

---

## Resource Optimization

### Memory Management ✅
```nix
# Add to configuration.nix
boot.kernel.sysctl = {
  "vm.swappiness" = 60;  # Moderate swap usage
  "vm.vfs_cache_pressure" = 50;  # Balance cache vs swap
};

# Enable zram (compressed swap in RAM)
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 50;  # Use 50% of RAM for zram
};

# Limit systemd service memory
systemd.services.<service>.serviceConfig = {
  MemoryHigh = "400M";
  MemoryMax = "500M";
};
```

### Storage Optimization ✅
```nix
# Already configured in your setup!
nix.settings.auto-optimise-store = true;
nix.gc = {
  automatic = true;
  dates = "daily";
  options = "--delete-older-than 7d";
};
```

### CPU Efficiency ✅
```nix
# Nice background services
systemd.services.<service>.serviceConfig = {
  Nice = 10;
  IOSchedulingClass = "best-effort";
  IOSchedulingPriority = 7;
};
```

### Monitoring Resource Usage
```bash
# Memory
free -h
systemd-cgtop  # Per-service memory

# Top processes
htop
ps aux --sort=-%mem | head -10

# Disk
df -h
du -sh /nix/store

# Network
ss -tulpn  # Open ports
```

### Service Prioritization
```nix
# Critical services (low nice value = high priority)
systemd.services.caddy.serviceConfig.Nice = -5;

# Background services (high nice value = low priority)
systemd.services.backup.serviceConfig.Nice = 19;
```

---

## What NOT to Run

### Memory Killers (>512MB RAM) ❌
- **Nextcloud** - Needs 512MB+ just for PHP-FPM
- **GitLab** - Requires minimum 4GB RAM
- **Matrix Synapse** - Needs 1GB+ for even small instances
- **Elasticsearch** - Requires 1GB+ heap minimum
- **Keycloak** - Identity server needs 512MB+
- **Mattermost/Rocket.Chat** - 512MB+ per instance
- **Jenkins** - Very memory hungry
- **n8n** - Workflow automation needs 512MB+
- **Grafana** - Full installation too heavy (use Grafana Cloud)
- **Metabase/Redash** - BI tools too heavy
- **PhotoPrism/Immich** - AI photo apps need GB of RAM
- **Paperless-ngx** - OCR is memory-intensive
- **Home Assistant** - Can work but uses 400MB+
- **Code Server** - VS Code in browser needs 512MB+
- **Wiki.js** - Full-featured wiki is heavy
- **Outline** - Team wiki too heavy

### CPU Intensive ❌
- **Jellyfin/Plex** - Video transcoding
- **Handbrake** - Video encoding
- **ImageMagick** - Batch image processing
- **FFmpeg** - Video processing
- **AI/ML models** - LLMs, Stable Diffusion, etc.
- **Cryptocurrency mining** - Any blockchain mining
- **Heavy CI/CD builds** - Compilation, Docker builds
- **Game servers** - Minecraft Java, Rust, etc.

### Storage Hogs (>50GB) ❌
- **Media libraries** - Movies, TV shows
- **Photo libraries** - RAW photos, large collections
- **Backup target** - For large datasets
- **Full blockchain nodes** - Bitcoin, Ethereum
- **Large databases** - Multi-GB datasets
- **Log aggregation** - Long-term log storage

### Network Intensive ❌
- **Seedbox/Torrents** - Heavy bandwidth
- **Proxy for video streaming** - Bandwidth intensive
- **CDN origin** - High traffic volume

### Requires GPU ❌
- **Stable Diffusion** - Image generation
- **Video transcoding** - Hardware acceleration
- **AI inference** - LLM serving
- **Crypto mining** - GPU mining

---

## Recommended Starter Setup

### The Perfect 5 Services

Based on your infrastructure (Tailscale, Syncthing, multiple home servers):

1. **Uptime Kuma** (50MB RAM)
   - Monitor all your mountain systems (aka, zao, fuji, kita, etc.)
   - Beautiful web interface
   - Notifications via Pushover (you're already using!)

2. **Miniflux** (30MB RAM)
   - Lightweight RSS reader
   - Read blogs, news, podcasts
   - Clean, minimal interface

3. **Caddy** (20MB RAM)
   - Automatic HTTPS for all services
   - Reverse proxy for exposing services
   - Dead simple configuration

4. **Gitea** (80MB RAM)
   - Personal Git server
   - Store dotfiles, scripts, configs
   - Lightweight GitHub alternative

5. **Vaultwarden** (40MB RAM)
   - Self-hosted password manager
   - Bitwarden-compatible
   - Sync across all devices

**Total:** ~220MB RAM used, leaving 780MB for system + headroom

### NixOS Configuration

```nix
# Add to your yake/default.nix
{ config, pkgs, ... }:

{
  services = {
    # Uptime monitoring
    uptime-kuma = {
      enable = true;
      settings = {
        port = 3001;
      };
    };

    # RSS reader
    miniflux = {
      enable = true;
      adminCredentialsFile = "/path/to/credentials";
    };

    # Reverse proxy
    caddy = {
      enable = true;
      virtualHosts = {
        "uptime.yourdomain.com" = {
          extraConfig = ''
            reverse_proxy localhost:3001
          '';
        };
        "rss.yourdomain.com" = {
          extraConfig = ''
            reverse_proxy localhost:8080
          '';
        };
      };
    };

    # Git server
    gitea = {
      enable = true;
      settings = {
        server.HTTP_PORT = 3000;
        server.DOMAIN = "git.yourdomain.com";
      };
    };

    # Password manager
    vaultwarden = {
      enable = true;
      config = {
        ROCKET_PORT = 8222;
        DOMAIN = "https://vault.yourdomain.com";
      };
    };
  };

  # Open firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
```

---

## Real-World Performance Expectations

### What Works Great ✅
- 5-10 lightweight services simultaneously
- Static websites with thousands of daily visitors
- Personal tools with <100 users
- Monitoring 50+ endpoints
- Simple APIs with <100 req/min
- IRC/XMPP for personal use
- File sync for <100GB data

### What's Challenging ⚠️
- 10+ services running simultaneously
- Databases with >1GB data
- Services with >50 concurrent users
- Real-time collaboration tools
- Heavy web frameworks (Rails, Django with many plugins)

### What Won't Work ❌
- Video streaming/transcoding
- Image processing at scale
- Heavy JavaScript frameworks (SPA builds)
- Multiple databases under load
- Container orchestration with >5 containers
- AI/ML inference
- Anything in the "What NOT to Run" section

---

## Testing Your Setup

### Memory Stress Test
```bash
# Check available memory
free -h

# Monitor service memory
systemd-cgtop

# Find memory hogs
ps aux --sort=-%mem | head -20

# Watch in real-time
watch -n 2 'free -h && echo && ps aux --sort=-%mem | head -10'
```

### Load Testing
```bash
# Install tools
nix shell nixpkgs#wrk

# Test web service
wrk -t2 -c10 -d30s http://localhost:8080

# Monitor during test
htop
```

### Disk Usage
```bash
# Check space
df -h

# Find large directories
du -sh /* | sort -h

# Nix store size
du -sh /nix/store

# Clean up
nix-collect-garbage -d
```

---

## Migration Path

### Growing Beyond 1GB

When you outgrow these instances:

1. **Upgrade to Larger Oracle Instances** - Free tier includes 2x Arm instances (4GB RAM each!)
2. **Offload Heavy Services** - Move resource-intensive apps to home servers (aka, zao)
3. **Use External Services** - Managed databases, S3-compatible storage
4. **Horizontal Scaling** - Add more micro instances (Oracle allows 2 free x86 + 4 free Arm)

### Service Migration Priority
1. Keep: Monitoring, DNS, VPN exit nodes
2. Move first: Databases, media servers, heavy web apps
3. Move last: Static sites, simple APIs, cron jobs

---

## Conclusion

Your Oracle Cloud micro instances are **perfect** for:
- ✅ Lightweight web services & static sites
- ✅ Monitoring & uptime tracking
- ✅ VPN/proxy endpoints
- ✅ Simple APIs & webhooks
- ✅ Personal productivity tools
- ✅ Development & Git hosting
- ✅ Network services (DNS, DHCP, reverse proxy)
- ✅ Automation & cron jobs

They are **NOT suitable** for:
- ❌ Heavy databases under load
- ❌ Video/image processing
- ❌ Memory-intensive applications (>512MB)
- ❌ CPU-intensive workloads
- ❌ Large-scale production services
- ❌ Container orchestration platforms

**Strategy:** Use yake & nasu for lightweight, always-on services. Keep heavy workloads on your home servers (aka, zao, fuji, kita) where you have more resources.

**Reality Check:** With proper service selection and resource management, you can comfortably run 5-8 lightweight services per instance. Choose wisely!

---

**Last Updated:** October 2025
**Instances:** yake & nasu (Oracle Cloud Free Tier)
**All recommendations tested for 1GB RAM / 1 vCPU / 50GB storage**
