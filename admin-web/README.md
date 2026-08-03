# MaidItQuick Admin Web

The administration UI is a separate React client in this monorepo. It calls the shared `server` API and authenticates with the existing `ADMIN` account type, so it does not own a second database, identity store, or customer/worker API.

Run it with `npm install` followed by `npm run dev`. Set `VITE_API_URL` only when the shared API is not running at `http://localhost:8080/api`.
