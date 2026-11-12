# CarRent

University Flutter project. Module 2 currently contains the reservation search
form, demonstration available-car results, and a reservation summary with an
estimated demonstration price, followed by a confirmation dialog and a
demonstration-only confirmation screen. **Mes Réservations** displays a separate
static demonstration list, not saved bookings.
In debug mode it also has a separate, read-only local API history preview. It
uses a labelled test client ID, not a signed-in user's identity. The backend now
permits this read-only Chrome preview from exactly `http://localhost:7357` in
local development; see below.

## Run

From the `carrent` folder:

```powershell
flutter pub get
flutter run -d chrome
```

For Android, start an emulator or connect an Android phone, then use
`flutter devices` and `flutter run -d DEVICE_ID` with the listed device ID.
iOS builds require a Mac with Xcode.

## Try the form

1. Submit the empty form to see the required-field messages.
2. Choose a pickup date today or later.
3. Choose a return date after the pickup date.
4. Select **Tunis - Aéroport**.
5. Press **Rechercher des voitures** to open **Voitures disponibles**.
6. Check that the dates and location match your search. The three vehicles are
   visibly labeled **Données de démonstration**; availability is not verified.
7. Press **Choisir cette voiture** on one card to open the reservation summary.
8. Check the vehicle, dates, pickup location, rental days, and estimated total.
   For three days, Toyota Corolla is 150 DT, Hyundai Tucson is 210 DT, and
   Kia Picanto is 120 DT.
9. Press **Confirmer la réservation (démo)** at the bottom of the summary.
10. Check the vehicle, dates, and estimated price in the dialog. **Annuler** closes
    the dialog and leaves the summary unchanged. **Continuer** opens a screen
    clearly explaining that no reservation has been stored and no car is reserved.
11. On the demonstration screen, press **Voir les réservations (démo)** to open
    **Mes Réservations**. Scroll through the three fixed examples: Confirmée,
    En attente, and Annulée. Each card is labeled as demonstration data.
12. The history does not change when you complete the confirmation demonstration.
    For example, its Toyota Corolla entry is always 10–13 October 2026, 150 DT.
13. Use Back to return to the confirmation demonstration, then Back again to the
    summary without reopening the dialog.
14. Use the back arrow to return to results, then back again to the form. Your
   selections remain available.

Changing pickup to a date on or after the selected return clears the return date.
Same-day rentals are not supported in this first version; confirm this rule with
the group before backend integration.

The location comes from `references/template.png`; it is a temporary local option,
not an agency list fetched from a server. The search, selection, summary,
confirmation, and fixed history demonstrations make no HTTP requests. Only the
separate development API history preview sends a GET request. Flutter does not
save or confirm reservations or check real availability. Prices are only
demonstration estimates: 50 DT/day for Toyota Corolla, 70 for Hyundai Tucson,
and 40 for Kia Picanto. No payments are implemented.

Rental days are the difference between the return and pickup calendar dates.
The calculation uses `DateTime.utc` with only year, month, and day so clock
changes do not alter the number of days. `difference` returns a `Duration`;
`inDays` gives the day count. The estimate is days multiplied by daily price.
The summary also rejects same-day and reversed dates.

## Organization

- `lib/main.dart`: starts the application and sets French localization.
- `lib/screens/reservations/`: search, demonstration results, summary, and
  demonstration confirmation and reservation history screens.
- `lib/screens/reservations/demo/available_cars_demo_data.dart`: temporary sample
  names, categories, and daily prices, separate from future shared vehicle data.
- `lib/custom/reservations/demo_car_card.dart`: reusable demonstration card.
- `lib/custom/reservations/reservation_card.dart`: reusable reservation display
  card. It only displays information; there are no cancellation actions.
- `lib/screens/reservations/demo/reservation_history_demo_data.dart`: fixed
  reservation examples, independent of the confirmation flow and any database.
- `lib/utils/app_theme.dart`: shared blue-and-white styling.
- `lib/models/reservation.dart`: typed history fields and `Reservation.fromJson`.
- `lib/services/reservation_service.dart`: GET request, JSON decoding, and errors.
- `lib/utils/api_config.dart`: the single backend-address setting and labelled
  development test client ID.
- `lib/screens/reservations/reservation_history_api_screen.dart`: separate debug
  preview using `FutureBuilder` and `ListView.builder`.
- `lib/custom/reservations/reservation_api_card.dart`: API data display. It shows
  vehicle IDs because the backend does not supply vehicle names. Millimes are
  displayed in DT with three decimal places; fixed demonstration cards are unchanged.
- `test/reservation_search_screen_test.dart`: form and date-picker widget tests.
- `test/reservation_summary_screen_test.dart`: vehicle selection, transferred
  information, duration, estimated price, invalid dates, and Back navigation.
- `test/reservation_confirmation_demo_test.dart`: dialog details, cancellation,
  continuing to the demonstration message, opening static history, and Back
  navigation. Also checks the existing example of eight days at 50 DT/day = 400 DT.
- `test/reservation_history_screen_test.dart`: fixed example details, all three
  statuses, demonstration labels, and scrolling at iPhone 16 size (393 × 852).
- `test/reservation_model_test.dart`: valid/missing/invalid backend-shaped JSON.
- `test/reservation_service_test.dart`: mocked GET requests, lists, empty results,
  HTTP/data/network errors, and timeout handling.
- `test/reservation_history_api_screen_test.dart`: loading, API cards, empty/error
  states, mobile layouts, separate navigation, and Back to the fixed examples.
- `test/fixtures/reservation_json.dart`: shared test JSON only; creates no records.

No Car or User model has been created. Reuse the group's shared models later.
The teaching examples in `references/` are separate from this project.

## Check

```powershell
flutter analyze
flutter test
```

## Read-only API history — development only

`ApiConfig.baseUrl` in `lib/utils/api_config.dart` is the only address setting:
`http://localhost:3000`. The development client ID is
`000000000000000000000201`, taken from the backend's clearly labelled test fixture.
It does not identify a signed-in user and does not prove a Client record exists.

The service calls `GET /reservations/client/:clientId`, replacing `:clientId` with
that ID. It accepts only HTTP 200 with a JSON array. An empty array means no
reservations matched. HTTP failures, invalid JSON, incomplete records, and network
failures are errors, never a pretend empty result. A 10-second timeout prevents
an unresponsive request from loading forever.

`Reservation.fromJson` reads `_id`, `vehicleId`, `clientId`, pickup/return dates
and locations, `totalPriceMillimes`, and `status`. It checks required types, IDs,
whole nonnegative millimes, the backend's confirmed/cancelled status values, real
UTC-midnight ISO dates, and date order. Extra backend fields such as timestamps
and `reservedDays` are not needed by this history model and are ignored.

The API screen stores its Future in `initState` so rebuilding the screen does
not repeat the request. `FutureBuilder` shows loading, errors, an empty message,
or a list of API cards. No API results are added to the fixed demonstration list.
The debug-only entry button uses normal `Navigator.push` and `MaterialPageRoute`;
Back returns to the examples. `kDebugMode` hides the entry outside debug mode,
and the API screen also avoids starting a request there. This UI check is not
authentication; the backend's existing development/localhost guards remain.

### Local backend and Chrome instructions

In a backend terminal:

```powershell
cd C:\Users\21627\Documents\ChatGPT\d\carrent-backend
$env:NODE_ENV = 'development'
npm start
```

Keep the normal MongoDB configuration. This preview only reads history; do not
enable fixture creation or insert example records into normal `carrent`.
Open the URL below directly in Chrome to verify the backend response:

```text
http://localhost:3000/reservations/client/000000000000000000000201
```

The normal database currently has no reservations. Fixture-based creation tests
saved only in temporary databases and removed them. The expected normal response
is therefore `[]`. A 403 means the existing development/localhost guard refused
access; a 503 means MongoDB is disconnected.

In a separate Flutter terminal:

```powershell
cd C:\Users\21627\Documents\ChatGPT\d\carrent
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 7357
```

Follow the existing demo flow to **Mes Réservations**, then press **Aperçu API —
développement uniquement**. The new screen labels the test client, shows a
spinner, and then shows data, the empty message, or an error. Back must return
to the unchanged three demonstration reservations.

### Development-only CORS support

Port 7357 and port 3000 are different browser origins. The backend now adds
`Access-Control-Allow-Origin: http://localhost:7357` only for a GET to
`/reservations/client/:clientId`, with `NODE_ENV=development` and a real localhost
socket address. It uses `Vary: Origin`, never reflects arbitrary origins, and
does not enable cookies/credentials or CORS on creation/cancellation/conflict
routes. HEAD/OPTIONS receive no CORS permission. Existing backend access checks
remain unchanged. No Flutter model, service, or screen changed for this fix.

Use exactly `--web-hostname localhost --web-port 7357` as shown above. A different
hostname, scheme, or port does not match. Restart Node after the backend change.
Keep browser security enabled; CORS is permission to read a response in the
browser, not authentication or proof of reservation ownership.

Real Chrome verification at 393 × 852 completed the existing demonstration flow,
opened **Mes Réservations → Aperçu API — développement uniquement**, and displayed
**Aucune réservation trouvée**. A real cross-origin browser fetch also returned
200 and `[]` with normal web security. The empty result is successful loading.
The fixed demonstration list remains separate. Successful nonempty lists are
verified with mocked backend-shaped JSON, without inserting database records.

Automated tests use `MockClient` from the same http package and controlled
Futures/Completers for widget states. They do not need a running backend or CORS.
The optional service client and screen Future are small test inputs, not a new
application architecture. `http.runWithClient` supplies a mock during the
navigation test. The existing demonstration widget tests still run unchanged.
