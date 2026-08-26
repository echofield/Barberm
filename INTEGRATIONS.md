# Barberm — MVP integration contract

Barberm is intentionally split into **two independent products**.

## A. Barberm Site

The client-facing site must keep working without Barberm Retention.

Core responsibilities:
- public salon page;
- services and barber discovery;
- compressed booking flow;
- existing booking provider remains source of truth;
- WhatsApp shortcut with prefilled context;
- lightweight Barber Passport;
- optional Monday Chair / referral / visit reward presentation.

Commercial demo assumption:
- 600 EUR first year;
- hosting / light maintenance included for year one;
- 300 EUR annual renewal after year one.

No Retention subscription is required for the site to continue working.

## B. Barberm Retention

Retention is an optional layer around the existing site and booking data.

Commercial pilot assumption:
- 3 months free;
- then 249 EUR/month if the salon chooses to keep it;
- stopping Retention must never disable the client site or booking flow.

The owner cockpit answers, in this order:
1. Who should I act on today?
2. What is the next best action?
3. What value is potentially at stake?
4. What happened after the action?

The default UI should remain compressed: **reactivate clients / fill weak inventory / reward near-returning clients**. Analytics are secondary.

## 1. Booking integration

Do not rebuild the booking provider first.

Barberm only needs a small booking feed:
- booking id;
- client name / phone / email;
- barber;
- service;
- appointment start;
- status: booked / completed / cancelled / no-show;
- price when available.

Preferred order:
1. official booking-provider API or webhook;
2. scheduled CSV/export ingestion;
3. manual import for the first pilot.

The client-facing flow can collect service + barber context before forwarding the user to the booking provider. This preserves a Barberm experience without pretending Barberm owns inventory it cannot yet read.

## 2. WhatsApp-first action layer

For the first salon pilots, WhatsApp is the preferred retention channel because it is immediate and familiar.

Product logic must not depend on WhatsApp specifically. Use a channel adapter so SMS, email or push can be added later.

Conceptual interface:
- `prepare_message(client, template, context)`
- `send_whatsapp(client, template, context)`
- `send_sms(client, template, context)`
- `send_email(client, template, context)`

Every outbound action should record:
- action id;
- client id;
- channel;
- reason;
- template/version;
- sent time;
- delivery status when available.

Pilot safety rule: no more than one automated retention message per client in 14 days unless the owner explicitly overrides it.

## 3. Passport capture

After a completed visit, create/update a Passport with:
- client;
- barber;
- visit date;
- style name;
- optional notes;
- optional photo;
- visit count.

A QR at the chair or on the receipt can open the client's Passport without requiring a full account during the pilot.

## 4. Return-window model

For clients with at least two completed visits:

`usual_return_days = median(days between completed visits)`

Suggested states:
- `too_early`: before 80% of usual interval;
- `return_window`: 80–125%;
- `overdue`: 125–180%;
- `cold`: >180%.

Never recommend a reactivation when the client already has a future booking.

For insufficient history, use a salon/service default until individual history exists.

## 5. Three immediate owner actions

### Reactivate
Target clients in `return_window` or `overdue`, excluding future bookings and recent outbound contact.

### Monday Chair
Recommend a weak inventory slot. Never place a free slot in already high-demand inventory unless the owner explicitly chooses it.

### Reward reminder
Only target clients one visit away from a defined reward.

These actions must remain independently triggerable. Failure or deactivation of one should not block the others.

## 6. Attribution

Barberm must distinguish four states:
1. **Potential value** — estimated value that could be recovered.
2. **Actioned value** — potential attached to actions actually sent.
3. **Booked value** — bookings created after an attributable action.
4. **Observed revenue** — completed / paid visits when the source provides it.

Never display potential value as earned revenue.

Conservative initial attribution:
- Barberm action was sent;
- client booked after the action and within 7 days;
- no future booking existed before the action;
- source action id is retained for inspection.

## 7. Pilot sequence

**Pilot 0 — presentation**
Current client site + cockpit with simulated actions.

**Pilot 1 — read-only data**
Import bookings and visits. Recommendations become real; actions remain manual.

**Pilot 2 — 3-month free Retention trial**
Enable owner-triggered WhatsApp / messaging actions and log them. Site remains independent.

**Pilot 3 — attribution**
Match resulting bookings and completed visits to actions and show booked vs observed revenue.

**Pilot 4 — paid Retention**
Only continue at 249 EUR/month if the salon chooses to keep it after seeing measurable value.

**Pilot 5 — optional automation**
Automate selected reactivation, reward reminders and Monday Chair only after owner trust is established.

## 8. Core principle

The product should feel like this:

**Site:** book → remember → return.

**Retention:** see → act → measure.

Neither product should be technically or commercially dependent on the other.