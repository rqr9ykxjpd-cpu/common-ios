# Common — next-build review notes draft

Do not paste this as a claim about build 2. Publish after the new build and
its required Supabase migrations/functions have been deployed and tested.
Keep the reviewer username/password in the dedicated App Store Connect fields;
do not put credentials in this repository.

## Notes for Review

Common is a campus-focused social app for university students; each user sees only their own campus. It is
currently offered in Türkiye. It includes a campus feed (questions, lecture
notes, events, announcements, help requests), study groups, manually selected
campus places, clubs (opened from the feed), meetup requests and messaging.
There is no people-directory or swipe-discovery tab. The main tabs are Feed,
On Campus, Chats and Profile. Clubs is not a tab; it opens as a sheet from
Feed. Existing conversations are preserved.

Study groups: from the feed, a student can post "I will study at <campus
place> at <time>" with a short note and an optional headcount limit. The
group appears as a card above the feed; other students join with one tap and
their avatars are shown on the card. There is no group chat. A group expires
two hours after its start time; the host can cancel it; moderators can remove it.

Founder contact: the founder's profile (badge "Common kurucusu") has a
"Send message" button that opens a direct conversation without a connection
request, so any student can reach the team from inside the app.

Message requests: replying to a story sends a written message request; the
recipient chooses whether to accept before a conversation opens.

A profile card can also be swiped right, but only on a profile the user has
deliberately opened from the feed, a campus place, a notification or a chat.
There is no discovery deck, no card stack to browse and no swipe tab. A
one-way right swipe only sends the other student an introduction request; it
opens no conversation. If both students right-swipe each other, a connection
is recorded and a direct message thread appears in Chats. Either side can
report, block or leave the conversation at any time.
The paywall follows the system appearance and keeps Free / Plus / Pro
comparison on one screen with price and purchase at the bottom.
Student affiliation is not verified in this version. Sign in with Google or
Apple is supported, and a .edu.tr email address is not required.

Use the Google account provided in the Sign-in Information fields. Tap
Continue with Google on the welcome screen. There is no email/password form
inside Common. The reviewer account must have a completed profile and be
tested for access without a second-factor or new-device approval prompt.

To find subscriptions: open Profile, open the settings gear, then tap
"Visitors" ("Ziyaretçiler" on a Turkish device) on a free account. The
locked "Ghost mode" ("Hayalet mod") row also opens the paywall. Choose Common Plus or Common Pro and use the
purchase button. Both subscriptions renew weekly. Products are
com.campus.social.plus.weekly and com.campus.social.pro.weekly. Prices are
provided by StoreKit for the tester's storefront. Restore Purchases, Terms
and Privacy are available at the bottom of the paywall.

To review community safety: use a post, comment or story menu to report that
content; long-press a received chat message to report it. Profiles and chat
menus provide user reporting and blocking. Reports identify the specific
content for moderator review. Text is checked for a defined set of explicit
insults/phrases. There is no claim that all photo/video content is classified
automatically; reports and moderator actions remain necessary.

To delete an account: Profile > settings gear > Delete account permanently.
The app offers native Apple reauthorization when applicable. If Apple access
cannot be revoked automatically, account deletion remains available with
explicit instructions for removing Common from Sign in with Apple settings.
Deleting the app account does not cancel an App Store subscription.

Common does not request GPS access. Campus presence is a place selected
manually by the user for a limited time.

English Terms: https://rqr9ykxjpd-cpu.github.io/common-ios/en/terms.html
English Privacy: https://rqr9ykxjpd-cpu.github.io/common-ios/en/privacy.html

## Build 5 — what changed since build 4 (for "What's New" / internal)

- Study groups (create, join, leave, cancel; cards above the feed).
- "Send message" on the founder's profile.
- Read receipts: messages are now marked read when a conversation is opened
  (server policy fix).
- Content from suspended or blocked accounts no longer appears in the feed,
  comments or stories.
- Restore Purchases no longer hides a plan the server already knows about.
- Moderators and post owners can remove comments.
- Keyboard dismisses when tapping outside a text field.
- Feed no longer stays empty after a cold launch.

Store version: keep 1.0 if build 4 is still unreleased (replace the build);
use 1.0.1 if build 4 has been released.

## Before submission

- Deploy the content-reporting, text-filter, campus-profile, campus-people
  and ghost-at-place migrations on the chosen Supabase project, and validate
  authorization as a regular user/moderator.
- Deploy Apple token revocation and configure its server-only Apple secrets;
  test both automatic revocation and the clearly labelled manual fallback.
- Repair the RevenueCat webhook and confirm a sandbox purchase changes the
  server plan, including restore and expiry handling.
- Test the dedicated reviewer Google account from a fresh device/session.
- Replace remaining old-brand store screenshots with screenshots from the
  tested new build. Upload the matching new build, not the existing build 2.
- Capture the four tabs (Feed, On Campus, Chats, Profile). Clubs is a
  feed sheet, not a tab. Do not reuse or upload old discovery / people /
  swipe screenshots.
  Verify sheet dismissal and place-to-feed filters.
- Club membership currently does not expose a member-profile directory. Do
  not claim that functionality in the review notes until it is implemented.
- Confirm get_introduction_requests and the right-swipe notification trigger
  are deployed on the live Supabase project before describing the
  request-accept-chat flow as working. This was left unverified when the
  previous session ended.
- Publish the matching privacy/terms pages and confirm App Privacy labels
  against actual collection, including custom user ID and purchase history.
- Address the earlier 4.3(b) finding with demonstrable product differences;
  do not describe the community as verified/closed when it is not enforced.
