# Nectar DXP MCP Server

A Model Context Protocol (MCP) server that enables AI assistants like Claude to interact with the Nectar DXP platform for unified communications monitoring and analytics.

## Features

- **Session Analytics** - Query call quality metrics, session summaries, and performance data
- **Location Insights** - Get quality metrics by location with geographic mapping
- **User Search** - Find users and their communication patterns
- **Tenant Management** - Access multi-tenant deployments
- **Endpoint Testing** - Retrieve endpoint client test results
- **Multi-User Support** - Per-request credentials via HTTP headers

## Deployment

### Docker

Build and run the container:

```bash
docker build -t nectar-mcp-server .
docker run -p 8000:8000 -e MCP_TRANSPORT=http nectar-mcp-server
```

### Kubernetes

Deploy with environment variables or use header-based authentication for multi-user:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nectar-mcp-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nectar-mcp-server
  template:
    metadata:
      labels:
        app: nectar-mcp-server
    spec:
      containers:
        - name: nectar-mcp-server
          image: nectar-mcp-server:latest
          ports:
            - containerPort: 8000
          env:
            - name: MCP_TRANSPORT
              value: "http"
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MCP_TRANSPORT` | Transport mode: `http` or `stdio` | `stdio` |
| `FASTMCP_HOST` | Host to bind to | `0.0.0.0` |
| `FASTMCP_PORT` | Port to listen on | `8000` |
| `NECTAR_DXP_URL` | Nectar DXP instance URL | - |
| `NECTAR_ACCESS_TOKEN` | JWT access token | - |
| `NECTAR_REFRESH_TOKEN` | Refresh token | - |
| `NECTAR_DOMAIN_NAME` | Domain name (optional) | - |
| `DEBUG_MODE` | Enable debug logging (`true`/`false`) | `false` |

### Per-User Authentication via Headers

For multi-user deployments, credentials can be passed via HTTP headers:

| Header | Description |
|--------|-------------|
| `X-Nectar-DXP-URL` | Nectar DXP instance URL |
| `X-Nectar-Access-Token` | JWT access token |
| `X-Nectar-Refresh-Token` | Refresh token |
| `X-Nectar-Domain-Name` | Domain name (optional) |

## Claude Desktop Setup

### Configuration File Location

- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

### Remote Server Configuration

Requires Node.js for the `mcp-remote` bridge. In Windows, run:
```powershell
winget install OpenJS.NodeJS.LTS
```

Edit your `claude_desktop_config.json` file to include the following json. Edit the `env` section to match your server configuration:

```json
{
  "mcpServers": {
    "nectar-dxp": {
      "command": "npx.cmd",
      "args": [
        "mcp-remote",
        "https://your-mcp-server.example.com/mcp",
        "--header",
        "X-Nectar-DXP-URL:${NECTAR_DXP_URL}",
        "--header",
        "X-Nectar-Access-Token:${NECTAR_ACCESS_TOKEN}",
        "--header",
        "X-Nectar-Refresh-Token:${NECTAR_REFRESH_TOKEN}",
        "--header",
        "X-Nectar-Domain-Name:${NECTAR_DOMAIN_NAME}"
      ],
      "autoApprove": ["*"],
      "env": {
        "NECTAR_DXP_URL": "https://demo.us.nectar.services",
        "NECTAR_ACCESS_TOKEN": "your-access-token",
        "NECTAR_REFRESH_TOKEN": "your-refresh-token",
        "NECTAR_DOMAIN_NAME": "your-domain-name"
      }
    }
  }
}
```

**Notes:**
- On Windows, use `npx.cmd` instead of `npx`
- Header values must not have spaces around the colon (Windows Claude Desktop bug)
- On macOS/Linux, use `npx` instead of `npx.cmd`

### Local Server Configuration (stdio mode)

```json
{
  "mcpServers": {
    "nectar-dxp": {
      "command": "python",
      "args": ["-m", "nectar_mcp_server.main"],
      "autoApprove": ["*"],
      "env": {
        "NECTAR_DXP_URL": "https://demo.us.nectar.services",
        "NECTAR_ACCESS_TOKEN": "your-access-token",
        "NECTAR_REFRESH_TOKEN": "your-refresh-token",
        "NECTAR_DOMAIN_NAME": "your-domain-name"
      }
    }
  }
}
```

## Available Tools

| Tool | Description |
|------|-------------|
| `get_connection_status` | Check connection configuration and connectivity |
| `configure_connection` | Set credentials at runtime |
| `set_session_filter` | Apply filters for session queries |
| `get_session_summary` | Get session metrics and statistics |
| `get_location_quality_summary` | Get quality metrics by location |
| `get_session_histogram` | Get time-series session data |
| `get_detailed_session_list` | Get detailed session records |
| `get_users` | Search for users |
| `get_locations` | Get configured locations |
| `get_tenant_names` | List available tenants |
| `get_tenant_platforms` | Get platforms for a tenant |
| `get_endpoint_test_count` | Get endpoint test counts |
| `get_endpoint_test_summaries` | Get endpoint test results |

## Testing the Server

Verify the server is running:

```bash
curl -X POST https://your-server.example.com/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "X-Nectar-DXP-URL: https://demo.us.nectar.services" \
  -H "X-Nectar-Access-Token: your-token" \
  -H "X-Nectar-Refresh-Token: your-refresh-token" \
  -H "X-Nectar-Domain-Name: your-domain-name" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "curl-test", "version": "1.0"}}}'
```

## Security

- **HTTPS Required** - DXP URLs must use HTTPS
- **Non-root Container** - Runs as unprivileged user (UID 1000)
- **Request Isolation** - Per-request credential context prevents cross-user leakage
- **Credential Redaction** - Debug logs redact sensitive tokens
- **Request Timeouts** - 30-second default timeout on outbound API calls

### Production Recommendations

1. Deploy behind an HTTPS ingress/load balancer
2. Configure network policies to restrict egress
3. Enable rate limiting at the ingress level
4. Use `DEBUG_MODE=true` only for troubleshooting

## Development

### Local Setup

```bash
# Install dependencies
pip install -e .

# Run in stdio mode
python -m nectar_mcp_server.main

# Run in HTTP mode
MCP_TRANSPORT=http python -m nectar_mcp_server.main
```

### Project Structure

```
nectar-mcp-server/
├── Dockerfile
├── pyproject.toml
├── README.md
└── code/
    ├── main.py              # Entry point
    ├── server.py            # FastMCP server instance
    ├── config.py            # Configuration management
    ├── auth.py              # Token management
    ├── api_client.py        # HTTP client helpers
    ├── request_context.py   # Per-request credential context
    ├── tools/               # MCP tool implementations
    │   ├── connection.py
    │   ├── filters.py
    │   ├── sessions.py
    │   ├── users.py
    │   ├── locations.py
    │   ├── tenants.py
    │   └── epc.py
    └── models/              # Pydantic models
```

## License

Proprietary - Nectar Services Corp.
