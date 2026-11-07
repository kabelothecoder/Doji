// The copy rules (CLAUDE.md › no buy/sell language) and the crisis check,
// shared by every AI function. The Dart side keeps the same list in
// lib/core/copy_rules.dart; both are tested against copy_rules.json.

import rules from "./copy_rules.json" with { type: "json" };

export const BANNED: readonly string[] = rules.banned;

/** True when [text] says something doji never says. */
export function breaksCopyRules(text: string): boolean {
  // Punctuation becomes a space so "sell." and "buy," are caught like the padded scan in the tests.
  const t = ` ${text.toLowerCase().replace(/[^a-z0-9'%\s-]/g, " ").replace(/\s+/g, " ")} `;
  return BANNED.some((b) => t.includes(b));
}

// Same words as FakeCoach's crisis intent (lib/features/coach/data/fake_coach.dart).
const crisisRe =
  /\b(kill myself|suicid\w*|want to die|wanna die|end my life|hurt myself|self[- ]?harm\w*|don'?t want to (live|be here)|no reason to live)\b/i;

export const isCrisis = (text: string): boolean => crisisRe.test(text);

/** Same line as FakeCoach.replyFor(CoachIntent.crisis). Decided in code, never by the model. */
export const CRISIS_REPLY =
  "that matters more than any trade. i'm a trading coach, not a counsellor, so please talk to " +
  "someone now: SADAG on 0800 567 567, any hour. you can come back to this after.";

export const COACH_FALLBACK = "i'll leave the market out of it. what does your plan say about this one?";
export const CHAT_FALLBACK = "that's outside what this brief can say. look at your conditions above.";

export const COPILOT_FALLBACK = "what in your written rules does this mark?";

// Words that rate a setup or its odds. Same pattern as ratesOdds in
// lib/features/chart/domain/copilot.dart.
const oddsRe =
  /\b\d+\s?%\s+(chance|probab\w*|likel\w*|of (these|them|trades|setups|the time))|\b(likely|unlikely|probab\w*|odds|chances?|high[- ]quality|low[- ]quality|good setup|bad setup|strong setup|weak setup|will (go|hit|reach|break|reverse|bounce|work))\b/i;

/** True when [text] rates a setup or its odds: the co-pilot never does. */
export const ratesOdds = (text: string): boolean => oddsRe.test(text);
