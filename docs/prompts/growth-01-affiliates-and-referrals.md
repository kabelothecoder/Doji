# Growth · slice 01 — affiliates, referral codes and discount links

Paste everything below the line into `claude` at the repo root. Run it once real auth and
Supabase are in (after phase 1 slice 03).

---

You are working on doji, a Flutter trading-discipline app (iOS, Android, Windows). Read
`CLAUDE.md` and `design/SOURCE.md` first and follow them exactly. Copy rules apply to every
referral screen, share text and affiliate asset: no profit promises, no "payout guaranteed", no
win rates, no testimonials doji can't prove.

## Goal

Let affiliates (trading educators, prop-firm communities, Discord owners) and normal users bring
traders to doji with a **link** or a **code**, and reward them.

1. **Codes and links.** Each affiliate and each signed-up user gets a code (`KABS20`-style, unique,
   case-insensitive) and a link `https://<domain>/r/<code>`. The link opens the store page, or the
   app if installed (deep link through the same scheme planned for Windows auth). The code can
   also be typed on signup or later in settings (one per account, within 14 days of signup).
2. **What the referred trader gets**: a discount on the first paid period. It must go through each
   store's own mechanism, never a price outside the store for digital subscriptions:
   - iOS: App Store **offer codes** / promotional offers on the subscription;
   - Android: Google Play **promo codes** / developer-determined offers;
   - Windows: Microsoft Store promo codes or the store's own discount.
   Read each store's current rules first and write in the plan exactly which mechanism is used
   and what Apple / Google allow (incl. any region-specific external-link rules). Map doji's
   referral code to the store offer server-side.
3. **What the referrer gets**: affiliates earn a revenue share; users earn free time (e.g. a month
   of pro per paying referral). Commission is only counted from the store's real transaction
   notifications (App Store Server Notifications, Google Play RTDN), after the refund window,
   never from client calls. Payouts to affiliates are manual exports for now (CSV), no payment
   rails in the app.
4. **Tables** (Supabase migration, RLS): `affiliates`, `referral_codes`, `referrals` (code,
   referred user, signup time, first paid time, status), `commissions`. Users read only their own
   rows; only the server writes status and money.
5. **In app**: settings › invite: the code, share link, copy button, "x traders joined", rewards
   earned. Signup: an optional "have a code?" field (skippable, a11y labelled). An affiliate view
   (web page is fine) with clicks, signups, paid conversions, commission due.
6. **Fraud**: no self-referral (same user / device / payment), rate limits on code checks, codes
   can be paused, attribution = first valid code.
7. **Measuring**: count link clicks, installs with a code, signups, first paid, still paying after
   2 months, per code. No third-party tracking SDKs without asking me first; respect store
   privacy labels.

## Rules

- Plan first: the store mechanisms per platform with links to the rules you read, the tables and
  policies, the edge functions (code check, store notification webhooks), every file and test.
  Wait for my OK.
- Tests: code generation and validation, attribution rules, self-referral blocks, commission only
  after a real paid event (fake store notifications), copy scan on all new strings.
- Do not apply migrations, deploy, commit or push unless I ask.
