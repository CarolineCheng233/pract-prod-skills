# API Reference

---

## Cloudflare API

Base URL: `https://api.cloudflare.com/client/v4`

Authentication header:
```
Authorization: Bearer $CF_API_TOKEN
Content-Type: application/json
```

### Zones

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/zones` | Add a domain. Body: `{"name":"example.com","jump_start":true}` |
| GET | `/zones/:zone_id` | Get zone details. Returns `name_servers[]`, `status` |
| GET | `/zones?name=example.com` | Find zone by domain name |

### DNS Records

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/zones/:zone_id/dns_records?per_page=100` | List all records |
| DELETE | `/zones/:zone_id/dns_records/:record_id` | Delete a record |

### Email Routing

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/zones/:zone_id/email/routing` | Get status. Returns `result.enabled` |
| POST | `/zones/:zone_id/email/routing/enable` | Enable email routing |
| GET | `/zones/:zone_id/email/routing/rules` | List forwarding rules |
| POST | `/zones/:zone_id/email/routing/rules` | Create forwarding rule |

**Create rule body:**
```json
{
  "name": "Forward contact",
  "enabled": true,
  "matchers": [{ "type": "literal", "field": "to", "value": "contact@example.com" }],
  "actions": [{ "type": "forward", "value": ["you@gmail.com"] }]
}
```

### Auth

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/user/tokens/verify` | Verify token. Returns `result.status: "active"` |

### Cloudflare Error Codes

| Code | Meaning |
|------|---------|
| 1061 | Zone already exists |
| 9106 | Invalid API token |
| 7003 | Zone not found |
| 10000 | Authentication error |

---

## Spaceship API

Base URL: `https://spaceship.dev/api/v1`

Authentication headers:
```
X-API-Key: $SPACESHIP_API_KEY
X-API-Secret: $SPACESHIP_API_SECRET
Content-Type: application/json
```

Rate limit: 5 requests per domain within 300 seconds for nameserver updates.

### Domains

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/domains?take=1` | List domains (used to verify credentials) |
| PUT | `/domains/:domain/nameservers` | Update nameservers |

**Update nameservers body:**
```json
{
  "provider": "custom",
  "hosts": ["ns1.cloudflare.com", "ns2.cloudflare.com"]
}
```
Returns: HTTP 200 with JSON `{"provider":"custom","hosts":["ns1","ns2"]}` on success.

### Spaceship Error Responses

Errors return a JSON body with `status` (HTTP code) and `title` or `detail` fields:
```json
{ "status": 401, "title": "Unauthorized" }
{ "status": 404, "title": "Domain not found" }
{ "status": 422, "title": "Unprocessable Entity", "detail": "..." }
```

---

## Brevo API

Base URL: `https://api.brevo.com/v3`

Authentication header:
```
api-key: $BREVO_API_KEY
Content-Type: application/json
```

### Domains

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/senders/domains` | Add domain. Body: `{"name":"example.com"}` |
| GET | `/senders/domains` | List all domains. Returns `domains[]` array |
| DELETE | `/senders/domains/:domain` | Delete a domain |
| PUT | `/senders/domains/:domain/authenticate` | Trigger authentication check |

**POST /senders/domains — Response:**
```json
{
  "id": "abc123",
  "domain_name": "example.com",
  "domain_provider": "Cloudflare",
  "dns_records": {
    "brevo_code": { "host_name": "@", "type": "TXT", "value": "brevo-code=...", "status": false },
    "dkim_record": null,
    "dkim1Record": { "host_name": "brevo1._domainkey", "type": "CNAME", "value": "b1.example-com.dkim.brevo.com", "status": false },
    "dkim2Record": { "host_name": "brevo2._domainkey", "type": "CNAME", "value": "b2.example-com.dkim.brevo.com", "status": false },
    "dmarc_record": { "host_name": "_dmarc", "type": "TXT", "value": "v=DMARC1; p=none; rua=...", "status": false }
  }
}
```

> **Note:** POST often returns `dkim_record: null` for new accounts using CNAME DKIM. Always follow up with `GET /senders/domains/:domain` to get the complete record set.

**GET /senders/domains/:domain — Response:**
Returns full domain details including all DNS record statuses. Uses `dkim1Record`/`dkim2Record` (camelCase) for CNAME DKIM, `dkim_record` (snake_case) for TXT DKIM.

**PUT /senders/domains/:domain/authenticate — Response:**
```json
{ "domain_name": "example.com", "message": "Domain has been authenticated successfully." }
```
Does NOT return an `authenticated` boolean. Use `GET /senders/domains/:domain` after PUT to check `.authenticated` status.

### Transactional Email

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/smtp/email` | Send a transactional email |

**POST /smtp/email — Body:**
```json
{
  "sender": { "name": "Support", "email": "contact@example.com" },
  "to": [{ "email": "recipient@gmail.com" }],
  "subject": "Hello",
  "htmlContent": "<html><body><p>Hello</p></body></html>"
}
```
Returns: `{ "messageId": "<...@smtp-relay.mailin.fr>" }` on success.

### Account

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/account` | Verify API key. Returns `email`, `plan`, `credits` |

### Brevo Error Codes

| HTTP | Meaning |
|------|---------|
| 400 | Bad request / domain already exists |
| 401 | Invalid API key |
| 404 | Domain not found |
| 429 | Rate limit exceeded |
