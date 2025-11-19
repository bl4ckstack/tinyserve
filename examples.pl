#!/usr/bin/env perl
# TinyServe - Advanced Usage Examples
# This file demonstrates how to extend TinyServe with custom routes and middleware

use strict;
use warnings;

# Example 1: Custom API Routes
# Add these to the register_default_routes() function in tinyserve.pl

sub example_custom_routes {
    # Simple GET route with query parameters
    register_route('GET', '/api/greet', sub {
        my ($req, $res) = @_;
        my $name = $req->{params}{name} || 'Guest';
        
        $res->{status} = 200;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = encode_json({
            greeting => "Hello, $name!",
            timestamp => time()
        });
    });
    
    # POST route with JSON body
    register_route('POST', '/api/users', sub {
        my ($req, $res) = @_;
        my $user = $req->{json};
        
        # Validate input
        unless ($user && $user->{name} && $user->{email}) {
            $res->{status} = 400;
            $res->{headers}{'Content-Type'} = 'application/json';
            $res->{body} = encode_json({
                error => 'Missing required fields: name, email'
            });
            return;
        }
        
        # Simulate saving user
        my $new_user = {
            id => int(rand(10000)),
            name => $user->{name},
            email => $user->{email},
            created_at => time()
        };
        
        $res->{status} = 201;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = encode_json({
            success => 1,
            user => $new_user
        });
    });
    
    # PUT route for updates
    register_route('PUT', '/api/users/123', sub {
        my ($req, $res) = @_;
        my $updates = $req->{json};
        
        $res->{status} = 200;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = encode_json({
            success => 1,
            message => 'User updated',
            updates => $updates
        });
    });
    
    # DELETE route
    register_route('DELETE', '/api/users/123', sub {
        my ($req, $res) = @_;
        
        $res->{status} = 204;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = '';
    });
    
    # File upload simulation (form data)
    register_route('POST', '/api/upload', sub {
        my ($req, $res) = @_;
        
        $res->{status} = 200;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = encode_json({
            success => 1,
            message => 'File uploaded',
            size => length($req->{body}),
            content_type => $req->{headers}{'content-type'}
        });
    });
}

# Example 2: Middleware Examples
# Add these using add_middleware() before starting the server

sub example_cors_middleware {
    add_middleware(sub {
        my ($req, $res) = @_;
        
        # Add CORS headers
        $res->{headers}{'Access-Control-Allow-Origin'} = '*';
        $res->{headers}{'Access-Control-Allow-Methods'} = 'GET, POST, PUT, DELETE, OPTIONS';
        $res->{headers}{'Access-Control-Allow-Headers'} = 'Content-Type, Authorization';
        
        # Handle preflight requests
        if ($req->{method} eq 'OPTIONS') {
            $res->{status} = 204;
            $res->{body} = '';
            return 0;  # Stop processing
        }
        
        return 1;  # Continue processing
    });
}

sub example_auth_middleware {
    add_middleware(sub {
        my ($req, $res) = @_;
        
        # Only protect /api/admin routes
        if ($req->{path} =~ m{^/api/admin}) {
            my $auth = $req->{headers}{authorization} || '';
            
            # Simple token validation
            unless ($auth eq 'Bearer secret-token-12345') {
                $res->{status} = 401;
                $res->{headers}{'Content-Type'} = 'application/json';
                $res->{body} = encode_json({
                    error => 'Unauthorized',
                    message => 'Valid authorization token required'
                });
                return 0;  # Stop processing
            }
        }
        
        return 1;  # Continue processing
    });
}

sub example_rate_limit_middleware {
    my %request_counts = ();
    my $limit = 100;  # requests per minute
    my $window = 60;  # seconds
    
    add_middleware(sub {
        my ($req, $res) = @_;
        
        # Get client IP (simplified)
        my $client_ip = $req->{headers}{'x-forwarded-for'} || 'unknown';
        my $now = time();
        
        # Clean old entries
        foreach my $ip (keys %request_counts) {
            if ($now - $request_counts{$ip}{time} > $window) {
                delete $request_counts{$ip};
            }
        }
        
        # Check rate limit
        if (exists $request_counts{$client_ip}) {
            $request_counts{$client_ip}{count}++;
            
            if ($request_counts{$client_ip}{count} > $limit) {
                $res->{status} = 429;
                $res->{headers}{'Content-Type'} = 'application/json';
                $res->{body} = encode_json({
                    error => 'Too Many Requests',
                    message => "Rate limit exceeded: $limit requests per minute"
                });
                return 0;  # Stop processing
            }
        } else {
            $request_counts{$client_ip} = {
                count => 1,
                time => $now
            };
        }
        
        return 1;  # Continue processing
    });
}

sub example_logging_middleware {
    add_middleware(sub {
        my ($req, $res) = @_;
        
        # Add custom request ID
        my $request_id = sprintf("%08x", int(rand(0xFFFFFFFF)));
        $res->{headers}{'X-Request-ID'} = $request_id;
        
        # Log request details
        print "[REQUEST-$request_id] $req->{method} $req->{path}\n";
        
        return 1;  # Continue processing
    });
}

sub example_cache_control_middleware {
    add_middleware(sub {
        my ($req, $res) = @_;
        
        # Add cache headers for static files
        if ($req->{path} =~ /\.(css|js|png|jpg|jpeg|gif|svg|woff|woff2)$/) {
            $res->{headers}{'Cache-Control'} = 'public, max-age=3600';
        } else {
            $res->{headers}{'Cache-Control'} = 'no-cache, no-store, must-revalidate';
        }
        
        return 1;  # Continue processing
    });
}

# Example 3: RESTful API with in-memory database
sub example_rest_api {
    my @todos = (
        { id => 1, title => 'Learn Perl', completed => 1 },
        { id => 2, title => 'Build TinyServe', completed => 1 },
        { id => 3, title => 'Deploy app', completed => 0 },
    );
    my $next_id = 4;
    
    # GET all todos
    register_route('GET', '/api/todos', sub {
        my ($req, $res) = @_;
        
        $res->{status} = 200;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = encode_json(\@todos);
    });
    
    # GET single todo
    register_route('GET', '/api/todos/1', sub {
        my ($req, $res) = @_;
        my $id = 1;  # In real app, extract from path
        
        my ($todo) = grep { $_->{id} == $id } @todos;
        
        if ($todo) {
            $res->{status} = 200;
            $res->{headers}{'Content-Type'} = 'application/json';
            $res->{body} = encode_json($todo);
        } else {
            $res->{status} = 404;
            $res->{headers}{'Content-Type'} = 'application/json';
            $res->{body} = encode_json({ error => 'Todo not found' });
        }
    });
    
    # POST new todo
    register_route('POST', '/api/todos', sub {
        my ($req, $res) = @_;
        my $data = $req->{json};
        
        unless ($data && $data->{title}) {
            $res->{status} = 400;
            $res->{headers}{'Content-Type'} = 'application/json';
            $res->{body} = encode_json({ error => 'Title is required' });
            return;
        }
        
        my $new_todo = {
            id => $next_id++,
            title => $data->{title},
            completed => $data->{completed} || 0
        };
        
        push @todos, $new_todo;
        
        $res->{status} = 201;
        $res->{headers}{'Content-Type'} = 'application/json';
        $res->{body} = encode_json($new_todo);
    });
}

# Example 4: Testing with curl commands
print <<"EXAMPLES";

TinyServe - Advanced Usage Examples
====================================

1. Test GET with query parameters:
   curl "http://localhost:8080/api/greet?name=John"

2. Test POST with JSON:
   curl -X POST http://localhost:8080/api/users \\
     -H "Content-Type: application/json" \\
     -d '{"name":"John Doe","email":"john\@example.com"}'

3. Test PUT request:
   curl -X PUT http://localhost:8080/api/users/123 \\
     -H "Content-Type: application/json" \\
     -d '{"name":"Jane Doe"}'

4. Test DELETE request:
   curl -X DELETE http://localhost:8080/api/users/123

5. Test with authentication:
   curl http://localhost:8080/api/admin/users \\
     -H "Authorization: Bearer secret-token-12345"

6. Test form data:
   curl -X POST http://localhost:8080/api/upload \\
     -F "file=@image.png"

7. Test CORS preflight:
   curl -X OPTIONS http://localhost:8080/api/status \\
     -H "Access-Control-Request-Method: POST"

8. Test todos API:
   curl http://localhost:8080/api/todos
   curl -X POST http://localhost:8080/api/todos \\
     -H "Content-Type: application/json" \\
     -d '{"title":"New task","completed":false}'

EXAMPLES
