# MakeItQuick API

Java 21, Spring Boot and MySQL backend foundation for MakeItQuick.

Before production, supply accounts and credentials for phone OTP, SMTP email delivery, Google Maps, notifications, and Google Play Console app signing. Payment is intentionally excluded.
# MakeItQuick server

## Local setup

1. Copy .env.example to .env.
2. Set your actual MySQL password plus a unique admin email and password.
3. Run mvn spring-boot:run.

For simulator-only development without local MySQL credentials, run with the
H2 in-memory datasource:

```bash
SPRING_DATASOURCE_URL='jdbc:h2:mem:makeitquick;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1' \
SPRING_DATASOURCE_USERNAME=sa \
SPRING_DATASOURCE_PASSWORD='' \
SPRING_DATASOURCE_DRIVER_CLASS_NAME=org.h2.Driver \
mvn spring-boot:run
```

Partner OTP endpoints return `devOtp` while no SMS provider is configured, so
local mobile testing can complete the OTP screen without external SMS delivery.

The first run creates the configured admin account only if its email does not already exist. Do not put real credentials in source code or share your .env file.

## API documentation

With the server running, open [Swagger UI](http://localhost:8080/swagger-ui.html). The machine-readable OpenAPI document is available at [http://localhost:8080/v3/api-docs](http://localhost:8080/v3/api-docs).

For protected endpoints, sign in through `POST /api/auth/login`, copy the returned token, then use **Authorize** in Swagger UI and enter `Bearer <token>`.
