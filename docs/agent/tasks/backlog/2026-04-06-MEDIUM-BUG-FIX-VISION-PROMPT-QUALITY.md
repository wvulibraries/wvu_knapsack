# TASK: Improve moondream vision prompt quality
**Status**: BACKLOG
**Priority**: MEDIUM
**Type**: bug-fix
**Created**: 2026-04-06
**Last Updated**: 2026-04-06

---

## Agent Assignment

**Assigned To**: GPT-4.1 0x
**Why This Agent**: Single constant change plus prompt engineering testing — fully specified, no architecture needed
**Supervision Level**: 🔴 Watched carefully

---

## Context

`VisionService` calls the local Ollama/Moondream model to generate alt text for images. During testing, the returned alt text was `"!!!IMAGE OF!!!"` — moondream was echoing back a fragment of the negative instruction in the prompt rather than describing the image.

The prompt was updated to remove negative instructions, but further tuning may be needed. Moondream is a small vision model (1.6B parameters) and performs best with short, direct, positive prompts.

**File**: `app/services/vision_service.rb`, lines 10–11

---

## Problem Statement

**Current prompt** (after initial fix):
```ruby
PROMPT = 'Briefly describe what is shown in this image in one concise sentence under 125 characters.'
```

**Previous bad output**: `"!!!IMAGE OF!!!"`
**Expected output**: Something like `"A political cartoon depicting soldiers crossing a river in winter."`

The prompt may still produce inconsistent results. This task validates output quality across several test images and refines the prompt if needed.

---

## Files Involved

### Primary Files — you will edit these
| File | Purpose | Key Section |
|---|---|---|
| `app/services/vision_service.rb` | Ollama vision integration | `PROMPT` constant, line ~10 |

---

## Implementation Steps

### Step 1 — Test current prompt quality
In Rails console (containers must be running):
```bash
docker compose exec web bundle exec rails console
```
```ruby
Pry.config.pager = false
AccountElevator.switch!('testing')

# Get 5 FileSets and test
conn = Hyrax::SolrService.instance.conn
resp = conn.get('select', params: { q: 'has_model_ssim:FileSet', rows: 5, fl: 'id' })
resp['response']['docs'].each do |doc|
  fs = Hyrax.query_service.find_by(id: Valkyrie::ID.new(doc['id'])) rescue next
  result = VisionService.call(fs)
  puts "#{doc['id']}: #{result.inspect}"
end
```

### Step 2 — Evaluate output
Good output: descriptive sentence about image content, under 125 chars, no `!!!` artifacts
Bad output: echoes prompt text, empty, or `nil`

### Step 3 — Tune prompt if needed
The prompt is in `app/services/vision_service.rb`:
```ruby
PROMPT = 'Briefly describe what is shown in this image in one concise sentence under 125 characters.'
```

Moondream responds well to:
- Short, direct instructions
- Positive framing only ("describe X" not "do not say Y")
- Single task per prompt

Alternatives to try if quality is poor:
- `'What is shown in this image? One sentence only.'`
- `'Describe this image briefly.'`
- `'Write a short description of this image for a visually impaired user.'`

### Step 4 — Also check AltTextGeneratorService prompt
`app/services/alt_text_generator_service.rb` has a separate prompt for text-based summarization.
Verify it also produces clean output:
```ruby
AltTextGeneratorService.call('A photograph of soldiers crossing a river during the Civil War, taken in 1863.')
```

---

## Acceptance Criteria
- [ ] `VisionService.call(fs)` returns a meaningful English sentence for at least 4/5 test images
- [ ] No `!!!` artifacts in output
- [ ] Output is under 125 characters
- [ ] `nil` returns only when image is genuinely unprocessable (non-image mime type, corrupt file)

---

## Stop Conditions — escalate to user immediately if:
- All 5 test images return nil — may indicate Ollama connectivity issue
- Output quality is consistently poor despite prompt changes — may need a different model

---

## Dependencies
**Blocked by**: none
**Blocks**: none
**Related tasks**: `2026-04-06-HIGH-REFACTOR-ALT-TEXT-M3-TO-NATIVE-ATTRIBUTE.md`

---

## Completion Report
*To be filled in by implementing agent*
