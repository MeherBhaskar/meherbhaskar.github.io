---
layout: default
title: Meher Bhaskar, notes on agentic AI that survives production
---

<section class="hero">
  <p class="kicker">Personal blog</p>
  <h1>Meher Bhaskar</h1>
  <p class="tagline">Notes on agentic AI that survives production.</p>
  <p class="intro">I'm a Senior Data Scientist building production agentic AI at retail scale. I write about what breaks between the demo and production: evals, multi-agent systems, benchmarking, and the engineering in between. Deeply useful, no fluff, new notes every few days.</p>
  <p class="social">
    <a href="https://github.com/MeherBhaskar">GitHub</a>
    <a href="https://linkedin.com/in/meherbhaskar">LinkedIn</a>
    <a href="https://meherbhaskar.medium.com">Medium</a>
    <a href="{{ '/feed.xml' | relative_url }}">RSS</a>
  </p>
</section>

<section class="post-list">
  <h2>Latest writing</h2>
  {% for post in site.posts limit: 8 %}
  <article class="post-card">
    <p class="post-meta">{{ post.date | date: "%B %-d, %Y" }}{% if post.tags and post.tags.size > 0 %} &middot; {% for tag in post.tags %}<span class="tag">{{ tag }}</span>{% endfor %}{% endif %}</p>
    <h3><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h3>
    <p class="excerpt">{{ post.description | default: post.excerpt | strip_html | truncate: 180 }}</p>
  </article>
  {% endfor %}
  <p><a href="{{ '/archive/' | relative_url }}">All posts</a></p>
</section>
