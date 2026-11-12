# CarRent backend

This is the group's initial backend setup, separate from Flutter and the teacher's
examples. It has `GET /health`, the Reservation model, a read-only reservation
date-conflict endpoint, and a local-development-only client history endpoint.
Cancellation is also available only in controlled local development.
`POST /reservations` now supports fixture-based creation only in explicitly
enabled, uniquely named temporary test databases. It refuses writes in normal
`carrent`. There is no real-vehicle creation flow, authentication, payment, or
Flutter connection yet.

## What each part does

- Node.js runs JavaScript outside a browser.
- Express receives HTTP requests and sends responses.
- MongoDB stores application records. It is a separate server, not installed by npm.
- Mongoose lets Node.js connect to MongoDB and will describe records using schemas.
- dotenv reads local configuration from `.env` into `process.env`.
- `server.js` starts Express, attempts the configured MongoDB connection, and defines
  the health endpoint.
- `package.json` describes the project, its dependencies, and `npm start` command.
- `package-lock.json` records the dependency versions installed by npm.
- `models/Reservation.js` defines the reservation fields and validation rules.
- `utils/reservationDates.js` parses UTC calendar dates and generates reserved days.
- `scripts/setupReservationIndex.js` inspects the local reservation collection;
  index installation requires a separately approved, explicit `--apply` run.
- `controllers/reservationController.js` checks date conflicts, retrieves a
  client's reservations, cancels reservations, and handles controlled test
  creation. All three restricted actions reuse the local-development helper;
  creation has additional flag/database/index checks.
- `routes/reservationRoutes.js` connects the reservation URLs to their controllers.
- `middlewares/reservationHistoryCors.js` adds the exact local Flutter origin to
  development history GET responses only; the controller's access checks remain.
- `fixtures/reservationCreationDemo.js` contains backend-only example IDs, rates,
  and locations for creation tests. These are not database Vehicle/Client records.

## Start in PowerShell

```powershell
cd C:\Users\21627\Documents\ChatGPT\d\carrent-backend
npm install
Copy-Item .env.example .env
npm start
```

Copy the example only when you do not already have your own `.env`. The setup does
not create `.env` automatically. Stop the server with Ctrl+C before restarting it.

The example URI is `mongodb://127.0.0.1:27017/carrent`. It assumes a separate local
MongoDB server on port 27017, but does not install or start MongoDB. Install/start
MongoDB separately, or configure an agreed MongoDB server using your own `.env`.
Restart this Node.js server after fixing an initial failed connection.

`.env` and `node_modules/` are excluded from Git. `.env.example` can be shared and
contains no credentials. Do not put private database credentials in source code
or commit your `.env`. The code does not print the connection URI.

## Test the endpoint

An endpoint is a method and URL handled by the server, such as `GET /health`.

Keep the server terminal open. Open `http://localhost:3000/health` in a browser, or
run this in a second PowerShell terminal:

```powershell
Invoke-RestMethod http://localhost:3000/health | ConvertTo-Json -Depth 3
```

If `.env` has not been configured, the expected response is:

```json
{
  "server": "running",
  "database": {
    "configured": false,
    "connected": false,
    "status": "not_configured"
  }
}
```

If `MONGO_URI` is set but MongoDB cannot be reached, `configured` is true,
`connected` is false, and the status becomes `disconnected` after the initial
connection attempt fails. It can be `connecting` during that attempt. The
`serverSelectionTimeoutMS: 5000` option limits the initial wait to about five
seconds. The HTTP server stays available for diagnosis.

Only a successful database connection produces `connected: true` and status
`connected`. HTTP 200 alone means Express responded; it does not prove that the
database is working. The endpoint reads Mongoose's current connection state, so
it does not keep reporting an old successful result after disconnection.

If port 3000 is already in use, change `PORT` in your `.env` and use that port in
the health URL. The conflict endpoint does not insert or update reservations.

## Check reservation date conflicts

Restart the Node.js server after code changes, using Ctrl+C and then `npm start`.

Send a GET request in Postman or open this URL in a browser:

```text
http://localhost:3000/reservations/check-conflict?vehicleId=000000000000000000000001&pickupDate=2026-11-10&returnDate=2026-11-18
```

The ID above is only a correctly formatted input example, not a real vehicle.
Use an agreed vehicle ID to check its confirmed reservations later.

All three parameters are required. The ID must contain 24 hexadecimal characters.
Dates must be real calendar dates in exactly `YYYY-MM-DD` format, without a time.
They are interpreted at UTC midnight, and return must be after pickup.

Example response when the query finds no confirmed reservation conflict:

```json
{
  "hasConflict": false,
  "message": "Ce résultat concerne uniquement les réservations confirmées, pas la disponibilité complète du véhicule."
}
```

`hasConflict: false` does not prove that the vehicle exists, is in service, or is
fully available. No Vehicle model exists here yet. This only checks confirmed
reservation dates for the supplied ID; cancelled reservations are ignored.

Existing reservations conflict if their pickup is before the requested return
AND their return is after the requested pickup. For an existing 10–18 November
booking, 12–15 November conflicts, but 18–20 November and 8–10 November do not.
The pickup date is included and the return date is excluded.

HTTP responses:

- `200`: the query succeeded; check `hasConflict` in the JSON.
- `400`: missing or invalid input, including impossible dates or repeated values.
- `503`: MongoDB is not connected, so the check cannot be performed.
- `500`: a database query or other unexpected error occurred.

The endpoint creates no reservations and does not reserve or lock a vehicle.

## Read a client's reservations — controlled local development only

The complete endpoint is `GET /reservations/client/:clientId`. Replace
`:clientId` with a MongoDB ObjectId in the URL path, not a query parameter.

This endpoint is disabled by default. It requires BOTH:

- Explicit `NODE_ENV=development`.
- A localhost connection: `127.0.0.1`, `::1`, or `::ffff:127.0.0.1`.

It checks the actual connection address and does not trust `X-Forwarded-For` or
other request headers to grant access. There are no server-wide proxy changes.

In your local PowerShell server terminal, stop the running server with Ctrl+C,
then run:

```powershell
$env:NODE_ENV = 'development'
npm start
```

This changes the environment of the current terminal and the server it starts,
not the system-wide environment or your `.env` file.

In Postman, use GET with this URL, or open it in your browser:

```text
http://localhost:3000/reservations/client/000000000000000000000001
```

The ID is a format example, not a real client record. With a connected database
and no matching reservations, the expected response is HTTP 200 with `[]`.
Otherwise the response is an array of that client's reservation documents,
including both `confirmed` and `cancelled`. Results are sorted by creation time
(`createdAt`) from newest to oldest, not by rental date.

Status codes:

- `200`: an array, including `[]` when no reservations match.
- `400`: invalid client ID during permitted local development.
- `403`: development mode is not explicitly enabled, or the connection is not local.
- `503`: MongoDB is disconnected during permitted local development.
- `500`: a database query or other unexpected error occurred.

To verify production blocking, stop the server, set
`$env:NODE_ENV = 'production'`, and run `npm start` again. History requests must
return 403 even with a valid client ID. Set it back to `development` only for
controlled local work. Missing or other environment values also disable history.

This guard is NOT authentication. Anyone allowed to use this local endpoint can
supply another client ID. Do not expose or forward it through a reverse proxy or
tunnel, or enable it in deployment. Real deployment must first add the group's
authentication and ownership checks. Future Flutter integration must use the
authenticated client's identity, not trust an arbitrary client ID.

Later, the Flutter reservation service can fetch the JSON array and convert it
using `fromJson`; `Mes Réservations` can display it through `FutureBuilder` and
`ListView.builder`, like the teacher's movie list. This task changes no Flutter
code and does not replace its static demonstration data.

## Cancel a reservation — controlled local development only

Use `POST /reservations/:id/cancel`, where `:id` is the reservation ID, not a
vehicle ID or client ID. No request body is required.

The same restrictions as history apply: explicitly set `NODE_ENV=development`
and connect through localhost. Other modes and non-local connections return 403.
This is NOT authentication. Anyone permitted to use this local endpoint could
cancel a reservation by its ID. Do not expose or forward it through deployment,
a proxy, or a tunnel. Real authentication and ownership checks must be added first.

Restart the backend in your local terminal after code changes:

```powershell
$env:NODE_ENV = 'development'
npm start
```

In Postman, choose POST and replace `RESERVATION_ID` with an existing reservation
ID in an isolated development/test database:

```text
http://localhost:3000/reservations/RESERVATION_ID/cancel
```

Cancelling changes `status` from `confirmed` to `cancelled` and calls `save()`.
The document is not deleted. HTTP 200 returns a message and the reservation:

```text
message: Réservation annulée avec succès.
reservation.status: cancelled
```

Repeating the request returns HTTP 200 with `Cette réservation est déjà annulée.`
and the existing document, without saving again. The reservation stays in client
history. It no longer blocks dates because conflict checking only matches
`confirmed` reservations. Other overlapping confirmed reservations can still
produce a conflict.

Status codes:

- `200`: cancelled successfully, or was already cancelled.
- `400`: invalid reservation ID during permitted local development.
- `403`: local development is not explicitly enabled or the connection is not local.
- `404`: no reservation matches the ID.
- `409`: the stored status is neither confirmed nor cancelled, so it is not changed.
- `503`: MongoDB is disconnected during permitted local development.
- `500`: a database lookup or save failed, or another unexpected error occurred.

Use a temporary test database when trying a real cancellation; it modifies a
record. No reservation-creation endpoint has been added.

## Reserved days — model integration only

Confirmed reservations now require `reservedDays`: a complete, ordered array of
UTC midnight dates from pickup up to, but excluding, return. For 10–13 November,
the array contains 10, 11, and 12 November. Missing, empty, incomplete, repeated,
out-of-order, extra, or invalid dates are rejected. Confirmed rentals must last
1–30 days. **The 30-day maximum is a provisional group decision.**

`utils/reservationDates.js` shares the tested generator between the model, tests,
and original isolated experiment. It accepts strict `YYYY-MM-DD` strings or valid
UTC-midnight Date objects, copies dates, and advances with `setUTCDate`. This
handles month/year boundaries without daylight-saving clock changes.

Small Mongoose setters check date inputs before Date casting can normalize an
impossible date such as February 30. Conditional required validation applies to
`reservedDays` for `confirmed` records. Its validator generates the expected list
and compares every timestamp and the array length. It does not silently fill in
missing days. Cancelled records may omit the array; re-confirming a record would
require a correct complete array again. Existing required fields, integer prices,
date order, status enum, IDs, and timestamps remain in place.

The creation controller generates `reservedDays` itself from validated dates. It
rejects a client-supplied array. Currently creation is restricted to temporary
test databases and the backend fixture described below; real creation is still
pending group integration.

### Index definition and deliberate installation

The schema defines the tested unique compound multikey index on `vehicleId` and
`reservedDays`, filtered to `status: confirmed`. Two confirmed documents cannot
share a vehicle/day pair once that index has been built. Cancelling a reservation
with `save()` removes it from that partial index while keeping its history.

Mongoose can normally build schema indexes when models initialize. This schema
explicitly sets **`autoIndex: false` and `autoCreate: false`**, so normal backend
startup does not build this index or create the collection automatically.

Defining the index in JavaScript does not make it exist in MongoDB. The isolated
tests explicitly build and verify indexes in their temporary databases. The
maintenance script below can deliberately install the index after separate
approval. Normal application startup still does not build it automatically.

The index was installed and verified in local `carrent` in a separately approved
maintenance step. That installation did not enable fixture-based creation there.
Every controlled creation request checks the temporary database's actual index
metadata. An absent or incorrect index disables writes. Future real creation must
also verify the index rather than assume the schema definition installed it.

### Future date updates

Read the reservation document, assign its new dates, regenerate `reservedDays`,
and use normal document validation and `save()`. Changing only the dates and
saving a confirmed document is rejected when the day list no longer matches.

Do not assume `updateOne`, `findOneAndUpdate`, bulk updates, or direct MongoDB
writes preserve this invariant. Mongoose update validators are disabled by
default; even `runValidators: true` validates only updated paths and uses query
context rather than the full document. A future update feature needs explicit
full-range safeguards. Do not bypass document validation or use
`validateModifiedOnly: true` for these changes. No date-edit endpoint is added.

### Run the isolated checks

From `carrent-backend`:

```powershell
node tests/reservation-day-uniqueness.experiment.js
node tests/reservation-reserved-days.test.js
```

The original experiment still demonstrates the index-only limitation in case H.
The real model test now rejects that incomplete-array case. It checks in-memory
validation, the actual schema and index in a new temporary database, simultaneous
inserts, date changes, and the unchanged health/conflict/history/cancellation HTTP
endpoints. It checks that startup does not build the index before the explicit
temporary-only build, compares read-only snapshots of normal reservation data and
indexes, and removes only the test database created by that run in `finally`.

## Inspect the reservation index before installation

From the backend folder, run the default **read-only** mode:

```powershell
$env:NODE_ENV = 'development'
node scripts/setupReservationIndex.js
```

It loads the existing `MONGO_URI` from the environment or this backend's `.env`.
It does not change either file. It accepts only `mongodb://` with one local host
(`localhost`, `127.0.0.1`, or `::1`) and exactly the `carrent` database. It rejects
remote/SRV addresses, proxy options, other databases, and any environment other
than explicit `development`. Its separate connection disables automatic creation
and indexing and uses `directConnection: true` to stay on that local host.
Credentials and reservation contents are never printed.

The report checks:

- Whether the `reservations` collection exists. Inspection does not create it.
- Whether its collection settings are ordinary. Views or custom options require
  manual review.
- Stored BSON field types, required fields, prices, dates, status, timestamps,
  and complete reserved-day arrays using the existing model's validation.
  Mongoose casting or defaults must not hide missing/old stored data.
- Repeated vehicle/day pairs among confirmed documents. Cancelled documents do
  not participate in this conflict check.
- Whether the exact named index `unique_confirmed_vehicle_day` already exists:
  `{ vehicleId: 1, reservedDays: 1 }`, unique, partial filter `{ status: 'confirmed' }`.
- Any other unexpected index besides the normal `_id_` index. This conservative
  script stops even for a differently named equivalent index or a potentially
  harmless extra index, so the group can review it first.

`ready: true` means the inspected state is suitable for installation; it does
**not** mean that the index is installed. Check `correctIndexExists` separately.
If records need migration, overlap, or have unexpected indexes/settings, the
script exits unsuccessfully and changes nothing. It does not repair data.

### Explicit installation — do not run until separately approved

Stop the backend and other database writers for the maintenance window. The
inspection is a snapshot, not a lock against another program changing data.
After reviewing a fresh inspection and receiving approval, the explicit command
would be:

```powershell
$env:NODE_ENV = 'development'
node scripts/setupReservationIndex.js --apply
```

This command repeats all checks. If needed, it creates only the `reservations`
collection and the one index defined in `Reservation.js`, awaits completion, and
reads MongoDB's index metadata to verify it. If already correct, it reports
success without rebuilding. It never saves, repairs, or deletes reservation
documents, drops other indexes, or uses destructive index synchronization.
MongoDB rejects an index build if conflicting keys are present; a failed run
needs manual review, not automatic data repair or index deletion.

The command above was run successfully against local `carrent` in the separately
approved installation step. It is not run automatically during server startup
or creation. `ready: true` alone is still not proof that the index exists; use
`correctIndexExists` and the installed metadata.

### Test the maintenance script safely

```powershell
node tests/setup-reservation-index.test.js
```

The CLI always requires the exact `carrent` database; it has no test-name bypass.
The test exercises those CLI/configuration guards, then calls the same inspection
and installation functions with its own uniquely named temporary database. It
tests missing collections, installation, repeated runs, valid stored data,
migration problems, overlaps, and unexpected indexes/settings. It compares
read-only snapshots of normal reservation records/indexes and removes only its
verified newly created temporary database in `finally`.

## Create reservations — isolated development tests ONLY

`POST /reservations` follows the teacher's `createMovie` pattern: read input,
validate, construct a model, `await save()`, then return HTTP 201 with the saved
document. These documents exist only in temporary testing, not normal `carrent`.

All conditions below are required:

- `NODE_ENV=development` and the request's actual socket address is localhost.
  Forwarded headers do not grant access.
- `ENABLE_RESERVATION_CREATION_TESTS=true`. This flag defaults to disabled and
  is set only in test-server child processes by the automated test.
- The selected database matches `carrent_creation_test_` plus 32 lowercase
  hexadecimal characters generated from a new random UUID. `carrent` and other
  database names are refused, even when the flag is true.
- MongoDB is local and connected directly (`directConnection=true` in the test
  URI), without a MongoDB proxy. This prevents discovering a different server.
  The normal server configuration and `.env` are not changed.
- MongoDB already has the verified `unique_confirmed_vehicle_day` index with
  ordered keys `{ vehicleId: 1, reservedDays: 1 }`, `unique: true`, and exact
  partial filter `{ status: 'confirmed' }`.

The controller never creates an index automatically. The test explicitly builds
and verifies it before successful writes. A flag alone does not enable creation
when any other check fails. This is NOT authentication. Do not forward this
development server through a proxy/tunnel or expose it publicly. Real deployment
needs the group's authentication and ownership checks first.

### JSON body

Send only the six fields below, with `Content-Type: application/json`:

```json
{
  "vehicleId": "000000000000000000000101",
  "clientId": "000000000000000000000201",
  "pickupDate": "2026-11-10",
  "returnDate": "2026-11-13",
  "pickupLocation": "Tunis - Aéroport",
  "returnLocation": "Tunis - Centre"
}
```

These IDs identify **test fixtures only**, not real database vehicles or clients.
The fixture contains Corolla (`...101`, 50000 millimes/day), Tucson (`...102`,
70000), Picanto (`...103`, 40000), two example client IDs (`...201`, `...202`),
and the two locations shown above. Unknown IDs/locations are rejected.

`req.body` is the JavaScript object produced by Express's existing JSON parser.
The controller accepts only these six string fields. It rejects extra fields,
including `dailyPriceMillimes`, `totalPriceMillimes`, `status`, `reservedDays`,
and `_id`. It never copies the whole request into the model.

Dates must be real `YYYY-MM-DD` calendar dates. The existing generator enforces
1–30 UTC days, including pickup and excluding return. The 30-day maximum remains
provisional. The backend uses `reservedDays.length` for rental days, takes the
daily rate from its fixture, multiplies them, and sets `status: confirmed`.
For the example above: 3 × 50000 = 150000 millimes (150 DT).

Mongoose validates the explicitly constructed document before `save()` inserts
it. HTTP 201 is sent only after the insert succeeds. There is no check-then-save
claim: the unique MongoDB index decides simultaneous conflicts. Error 11000 is
returned as HTTP 409. Cancelling keeps the document in history but removes it
from the confirmed-only index, so another booking can use those days.

Responses:

- `201`: saved in the controlled temporary database; body is the saved document.
- `400`: missing/invalid input, unknown fixture ID/location, or forbidden fields.
- `403`: local development, flag, local direct connection, or test-name guard fails.
- `409`: MongoDB rejected a duplicate vehicle/day booking.
- `503`: MongoDB is disconnected, or the collection/index is absent/incorrect.
- `500`: another unexpected database failure; success is never reported on failure.

### Run and verify safely

From `carrent-backend`:

```powershell
node tests/reservation-creation.test.js
```

The test creates a fresh temporary database, builds the index, starts existing
`server.js` on temporary ports, and sends real HTTP requests. It exercises correct
rates/days/totals, invalid inputs, missing/wrong indexes, sequential/simultaneous
conflicts, adjacent bookings, other vehicles, cancellation/history, and disabled
configurations. A valid creation attempt against normal `carrent` must return 403.
All normal collections' record/index hashes are compared before and after.
Servers stop and only the newly owned temporary database is removed in `finally`.
The normal `.env` and normal database are not repurposed for fixture testing.

Later, replace the fixture lookup with the group's shared Vehicle and Client
lookups. Obtain the price and permitted locations from trusted backend data and
the client identity from the agreed authentication flow. Keep server-generated
days/totals, full model validation, and the verified unique index. That future
integration will need its own reviewed access rules; simply removing these test
guards is not sufficient. Flutter remains unchanged in this task.

## Development-only CORS for Flutter history

Flutter Web at `http://localhost:7357` and Node at `http://localhost:3000` have
different origins because their ports differ. Chrome needs the API to permit
reading that cross-origin response. The route-specific middleware now adds:

```text
Access-Control-Allow-Origin: http://localhost:7357
Vary: Origin
```

The permission requires ALL of: `NODE_ENV=development`, method GET, the existing
`/reservations/client/:clientId` route, an actual loopback socket address, and an
exact Origin equal to the fixed development constant `http://localhost:7357`.
`127.0.0.1:7357`, another port, HTTPS, a trailing slash, or another origin do not
match. Forwarded headers never grant localhost access. The constant is kept in
the small middleware; no extra environment variable or package is needed.

The middleware uses Express `res.vary`, `res.set`, and `next()`. `next()` passes
control to the unchanged history controller. That controller still rejects
non-local requests and environments other than development. Development history
GET responses vary by Origin even when no permission header is sent, so caches
do not confuse allowed-origin and other-origin responses. Invalid client-ID
errors can also be read by the permitted local Flutter preview.

There is no wildcard, arbitrary Origin reflection, credentials/cookie permission,
or global CORS middleware. Other routes and methods (including HEAD and OPTIONS)
receive no new CORS permission. The current Flutter service sends a simple GET,
so no preflight support is needed. No new API has been created. Production history
continues returning 403 and has no development permission header.

CORS is NOT authentication. A non-browser client can supply an Origin header,
and a local development caller can still supply a client ID. Real deployment
needs authentication and ownership checks; these existing limitations remain.

Start Node from this backend folder:

```powershell
$env:NODE_ENV = 'development'
npm start
```

In the Flutter folder, use a second terminal:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357
```

Navigate through the existing demonstration flow to **Mes Réservations**, then
open **Aperçu API — développement uniquement**. With the current empty normal
database, **Aucune réservation trouvée** means the request succeeded. Do not add
sample database records just to populate this screen. Browser security stays on.

Run the read-only backend checks with:

```powershell
node tests/reservation-history-cors.test.js
```

These verify allowed/disallowed origins, Vary, no credentials/cookies, method/path
scope, all loopback address formats, spoofed forwarding headers, development vs
production/test/unset environments, and existing endpoint behavior. Requests are
read-only or rejected before writes. Normal collection/record/index snapshots
must remain identical; temporary verification servers are stopped afterward.
Real Chrome verification also reached the empty API-history message at iPhone 16
logical dimensions. No reservations or indexes were changed for the CORS fix.
