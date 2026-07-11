---
name: linkedin-post
description: Write and optimize LinkedIn posts for maximum engagement. Use when user asks to create, draft, write, review, or improve LinkedIn posts. Also triggers on "social media post for LinkedIn", "professional networking post", "optimize my LinkedIn content", or requests to reach professional audiences on LinkedIn.
---

# LinkedIn Post Skill

Data-backed guidelines for high-engagement LinkedIn content.

## Workflow

1. **Determine task type:**
   - **Writing new post?** → Gather topic/message from user, then apply structure and guidelines below
   - **Reviewing existing post?** → Check against Pre-Publish Checklist, suggest specific improvements

2. **For new posts:**
   - Ask for topic/key message if not provided
   - Choose content type (personal story, hot take, how-to, etc.)
   - Write hook first, then body, then CTA
   - Add formatting and hashtags
   - Verify against checklist

3. **For reviews:**
   - Identify what's working
   - List specific issues with data-backed reasoning
   - Provide rewritten version

## Example Output

**User request:** "Write a post about learning from failure in tech"

**Good output:**
```
I mass-deleted our production database.

It was 2 AM. I was "fixing" a bug. One wrong WHERE clause and 3 years of customer data vanished.

My hands shook as I called my CTO.

What happened next changed how I think about failure:
→ He asked if I was okay before asking about the database
→ We had backups (thank god) but the recovery took 6 hours
→ Monday, we did a blameless postmortem

The lesson wasn't "be more careful."

It was: build systems that assume humans will make mistakes.

Now I build with guardrails. Confirmation prompts. Staging environments. Required peer reviews for anything touching prod.

What's a failure that made you better at your job? 👇

#engineering #leadership #techculture
```
(1,247 characters, personal failure story, specific hook, clear takeaway, comment-driving question)

**Bad output:**
```
Excited to share my thoughts on failure! 🎉

Failure is important for growth. We all make mistakes and that's okay! The key is to learn from them and keep moving forward. 

Here are some tips:
- Learn from mistakes
- Keep trying
- Stay positive

What do you think about failure? Let me know in the comments!

#failure #success #motivation #growth #mindset #leadership #tech #learning
```
(Why it fails: generic hook, no specific story, vague advice, 8 hashtags, emoji overuse)

## Core Rules

1. **Data over opinions** - Every recommendation backed by engagement data
2. **Authenticity wins** - Personal stories outperform polished announcements
3. **Comments > Likes** - 1 comment = 5 likes in algorithmic weight
4. **Consistency beats virality** - Regular posting compounds engagement

## Post Structure

### Length: 1,200-1,500 Characters

```
Hook (1-2 lines):     50-100 chars
Body (the meat):      1,000-1,200 chars
CTA (call to action): 100-200 chars
```

This triggers "see more" expansion (counted as engagement) while remaining readable in 60-90 seconds.

### Formatting

**Do:**

- Line breaks every 1-2 sentences (+45% engagement)
- Bullet points or numbered lists (+38% engagement)
- One emoji per paragraph max (+22% engagement)
- 3-5 relevant hashtags (+15% engagement)
- Use arrows (→) for list items

**Don't:**

- Emoji in every line (-25% engagement)
- Wall of text (-40% engagement)
- More than 5 hashtags (-20% engagement)
- Excessive caps (-15% engagement)

### Template

```
[Hook line - no emoji]

[2-3 sentence paragraph]

[2-3 sentence paragraph]

Key points:
→ Point one
→ Point two
→ Point three

[Conclusion paragraph]

[CTA - one emoji OK here]

#relevanthashtag #another #onemore
```

## First Line (The Hook)

The first line determines 2.8x engagement difference.

### High-Performing Hooks

| Pattern | Example | Engagement |
|---------|---------|------------|
| Controversial take | "Hot take: Your resume doesn't matter" | 4.2% |
| Number + outcome | "I made $100K from one cold email" | 3.9% |
| Failure story | "I got fired. Best thing that happened" | 3.7% |
| Question | "Why do 90% of startups fail?" | 3.4% |
| Counterintuitive | "The best developers don't code" | 3.3% |

### Hooks to Avoid

- "Excited to share that..." (0.8%)
- "Check out my new course!" (0.6%)
- "Great things are coming" (0.5%)
- Link only posts (0.4%)

## Content Types by Engagement

```
Personal failure story:     4.8%  <- BEST
Career lesson/reflection:   4.2%
Industry hot take:          3.9%
How-to/tutorial:            3.1%
Company milestone:          2.1%
Job posting:                1.8%
Product announcement:       1.4%
Article share (no context): 0.9%  <- WORST
```

**The vulnerability premium**: Genuine struggles get 3-5x more engagement than polished success stories.

## Post Format by Engagement

```
Carousel (5-10 slides): 5.2%  <- BEST
Single image:           3.4%
Text only:              3.1%
Video (< 60 sec):       2.8%
Document/PDF:           2.6%
Video (> 60 sec):       1.9%
Link to article:        1.4%  <- WORST
```

### Optimal Carousel Structure

1. Slide 1: Hook/promise
2. Slides 2-8: Value delivery
3. Slide 9: Summary
4. Slide 10: CTA + follow prompt

## Timing Strategy

### Best Days

```
Tuesday:    3.2%  <- BEST
Wednesday:  3.0%
Thursday:   2.9%
Monday:     2.7%
Friday:     2.4%
Saturday:   2.1%
Sunday:     1.8%
```

### Best Times by Content Type

| Content Type | Best Time | Reason |
|--------------|-----------|--------|
| Career advice | Tue 7-8 AM | Commute scrolling |
| Technical tutorials | Wed 11 AM-1 PM | Lunch break learning |
| Industry hot takes | Thu 8-9 AM | Ready to argue |
| Personal stories | Sun 7-9 PM | Reflective mood |

**Pro tip**: Sunday evening posts (6-9 PM) that gain initial traction get a "head start" for Monday morning algorithm boost.

## Driving Comments

Comments are worth 5x more than likes algorithmically. Use these triggers:

1. **Ask specific questions**: "What's the worst interview question you've gotten?"
2. **Invite disagreement**: "Unpopular opinion: [take]. Change my mind."
3. **Request stories**: "Reply with your biggest career mistake."
4. **Create debate**: "Which is better for startups: remote or in-office?"

**Critical**: Reply to comments within the first hour for +67% total engagement.

## Pre-Publish Checklist

Before posting, verify:

- [ ] First line would make someone stop scrolling
- [ ] 1,200-1,500 characters total
- [ ] Personal story or specific experience included
- [ ] Line breaks every 1-2 sentences
- [ ] Ends with genuine question
- [ ] 3-5 relevant hashtags
- [ ] Posted Tuesday-Thursday, 7-9 AM or 11 AM-1 PM
- [ ] Ready to respond to comments in first hour

## What to Avoid

1. **Engagement pods** - Detected by algorithm, hurts long-term reach (-50% follower growth)
2. **Generic comments** - "Great post!" adds no value
3. **Over-promotion** - Product announcements get 1.4% vs 4.8% for personal stories
4. **Link-only posts** - Lowest engagement at 0.4%
5. **Long videos** - Videos >60 sec drop to 1.9% engagement

## Audience Size Context

Smaller accounts have higher engagement rates:

```
1K-5K followers:   4.1%
5K-10K followers:  3.5%
10K-25K followers: 3.1%
100K+ followers:   1.9%
```

---

*Based on analysis of 50,247 LinkedIn posts from 2,500 tech professionals. Source: Olamide Olaniyan's research.*
