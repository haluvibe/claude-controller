# Job Applicant Skill -- Architecture Design

## 1. Overview

Automated job application assistant that navigates job listings, extracts requirements, generates tailored cover letters, fills application forms via browser automation, and tracks all applications in persistent memory.

The skill follows the same patterns established by the email automation skills (`gmail-organizer`, `proton-organizer`, `email-review`): markdown prompt as SKILL.md, persistent state in MEMORY.md, run history in SESSION-LOG.md, and Chrome MCP tools for browser interaction.

---

## 2. Directory Structure

```
.claude/skills/job-applicant/
  SKILL.md                    -- Main skill prompt (invoked via /job-applicant)
  MEMORY.md                   -- Applied jobs tracker + user profile + preferences
  SESSION-LOG.md              -- Run history (one entry per session)
  ARCHITECTURE.md             -- This document
  resume.md                   -- User's resume in markdown (source of truth for cover letters)
  cover-letter-template.md    -- Base cover letter template with placeholders
```

### File Responsibilities

| File | Owner | Purpose |
|------|-------|---------|
| `SKILL.md` | Skill prompt | Read by Claude Code when skill is invoked. Defines the full workflow. |
| `MEMORY.md` | Skill (read/write) | Persistent state: user profile, applied jobs log, site-specific notes. |
| `SESSION-LOG.md` | Skill (append-only) | Chronological record of every run for auditability. |
| `resume.md` | User (manual edits) | Canonical resume content. Skill reads but never writes. |
| `cover-letter-template.md` | User (manual edits) | Base template. Skill reads, fills placeholders, and presents for approval. |

---

## 3. SKILL.md Frontmatter

```yaml
---
name: job-applicant
description: "Navigate job listings, generate tailored cover letters, fill application forms, and track applications"
allowed-tools: >-
  mcp__claude-in-chrome__tabs_context_mcp,
  mcp__claude-in-chrome__tabs_create_mcp,
  mcp__claude-in-chrome__navigate,
  mcp__claude-in-chrome__read_page,
  mcp__claude-in-chrome__find,
  mcp__claude-in-chrome__computer,
  mcp__claude-in-chrome__form_input,
  mcp__claude-in-chrome__javascript_tool,
  mcp__claude-in-chrome__get_page_text,
  mcp__claude-in-chrome__upload_image,
  mcp__claude-in-chrome__screenshot,
  mcp__claude-controller__notify_ipad,
  Read,
  Edit,
  Write,
  WebFetch,
  Bash
---
```

### Design Decisions

- **User-invocable only.** This skill should never run on a schedule or be auto-triggered. Job applications require human oversight.
- **Chrome required.** Unlike the email organizer which has a headless fallback, this skill MUST have Chrome available. If Chrome tools are not detected, the skill should abort immediately with a clear message.
- **No arguments in frontmatter.** The user provides job URLs or search criteria as free-text input when invoking the skill. The skill parses the input in Step 1.
- **Bash tool included.** Needed for PDF resume handling (the user may need to convert resume.md to PDF, or the skill may need to locate an existing PDF on disk).

---

## 4. MEMORY.md Structure

### 4.1 User Profile

Stores the data needed to auto-fill application forms. The user populates this once and the skill reads it on every run.

```markdown
## User Profile

| Field | Value |
|-------|-------|
| Full Name | Paul Hayes |
| Email | [user's email] |
| Phone | [user's phone] |
| Location | Canberra, ACT, Australia |
| Work Rights | Australian Citizen |
| LinkedIn | [URL] |
| GitHub | [URL] |
| Portfolio | [URL] |
| Notice Period | 2 weeks |
| Willing to Relocate | Yes -- Sydney, Melbourne |
| Salary Expectation | $[X]-$[Y] AUD (negotiable) |
| Years of Experience | [X] |
| Highest Qualification | [degree, institution] |
```

### 4.2 Preferences

```markdown
## Preferences

| Preference | Value |
|------------|-------|
| Job Types | Full-time, Contract |
| Target Roles | [e.g., Senior Software Engineer, Tech Lead, Engineering Manager] |
| Industries | Technology, SaaS, FinTech |
| Min Salary | $[X] AUD |
| Excluded Companies | [any companies to skip] |
| Excluded Roles | [any role types to skip] |
| Max Applications Per Session | 5 |
| Auto-Submit | No (require approval for each) |
```

### 4.3 Applied Jobs Log

The core tracking table. Every application attempt is recorded here.

```markdown
## Applied Jobs

| # | Date | Company | Role | URL | Platform | Status | Cover Letter | Notes |
|---|------|---------|------|-----|----------|--------|--------------|-------|
| 1 | 2026-01-31 | Display R | [role] | [URL] | Direct | Applied | Yes | First entry (pre-existing) |
```

**Status values:**
- `Applied` -- Application submitted successfully
- `Skipped` -- User chose to skip after review
- `Failed` -- Submission failed (form error, missing fields, etc.)
- `Draft` -- Cover letter generated but not yet submitted
- `Duplicate` -- Already applied (detected in pre-check)
- `Withdrawn` -- User withdrew after applying

### 4.4 Platform Notes

Site-specific automation notes learned from experience (same concept as the email skill's "Unsubscribe Method Notes").

```markdown
## Platform Notes

### SEEK (seek.com.au)
- Login required before applying
- "Quick Apply" button uses saved profile
- Resume upload: PDF only, max 5MB
- Cover letter: paste into text area (no file upload)

### LinkedIn (linkedin.com)
- "Easy Apply" uses LinkedIn profile
- Some listings redirect to external ATS
- Resume upload supported in Easy Apply flow

### Indeed (indeed.com)
- Resume upload: PDF or DOCX
- Some employers use Indeed's built-in questions
- May require Indeed account login
```

### 4.5 Statistics

```markdown
## Statistics

- Total applications: X
- Successful submissions: X
- Failed submissions: X
- Skipped by user: X
- Cover letters generated: X
- Sessions run: X
```

---

## 5. Workflow Design

### Step 0: Pre-Flight Checks

1. **Check Chrome availability.** Call `tabs_context_mcp`. If Chrome tools are not available, abort immediately:
   > "Chrome browser automation is required for job applications. Please ensure Claude in Chrome is running and try again."
2. **Read MEMORY.md.** Load user profile, preferences, applied jobs log, and platform notes.
3. **Read resume.md.** Load the canonical resume for cover letter generation.
4. **Read cover-letter-template.md.** Load the template.
5. **Validate profile completeness.** If critical fields are missing (name, email, phone, work rights), warn the user and list what needs to be filled in MEMORY.md before proceeding.

### Step 1: Parse User Input

The user provides one of:
- **One or more job URLs:** Direct links to specific job listings.
- **Search criteria:** e.g., "Senior iOS Developer roles in Canberra on SEEK" -- the skill navigates to the job board and searches.
- **A saved search or job board URL:** e.g., a SEEK saved search URL.

Parse the input and build a list of job URLs to process.

If search criteria are provided (not direct URLs):
1. Navigate to the appropriate job board (SEEK, LinkedIn, Indeed, etc.).
2. Enter search terms and location.
3. Extract the first N job listing URLs from results (N = `Max Applications Per Session` from preferences, default 5).
4. Present the list to the user for confirmation before proceeding.

### Step 2: Extract Job Details

For each job URL:

1. **Navigate** to the URL using `mcp__claude-in-chrome__navigate`.
2. **Wait** for the page to load (2-3 seconds).
3. **Extract job details** using `get_page_text` and/or `read_page`:
   - Job title
   - Company name
   - Location
   - Salary range (if listed)
   - Employment type (full-time, contract, etc.)
   - Key requirements (skills, experience, qualifications)
   - Job description summary
   - Application deadline (if listed)
   - Application method (apply on site, redirect to ATS, email, etc.)
4. **Take a screenshot** for the session log record.

### Step 3: Deduplication Check

For each extracted job:
1. Check MEMORY.md "Applied Jobs" table.
2. Match on: company name + role title, OR URL (normalized -- strip query params, trailing slashes).
3. If a match is found with status `Applied` or `Draft`:
   - Skip this job.
   - Report: "Already applied to [Company] - [Role] on [date]. Skipping."
4. If matched with status `Failed`:
   - Ask user: "Previously failed to apply to [Company] - [Role] on [date]. Retry?"

### Step 4: Generate Cover Letter

For each new job that passes deduplication:

1. **Analyze the job listing** against `resume.md`:
   - Identify which of the user's skills/experience match the listed requirements.
   - Identify the 2-3 strongest alignment points.
   - Note any gaps.

2. **Generate a tailored cover letter** using the template from `cover-letter-template.md` with these rules:
   - **Length:** 250-350 words maximum (fits on one page).
   - **Tone:** Australian professional -- direct, confident, not overly formal. No "I am writing to express my interest" boilerplate.
   - **Structure:**
     - Opening: What role, where you found it, one sentence on why you are a strong fit.
     - Body (2 paragraphs): Specific experience that maps to their stated requirements. Reference actual projects, technologies, or outcomes from resume.md. Do not repeat the job ad back to them.
     - Closing: Availability, enthusiasm, call to action.
   - **Must reference** at least 2 specific requirements from the job listing.
   - **Must pull** at least 2 concrete experiences from resume.md.
   - **Must NOT** include: cliches ("passion for technology"), vague claims without evidence, or content not supported by the resume.

3. **Present the cover letter to the user** along with the job details summary:
   ```
   ## [Company] - [Role]
   Location: [location] | Type: [type] | Salary: [range]

   ### Key Requirements Matched
   - [requirement 1] -> [your experience]
   - [requirement 2] -> [your experience]

   ### Generated Cover Letter
   [cover letter text]

   ### Action
   1. Submit as-is
   2. Edit cover letter (provide changes)
   3. Skip this job
   ```

4. **Wait for user approval.** Do not proceed to form filling without explicit confirmation.

### Step 5: Fill Application Form

After user approves the cover letter:

1. **Navigate to the application page.** This may be:
   - An "Apply" button on the job listing page.
   - A redirect to an external ATS (Workday, Greenhouse, Lever, etc.).
   - A separate application URL.

2. **Take a screenshot** of the form to understand its layout.

3. **Use `describe_ui` or `read_page`** to get the form structure and identify all fields.

4. **Fill fields from MEMORY.md user profile:**
   - Name, email, phone, location, work rights, LinkedIn, etc.
   - Map field labels to profile data using fuzzy matching (e.g., "Mobile Number" = Phone, "Are you authorized to work in Australia?" = Work Rights).

5. **Paste the cover letter** into the appropriate field:
   - If there is a "Cover Letter" text area: paste the full text.
   - If there is a cover letter file upload: notify the user that a file upload is needed and provide the text for them to save as PDF.

6. **Handle common form patterns:**
   - Dropdowns: Use `form_input` with the matching option text.
   - Radio buttons: Click the appropriate option.
   - Checkboxes (e.g., "I agree to privacy policy"): Check them.
   - Multi-step forms: Navigate through each step, filling fields as they appear.
   - "How did you hear about us?": Default to "Job Board" or the specific platform name.

7. **Handle resume upload:**
   - Look for a file input element.
   - If a resume PDF exists at a known path (e.g., `~/Documents/Resume_PaulHayes.pdf`), use `upload_image` with the file input ref.
   - If no PDF exists, notify the user: "Please upload your resume PDF manually. I've filled all other fields."
   - Record the resume file path in MEMORY.md Platform Notes for future runs.

### Step 6: Pre-Submit Review

**This is a critical safety gate.**

1. **Take a screenshot** of the completed form.
2. **Present a summary to the user:**
   ```
   ## Ready to Submit: [Company] - [Role]

   ### Form Summary
   - Name: [filled value]
   - Email: [filled value]
   - Phone: [filled value]
   - Resume: [uploaded / manual upload needed]
   - Cover Letter: [pasted / uploaded / manual needed]
   - Additional fields: [list any non-standard fields and values]

   ### Submit?
   1. Yes, submit now
   2. Let me review the form first (take control)
   3. Skip this application
   ```

3. **Wait for explicit user confirmation before clicking Submit.**

### Step 7: Submit Application

After user confirmation:

1. **Click the Submit button.** Use `find` to locate the submit button, then `computer` to click it.
2. **Wait 3-5 seconds** for the submission to process.
3. **Take a screenshot** of the confirmation page.
4. **Verify success:**
   - Look for confirmation text ("Thank you", "Application submitted", "We've received your application").
   - Check for error messages (validation failures, missing required fields).
5. **If successful:**
   - Record as `Applied` in MEMORY.md.
   - Report success to user.
6. **If failed:**
   - Take a screenshot of the error.
   - Record as `Failed` in MEMORY.md with the error reason.
   - Report the failure to user and ask if they want to retry or skip.

### Step 8: Update MEMORY.md

After each application attempt (success or failure):

1. **Add a new row** to the "Applied Jobs" table with all details.
2. **Update statistics** (increment counters).
3. **Add platform notes** if anything new was learned about the job site's form structure.

### Step 9: iPad Notification

After all jobs in the session are processed:

```
mcp__claude-controller__notify_ipad({
  message: "Job Applications: X submitted, Y skipped, Z failed"
})
```

### Step 10: Update SESSION-LOG.md

Append a session entry:

```markdown
---

## Session [N] ([date])

**Status:** Completed
**Jobs processed:** X
**URLs provided:** [list]

### Results
| # | Company | Role | Action | Result |
|---|---------|------|--------|--------|
| 1 | [company] | [role] | Applied | Success |
| 2 | [company] | [role] | Skipped | User chose to skip |

### Cover Letters Generated
- [Company] - [Role]: [first line of cover letter...]

### Platform Notes Learned
- [any new automation notes]

### Errors
- [any errors encountered]
```

---

## 6. Cover Letter Template Design

`cover-letter-template.md` uses simple placeholders that the skill replaces:

```markdown
# Cover Letter Template

{{USER_NAME}}
{{USER_EMAIL}} | {{USER_PHONE}}
{{USER_LOCATION}}

{{DATE}}

RE: {{ROLE_TITLE}} at {{COMPANY_NAME}}

{{OPENING_PARAGRAPH}}

{{BODY_PARAGRAPH_1}}

{{BODY_PARAGRAPH_2}}

{{CLOSING_PARAGRAPH}}

Kind regards,
{{USER_NAME}}
```

### Generation Prompt (embedded in SKILL.md)

The cover letter generation uses the following internal prompt:

> You are writing a cover letter for a job application. You have the candidate's resume and the job listing details.
>
> Rules:
> - 250-350 words maximum (body paragraphs only, excluding header/signature).
> - Australian professional tone: direct, confident, warm but not overly casual.
> - Opening: State the role and one compelling reason you are a strong fit. Do not use "I am writing to express my interest" or similar boilerplate.
> - Body paragraph 1: Map 1-2 specific requirements from the job listing to concrete experience from the resume. Use specific project names, technologies, metrics, or outcomes.
> - Body paragraph 2: Map 1-2 additional requirements, focusing on a different aspect (e.g., if paragraph 1 covered technical skills, paragraph 2 covers leadership or domain knowledge).
> - Closing: State availability and notice period. Express genuine interest. One sentence, no groveling.
> - Do NOT include anything not supported by the resume.
> - Do NOT use: "passionate about", "excited to", "I believe I would be a great fit", "proven track record", or any content-free filler.
> - DO use: specific numbers, project names, technologies, and outcomes from the resume.

---

## 7. Safety Design

### 7.1 Submission Gating

**Default: Manual approval required for every submission.** The skill MUST present the completed form and cover letter to the user and receive explicit confirmation ("yes", "submit", "1") before clicking any submit button.

The `Auto-Submit` preference in MEMORY.md defaults to `No`. If the user changes it to `Yes`, the skill may submit without asking -- but ONLY for job boards the user has previously applied through successfully (tracked in Platform Notes). Unknown platforms always require manual approval regardless of the Auto-Submit setting.

### 7.2 Duplicate Prevention

Three-layer deduplication:
1. **URL match:** Normalize URL (strip query params, fragments, trailing slashes) and compare against Applied Jobs log.
2. **Company + Role match:** Case-insensitive match of company name AND role title.
3. **Fuzzy match warning:** If company name matches but role title differs, warn the user: "You've already applied to [Company] for [Other Role] on [date]. Proceed with this different role?"

### 7.3 Error Handling

| Error | Response |
|-------|----------|
| Chrome not available | Abort entire session with clear message |
| Page fails to load | Wait 10 seconds, retry once. If still fails, skip job, record as `Failed`. |
| Form validation error | Screenshot the error, report to user, ask to retry or skip. |
| File upload fails | Notify user to upload manually, pause and wait. |
| CAPTCHA or bot detection | Stop. Notify user: "This site has bot detection. Please complete the form manually." Record as `Failed -- CAPTCHA`. |
| Login required | Notify user: "This site requires login. Please log in and then tell me to continue." Pause and wait. |
| Application requires account creation | Stop. Notify user this is a prohibited action per security rules. User must create the account themselves. |
| Missing required field not in profile | Ask user for the value. Store it in MEMORY.md for future use. |

### 7.4 Rate Limiting

- **Default max 5 applications per session** (configurable in Preferences).
- **Minimum 30-second delay between applications** on the same platform.
- **If a site shows rate-limiting behavior** (429 errors, "too many requests"), stop and notify the user.

### 7.5 Privacy

- The skill NEVER enters passwords. If a login is needed, the user must handle it.
- The skill NEVER creates accounts on the user's behalf.
- The skill does NOT store passwords, API keys, or authentication tokens in MEMORY.md.
- Financial information (salary expectation) is stored in MEMORY.md but only entered into forms with the user profile data -- never exposed to untrusted sources.

---

## 8. Component Interaction Diagram

```
User
  |
  | "Apply to these 3 jobs: [url1], [url2], [url3]"
  v
SKILL.md (Claude Code reads and follows)
  |
  |--- Read MEMORY.md (profile, applied jobs, platform notes)
  |--- Read resume.md (canonical resume)
  |--- Read cover-letter-template.md (template)
  |
  | For each job URL:
  |
  |--- [Chrome] Navigate to job URL
  |       |
  |       v
  |    Extract job details (title, company, requirements)
  |       |
  |       v
  |    Dedup check against MEMORY.md Applied Jobs table
  |       |
  |       v (if new)
  |    Generate cover letter (resume.md + job details + template)
  |       |
  |       v
  |    Present to user for approval  <------- USER DECISION GATE
  |       |
  |       v (if approved)
  |--- [Chrome] Navigate to application form
  |       |
  |       v
  |    Fill form fields from MEMORY.md User Profile
  |    Paste cover letter
  |    Upload resume PDF
  |       |
  |       v
  |    Pre-submit review screenshot  <------- USER DECISION GATE
  |       |
  |       v (if confirmed)
  |--- [Chrome] Click Submit
  |       |
  |       v
  |    Verify success/failure
  |       |
  |       v
  |--- Write MEMORY.md (add applied job record, update stats)
  |--- Append SESSION-LOG.md
  |
  | After all jobs:
  |
  |--- iPad notification (summary)
  v
Done
```

---

## 9. Data Flow

```
resume.md (read-only)
    |
    v
cover-letter-template.md (read-only)
    |
    v
[Job listing page content] -----> Cover Letter Generator -----> Generated cover letter
                                                                     |
                                                                     v
MEMORY.md User Profile -----> Form Filler -----> [Application form on website]
                                                       |
                                                       v
                                                  Submit result
                                                       |
                                                       v
                                              MEMORY.md Applied Jobs (append)
                                              SESSION-LOG.md (append)
                                              iPad Notification (send)
```

---

## 10. Allowed Tools Rationale

| Tool | Reason |
|------|--------|
| `tabs_context_mcp` | Check Chrome availability, get existing tabs |
| `tabs_create_mcp` | Open new browser tabs |
| `navigate` | Navigate to job URLs and application forms |
| `read_page` | Get accessibility tree of form elements |
| `find` | Locate specific form elements (submit button, file input, etc.) |
| `computer` | Click, type, scroll, take screenshots, keyboard shortcuts |
| `form_input` | Set values in form fields (dropdowns, text inputs, checkboxes) |
| `javascript_tool` | Execute JS for edge cases (e.g., triggering React state updates on SPAs) |
| `get_page_text` | Extract full text content of job listings |
| `upload_image` | Upload resume PDF to file input elements |
| `screenshot` | Visual verification of forms before/after submission |
| `notify_ipad` | Send completion notification to iPad |
| `Read` | Read MEMORY.md, resume.md, cover-letter-template.md, SESSION-LOG.md |
| `Edit` | Update MEMORY.md with new applications and platform notes |
| `Write` | Create SESSION-LOG.md entries |
| `WebFetch` | Fetch job listing content when Chrome read_page is insufficient |
| `Bash` | Locate resume PDF on disk, file operations |

---

## 11. Technology Evaluation

### Job Board Support Priority

| Platform | Priority | Automation Feasibility | Notes |
|----------|----------|----------------------|-------|
| SEEK | P0 (primary) | High | Most AU jobs. Well-structured forms. "Quick Apply" flow. |
| LinkedIn | P1 | Medium | "Easy Apply" works well. External redirects vary. Login required. |
| Indeed | P2 | Medium | Varies by employer. Some use Indeed forms, some redirect. |
| Direct company sites | P3 | Low-Medium | Every company different. ATS platforms (Greenhouse, Lever, Workday) have patterns. |
| Glassdoor | P3 | Medium | Often redirects to company site. |

### ATS Platform Patterns

These patterns should accumulate in Platform Notes as the skill encounters them:

| ATS | Form Pattern | Notes |
|-----|-------------|-------|
| Greenhouse | Multi-step, file uploads, custom questions | Common for tech companies |
| Lever | Single page, file upload, cover letter text area | Used by Spotify, etc. |
| Workday | Multi-step wizard, account creation often required | Often requires manual account creation |
| SmartRecruiters | Single page with file upload | Relatively straightforward |
| BambooHR | Simple single-page form | Small-medium companies |

---

## 12. Architectural Decisions

### ADR-001: User Approval Required Before Every Submission

**Context:** Job applications are high-stakes, irreversible actions. A bad cover letter or incorrect form data could damage the user's professional reputation.

**Decision:** Every submission requires explicit user approval. There are two gates: (1) cover letter approval, and (2) pre-submit form review.

**Rationale:** Unlike email organization (where a misclassified email can be recovered from trash), a submitted job application cannot be recalled. The cost of a mistake far outweighs the convenience of auto-submission.

**Exception:** If the user explicitly sets `Auto-Submit: Yes` in preferences AND the platform has been used successfully before, the pre-submit gate can be skipped (cover letter approval still required).

### ADR-002: Markdown Resume as Source of Truth

**Context:** The cover letter generator needs access to the user's experience and skills.

**Decision:** Use a markdown file (`resume.md`) as the canonical source. The skill reads it but never modifies it.

**Rationale:** Markdown is human-readable and editable. It avoids the complexity of parsing PDF/DOCX. The user maintains it manually, ensuring accuracy. A separate PDF file is used for upload to job sites.

### ADR-003: Platform Notes as Learning Mechanism

**Context:** Different job sites have different form structures, and the skill needs to remember what works.

**Decision:** Store site-specific automation notes in MEMORY.md under "Platform Notes". The skill appends new learnings after each session.

**Rationale:** This mirrors the "Unsubscribe Method Notes" pattern from the email skills, which proved highly effective at accumulating operational knowledge across sessions. Each new platform interaction teaches the skill something that benefits future runs.

### ADR-004: No Account Creation by the Skill

**Context:** Many job boards require account creation before applying.

**Decision:** The skill will never create accounts. If an account is required, it stops and asks the user to create it manually.

**Rationale:** Account creation involves agreeing to terms of service and potentially providing payment information. This is a prohibited action per the system's security rules. The user must handle this themselves.

### ADR-005: Session-Based Processing with Hard Limit

**Context:** Applying to too many jobs in one sitting leads to fatigue and lower-quality applications.

**Decision:** Default maximum of 5 applications per session. Configurable in preferences.

**Rationale:** Quality over quantity. Each application gets full attention (cover letter review, form verification). The limit also prevents rate-limiting issues with job boards.

---

## 13. Implementation Order

1. **Phase 1: Core files.** Create SKILL.md, MEMORY.md (with user profile template and Display R entry), SESSION-LOG.md, resume.md (empty template for user to fill), cover-letter-template.md.

2. **Phase 2: Single-URL workflow.** Implement the full workflow for a single job URL: extract, generate cover letter, present for approval. No form filling yet.

3. **Phase 3: Form filling.** Add SEEK-specific form filling. Test with real SEEK listings. Build out Platform Notes for SEEK.

4. **Phase 4: Multi-URL and search.** Support multiple URLs in one invocation. Support search criteria (navigate to job board, search, extract URLs).

5. **Phase 5: Additional platforms.** Add LinkedIn, Indeed, and common ATS patterns based on real usage.

---

## 14. Open Questions for User

Before building, the following need user input:

1. **Resume content.** The user needs to populate `resume.md` with their actual resume.
2. **Profile data.** The user needs to fill in the User Profile section of MEMORY.md.
3. **Resume PDF location.** Where is the PDF resume stored on disk? (e.g., `~/Documents/Resume.pdf`)
4. **Display R details.** The first entry in Applied Jobs is "Display R" -- what is the full role title, URL, and date?
5. **SEEK login.** Is the user already logged into SEEK in Chrome? The skill needs an active session.
6. **Preferred cover letter tone.** The current design specifies "Australian professional" -- any adjustments?
