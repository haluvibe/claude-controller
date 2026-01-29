# Gmail Unsubscribe - Learning Memory

This file stores preferences and learned decisions for email organization.

## Last Updated
2026-01-29 (Session 9)

---

## Unsubscribe Preferences

### Always Unsubscribe (Marketing/Promotional)
| Sender | Domain | Category | Date Added | Notes |
|--------|--------|----------|------------|-------|
| Uneed | uneed.best | Newsletter | 2026-01-28 | Weekly product newsletter (Bento platform) |
| HeyGen | email.heygen.com | Product Marketing | 2026-01-28 | AI video tool promotions |
| Interdiscount | info.interdiscount.ch | Retail Marketing | 2026-01-28 | Swiss electronics retailer birthday promos |
| Flippa | flippa.com | Marketplace Marketing | 2026-01-29 | Business marketplace promos, marketing@ sender, HubSpot |
| Republic Europe | republic.com | Investment Marketing | 2026-01-29 | Private equity/investment promos, Mailchimp |
| Bubble | mail.bubble.io | Newsletter | 2026-01-29 | No-code platform newsletter, newsletter@ sender |
| Spotify | spotify.com | Win-back Marketing | 2026-01-29 | Premium re-subscription promos, no-reply@ sender |
| Aussie Home Loans | mc.aussie.com.au | Financial Marketing | 2026-01-29 | Home loan marketing via Mailchimp |
| Coopers Group | coopers.ch | Recruiting Newsletter | 2026-01-29 | Monthly IT jobs newsletter via Mailchimp |
| WEF Strategic Intelligence | email.weforum.org | Newsletter | 2026-01-29 | Annual meeting highlights, event digest |
| Ticketcorner | ticketcorner.ch | Promo/Coupon | 2026-01-29 | Swiss ticketing birthday coupons, no List-Unsubscribe header |
| Turkish Airlines | turkishairlines.com | Airline Marketing | 2026-01-29 | Birthday promo emails, no List-Unsubscribe header |
| SEEK | seek.com.au | Job Marketing | 2026-01-29 | Job search save prompts, marketing via SendGrid |

### Auto-Trash (delete without reading)
| Sender | Domain | Category | Reason |
|--------|--------|----------|--------|
| Google Cloud Alerting | alerting-noreply@google.com | Dev Alerts | Firebase billing/usage alerts — auto-trash |
| Firebase | firebase-noreply@google.com | Dev Alerts | Crash reports — auto-trash |

### Auto-Read + Archive (low-priority, not trash)
| Sender | Domain | Category | Date Added | Notes |
|--------|--------|----------|------------|-------|
| Slack | no-reply@slack.com | Workspace | 2026-01-29 | Content deletion notices, workspace updates |
| Facebook Developers | developers.facebook.com | Dev Alerts | 2026-01-29 | API version upgrades, SDK updates |
| Wise | wise.com | Financial Account | 2026-01-29 | Privacy/policy notices (NOT transactions/security) |
| Ubisoft | updates.ubisoft.com | Account | 2026-01-29 | ToS/privacy updates |
| LinkedIn | linkedin.com | Social/Professional | 2026-01-29 | Connection updates, endorsements, notifications |
| Patreon | patreon.com | Creator Updates | 2026-01-29 | Subscribed creator content updates |
| Reddit | redditmail.com | Social/Forum | 2026-01-29 | Comment replies, chat requests, subreddit notifications |
| YouTube | youtube.com | Social/Creator | 2026-01-29 | Subscriber notifications, channel updates |
| Render | render.com | Dev Platform | 2026-01-29 | Subprocessor updates, platform marketing |
| TestFlight | apple.com (TestFlight) | Dev Builds | 2026-01-29 | Build processing notifications |
| App Store Connect | apple.com (ASC) | Dev Builds | 2026-01-29 | Build upload confirmations, review status |
| Aussie Broadband (maintenance) | aussiebroadband.com.au | ISP Notices | 2026-01-29 | Network maintenance notices (NOT receipts/invoices) |
| POF (Plenty of Fish) | pof.com | Social/Dating | 2026-01-29 | Match notifications, likes, messages |

### Keep Unread (Important)
| Sender | Domain | Category | Reason |
|--------|--------|----------|--------|
| Google | accounts.google.com | Security | Security alerts — always keep unread |
| Belle Property | belleproperty.com | Real Estate | User interested in property listings |
| Oz Combined Realty | ozcomrealty.com.au | Real Estate | Property alert matching |
| Ray White | raywhite.com | Real Estate | Agent listings updates |

### Needs Review (Uncertain)
| Sender | Domain | Category | Notes |
|--------|--------|----------|-------|
| NAB | nab.com.au | Mixed (Bank) | Marketing + legitimate account emails mixed — needs per-email review |

---

## Sender Categories

### Auto-Trash Senders
- `alerting-noreply@google.com` - Firebase billing alerts (delete without reading)
- `firebase-noreply@google.com` - Crash reports (delete without reading)

### Auto-Read + Archive Senders (low-priority, mark read + archive)
- `*@slack.com` - Workspace notices (not security)
- `*@developers.facebook.com` - Dev platform updates
- `*@wise.com` - Financial account notices (not transactions/security)
- `*@updates.ubisoft.com` - Account/ToS updates
- `*@linkedin.com` - Professional network notifications
- `*@patreon.com` - Creator subscription updates
- `*@redditmail.com` - Forum/comment notifications
- `*@youtube.com` - Subscriber notifications
- `*@render.com` - Dev platform updates
- `*@apple.com` (TestFlight/ASC builds) - Build processing/upload notifications
- `*@aussiebroadband.com.au` (maintenance only) - Network maintenance notices
- `*@pof.com` - Dating app notifications

### Keep Unread Senders (Important)
- `*@accounts.google.com` - Security alerts
- `*@github.com` - Development notifications
- `*@apple.com` - Apple services
- `*@raywhite.com` - Real estate (user interested)
- `*@ozcomrealty.com.au` - Real estate alerts (user interested)
- `*@belleproperty.com` - Real estate (user interested)

### Marketing Senders (Auto-Unsubscribe Candidates)
- `newsletter@*` - Newsletters
- `marketing@*` - Marketing
- `promo@*` - Promotions
- `no-reply@*` + CATEGORY_PROMOTIONS - Promotional emails
- `*@mc.*.com.au` - Mailchimp-powered Australian marketing
- `noreply-*@republic.com` - Republic Europe investment promos
- `*@email.weforum.org` - WEF newsletters
- `*@ticketcorner.ch` - Swiss ticketing promos
- `*@turkishairlines.com` - Airline marketing
- `*@seek.com.au` - Job marketing

### Gray Area (Ask User)
- Real estate alerts (currently: keep unread)
- Event notifications from unknown senders

---

## User Decisions Log

| Date | Sender | Decision | Reason |
|------|--------|----------|--------|
| 2026-01-28 | Uneed (newsletter@uneed.best) | Unsubscribe | User confirmed |
| 2026-01-28 | Belle Property | Keep | User interested in property listings |
| 2026-01-28 | HeyGen (no_reply@email.heygen.com) | Unsubscribe | Auto - marketing email |
| 2026-01-28 | Interdiscount (infomail@info.interdiscount.ch) | Unsubscribe | Auto - retail marketing |
| 2026-01-29 | Uneed (newsletter@uneed.best) | Unsubscribe | Auto - confirmed via Bento unsubscribe page |
| 2026-01-29 | HeyGen (no_reply@email.heygen.com) | Unsubscribe | Auto - already unsubscribed (confirmed) |
| 2026-01-29 | Interdiscount (infomail@info.interdiscount.ch) | Unsubscribe | Partial - requires button click on opt-out page |
| 2026-01-29 | Uneed (newsletter@uneed.best) | Unsubscribe | Auto - confirmed unsubscribed via Bento (Status: Unsubscribed) |
| 2026-01-29 | HeyGen (no_reply@email.heygen.com) | Unsubscribe | Auto - already unsubscribed (customer.io confirms) |
| 2026-01-29 | Interdiscount (infomail@info.interdiscount.ch) | Unsubscribe | Partial - opt-out page loaded but button needs manual click |
| 2026-01-29 | Uneed (newsletter@uneed.best) | Unsubscribe | Confirmed - Bento "Status: Unsubscribed" |
| 2026-01-29 | Flippa (marketing@flippa.com) | Unsubscribe | Partial - HubSpot preferences page loaded, needs checkbox |
| 2026-01-29 | Republic Europe (noreply-eur@republic.com) | Unsubscribe | Partial - Mailchimp page loaded, needs button click |
| 2026-01-29 | Bubble (newsletter@mail.bubble.io) | Unsubscribe | Partial - JS-rendered page, needs manual interaction |
| 2026-01-29 | Spotify (no-reply@spotify.com) | Unsubscribe | Partial - JS-rendered page, needs manual interaction |
| 2026-01-29 | Aussie Home Loans (heretohelp@mc.aussie.com.au) | Unsubscribe | Partial - encrypted link, needs manual click |
| 2026-01-29 | Coopers Group (elena.dcruz@coopers.ch) | Unsubscribe | Partial - Mailchimp page loaded, needs button click |
| 2026-01-29 | WEF (intelligence@email.weforum.org) | Unsubscribe | Partial - encrypted link, needs manual click |
| 2026-01-29 | Ubisoft (news@updates.ubisoft.com) | Keep | ToS/privacy update, not marketing |
| 2026-01-29 | Mickmumpitz (bingo@patreon.com) | Keep | Patreon creator update, user subscribed |
| 2026-01-29 | LinkedIn (messages-noreply@linkedin.com) | Keep | Professional network notification |
| 2026-01-29 | Uneed (newsletter@uneed.best) | Unsubscribe | Session 6 - Confirmed via Bento "Status: Unsubscribed" |
| 2026-01-29 | Flippa (marketing@flippa.com) | Unsubscribe | Session 6 - Confirmed via HubSpot "presently unsubscribed from all emails" |
| 2026-01-29 | Republic Europe (noreply-eur@republic.com) | Unsubscribe | Session 6 - Partial, Mailchimp form loaded, needs button click |
| 2026-01-29 | Coopers Group (elena.dcruz@coopers.ch) | Unsubscribe | Session 6 - Partial, Mailchimp form loaded, needs button click |
| 2026-01-29 | Spotify (no-reply@spotify.com) | Unsubscribe | Session 6 - Partial, JS-rendered page |
| 2026-01-29 | Bubble (newsletter@mail.bubble.io) | Unsubscribe | Session 6 - Partial, JS-rendered page |
| 2026-01-29 | Aussie Home Loans (heretohelp@mc.aussie.com.au) | Unsubscribe | Session 6 - Skipped, encrypted Mailchimp link |
| 2026-01-29 | WEF (intelligence@email.weforum.org) | Unsubscribe | Session 6 - Skipped, encrypted link |
| 2026-01-29 | Google Cloud Alerting (x7) | Keep | Session 6 - Firebase RTDB billing alerts |
| 2026-01-29 | Firebase (x2) | Keep | Session 6 - Crash reports |
| 2026-01-29 | Slack (x2) | Keep | Session 6 - Content deletion notice |
| 2026-01-29 | Google Security | Keep | Session 6 - Account security alert |
| 2026-01-29 | Wise | Keep | Session 6 - Privacy notice update |
| 2026-01-29 | Facebook Developers | Keep | Session 6 - Graph API v19 upgrade |
| 2026-01-29 | Ubisoft | Keep | Session 6 - ToS/privacy update |
| 2026-01-29 | Mickmumpitz (Patreon) | Keep | Session 6 - Creator update |
| 2026-01-29 | LinkedIn | Keep | Session 6 - Connection update |
| 2026-01-29 | Ray White | Keep | Session 6 - Weekly property listings |
| 2026-01-29 | Oz Combined Realty (x2) | Keep | Session 6 - Property alert match |
| 2026-01-29 | Belle Property | Keep | Session 6 - New listing alert |
| 2026-01-29 | Flippa (marketing@flippa.com) | Read+Trashed | Session 7 - Auto via Chrome (Always Unsubscribe) |
| 2026-01-29 | Spotify (no-reply@spotify.com) | Read+Trashed | Session 7 - Auto via Chrome (Always Unsubscribe) |
| 2026-01-29 | Bubble (newsletter@mail.bubble.io) | Read+Trashed | Session 7 - Auto via Chrome (Always Unsubscribe) |
| 2026-01-29 | Uneed (newsletter@uneed.best) | Read+Trashed | Session 7 - Auto via Chrome (Always Unsubscribe) |
| 2026-01-29 | Coopers Group (elena.dcruz@coopers.ch) | Read+Trashed | Session 7 - Auto via Chrome (Always Unsubscribe) |
| 2026-01-29 | Republic Europe (noreply-eur@republic.com) | Read+Trashed | Session 7 - Auto via Chrome (Always Unsubscribe) |
| 2026-01-29 | WEF (intelligence@email.weforum.org) | Read+Trashed | Session 7 - Auto via Chrome (Always Unsubscribe) |
| 2026-01-29 | Aussie Home Loans (heretohelp@mc.aussie.com.au) | Read+Trashed | Session 7 - Auto via Chrome (Always Unsubscribe) |
| 2026-01-29 | Google Cloud Alerting (x8) | Keep | Session 7 - Firebase RTDB billing alerts |
| 2026-01-29 | Firebase (x2) | Keep | Session 7 - Crash reports |
| 2026-01-29 | Google Security | Keep | Session 7 - Gmail access security alert |
| 2026-01-29 | Slack (x2) | Keep | Session 7 - Content deletion notice |
| 2026-01-29 | Wise | Keep | Session 7 - Privacy notice |
| 2026-01-29 | Facebook Developers | Keep | Session 7 - Graph API v19 upgrade |
| 2026-01-29 | Ray White | Keep | Session 7 - Weekly listings |
| 2026-01-29 | Oz Combined Realty (x2) | Keep | Session 7 - Property alerts |
| 2026-01-29 | Belle Property | Keep | Session 7 - New listing |
| 2026-01-29 | LinkedIn | Keep | Session 7 - Connection updates |
| 2026-01-29 | Ubisoft | Keep | Session 7 - ToS update |
| 2026-01-29 | Mickmumpitz (Patreon) | Keep | Session 7 - Creator update |
| 2026-01-29 | Google Cloud Alerting (x9) | Auto-Trashed | Session 8 - Firebase RTDB billing alerts |
| 2026-01-29 | Firebase (x2) | Auto-Trashed | Session 8 - Crash reports |
| 2026-01-29 | Interdiscount (infomail@info.interdiscount.ch) | Read+Trashed | Session 8 - Always Unsubscribe list match |
| 2026-01-29 | HeyGen (no_reply@email.heygen.com) | Read+Trashed | Session 8 - Always Unsubscribe list match |
| 2026-01-29 | Ticketcorner | Read+Trashed | Session 8 - User approved, added to Always Unsubscribe (no List-Unsubscribe header) |
| 2026-01-29 | Turkish Airlines | Read+Trashed | Session 8 - User approved, added to Always Unsubscribe (no List-Unsubscribe header) |
| 2026-01-29 | SEEK (seek.com.au) | Read+Trashed | Session 8 - User approved, added to Always Unsubscribe (no List-Unsubscribe header) |
| 2026-01-29 | Google Security | Keep | Session 8 - Account security alert |
| 2026-01-29 | Slack | Keep | Session 8 - Workspace notice |
| 2026-01-29 | Ray White | Keep | Session 8 - Weekly property listings |
| 2026-01-29 | Oz Combined Realty (x2) | Keep | Session 8 - Property alerts |
| 2026-01-29 | Belle Property (x2) | Keep | Session 8 - New listing alerts |
| 2026-01-29 | Facebook Developers | Keep | Session 8 - Graph API upgrade |
| 2026-01-29 | Wise | Keep | Session 8 - Privacy notice |
| 2026-01-29 | Ubisoft | Keep | Session 8 - ToS update |
| 2026-01-29 | Mickmumpitz (Patreon) | Keep | Session 8 - Creator update |
| 2026-01-29 | LinkedIn | Keep | Session 8 - Connection updates |
| 2026-01-29 | Google Cloud Alerting (x35) | Bulk-Trashed | Session 9 - Bulk trash via Chrome search |
| 2026-01-29 | Firebase (x5) | Bulk-Trashed | Session 9 - Bulk trash via Chrome search |
| 2026-01-29 | Slack (many) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | LinkedIn (many) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | Reddit (many) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | Wise (many) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | Facebook (many) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | Patreon (many) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | Ubisoft (2) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | TestFlight/ASC (many) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | YouTube (many) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | Render (5) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | Aussie Broadband maintenance (11) | Bulk-Archived | Session 9 - Bulk archive via Chrome search |
| 2026-01-29 | POF/Plenty of Fish (41) | Bulk-Archived | Session 9 - Bulk archive via Chrome search (Social category) |
| 2026-01-29 | All Promotions (excl. real estate) (~98) | Bulk-Trashed | Session 9 - Bulk trash category:promotions excluding real estate senders |

---

## Learned Patterns

### High Confidence Unsubscribe
- CATEGORY_PROMOTIONS + `newsletter@` sender
- CATEGORY_PROMOTIONS + `marketing@` sender (e.g. Flippa)
- Has List-Unsubscribe header + promotional subject keywords
- Sender domain matches known marketing platforms (mailchimp, sendgrid, customerio, bentonow, hubspot, etc.)
- `no-reply@` sender + win-back/re-subscription content (e.g. Spotify)
- `mc.*` subdomain = Mailchimp-powered marketing
- `noreply-*@` prefix on known marketing domains

### High Confidence Keep
- CATEGORY_UPDATES from tech companies (Google, Facebook, Slack)
- Security/authentication emails
- Transaction receipts
- Shipping notifications
- Real estate alerts (user preference)
- Developer platform alerts (Firebase, Facebook Developers)
- Financial account updates (Wise)
- ToS/privacy policy updates from gaming/service platforms
- Patreon creator updates
- LinkedIn professional notifications

### Unsubscribe Method Notes
- Bento (bentonow.com): Direct URL visit works, confirmed "Status: Unsubscribed" (verified sessions 3-6)
- Mailchimp (list-manage.com): GET loads confirmation page but needs button click (verified sessions 4-6)
- HubSpot (hs/preferences-center): Session 6 update - Flippa now shows "presently unsubscribed from all emails" (previously partial)
- Bubble.io: JS-rendered, WebFetch cannot interact (verified sessions 4-6)
- Spotify: JS-rendered, WebFetch cannot interact (verified sessions 4-6)
- Encrypted Mailchimp links (mc.*.com.au): Need manual browser click (verified sessions 4-6)
- Claude-in-Chrome: Session 7 - CONFIRMED WORKING. Shift+I marks read, trash icon click deletes. Keyboard `#` shortcut does NOT work (shortcuts may be disabled), must click trash icon at toolbar position (~421, 88).
- **BULK OPERATIONS (Session 9)**: Far more efficient than individual processing. Procedure:
  1. Search: `from:sender.com is:unread` (or `category:promotions -from:excluded`)
  2. Click select-all checkbox (289, 142)
  3. Click "Select all conversations that match this search" link
  4. Click action icon: Archive (349, 142) or Trash (429, 142)
  5. Confirm bulk action dialog → OK
  - Processes hundreds of emails in seconds vs. minutes per individual email
  - Gmail archive = removes from inbox + marks as read (confirmed session 9)
  - Use negative filters `-from:sender` to protect important senders from bulk operations

---

## Statistics

- Total emails processed: ~400+ (149 prev + 100 classified + ~150 bulk-processed in session 9)
- Auto-unsubscribed (confirmed): 9 (HeyGen x3, Interdiscount x2, Uneed x4 via Bento, Flippa x1 via HubSpot)
- User-approved unsubscribes (attempted): 11 senders total (added Ticketcorner, Turkish Airlines, SEEK in session 8)
- Kept: 88+ (including real estate, dev alerts, account updates, security)
- Pending review: 1 (NAB — mixed marketing/account)
- Failed/partial: 6 senders still need manual interaction (Republic Europe, Coopers, Spotify, Bubble, Aussie, WEF)
- Read+Trashed via Chrome: 24 individual (8 session 7 + 16 session 8) + ~138 bulk (session 9)
- Session 7: 30 emails scanned, 8 marketing (all read+trashed via Chrome), 22 kept
- Session 8: 30 emails scanned, 11 auto-trash, 5 marketing, 14 kept
- Session 9: 100 emails classified + BULK OPERATIONS via Chrome:
  - Bulk-trashed: ~40 GCloud Alerting + ~5 Firebase + ~98 Promotions category = ~143 trashed
  - Bulk-archived: LinkedIn, Reddit, Wise, Facebook, Patreon, Ubisoft, TestFlight/ASC, YouTube, Render, Aussie BB maintenance, POF = ~100+ archived
  - Inbox reduced: 1,140 → 1,075 (65 fewer unread)
  - Key technique: Gmail bulk search + "Select all conversations" + action button = massively efficient
- Accuracy rate: High - bulk promotions trash excluded real estate senders successfully
