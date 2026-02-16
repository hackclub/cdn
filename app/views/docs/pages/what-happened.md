---
title: What happened?
icon: question
order: 99
---

# what happened?

## the first Hack Club CDN

in ~april 2020, Max & Lachlan built a CDN. a silly little thing...
a more civilized weapon for an organization Hack Club is no longer shaped like at all...,,

it worked by creating a new [Vercel](https://vercel.app) deploy every time someone wanted to add a file.
while i'm sure vercel loved this (~~their ToS says "don't do this"~~), at some point (maybe december of 2025ish?) all the `cloud-*-hack-club-bot.vercel.app` file URLs went down.
deployment retention policies being what they are, the deployments are not retained.
AIUI this is because we didn't pay the bill.

Hack Club CDN V1/V2 deletum est.

## the second Hack Club CDN

recognizing that CDNing the prior way was kinda silly, in ~february of 2025 Tom (@Deployor) wrote a new CDN!
this was backed by a Hetzner object storage bucket, which some might say is a better design decision...

eventually the card tied to the Hetzner account got receipt-locked & all the resources and data in it got nuked.
AIUI this is because we didn't pay the bill.

Hack Club CDN V3 deletum est.

## but why is it _gone_?

combination of two confounding factors:
<ul><li>no backups<ul><li> two is one, one is none, we had none :-(</li></ul></li> <li>and, we gave out direct bucket URLs<ul><li>this was our achilles heel, i think.
if it's not on a domain you own, you're at the mercy of your storage provider falling out from under you.</li></ul></li>
</ul>

## i had files there!

i think we failed the community here, and i'm sorry.
i've recovered as many files as i can by scraping the originals from slack, and those are available at
`https://cdn.hackclub.com/rescue?url=<vercel/hel1 URL>`. this is a stable URL and should work forever.

here are stats on the recovery, keeping in mind that these are only the files we know about:

| Source                | Recovered    | Unfortunately lost to time |
|-----------------------|--------------|----------------------------|
| Vercel via Slack      | 12,126 files | 1,341 files                |
| Hetzner via Slack     | 11,616 files | 725 files                  |
| Vc/hel1 via Scrapbook | 21,773 files | 1,067 files                |

(h/t @msw for the [original pass](https://github.com/maxwofford/cdn-bucketer) at the scraper script!)
## why should i trust that this one will last?
very fair question given we've lost 2 CDNs and counting so far...
this time is different because it's on a domain Hack Club owns - even if Cloudflare R2 disappears one day, we can restore a backup and redirect the `https://cdn.hackclub.com/<id>` URLs somewhere else without you changing everywhere they're linked from. and, at least as long as i'm here......we're gonna pay the bill this time.

CDN V4 is not fantastic code.
it's written to be thrown out and replaced with something better in a few years.
*BUT!* it is architected in such a way that when we eventually do that, **nobody will have to change their URLs**.

~your pal nora <3
