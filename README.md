# TinyServe

[![Perl](https://img.shields.io/badge/Perl-5.10%2B-39457E?style=flat&logo=perl)](https://www.perl.org/)
[![License](https://img.shields.io/badge/License-MIT-00A98F?style=flat)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-FF6B6B?style=flat)](tinyserve.pl)

> Lightning-fast HTTP development server in pure Perl. No dependencies, no bloat, just serve.

## Why TinyServe?

Sometimes you just need to spin up a quick server. No frameworks, no complexity, no waiting for npm install. Just pure Perl doing what it does best: getting out of your way and getting stuff done.

**Built for developers who value simplicity over ceremony.**

## Quick Start
```bash
# Basic usage - serve current directory on port 8080
perl tinyserve.pl

# Custom port and directory
perl tinyserve.pl --port 3000 --root ./dist

# Verbose mode to see everything
perl tinyserve.pl --verbose
```

That's it. Your server is running.

## Features

**Static File Serving** • Automatic MIME type detection for 20+ formats  
**Custom Routes** • Define API endpoints with GET, POST, PUT, DELETE  
**JSON Native** • Built-in JSON parsing and response handling  
**Concurrent Connections** • Handle 50+ simultaneous connections  
**Request Logging** • Detailed timing and request information  
**Hot Reloadable** • Edit routes without restart  
**Zero Config** • Sensible defaults, works out of the box  
**Middleware Support** • Chain request/response processors

## Installation

No installation needed. Just grab the script:
```bash
curl -O https://raw.githubusercontent.com/yourrepo/tinyserve/main/tinyserve.pl
chmod +x tinyserve.pl
./tinyserve.pl
```

**Requirements:** Perl 5.10+ (already on most systems)

**Optional modules for full features:**
```bash
cpanm JSON::PP URI::Escape Time::HiRes
```

## Command Line Options
```bash
perl tinyserve.pl [OPTIONS]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--port <PORT>` | Port to listen on | 8080 |
| `--host <HOST>` | Host to bind to | 0.0.0.0 |
| `--root <PATH>` | Document root directory | ./public |
| `--verbose` | Enable verbose logging | Off |
| `--max-connections <N>` | Max concurrent connections | 50 |
| `--timeout <SEC>` | Connection timeout | 30 |
| `--help` | Show help message | - |

## Built-in API Endpoints

TinyServe comes with example endpoints to get you started:

### GET /api/status

Server health check and info.
```bash
curl http://localhost:8080/api/status
```
```json
{
  "status": "ok",
  "version": "1.0.0",
  "uptime": 1234567890
}
```

### POST /api/echo

Echo back request data - perfect for testing.
```bash
curl -X POST http://localhost:8080/api/echo \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```
```json
{
  "method": "POST",
  "path": "/api/echo",
  "headers": {...},
  "body": "{\"test\": \"data\"}",
  "json": {"test": "data"},
  "params": {}
}
```

## Custom Routes

Add your own API endpoints by editing the script:
```perl
# Simple JSON API
register_route('GET', '/api/users', sub {
    my ($req, $res) = @_;
    $res->{status} = 200;
    $res->{headers}{'Content-Type'} = 'application/json';
    $res->{body} = encode_json({
        users => [
            { id => 1, name => 'Alice' },
            { id => 2, name => 'Bob' }
        ]
    });
});

# Handle POST with JSON body
register_route('POST', '/api/users', sub {
    my ($req, $res) = @_;
    my $data = $req->{json};  # Automatically parsed
    
    $res->{status} = 201;
    $res->{headers}{'Content-Type'} = 'application/json';
    $res->{body} = encode_json({
        id => 3,
        name => $data->{name}
    });
});

# Access query parameters
register_route('GET', '/api/search', sub {
    my ($req, $res) = @_;
    my $query = $req->{params}{q};  # From ?q=search
    
    $res->{status} = 200;
    $res->{headers}{'Content-Type'} = 'application/json';
    $res->{body} = encode_json({
        query => $query,
        results => []
    });
});
```

## Middleware

Add cross-cutting concerns with middleware:
```perl
# CORS middleware
add_middleware(sub {
    my ($req, $res) = @_;
    $res->{headers}{'Access-Control-Allow-Origin'} = '*';
    $res->{headers}{'Access-Control-Allow-Methods'} = 'GET, POST, PUT, DELETE';
    return 1;  # Continue processing
});

# Authentication middleware
add_middleware(sub {
    my ($req, $res) = @_;
    
    if ($req->{path} =~ m{^/api/admin}) {
        my $auth = $req->{headers}{authorization} || '';
        
        unless ($auth eq 'Bearer secret-token') {
            $res->{status} = 401;
            $res->{headers}{'Content-Type'} = 'application/json';
            $res->{body} = encode_json({ error => 'Unauthorized' });
            return 0;  # Stop processing
        }
    }
    
    return 1;  # Continue
});

# Logging middleware
add_middleware(sub {
    my ($req, $res) = @_;
    log_message("DEBUG", "Processing: $req->{method} $req->{path}");
    return 1;
});
```

## Request Object

Every route handler receives a request object:
```perl
{
    method => 'POST',              # HTTP method
    path => '/api/users',          # URL path
    uri => '/api/users?page=1',    # Full URI
    query_string => 'page=1',      # Raw query string
    headers => {                   # Request headers (lowercase keys)
        'content-type' => 'application/json',
        'user-agent' => 'curl/7.68.0'
    },
    body => '{"name":"Alice"}',    # Raw request body
    json => { name => 'Alice' },   # Parsed JSON (if Content-Type: application/json)
    params => { page => 1 }        # Query params + form data
}
```

## Response Object

Modify the response object to send data:
```perl
{
    status => 200,                 # HTTP status code
    headers => {                   # Response headers
        'Content-Type' => 'application/json',
        'X-Custom-Header' => 'value'
    },
    body => '{"result":"success"}' # Response body
}
```

## Supported MIME Types

TinyServe automatically detects and serves these file types:

**Web:** html, htm, css, js, json, xml, txt  
**Images:** png, jpg, jpeg, gif, svg, ico  
**Fonts:** woff, woff2, ttf  
**Documents:** pdf, zip  
**Video:** mp4, webm

Unknown types default to `application/octet-stream`.

## Real-World Examples

### Frontend Development
```bash
# Serve your React/Vue/Angular build
perl tinyserve.pl --root ./dist --port 3000
```

### API Prototyping
```perl
# Quick mock API for testing
register_route('GET', '/api/products', sub {
    my ($req, $res) = @_;
    $res->{headers}{'Content-Type'} = 'application/json';
    $res->{body} = encode_json([
        { id => 1, name => 'Widget', price => 19.99 },
        { id => 2, name => 'Gadget', price => 29.99 }
    ]);
});
```

### File Upload Handler
```perl
register_route('POST', '/upload', sub {
    my ($req, $res) = @_;
    
    # Save uploaded file
    open my $fh, '>', 'uploads/file.dat';
    print $fh $req->{body};
    close $fh;
    
    $res->{status} = 201;
    $res->{headers}{'Content-Type'} = 'application/json';
    $res->{body} = encode_json({ success => 1 });
});
```

### WebSocket Proxy (with external tools)
```bash
# Use TinyServe for static files, proxy WS elsewhere
perl tinyserve.pl --port 8080 &
websocat -s 8081 ws://production-server.com/ws &
```

### Development with Hot Reload
```bash
# Serve files with verbose logging
perl tinyserve.pl --verbose --root ./src

# In another terminal, watch for changes
watch -n 1 'echo "Files changed at $(date)"'
```

## Performance Tips

### Increase Concurrency
```bash
# Handle more simultaneous connections
perl tinyserve.pl --max-connections 100
```

### Adjust Timeout
```bash
# Longer timeout for slow clients
perl tinyserve.pl --timeout 60

# Shorter timeout for fast networks
perl tinyserve.pl --timeout 5
```

### Localhost Only
```bash
# Bind to localhost for security
perl tinyserve.pl --host 127.0.0.1
```

## Security Notes

**TinyServe is designed for development only. Do not use in production.**

- No HTTPS support
- Basic directory traversal protection
- No rate limiting
- No authentication by default
- Verbose error messages

For production, use Apache, Nginx, or a proper application server.

## Logging

### Standard Mode
```
[2025-01-15 10:23:45] [INFO] TinyServe v1.0.0 started
[2025-01-15 10:23:45] [INFO] Listening on http://0.0.0.0:8080
[2025-01-15 10:23:50] GET /index.html - 200 - 5.23ms
[2025-01-15 10:23:51] GET /api/status - 200 - 1.15ms
```

### Verbose Mode
```bash
perl tinyserve.pl --verbose
```

Shows full request headers and body (first 200 chars).

## Troubleshooting

### Port Already in Use
```bash
# Check what's using the port
lsof -i :8080

# Or use a different port
perl tinyserve.pl --port 8081
```

### Permission Denied
```bash
# Ports below 1024 need root
sudo perl tinyserve.pl --port 80

# Or use a higher port
perl tinyserve.pl --port 8080
```

### Missing Modules
```bash
# Install missing Perl modules
cpanm JSON::PP URI::Escape Time::HiRes IO::Socket::INET
```

### Files Not Found
```bash
# Check your document root
perl tinyserve.pl --root ./public --verbose

# List files being served
ls -la ./public
```

## Comparison

| Feature | TinyServe | Python SimpleHTTPServer | Node http-server |
|---------|-----------|-------------------------|------------------|
| Startup Time | Instant | ~1s | ~2s |
| Memory Usage | <10MB | ~30MB | ~50MB |
| Custom Routes | Yes | No | Limited |
| JSON Support | Built-in | No | No |
| Dependencies | Perl stdlib | Python | Node + npm |
| Hot Reload | Edit & run | Restart | Restart |

## Tips & Tricks

### Create a Systemd Service
```ini
[Unit]
Description=TinyServe Development Server
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/path/to/project
ExecStart=/usr/bin/perl /path/to/tinyserve.pl --port 8080 --root ./public
Restart=always

[Install]
WantedBy=multi-user.target
```

### Alias for Quick Start
```bash
# Add to ~/.bashrc or ~/.zshrc
alias serve='perl ~/bin/tinyserve.pl'

# Now just type:
serve
serve --port 3000
```

### JSON Pretty Printing
```bash
# Format API responses with jq
curl http://localhost:8080/api/status | jq .
```

### Test with Multiple Clients
```bash
# Apache Bench
ab -n 1000 -c 10 http://localhost:8080/

# wrk
wrk -t4 -c100 -d30s http://localhost:8080/
```

## Contributing

TinyServe is intentionally minimal. PRs welcome for:

- Bug fixes
- Performance improvements
- Additional MIME types
- Better error handling

Please keep it simple and dependency-free.

## License

MIT License - use it however you want.

## Credits

Built with Perl and a passion for simplicity.

**Philosophy:** The best server is the one that gets out of your way.

---

**Made by developer, for developers** • Star it if you find it useful!

