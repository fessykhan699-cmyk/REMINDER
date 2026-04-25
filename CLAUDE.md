---
# Invoice Flow — Claude Code Project Instructions

## Memory System — READ THIS ORDER EVERY SESSION
1. FIRST: Check graphify-out/graph.json for code structure
2. SECOND: Check C:\Users\fessy\vault\invoice-flow\ for decisions and context
3. THIRD: Only read raw Dart files when actually editing

## Session Start
- Always /resume before starting work
- If no /resume given, ask: "Should I /resume first?"

## Session End
- Always /save before closing

## Project Rules
- Flutter/Dart only — no backend unless I ask
- Hive for ALL local storage
- Firebase Auth for login
- Google Play Billing for subscriptions
- UAE context: AED currency, VAT awareness

## Hard Rules
- Auth methods MUST set session state BEFORE calling _triggerCloudRestore. Never after.
- Riverpod controller build() MUST NOT use _didLoad-style class fields to guard loadInitial. Always schedule loadInitial unconditionally.
- _triggerCloudRestore MUST invalidate every controller that reads restored data (invoices, clients, dashboard, and any new ones).
- Silent catch blocks are forbidden. Every catch logs with [Tag] prefix and stack trace.
- [DIAGNOSTIC]-prefixed logs are temporary debugging only and must be deleted before release.
- See vault/invoice-flow/decisions/active-decisions.md for full rationale and code examples.

## Current Sprint
- [Claude will update this on /save]
---
