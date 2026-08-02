# API examples

## Login (US 1.1 canonical)

```http
POST /api/v1/admin/login
Content-Type: application/json

{"email":"ops@maiditquick.com","password":"strong-password","rememberMe":true}
```

Raw token payload (not envelope-wrapped); refresh token also set as the
`admin_refresh` httpOnly cookie (7 days with `rememberMe`, session-only otherwise):

```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<raw>",
  "expiresIn": 900,
  "name": "Ops Admin",
  "permissions": ["ADMIN_READ", "ADMIN_WRITE", "AUDIT_READ"],
  "admin": {"id": 3, "name": "Ops Admin", "email": "ops@maiditquick.com", "role": "ADMIN"}
}
```

## Silent session restore (US 1.1)

```http
POST /api/v1/admin/refresh-token
```
Rotates the `admin_refresh` cookie: the presented token is revoked and a new
pair is returned (same raw shape as login).

## Forgot password (US 1.2)

```http
POST /api/v1/admin/forgot-password
Content-Type: application/json

{"email":"ops@maiditquick.com"}
```

Always HTTP 200 with the generic message (no account enumeration):

```json
{"message": "If an account exists, a password reset link has been sent."}
```

## Reset password (US 1.3)

```http
POST /api/v1/admin/reset-password
Content-Type: application/json

{"token":"<64-char token from the email>","newPassword":"new-strong-password"}
```

HTTP 200 on success; 400 `This password reset link is invalid or has expired.`
for unknown/used/expired tokens; 422 for validation errors. Success revokes
every refresh session of the account.

## Authenticated call (envelope-wrapped)

```http
GET /api/v1/admin/dashboard/summary
Authorization: Bearer <access-token>
```

## State change with audit (envelope-wrapped)

```http
PATCH /api/v1/admin/users/42/status
Authorization: Bearer <access-token>
Content-Type: application/json

{"status":"SUSPENDED","reason":"Repeated payment fraud"}
```

## Partner KYC workflow

Approve a pending partner (clears rejection reason, records approvedAt, notifies the partner app, audits):

``http
POST /api/v1/admin/partners/7/approve
Authorization: Bearer <access-token>
``

Reject with a mandatory reason (422 if blank / over 1000 chars):

``http
POST /api/v1/admin/partners/7/reject
Authorization: Bearer <access-token>
Content-Type: application/json

{"reason":"Invalid IFSC code provided"}
``

Upload KYC documents (multipart; identity proof type via query param, identity/address fields):

``http
POST /api/v1/admin/partners/7/documents?docType=PAN
Authorization: Bearer <access-token>
Content-Type: multipart/form-data

identity: <file>
address: <file>
``

Documents are stored under backend/uploads/partners/ and served publicly:

``http
GET /uploads/partners/7-3f2a9b1c-identity.svg
``

## Customer verification

``http
GET /api/v1/admin/customers/overview?query=&kyc=&flagged=&page=0&size=100
Authorization: Bearer <access-token>
``

Manual override actions (FLAG requires reason):

``http
PATCH /api/v1/admin/customers/12/verification
Authorization: Bearer <access-token>
Content-Type: application/json

{"action":"FLAG","reason":"Suspicious activity"}

PATCH /api/v1/admin/customers/12/verification
{"action":"VERIFY"}

PATCH /api/v1/admin/customers/12/verification
{"action":"CLEAR_FLAG"}
``

## Live operations

``http
GET /api/v1/admin/bookings/live
Authorization: Bearer <access-token>
``

Escalate a booking to emergency support (notifies partner app, audits):

``http
POST /api/v1/admin/bookings/21/escalate
Authorization: Bearer <access-token>
Content-Type: application/json

{"reason":"Customer reports the maid did not show up"}
``

## Bookings ledger

``http
GET /api/v1/admin/bookings/ledger?from=2026-07-01&to=2026-08-01&status=COMPLETED&customerQ=ananya&partnerQ=priya&page=0&size=100
Authorization: Bearer <access-token>
``

Response items include the commission split (platform_commission_pct setting, default 18%):

``json
{"id": 21, "status": "COMPLETED", "amountPaid": 2000.00,
 "commissionPct": 18, "commission": 360.00, "netPayout": 1640.00}
``