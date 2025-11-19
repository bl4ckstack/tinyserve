# TinyServe

Lightweight HTTP development server written in Perl.

## Requirements

Perl 5.10+ with modules: JSON::PP, URI::Escape (usually pre-installed)

```bash
# If needed
cpanm JSON::PP URI
```

## Usage

```bash
chmod +x tinyserve.pl
./tinyserve.pl
```

Open http://localhost:8080

## Options

```bash
./tinyserve.pl --port 3000 --root ./dist --verbose
./tinyserve.pl --host 127.0.0.1 --max-connections 100
./tinyserve.pl --help
```

## Features

- Static file serving with MIME type detection
- Custom route handlers (GET, POST, PUT, DELETE)
- JSON and form data parsing
- Request logging with timing
- Concurrent connections via IO::Select
- Middleware support

## API Examples

```bash
curl http://localhost:8080/api/status
curl -X POST http://localhost:8080/api/echo -H "Content-Type: application/json" -d '{"test":"data"}'
```

## Custom Routes

Edit `register_default_routes()` in tinyserve.pl:

```perl
register_route('GET', '/api/hello', sub {
    my ($req, $res) = @_;
    $res->{status} = 200;
    $res->{headers}{'Content-Type'} = 'application/json';
    $res->{body} = encode_json({ message => 'Hello World' });
});
```

## Middleware

```perl
add_middleware(sub {
    my ($req, $res) = @_;
    $res->{headers}{'Access-Control-Allow-Origin'} = '*';
    return 1;
});
```

## License

MIT
