# 16 — Weighed items, scale & dynamic barcode labels

Per-kg items (fish, meat, produce) priced from an actual weight, read from a USB / serial scale or typed by staff, with an optional printed EAN-13 label that is scanned back at the counter.

POS only — weighed items are hidden from storefront and kiosk menus, and `POST /orders` rejects them for any source other than `pos`.

---

## Menu item fields

Returned on POS bootstrap / `GET /pos/menu` items:

| Field | Type | Notes |
|-------|------|-------|
| `sold_by` | `unit` \| `weight` | `weight` = priced per kg |
| `price` | number | For weighed items this is the **rate per kg** |
| `weight_unit` | string | `kg` (display unit) |
| `plu_code` | string \| null | Short item code embedded in labels. Unique per branch. Required to print labels |
| `min_weight` / `max_weight` | number \| null | Optional limits in kg (3 decimals) |

Weighed items have no variants.

## Restaurant settings — `restaurant.weighing`

Present on POS bootstrap (`restaurant.weighing`) and the web POS restaurant prop.

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `false` | Admin toggle for the feature |
| `prefix` | `"20"` | 1–2 digit EAN-13 prefix for in-store variable-measure codes (GS1 reserves `20`–`29`) |
| `payload` | `"weight"` | `weight` = grams in the barcode (recommended); `price` = line total in the barcode |
| `price_decimals` | `2` | Only for `payload = price` |
| `label_width_mm` / `label_height_mm` | `50` / `38` | Sticker size |
| `label_show_restaurant` / `label_show_date` | `true` | Optional label lines |
| `auto_print_on_stable` | `false` | Default for the weighing station |

---

## Barcode format (EAN-13)

```text
[prefix][PLU, zero-padded][value, 5 digits][check digit]
 "20"    "00123"           "00750"          "2"        → 2000123007502
```

- PLU length = `13 − 1 − 5 − len(prefix)` (5 digits with prefix `20`).
- PLUs compare **without leading zeros** (`00123` == `123`).
- Value: `weight` payload → grams (`round(kg × 1000)`); `price` payload → `round(total × 10^price_decimals)`. Values above `99999` cannot be encoded.
- Check digit: standard EAN-13 (odd positions × 1, even × 3, `(10 − sum mod 10) mod 10`).

Line total = `round(rate × weight_kg, 2)`. Weight is rounded to 3 decimals.

Reference implementations: `App\Support\WeighedBarcode` (PHP), `resources/js/lib/weighedBarcode.js`, `pos_app/lib/utils/weighed_barcode.dart`.

---

## Flow A — scale → label → scan

1. Staff picks the item at the weighing station; the scale streams the weight.
2. `POST /api/v1/pos/weight-labels` with `{ menu_item_id, weight, pos_terminal_code? }`.
   - The server checks `sold_by`, PLU, min/max and value overflow, logs the label (`weight_labels`), and returns `label.barcode` + print fields.
   - Offline: the client may build the same barcode locally (pure function above); checkout still re-validates.
3. Print the sticker: name, weight, rate per kg, total, EAN-13 (ESC/POS `GS k` m=67, HRI below).
4. At the counter, scan the label. Parse it with the restaurant settings, match the item by PLU, add a cart line with `weight` from the barcode and `scanned_barcode`.
   - Reject the same label twice on one ticket.

## Flow B — manual weight

Tap the item, enter a decimal weight (kg or grams), add to cart. No barcode involved.

---

## Cart line → place order

```json
{
  "menu_item_id": 42,
  "quantity": 1,
  "weight": 0.75,
  "scanned_barcode": "2000123007502"
}
```

| Rule | Server behaviour |
|------|------------------|
| `weight` | Required for weighed items (0.001–99.999 kg) unless `scanned_barcode` decodes one |
| `scanned_barcode` | Must be a valid weighed EAN-13 whose PLU matches the item. Its weight / price **overrides** the client `weight` |
| `quantity` | Forced to `1` per weighed line — one line per weighing |
| Pricing | `unit_price = round(rate × weight, 2)`; `unit_rate` = per-kg rate |

Order line payloads (receipts, resume cart, order detail) include `weight`, `weight_unit`, `unit_rate`. Receipts and KOT print `0.750 kg` instead of `1x`, with `@ ₹800.00/kg`.

Errors are 422 with messages such as weight required, weight out of range, invalid label, or weighed item not allowed for this channel.

---

## Scale connection

| Client | Transport |
|--------|-----------|
| Web POS | Web Serial API (Chrome / Edge, HTTPS or localhost) |
| Flutter POS — Android | USB-OTG serial (`usb_serial`: CH34x, CP210x, FTDI, PL2303, CDC) |
| Flutter POS — Windows / macOS / Linux | `flutter_libserialport` (COM / `/dev/cu.*`) |

Default line settings: 9600 baud, 8 data bits, no parity, 1 stop bit. Scales either stream continuously or answer a poll command (e.g. `W\r\n`) sent every `poll_ms`.

Frame parsing (Essae / CAS style), one frame per CR / LF / ETX:

```text
ST,GS,+  0.750kg   → 0.750 kg, stable
US,NT,  1.205 kg   → 1.205 kg, settling
   750 g           → 0.750 kg
0.750              → 0.750 kg (or grams when the unit setting is g)
```

`ST` / `US` flags drive stability when present; otherwise a reading counts as stable after it holds unchanged for `stable_ms` (default 600 ms). Tare is applied client-side.
