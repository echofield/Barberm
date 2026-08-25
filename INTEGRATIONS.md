# Barberm — MVP integration contract

The client site and dashboard are currently a presentation. `schema.sql` defines the future source-of-truth model.

## 1. First live integration: bookings

Barberm only needs a small booking feed to become useful:

- booking id
- client name / phone / email
- barber
- service
- appointment start
- status: booked / completed / cancelled / no-show
- price when available

Preferred order:

1. official booking-provider API or webhook;
2. scheduled CSV/export ingestion;
3. manual import for the first pilot.

Do not make Barberm the booking system at first. Keep the existing provider as the booking source of truth and add the retention layer around it.

## 2. Passport capture

After a completed visit, create/update a Passport with:

- client
- barber
- visit date
- style name
- optional barber notes
- optional photo
- visit count

A QR shown at the chair or on the receipt can open the client's Passport without requiring a full account in the first pilot.

## 3. Return-window model

For every client with at least two completed visits:

`usual_return_days = median(days between completed visits)`

Suggested state:

- `too_early`: before 80% of their usual interval
- `return_window`: 80–125%
- `overdue`: 125–180%
- `cold`: >180%

Never recommend a reactivation if the client already has a future booking.

For clients with insufficient history, use a salon/service default until individual history exists.

## 4. Immediate actions

Dashboard actions should become `retention_actions` records.

### Reactivation

Target only clients in `return_window` or `overdue`, excluding:

- future bookings
- recent outbound contact
- no marketing consent where consent is required

Suggested safety rule for the pilot: no more than one automated retention message per client in 14 days.

### Reward reminder

Only when a client is one visit away from a defined reward.

### Referral follow-up

Only for an open referral where the invited client has not booked yet.

### The Chair

The owner selects or accepts a recommended weak inventory slot. The system never places the free slot into already high-demand inventory unless the owner explicitly chooses it.

## 5. Messaging layer

Do not hard-wire a vendor into product logic.

Use a channel adapter with these conceptual methods:

- `send_sms(client, template, context)`
- `send_email(client, template, context)`
- later: WhatsApp / push

Every outbound should write back:

- action id
- client id
- channel
- sent time
- template/version
- delivery status when available

## 6. Attribution

Barberm should show four different states clearly:

1. **Potential value** — estimated value of clients who could be recovered.
2. **Actioned value** — potential value associated with actions actually sent.
3. **Booked value** — bookings created after an attributable action.
4. **Observed revenue** — completed visits / paid value, when the booking source provides it.

Do not display potential value as earned revenue.

A conservative first attribution rule:

- client received a Barberm action;
- client booked within 7 days;
- booking happened after the action;
- no future booking existed before the action.

Keep `source_action_id` on the booking/attribution event so the owner can inspect why Barberm claims influence.

## 7. Dashboard definitions

### Active clients
Clients with a completed visit or active Passport in the selected period.

### Repeat rate 45d
Percentage of eligible clients who completed another visit within 45 days.

### At risk
Clients past their expected return window, without a future booking.

### Return revenue
Completed-visit value from existing clients. Barberm-influenced return revenue should be a separate metric.

### Fill rate
Booked chair-time / available chair-time for the selected window.

## 8. Pilot sequence

**Pilot 0 — presentation**
Current client site + dashboard demo.

**Pilot 1 — read-only salon data**
Import bookings and completed visits. Dashboard recommendations are real, actions remain manual.

**Pilot 2 — action layer**
Owner can trigger a retention message from Barberm. Log every action.

**Pilot 3 — attribution**
Match resulting bookings and completed visits back to actions.

**Pilot 4 — automation**
Only after the salon trusts the recommendations: optional scheduled reactivation, reward reminders, referral follow-ups and The Chair orchestration.

## 9. The real owner 'aha'

The dashboard should answer, in order:

1. Who should I act on today?
2. What should I do?
3. Why these clients / this slot?
4. What value is at stake?
5. What happened after I acted?

Everything else is secondary analytics.
