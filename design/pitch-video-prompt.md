# Claude Design prompt: doji pitch explainer video (~15 min)

Paste everything below the line into Claude Design (Doji project, design system `Doji Design System.dc.html`).
Voiceover is recorded separately in Fish Audio (see "Fish Audio voiceover" at the end).

---

Make a ~15-minute science-explainer video that pitches **doji** to a business partner. Use the Doji design system in this project for every colour, font, radius and motion spec.

## Goal and audience

- Viewer: my business partner. They like money, so the market gap, revenue and partnership parts must be long, concrete and visual.
- Balance: product and vision first, then a long money section, then the hard questions answered honestly.
- After watching, they should understand what doji is, the gap it fills, how it grows, how it makes money, and the risks.

## Format

- 16:9, 1920x1080, ~15:00, 13 chapters with a title card each.
- Style: a mix. Animated science diagrams (flat shapes, candles, flow lines, Kurzgesagt-like) for ideas; real doji app screens floating on a dark stage (Apple-keynote-like) for the product.
- Narration: write the full voiceover script, ~2,200 words (about 150 words a minute), split per scene with time codes. Also show short kinetic captions on screen (lowercase, calm).
- Leave silent breathing room: 1-2s between scenes, no music under the key numbers.
- Deliver: a scene-by-scene storyboard (scene, time code, visuals, voiceover text, on-screen text, transition), then the animated frames. Export the voiceover as one plain-text block per scene, labelled `S01`, `S02`..., so each can be pasted into Fish Audio.

## Brand (from the design system)

- Background `#050607`, surfaces `#0F1113` / `#17191C`, separator `#26292E`.
- Text `#F5F5F7` / `#A1A1A6` / `#6E6E73`.
- doji-green `#2FD67B` = rule kept, primary. tilt-orange `#FF9F0A` = risk, rule broken.
- Grid L0-L4: `#101A14 → #16391F → #1E6B3E → #27A35C → #2FD67B`.
- Fonts: Geist + Geist Mono. Glass: elevated-1 at 60%, blur 24-30, 1px white at 8%.
- Motion: spring.standard 380/34, grid fill 360ms with 4ms stagger, blinking terminal cursor.
- Price candles are always neutral grey. Green and orange always come with a text label.
- Copy voice: lowercase, calm, honest.

## Assets (attached: use these, don't redraw the product)

Logo (`design/pitch-assets/logo/`):
- `doji-symbol.svg`: the doji mark. Use for the logo reveal (chapter 1), the name/logo story (chapters 2-3) and the end card.
- `doji-app-icon.svg` / `app_icon.png`: the app icon on a phone home screen, for the close.

App screenshots (`design/pitch-assets/screens/`, real renders from the app). Show them in device frames (iPhone for `_phone`, a Windows window for `_windows`) on the dark stage:
- intro animation frames, for the name chapter (the candle becomes a perfect doji): `intro_k1_candle_rises`, `intro_k2_wiggle_down`, `intro_k3_perfect_doji`, `intro_k4_typed`, `intro_k5_landed`.
- onboarding (chapter 6): `boot_phone`, `question_risk_phone`, `compile_phone`, `pledge_phone`; Windows: `question_risk_windows`, `pledge_windows`.
- sign-in and app lock: `auth_a1_welcome_phone`, `auth_a9_success_phone`, `auth_a8b_locked_phone`.
- markets and the AI brief (chapters 6-7): `markets_list_phone`, `markets_list_windows`, `markets_1b_phone`, `markets_1b_brief_phone`, `markets_1b_locked_phone` (free-plan limit, for the money chapter), `markets_search_phone`.
- chart and co-pilot (chapter 7): `chart_zone_phone`, `chart_level_phone`, `chart_trendLine_phone`, `chart_position_phone`, `chart_windows`.
- AI coach (chapter 7): `coach_1c_phone`, `coach_listening_phone`, `coach_windows`.
- practice: backtest refine and gym (chapter 6): `practice_compare_phone`, `practice_compare_windows`, `practice_drill_phone`.

Missing screens (draw a placeholder frame labelled "screen coming"; I'll replace it): home with the loss-limit and drawdown meters, the tilt warning, the journal with process grades, the discipline grid, replay, plans.

## Hard copy rules (never break)

doji is a trading-discipline app, not a signals app. No buy/sell calls, no "signals", no "guaranteed", no win rates, no profit promises for traders, no invented testimonials. Business figures are **targets and assumptions**: label each one "target" or "assumption" on screen. Market figures are labelled "widely reported" or "industry estimate".

## The numbers (use exactly these)

**Plans (from the app, monthly; annual = 10x monthly, "2 months free"; 3-day trial on paid plans)**

| plan | USD | ZAR | for |
|---|---|---|---|
| free | $0 | R0 | journal, grid, 1 ai brief a day |
| basic | $9 | R149 | unlimited ai chat, setup memory |
| pro trader | $24 | R399 | full toolkit, strategy analyzer, 60 voice-coach min |
| elite prop | $99 | R1,499 | voice coach, multiple prop accounts, pdf reports |

**Unit economics (assumptions)**

- paid mix: 50% basic, 40% pro, 10% elite → blended ~$24 per paid user a month.
- after app-store fees (15-30%) and AI costs (~$1-2 per paid user a month): ~$17 net per paid user a month.
- free to paid: 4%. So 25 free users make 1 paying user.
- monthly churn on paid: 8% (traders quit after a blown account; the gym and streaks exist to lower this).

**Milestone ladder (targets, no dates)**

| step | paid users | free users needed (at 4%) | MRR | ARR |
|---|---|---|---|---|
| 1. proof | 100 | 2,500 | $2.4k (~R43k) | $29k |
| 2. ramen | 1,000 | 25,000 | $24k (~R430k) | $288k (~R5.2M) |
| 3. team | 5,000 | 125,000 | $120k (~R2.2M) | $1.44M (~R26M) |
| 4. scale | 20,000 | 500,000 | $480k (~R8.6M) | $5.8M (~R104M) |
| 5. category leader | 100,000 | 2.5M | $2.4M | $29M |

(ZAR at ~R18 = $1, assumption.)

**Partnership revenue (vision, industry-typical ranges, to be negotiated)**

- prop firms: 10-20% referral on challenge fees (typical challenge $50-$500). Example: 1,000 challenges a month × $150 × 15% = **$22.5k a month**.
- brokers (Deriv, MT5 brokers): flat CPA per funded referral, typically $100-$400. Example: 300 funded accounts a month × $200 = **$60k a month**. (We take flat CPA, not per-lot rebates: see chapter 11.)
- educators and creators: we pay them 20-30% recurring of the plans they bring; they bring their students in bulk.
- platforms and data: news-calendar, charting and data partners; co-marketing, app-store featuring, later a white-label doji for prop firms (B2B licence, target $2k-$10k a month per firm).
- At step 4, partnerships add a target **20-30%** on top of subscriptions.

## Chapters (15:00)

1. **cold open (0:00-0:50)**: a trader at 2am, red screen, revenge trade, account blown. Line: most traders don't fail on strategy, they fail on discipline. Logo reveal.
2. **the name (0:50-1:50)**: animate a doji candle forming: open and close at the same price, buyers and sellers in balance. That is the trader doji builds: calm, balanced, waits for their own setup instead of forcing trades.
3. **the logo and brand (1:50-2:50)**: the logo grows out of the doji candle; dark-first palette; green means "rule kept" (not profit), orange means "risk"; the discipline grid as the brand's signature, like a fitness ring for traders.
4. **the problem, as science (2:50-4:00)**: diagram of the tilt loop: loss → emotion → bigger size → broken rule → bigger loss. Widely reported: most prop challenge takers fail, mostly on daily loss and drawdown rules, which are discipline, not strategy. Show how a rule plus a pause breaks the loop.
5. **the whitespace (4:00-5:20)**: a 2x2 map. x-axis: looks back (journals) → acts live (in the moment). y-axis: hype (signals) → discipline.
   - signal groups / gurus: live, but hype and calls.
   - journals (Tradezella, Edgewonk, TraderSync-style): discipline, but only after the damage, desktop-first.
   - charting AI (TradingView-style): live, but about the chart, not the trader.
   - prop firm dashboards: show the rules, don't coach.
   - **empty quadrant: live + discipline. doji sits there.**
   Then the gaps we fill, one card each: an AI coach that refuses to give calls; prop rules + trailing drawdown measured live; Deriv synthetics (huge in Africa, ignored by western tools); mobile-first with voice; the trader's own strategy in their own words, not an indicator menu; local pricing in rand.
   Then a "fill-in" card, visibly blank with a cursor: "your idea here" (for the partner to add gaps live in the meeting).
6. **how doji helps traders (5:20-7:20)**: real app screens: onboarding in their own words; home with the daily loss limit and prop drawdown meters; tilt warning after 2 losses in a row; post-trade sheet; journal with process grade A-F (graded on following the plan, not on profit); markets with the trader's own strategy "met / forming / waiting"; backtest, replay and gym drills; multiple accounts (prop challenge, Deriv synthetics, personal).
7. **ai features (7:20-8:40)**: the AI brief (measured conditions, never a prediction), ask-the-brief chat, voice coach (talks the trader down, refuses calls, crisis line first), chart co-pilot ("what is this?" on each drawing), pre-trade check, strategy reader (spoken strategy → checkable conditions). The safety guard: every AI reply is checked against the copy rules before the trader sees it. The model key never leaves our server.
8. **the cult chase (8:40-9:40)**: a cult-brand community like Apple or Supreme, for disciplined traders: streaks, the green grid people screenshot and share, practice days, ranks, later in-app community chat. Identity: "i'm a doji trader" = i keep my rules.
9. **how we scale (9:40-11:00)**: growth-engine flywheel diagram:
   - paid ads (meta, tiktok, youtube), aiming at CAC under $40 per paid user (assumption; payback ~2-3 months at $17 net).
   - AI UGC videos: many short creative variants a week, cheap testing.
   - long-form forex education videos on youtube: trust and search traffic.
   - giveaways: funded prop challenges and elite months for streaks.
   - community + streak sharing: every shared grid is an ad.
   - creators and affiliates bring students in bulk.
   - free plan funnel: free brief + journal → upgrade.
   - multi-market expansion: forex, synthetics, prop traders first (SA, Nigeria, Kenya, then UK/EU/US); futures, stocks later.
10. **the money (11:00-12:40)**, longest and most visual:
    - the plans table.
    - unit economics as a funnel: 25 free → 1 paid → $24 → $17 net.
    - the milestone ladder as rising steps on the green grid, each labelled "target".
    - partnership streams as a vision, with the worked examples above.
    - a stacked bar per ladder step: subscriptions vs partnerships vs B2B.
11. **the business, heavily criticised (12:40-14:05)**: tone: we attack our own model harder than an investor would, then fix it. Layout per card: the critique in orange (labelled "critique"), a severity bar (low / medium / high, as text), the fix in green (labelled "fix"). Group them:

    **revenue structure**
    - critique (high): "your partnership money depends on traders losing. prop firms earn on failed challenges; brokers earn on volume. a discipline app paid by the people who profit from indiscipline is a contradiction." → fix: flat CPA only, never per-lot or loss-based revenue share; cap partnerships at ~30% of revenue so subscriptions stay the core; publish an affiliate policy in the app; partner only with firms that pay out reliably and have clear rules; doji can walk away from any partner.
    - critique (high): "subscriptions for traders are a leaky bucket. 8% monthly churn means you replace your whole base every year." → fix: annual plans (2 months free) pushed at the first green streak; the gym and replay give value between accounts; churn-save offers (pause, not cancel); prop traders re-subscribe each new challenge.
    - critique (medium): "app stores take 15-30% and AI bills grow with every user." → fix: web and Windows checkout where store rules allow; per-plan AI limits already enforced on the server; cheap model for the brief, better model only for the coach; price AI-heavy features in pro and elite.
    - critique (medium): "four plans is too many for a new brand." → fix: test free / pro / elite first, keep basic only if data shows it converts.

    **market and growth**
    - critique (high): "trading apps are ad-restricted. meta, google and tiktok limit financial ads." → fix: lead with education content and creators (organic), position ads as a discipline / journaling tool not a trading product, follow each platform's financial-services policy, get certified where required.
    - critique (medium): "CAC under $40 is a guess." → fix: step 1 (100 paid) is a measurement step; no paid scale until CAC payback is under 3 months.
    - critique (medium): "small home market: SA and Deriv synthetics are niche." → fix: SA is the test market, not the ceiling; the product is market-neutral already (forex, CFDs, crypto, futures and stocks in the model).
    - critique (medium): "a 'cult' brand can turn toxic, like signal groups." → fix: the cult is built on rules kept, never on profits shown; no P&L leaderboards, only streaks and process grades.

    **company structure**
    - critique (high): "two founders, no legal or compliance person, regulated industry." → fix: legal review per country before launch (FSCA in SA, FCA in the UK etc.); doji gives no advice and no calls, every AI reply passes a copy-rule guard; a fractional compliance advisor from step 2.
    - critique (high): "who owns what? who does what?" → fix: a written founder agreement (equity split, vesting over 4 years with a 1-year cliff, roles: product/tech vs growth/partnerships, decision rules, exit terms) before any money comes in. (Leave the split as a blank card for us to fill.)
    - critique (medium): "one developer = key-person risk." → fix: the codebase is documented and tested; hire a second engineer at step 2.
    - critique (medium): "copycats: TradingView or a prop firm builds this." → fix: moats are the trader's own history (journal, replays, versions), the community, and trust from refusing to sell calls; white-label doji to prop firms so they partner instead of compete.
    - critique (low): "is 4% conversion realistic?" → fix: it's an assumption; step 1 measures it before we spend.

    End with a blank "partner's critique" card with a blinking cursor, for live Q&A.
12. **future predictions (14:05-14:40)**: label the whole chapter "our predictions, not facts". A timeline that fills in left to right:
    - AI coaches become normal in trading apps; the winners are the ones traders trust because they refuse to give calls.
    - prop firms keep growing and get regulated harder; firms will want tools that keep their traders inside the rules: B2B demand for doji.
    - regulators push back on signal sellers and finfluencers; honest discipline tools gain.
    - voice-first coaching on phones and wearables during the trading session.
    - trader identity becomes portable: a verified "discipline record" (streaks, process grades) that a prop firm could accept as proof. doji could own that record.
    - Africa's retail trading base keeps growing on mobile; first-mover advantage for a local-priced, mobile-first tool.
13. **close (14:40-15:00)**: the vision: doji becomes the go-to discipline platform for traders. Back to the trader from scene 1, now calm, closing the day on a green grid. Logo, tagline "keep your rules.", "let's build it."

## Notes

- Keep every scene readable without sound.
- Accessible: text contrast at least 4.5:1, nothing signalled by colour alone.
- Leave the blank "fill-in" cards (chapter 5, chapter 11's founder split and partner's critique) clearly editable.

## Fish Audio voiceover

The voiceover is generated with **Fish Audio** (fish.audio, text-to-speech), via its MCP server (`https://api.fish.audio/mcp`) or the web app. Write the script so it can be pasted straight in.

**Voice**
- One narrator for the whole video: a calm, warm, English documentary voice, mid-pitch, unhurried (Fish Audio voice library: search "calm narrator" / "documentary"). Optionally a cloned founder voice for the close (chapter 13).
- Optional second voice for the critique cards in chapter 11: a sharper, sceptical voice reads each critique; the narrator reads each fix.

**Script format**
- Plain text only, one block per scene, labelled `S01`, `S02`... with a timing note, e.g. `S04 · 70s · narrator`.
- No markdown, no symbols the voice would read aloud: write "twenty-four dollars", "four percent", "R three ninety-nine", "one point four four million".
- Keep each block under ~300 words so it renders in one Fish Audio generation.
- Use Fish Audio audio tags in square brackets to direct delivery, sparingly:
  - `[calm]` for the narrator by default, `[serious]` for the problem and critique chapters,
  - `[excited]` only on the milestone ladder and the close,
  - `[pause]` or a line break before every key number, so the number lands with silence around it.
- Read "doji" as "DOH-jee" (add a pronunciation note at the top of the script).
- Captions on screen use the same words as the voiceover, shortened.

**Hand-off**
- At the end, output the full script as one `voiceover.txt` (all scene blocks in order) and a timing table (scene, start, end, voice, word count), so each Fish Audio clip can be dropped onto the video timeline at its scene.
- Total ~2,200 words for 15:00. Budget: Fish Audio bills 1 credit per character, so the script is ~13,000 credits.
