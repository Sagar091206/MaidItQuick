#!/usr/bin/env bash

set -euo pipefail

PORT="${1:-8080}"
if lsof -i :"${PORT}" >/dev/null 2>&1; then
  echo "Error: Port ${PORT} is already in use."
  echo "Try: ./run-local.sh 8081"
  exit 1
fi

if ! command -v mvn >/dev/null 2>&1; then
  echo "Error: Maven (mvn) is not installed or not on your PATH."
  exit 1
fi

echo "Starting MakeItQuick server on port ${PORT} using H2 in-memory database..."

export SPRING_DATASOURCE_URL="jdbc:h2:mem:makeitquick;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1"
export SPRING_DATASOURCE_USERNAME="sa"
export SPRING_DATASOURCE_PASSWORD=""
export SPRING_DATASOURCE_DRIVER_CLASS_NAME="org.h2.Driver"

mvn spring-boot:run -Dspring-boot.run.arguments="--server.port=${PORT}"