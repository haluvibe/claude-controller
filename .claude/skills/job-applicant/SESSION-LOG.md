# Job Applicant - Session Log

Running log of every job application session. Each entry records jobs processed, cover letters generated, applications submitted, and any errors.

---

## Session 1 — 2026-02-03

**Jobs processed:** 8
**Source:** SEEK (search: React/JavaScript, Work from home)

### Results
| # | Company | Role | Action | Result |
|---|---------|------|--------|--------|
| 1 | Displayr | Senior Frontend Engineer | Pre-existing | Applied before skill existed |
| 2 | Expertech | Senior Front End Engineer | Skipped | Already applied + not fully remote |
| 3 | InstantScripts (Wesfarmers Health) | Senior Full-Stack Engineer (React/Node.js) | Failed | SuccessFactors requires account creation |
| 4 | Canva | Senior Frontend Engineer - Product/Features | Skipped | Already applied |
| 5 | Okendo | Software Engineer | Applied | SEEK Quick Apply successful |
| 6 | Karbon | Fullstack Engineer | Applied | Greenhouse form, manual resume upload |
| 7 | Lorien APAC | Senior Full Stack Developer | Applied | SEEK Quick Apply, truthful Rust/iOS answers |
| 8 | Anson McCade | Full Stack Developer / React Native and Node JS | Applied | SEEK Quick Apply, no screening questions |

### Cover Letters Generated
- Okendo - Software Engineer: "I'm applying for the Software Engineer role at Okendo..."
- Karbon - Fullstack Engineer: "I'm applying for the Fullstack Engineer position at Karbon..."
- Lorien APAC - Senior Full Stack Developer: "I'm applying for the Senior Full Stack Developer position..."
- Anson McCade - Full Stack Developer / React Native and Node JS: "I'm applying for the Full Stack Developer / React Native and Node JS contract..."

### Platform Notes Learned
- SEEK Quick Apply carries over previous cover letter text — must Cmd+A and replace each time
- SEEK split-panel view can cause `get_page_text` to extract the wrong listing — navigate to dedicated job URL instead
- Greenhouse requires manual file picker for resume upload
- SuccessFactors requires account creation — cannot automate
- SEEK "Save this search" popup persists and needs Escape key to dismiss
- Chrome extension sometimes targets wrong tab — use `find` + ref-based clicks as fallback

### Errors
- InstantScripts: SuccessFactors redirect requires account creation (safety rule)
- Chrome extension intermittently clicked wrong tab during Anson McCade submit — resolved via ref-based click

---

## Session 2 — 2026-02-03 (LinkedIn)

**Jobs processed:** 7
**Source:** LinkedIn (search: React/JavaScript, Remote, Past week)

### Results
| # | Company | Role | Action | Result |
|---|---------|------|--------|--------|
| 1 | Copperbelt Energy Corporation Plc | Full Stack Developer | Applied | LinkedIn Easy Apply successful |
| 2 | Mercor (via Hatch) | Software Engineer @ Mercor | Failed | Hatch requires account creation |
| 3 | Magic Media | Frontend ReactJS Developer | Applied | LinkedIn Easy Apply (Workable-powered) successful |
| 4 | Twine | Website Developer – Remote | Skipped | Freelance marketplace (user preference) |
| 5 | Hire Overseas | Web Developer (Analytics and Tracking) | Skipped | Requires Loom video walkthrough |
| 6 | Atomic Tessellator | Lead Engineer, Front-end | Skipped | Vue.js stack (not React), email apply only |
| 7 | Commerce (BigCommerce) | Senior Software Engineer - Frontend | Skipped | Hybrid 3 days/week for Sydney Metro, Workday ATS |
| 8 | DataAnnotation | Full Stack Developer (UX/UI) | Skipped | AI training role, not traditional dev |

### Cover Letters Generated
- Magic Media - Frontend ReactJS Developer: "I'm applying for the Frontend ReactJS Developer contract position at Magic Media..."

### Platform Notes Learned
- LinkedIn Easy Apply can be powered by Workable (same modal flow but with Workable screening questions)
- LinkedIn "React Developer" search in Australia returns mostly irrelevant results (C++, Java, Sales, etc.)
- LinkedIn pagination via clicking page numbers triggers Premium upsell — use URL parameter `start=N` instead
- Workday ATS (BigCommerce) requires manual apply or LinkedIn OAuth — cannot automate
- DataAnnotation is AI training/annotation work, not traditional software development
- "Follow [Company]" checkbox confirmed pre-checked on LinkedIn review step — must uncheck via form_input

### Errors
- Browser extension disconnected briefly mid-session — reconnected successfully
- Screenshot permission denied once (user misclick) — re-requested and granted

---

## Session 3 — 2026-02-04 (LinkedIn)

**Jobs processed:** 5
**Source:** LinkedIn (search: Senior Frontend React, Remote, Past week)

### Results
| # | Company | Role | Action | Result |
|---|---------|------|--------|--------|
| 1 | Tailor | Senior Frontend Engineer (Australia - AEST, Remote) | Applied | LinkedIn → Ashby form, Y-Combinator backed, no cover letter field |
| 2 | Pluralis Research | Senior / Staff Frontend Engineer | Applied | LinkedIn → Ashby form, USV-backed, custom questions answered |
| 3 | Venus Labs | Frontend Engineer (DeFi / Web3 Protocol) | Applied | LinkedIn Easy Apply, DeFi/Web3 role, screening questions answered |
| 4 | Kraken | Senior Software Engineer - Frontend - Onchain | Applied | LinkedIn → Ashby form, crypto exchange, custom questions answered |
| 5 | BRG | Software Engineer | Skipped | Workday ATS requires account creation — cannot automate |

### Cover Letters Generated
- None (Ashby and LinkedIn Easy Apply forms had no cover letter field)

### Platform Notes Learned
- Ashby ATS (jobs.ashbyhq.com) is common for Y-Combinator startups — simple form with name, email, phone, resume, optional website
- Ashby has no cover letter field, just custom questions
- Workday ATS (*.wd5.myworkdayjobs.com) requires account creation — cannot automate (similar to SuccessFactors)
- LinkedIn Apply button sometimes unresponsive to coordinate clicks — use `read_page` with `filter: interactive` to find ref and click by reference
- LinkedIn pagination via URL parameter `start=N` works reliably (e.g., `start=25` for page 2)
- Most "remote" jobs on SEEK/LinkedIn in Australia are actually hybrid (Sydney/Melbourne office required)

### Errors
- LinkedIn Apply button required ref-based click instead of coordinate click
- Many jobs labeled "remote" were actually hybrid — extensive filtering required

---
