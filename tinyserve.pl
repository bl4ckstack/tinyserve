#!/usr/bin/env perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use Getopt::Long;
use File::Basename;
use Time::HiRes qw(time);
use URI::Escape;
use JSON::PP;
use POSIX qw(strftime);

# TinyServe - A robust HTTP development server
# Version 1.0

our $VERSION = '1.0.0';

# Configuration defaults
my %config = (
    port => 8080,
    host => '0.0.0.0',
    root => './public',
    verbose => 0,
    max_connections => 50,
    timeout => 30,
    help => 0,
);

# Route registry
my %routes = (
    GET => {},
    POST => {},
    PUT => {},
    DELETE => {},
);

# Middleware stack
my @middleware = ();

# MIME types mapping
my %mime_types = (
    html => 'text/html',
    htm => 'text/html',
    css => 'text/css',
    js => 'application/javascript',
    json => 'application/json',
    xml => 'application/xml',
    txt => 'text/plain',
    png => 'image/png',
    jpg => 'image/jpeg',
    jpeg => 'image/jpeg',
    gif => 'image/gif',
    svg => 'image/svg+xml',
    ico => 'image/x-icon',
    pdf => 'application/pdf',
    zip => 'application/zip',
    woff => 'font/woff',
    woff2 => 'font/woff2',
    ttf => 'font/ttf',
    mp4 => 'video/mp4',
    webm => 'video/webm',
);

# Parse command line arguments
GetOptions(
    'port=i' => \$config{port},
    'host=s' => \$config{host},
    'root=s' => \$config{root},
    'verbose' => \$config{verbose},
    'max-connections=i' => \$config{max_connections},
    'timeout=i' => \$config{timeout},
    'help' => \$config{help},
) or die "Error parsing options\n";

if ($config{help}) {
    print_help();
    exit 0;
}

# Initialize server
sub main {
    print_banner();
    
    # Validate document root
    unless (-d $config{root}) {
        log_message("ERROR", "Document root '$config{root}' does not exist");
        exit 1;
    }
    
    # Register default routes
    register_default_routes();
    
    # Create server socket
    my $server = IO::Socket::INET->new(
        LocalHost => $config{host},
        LocalPort => $config{port},
        Proto => 'tcp',
        Listen => $config{max_connections},
        Reuse => 1,
    ) or die "Cannot create server socket: $!\n";
    
    log_message("INFO", "TinyServe v$VERSION started");
    log_message("INFO", "Listening on http://$config{host}:$config{port}");
    log_message("INFO", "Document root: $config{root}");
    log_message("INFO", "Press Ctrl+C to stop");
    
    # Create select object for non-blocking I/O
    my $select = IO::Select->new($server);
    
    # Main server loop
    while (1) {
        my @ready = $select->can_read($config{timeout});
        
        foreach my $socket (@ready) {
            if ($socket == $server) {
                # Accept new connection
                my $client = $server->accept();
                if ($client) {
                    $select->add($client);
                    $client->autoflush(1);
                }
            } else {
                # Handle client request
                handle_client($socket);
                $select->remove($socket);
                close($socket);
            }
        }
    }
}

# Handle client connection
sub handle_client {
    my ($client) = @_;
    my $start_time = time();
    
    # Read request with timeout
    my $request_line = <$client>;
    return unless $request_line;
    
    chomp($request_line);
    my ($method, $uri, $protocol) = split(/\s+/, $request_line);
    
    return unless $method && $uri;
    
    # Parse headers
    my %headers = ();
    while (my $line = <$client>) {
        chomp($line);
        last if $line eq '' || $line eq "\r";
        
        if ($line =~ /^([^:]+):\s*(.+)$/) {
            $headers{lc($1)} = $2;
        }
    }
    
    # Parse query string and path
    my ($path, $query_string) = split(/\?/, $uri, 2);
    $path = uri_unescape($path);
    
    # Create request object
    my $request = {
        method => $method,
        path => $path,
        uri => $uri,
        query_string => $query_string || '',
        headers => \%headers,
        body => '',
        params => {},
        json => undef,
    };
    
    # Read request body if present
    if ($headers{'content-length'}) {
        my $content_length = $headers{'content-length'};
        read($client, $request->{body}, $content_length);
        
        # Parse body based on content type
        my $content_type = $headers{'content-type'} || '';
        
        if ($content_type =~ /application\/json/) {
            eval {
                $request->{json} = decode_json($request->{body});
            };
            if ($@) {
                send_error($client, 400, "Invalid JSON: $@");
                return;
            }
        } elsif ($content_type =~ /application\/x-www-form-urlencoded/) {
            $request->{params} = parse_form_data($request->{body});
        }
    }
    
    # Parse query parameters
    if ($query_string) {
        my $query_params = parse_form_data($query_string);
        $request->{params} = { %{$request->{params}}, %$query_params };
    }
    
    # Create response object
    my $response = {
        status => 200,
        headers => {
            'Server' => "TinyServe/$VERSION",
            'Connection' => 'close',
        },
        body => '',
    };
    
    # Apply middleware
    foreach my $mw (@middleware) {
        my $result = $mw->($request, $response);
        unless ($result) {
            send_response($client, $response);
            log_request($request, $response, time() - $start_time);
            return;
        }
    }
    
    # Route request
    my $handled = 0;
    
    if (exists $routes{$method} && exists $routes{$method}{$path}) {
        # Custom route handler
        eval {
            $routes{$method}{$path}->($request, $response);
        };
        if ($@) {
            send_error($client, 500, "Internal Server Error: $@");
            log_request($request, { status => 500 }, time() - $start_time);
            return;
        }
        $handled = 1;
    } else {
        # Try to serve static file
        $handled = serve_static_file($path, $response);
    }
    
    if ($handled) {
        send_response($client, $response);
    } else {
        send_error($client, 404, "Not Found");
        $response->{status} = 404;
    }
    
    log_request($request, $response, time() - $start_time);
}

# Serve static files
sub serve_static_file {
    my ($path, $response) = @_;
    
    # Security: prevent directory traversal
    $path =~ s/\.\.//g;
    
    # Default to index.html for directories
    if ($path eq '/' || $path =~ /\/$/) {
        $path .= 'index.html';
    }
    
    my $file_path = $config{root} . $path;
    
    unless (-f $file_path && -r $file_path) {
        return 0;
    }
    
    # Determine MIME type
    my ($name, $dir, $ext) = fileparse($file_path, qr/\.[^.]*/);
    $ext =~ s/^\.//;
    my $mime_type = $mime_types{lc($ext)} || 'application/octet-stream';
    
    # Read file
    open(my $fh, '<:raw', $file_path) or return 0;
    local $/;
    my $content = <$fh>;
    close($fh);
    
    $response->{status} = 200;
    $response->{headers}{'Content-Type'} = $mime_type;
    $response->{headers}{'Content-Length'} = length($content);
    $response->{body} = $content;
    
    return 1;
}

# Send HTTP response
sub send_response {
    my ($client, $response) = @_;
    
    my $status_text = get_status_text($response->{status});
    
    print $client "HTTP/1.1 $response->{status} $status_text\r\n";
    
    foreach my $header (keys %{$response->{headers}}) {
        print $client "$header: $response->{headers}{$header}\r\n";
    }
    
    print $client "\r\n";
    print $client $response->{body} if $response->{body};
}

# Send error response
sub send_error {
    my ($client, $status, $message) = @_;
    
    my $status_text = get_status_text($status);
    my $html = generate_error_page($status, $status_text, $message);
    
    print $client "HTTP/1.1 $status $status_text\r\n";
    print $client "Content-Type: text/html\r\n";
    print $client "Content-Length: " . length($html) . "\r\n";
    print $client "Server: TinyServe/$VERSION\r\n";
    print $client "Connection: close\r\n";
    print $client "\r\n";
    print $client $html;
}

# Generate error page HTML
sub generate_error_page {
    my ($status, $status_text, $message) = @_;
    
    return <<"HTML";
<!DOCTYPE html>
<html>
<head>
    <title>$status $status_text</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; background: #f5f5f5; }
        .error-container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #e74c3c; margin: 0 0 20px 0; }
        p { color: #555; line-height: 1.6; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #999; font-size: 12px; }
    </style>
</head>
<body>
    <div class="error-container">
        <h1>$status $status_text</h1>
        <p>$message</p>
        <div class="footer">TinyServe v$VERSION</div>
    </div>
</body>
</html>
HTML
}

# Get HTTP status text
sub get_status_text {
    my ($status) = @_;
    
    my %status_texts = (
        200 => 'OK',
        201 => 'Created',
        204 => 'No Content',
        400 => 'Bad Request',
        401 => 'Unauthorized',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
        500 => 'Internal Server Error',
        501 => 'Not Implemented',
        503 => 'Service Unavailable',
    );
    
    return $status_texts{$status} || 'Unknown';
}

# Parse form data
sub parse_form_data {
    my ($data) = @_;
    my %params = ();
    
    foreach my $pair (split(/&/, $data)) {
        my ($key, $value) = split(/=/, $pair, 2);
        $key = uri_unescape($key || '');
        $value = uri_unescape($value || '');
        $params{$key} = $value;
    }
    
    return \%params;
}

# Register a route
sub register_route {
    my ($method, $path, $handler) = @_;
    $routes{uc($method)}{$path} = $handler;
}

# Add middleware
sub add_middleware {
    my ($handler) = @_;
    push @middleware, $handler;
}

# Register default example routes
sub register_default_routes {
    # API endpoint example
    register_route('GET', '/api/status', sub {
        my ($req, $res) = @_;
        $res->{status} = 200;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = encode_json({
            status => 'ok',
            version => $VERSION,
            uptime => time(),
        });
    });
    
    # Echo endpoint for testing POST
    register_route('POST', '/api/echo', sub {
        my ($req, $res) = @_;
        $res->{status} = 200;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = encode_json({
            method => $req->{method},
            path => $req->{path},
            headers => $req->{headers},
            body => $req->{body},
            json => $req->{json},
            params => $req->{params},
        });
    });
}

# Log request
sub log_request {
    my ($request, $response, $duration) = @_;
    
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $duration_ms = sprintf("%.2f", $duration * 1000);
    
    my $log_line = sprintf(
        "[%s] %s %s - %d - %sms",
        $timestamp,
        $request->{method},
        $request->{uri},
        $response->{status},
        $duration_ms
    );
    
    print "$log_line\n";
    
    if ($config{verbose}) {
        print "  Headers: " . encode_json($request->{headers}) . "\n";
        if ($request->{body}) {
            print "  Body: " . substr($request->{body}, 0, 200) . "\n";
        }
    }
}

# Log message
sub log_message {
    my ($level, $message) = @_;
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    print "[$timestamp] [$level] $message\n";
}

# Print banner
sub print_banner {
    print "\n";
    print "╔════════════════════════════════════════╗\n";
    print "║         TinyServe v$VERSION              ║\n";
    print "║  Lightweight HTTP Development Server   ║\n";
    print "╚════════════════════════════════════════╝\n";
    print "\n";
}

# Print help
sub print_help {
    my $help_text = <<'END_HELP';
TinyServe v1.0.0 - Lightweight HTTP Development Server

USAGE:
    perl tinyserve.pl [OPTIONS]

OPTIONS:
    --port <PORT>              Port to listen on (default: 8080)
    --host <HOST>              Host to bind to (default: 0.0.0.0)
    --root <PATH>              Document root directory (default: ./public)
    --verbose                  Enable verbose logging
    --max-connections <NUM>    Maximum concurrent connections (default: 50)
    --timeout <SECONDS>        Connection timeout (default: 30)
    --help                     Show this help message

EXAMPLES:
    # Start server on default port 8080
    perl tinyserve.pl

    # Start on custom port with specific document root
    perl tinyserve.pl --port 3000 --root ./dist

    # Enable verbose logging
    perl tinyserve.pl --verbose

    # Bind to localhost only
    perl tinyserve.pl --host 127.0.0.1 --port 8080

FEATURES:
    - Static file serving with automatic MIME type detection
    - Custom route handlers for GET, POST, PUT, DELETE
    - JSON and form data parsing
    - Request/response logging with timing
    - Concurrent connection handling
    - Customizable error pages

API ENDPOINTS:
    GET  /api/status    - Server status information
    POST /api/echo      - Echo back request data (for testing)

END_HELP
    print $help_text;
}

# Start the server
main();
