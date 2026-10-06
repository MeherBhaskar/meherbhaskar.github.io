---
layout: default
title: Meher Bhaskar, notes on agentic AI that survives production
---

<section class="hero">
  <div class="hero-top">
    <img class="avatar" src="{{ '/assets/images/profile.jpg' | relative_url }}" alt="Meher Bhaskar" width="104" height="104">
    <div>
      <p class="kicker">Agentic AI Engineer</p>
      <h1>Meher Bhaskar</h1>
      <p class="tagline">I build agentic AI that survives production.</p>
    </div>
  </div>
  <p class="intro">I'm Meher Bhaskar Madiraju, a Senior Data Scientist at Walmart Global Tech. I build production agentic AI systems at retail scale: multi-agent systems for real business workflows, with the evals, orchestration, and operating discipline that keep them alive in production. I write here about what breaks between the demo and production, and I research how to benchmark the agents we ship.</p>
  <p class="social">
    <a href="mailto:meherbhaskar.madiraju@gmail.com">Email</a>
    <a href="https://github.com/MeherBhaskar">GitHub</a>
    <a href="https://linkedin.com/in/meherbhaskar">LinkedIn</a>
    <a href="https://scholar.google.com/citations?hl=en&user=FxAZvUIAAAAJ">Google Scholar</a>
    <a href="{{ '/feed.xml' | relative_url }}">RSS</a>
  </p>
</section>

<section class="section">
  <h2>What I do</h2>
  <div class="cards">
    <div class="card">
      <h3>Agentic AI in production</h3>
      <p>Multi-agent systems for real business workflows, running in production. Tool design, orchestration patterns, fallback ladders, cost and latency budgets, and operating agents like real services.</p>
    </div>
    <div class="card">
      <h3>Multi-agent systems</h3>
      <p>Designing agents that work together: coordination, state, and the failure modes that live at the seams. The patterns that hold up under load, and the ones that don't.</p>
    </div>
    <div class="card">
      <h3>Agent evaluation and benchmarking</h3>
      <p>RigorBench and Benchmark Radar: research on measuring what AI agents actually do, because benchmarks measure benchmarks until you fix the methodology.</p>
    </div>
  </div>
</section>

<section class="section">
  <h2>Talks</h2>
  <div class="talk">
    <p class="talk-title">"Beyond the Prototype: Engineering Agentic AI for Production"</p>
    <p class="talk-meta">OMS Analytics Conference, Georgia Tech &middot; October 9, 2026</p>
  </div>
  <div class="talk">
    <p class="talk-title">"From PoC to Production: Deploying Agentic AI at Enterprise Scale"</p>
    <p class="talk-meta">NWA TechFest &middot; August 26, 2026</p>
  </div>
</section>

<section class="section">
  <h2>Research</h2>
  <p>Four research papers on arXiv on benchmarking AI agents, including RigorBench and Benchmark Radar. I've volunteered as a reviewer for TMLR. Profiles: <a href="https://scholar.google.com/citations?hl=en&user=FxAZvUIAAAAJ">Google Scholar</a> &middot; <a href="https://orcid.org/0009-0002-1454-0668">ORCID</a>.</p>
</section>

<section class="post-list">
  <h2>Writing</h2>
  {% for post in site.posts limit: 8 %}
  <article class="post-card">
    <p class="post-meta">{{ post.date | date: "%B %-d, %Y" }}{% if post.tags and post.tags.size > 0 %} &middot; {% for tag in post.tags %}<span class="tag">{{ tag }}</span>{% endfor %}{% endif %}</p>
    <h3><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h3>
    <p class="excerpt">{{ post.description | default: post.excerpt | strip_html | truncate: 180 }}</p>
  </article>
  {% endfor %}
  <p><a href="{{ '/archive/' | relative_url }}">All posts</a></p>
</section>

<section class="section cta">
  <h2>Working on agents in production?</h2>
  <p class="section-sub">I'm always up for talking shop about agentic AI, evals, and multi-agent systems. The best way to reach me is email. <a href="{{ '/about/' | relative_url }}">More about me</a>.</p>
  <p><a class="btn" href="mailto:meherbhaskar.madiraju@gmail.com">meherbhaskar.madiraju@gmail.com</a></p>
</section>
