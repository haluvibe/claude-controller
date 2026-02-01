---
description: "Search job boards for React/JavaScript roles, generate tailored cover letters, fill application forms, and track applications"
allowed-tools: mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__find, mcp__claude-in-chrome__computer, mcp__claude-in-chrome__form_input, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__get_page_text, mcp__claude-in-chrome__upload_image, mcp__claude-in-chrome__screenshot, mcp__claude-in-chrome__describe_ui, mcp__claude-controller__notify_ipad, Read, Edit, Write, Bash
---

# Job Applicant

Automated job application assistant. Searches job boards for React/JavaScript roles, extracts job details, generates tailored cover letters, fills application forms via Chrome, and tracks everything in memory.

## Memory

Before processing, read all memory and config files:
- `.claude/skills/job-applicant/MEMORY.md` -- user profile, applied jobs, preferences, platform notes
- `.claude/skills/job-applicant/resume.md` -- canonical resume (source of truth for cover letters)
- `.claude/skills/job-applicant/cover-letter-template.md` -- cover letter template

After processing, update MEMORY.md with new applications and any platform learnings.

## Session Log

Before processing, read: `.claude/skills/job-applicant/SESSION-LOG.md`
After processing, append a new session entry.

## Step 0: Pre-Flight

1. Verify Chrome is available:
   ```
   mcp__claude-in-chrome__tabs_context_mcp({ createIfEmpty: true })
   ```
   If Chrome tools fail, abort: "Chrome is required for job applications. Please ensure the Claude in Chrome extension is connected."

2. Load MEMORY.md, resume.md, and cover-letter-template.md.

3. Check the user's input:
   - If URLs are provided: process those specific job listings
   - If no URLs: search the target websites from MEMORY.md for React/JavaScript roles

## CRITICAL RULES

### Never Fabricate Skills
- **ONLY reference skills, technologies, experience, and qualifications that exist in `resume.md`.**
- If a skill or technology is not mentioned in the resume, do NOT claim the user has it — not in cover letters, not in screening answers, not anywhere.
- This applies even if it would strengthen the application. Honesty is non-negotiable.
- When answering screening questions about specific technologies not in the resume, answer truthfully (e.g., "0 years" or "No experience").

### Apply Broadly, Never Lie
- **Apply for EVERY role that includes React or JavaScript**, regardless of what other skills or technologies the listing requires.
- A listing may include skills the user doesn't have. That does NOT mean the user can't get the job — companies often have flexibility, or may have other openings.
- The strategy is: cast a wide net by applying to everything React/JavaScript-related, but never misrepresent skills or experience.
- Do NOT skip a job because the listing mentions technologies not in the resume. Only skip if the role has zero React/JavaScript relevance.

### Cover Letter Integrity
- Cover letters must ONLY cite skills and experience that appear in `resume.md`.
- Focus on the strongest overlaps between the job requirements and the resume.
- For requirements the user doesn't meet, simply don't mention them — do not fabricate or exaggerate.
- Never say "I have experience with X" unless X appears in the resume.

## Step 1: Search Job Boards

If no specific URLs were provided, search each target website:

### SEEK
1. Navigate to `https://www.seek.com.au`
2. Search for "React" or "JavaScript" in the relevant location
3. Extract job listing URLs from search results
4. Filter: only jobs with React or JavaScript in the title or description

### Web3 Career
1. Navigate to `https://web3.career`
2. Search for React or JavaScript roles
3. Extract job listing URLs from search results

Collect up to 10 job URLs per session (configurable in Preferences).

## Step 2: Extract Job Details

For each job URL:

1. Navigate to the URL.
2. Wait 2-3 seconds for the page to load.
3. Extract using `get_page_text` and/or `read_page`:
   - Job title
   - Company name
   - Location
   - Salary range (if listed)
   - Employment type (full-time, contract, etc.)
   - Key requirements (skills, experience, qualifications)
   - Job description summary
   - Application method (apply on site, redirect to ATS, etc.)
4. Take a screenshot for the session log.

## Step 3: Deduplication Check

For each extracted job:
1. Check MEMORY.md "Applied Jobs" table.
2. Match on: company name + role title, OR URL (normalized).
3. If match found with status `Applied`: skip it, report "Already applied to [Company] - [Role]. Skipping."
4. If match found with status `Failed`: ask user "Previously failed to apply. Retry?"

## Step 4: Generate Cover Letter

For each new job:

1. **Analyze the job listing** against `resume.md`:
   - Identify which skills/experience match the listed requirements
   - Identify the 2-3 strongest alignment points
   - Note any gaps

2. **Generate a tailored cover letter** following these rules:
   - **Length:** 250-350 words maximum
   - **Tone:** Australian professional -- direct, confident, not overly formal
   - **Structure:**
     - Opening: What role, where found, one sentence on why strong fit
     - Body (2 paragraphs): Specific experience mapping to their requirements. Reference actual projects, technologies, outcomes from resume.md. Do not repeat the job ad back to them.
     - Closing: Availability, enthusiasm, call to action
   - **Must reference** at least 2 specific requirements from the job listing that MATCH skills in resume.md
   - **Must pull** at least 2 concrete experiences from resume.md
   - **ABSOLUTE CONSTRAINT:** Every skill, technology, and experience claim MUST exist in resume.md. If it's not in the resume, do not mention it. No exceptions.
   - **For unmatched requirements:** Simply don't address them. Focus the letter on what DOES match. Never apologise for missing skills either.
   - **BANNED phrases:** "I am writing to express my interest", "passionate about", "excited to", "proven track record", any content-free filler
   - **DO use:** specific numbers, project names, technologies, and outcomes from the resume

3. **Present to user for approval:**
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
   2. Edit cover letter
   3. Skip this job
   ```

4. **Wait for user approval.** Do not proceed without explicit confirmation.

## Step 5: Fill Application Form

After user approves the cover letter:

1. Click the "Apply" button on the job listing page.
2. Take a screenshot of the form.
3. Use `read_page` or `describe_ui` to get the form structure.
4. Fill fields from MEMORY.md User Profile:
   - Name, email, phone, location, work rights, LinkedIn, etc.
   - Map field labels to profile data (e.g., "Mobile Number" = Phone)
5. Paste the cover letter into the cover letter field (text area or upload).
6. Handle resume upload:
   - Look for a file input element
   - If found, use `upload_image` with the ref to upload `~/Documents/resume26.pdf`
   - If upload fails, notify user: "Please upload your resume manually. I've filled all other fields."
7. Handle screening questions:
   - Check MEMORY.md "Common Screening Answers" for known answers
   - For unknown questions, use AI reasoning based on resume.md to generate answers
   - Store new Q&A pairs in MEMORY.md for future use
8. Handle common patterns:
   - Dropdowns: use `form_input` with matching option text
   - Radio buttons: click the appropriate option
   - Checkboxes (privacy policy, terms): check them
   - Multi-step forms: navigate through each step
   - "How did you hear about us?": "Job Board" or the platform name

## Step 6: Pre-Submit Review

**Critical safety gate.**

1. Take a screenshot of the completed form.
2. Present summary to user:
   ```
   ## Ready to Submit: [Company] - [Role]

   ### Form Summary
   - Name: [value]
   - Email: [value]
   - Resume: [uploaded / manual needed]
   - Cover Letter: [pasted / uploaded]
   - Screening answers: [list]

   ### Submit?
   1. Yes, submit now
   2. Let me review first
   3. Skip this application
   ```
3. **Wait for explicit confirmation before clicking Submit.**

## Step 7: Submit and Verify

After user confirms:

1. Click the Submit button.
2. Wait 3-5 seconds.
3. Take a screenshot of the result page.
4. Verify success (look for "Thank you", "Application submitted", etc.).
5. If successful: record as `Applied` in MEMORY.md.
6. If failed: screenshot the error, record as `Failed`, ask user to retry or skip.

## Step 8: Update Memory

After each application attempt:
1. Add row to "Applied Jobs" table in MEMORY.md.
2. Update statistics.
3. Add any new screening Q&A pairs to "Common Screening Answers".
4. Add platform notes if anything new was learned about the site's form structure.

## Step 9: iPad Notification

After all jobs in the session are processed:
```bash
curl -s -X POST "http://localhost:19847/notify" \
  -H "Content-Type: application/json" \
  -d '{"message": "Job Applications: X submitted, Y skipped, Z failed"}' \
  || true
```

## Step 10: Update Session Log

Append to `.claude/skills/job-applicant/SESSION-LOG.md`:

```markdown
---

## Session [N] — [YYYY-MM-DD HH:MM]

**Jobs processed:** X
**Source:** [SEEK / web3.career / direct URLs]

### Results
| # | Company | Role | Action | Result |
|---|---------|------|--------|--------|
| 1 | [company] | [role] | Applied | Success |
| 2 | [company] | [role] | Skipped | Duplicate |

### Cover Letters Generated
- [Company] - [Role]: [first line...]

### Platform Notes Learned
- [any new learnings]

### Errors
- [any errors]
```

## Safety Rules

- **NEVER submit without user approval.** Two gates: cover letter approval + pre-submit review.
- **NEVER create accounts.** If login/account creation is required, ask the user to handle it.
- **NEVER enter passwords.** If login is needed, the user handles it manually.
- **Max 5 applications per session** (configurable in Preferences).
- **30-second minimum delay** between applications on the same platform.
- **CAPTCHA:** If detected, stop and notify user. Record as `Failed -- CAPTCHA`.
- **Bot detection:** If rate-limited or blocked, stop immediately and notify user.
- **Missing fields:** If a required field isn't in the profile, ask the user. Store their answer for next time.
- **File upload failure:** Notify user to upload manually, pause and wait.
