---
layout: default
title: Meher Bhaskar, notes on agentic AI that survives production
---

<section class="hero">
  <p class="kicker">Senior Data Scientist &middot; Production Agentic AI</p>
  <h1>Meher Bhaskar</h1>
  <p class="tagline">I build agentic AI that survives production.</p>
  <p class="intro">I'm Meher Bhaskar Madiraju, a Senior Data Scientist at Walmart Global Tech in Bentonville. I build production agentic AI systems at retail scale: multi-agent systems for real business workflows used across 600+ locations, a multi-agent hyperparameter tuning platform, and geography-based demand forecasting. I write here about what breaks between the demo and production: evals, orchestration, benchmarking, and the engineering in between. Deeply useful, no fluff, new notes every few days.</p>
  <p class="social">
    <a href="mailto:meherbhaskar.madiraju@gmail.com">Email</a>
    <a href="https://github.com/MeherBhaskar">GitHub</a>
    <a href="https://linkedin.com/in/meherbhaskar">LinkedIn</a>
    <a href="https://scholar.google.com/citations?hl=en&user=FxAZvUIAAAAJ">Google Scholar</a>
    <a href="{{ '/feed.xml' | relative_url }}">RSS</a>
  </p>
</section>

<section class="section">
  <h2>Proof, not promises</h2>
  <div class="stats">
    <div class="stat"><strong>600+</strong><span>retail locations running production agentic AI I built</span></div>
    <div class="stat"><strong>26</strong><span>essays on production AI, published monthly since September 2024</span></div>
    <div class="stat"><strong>4</strong><span>research papers on arXiv on benchmarking AI agents</span></div>
    <div class="stat"><strong>2026</strong><span>speaker, OMS Analytics Conference at Georgia Tech</span></div>
  </div>
</section>

<section class="section">
  <h2>What I build</h2>
  <div class="cards">
    <div class="card">
      <h3>Production agentic AI</h3>
      <p>Multi-agent systems for real business workflows at retail scale, live across 600+ locations. The full lifecycle: tool design, orchestration patterns, fallback ladders, cost and latency budgets, and operating agents like real services.</p>
    </div>
    <div class="card">
      <h3>ML platforms and forecasting</h3>
      <p>A multi-agent platform for hyperparameter optimization, plus geography-based demand forecasting that feeds real planning decisions.</p>
    </div>
    <div class="card">
      <h3>Agent evaluation and benchmarking</h3>
      <p>RigorBench and Benchmark Radar: research on measuring what AI agents actually do, because benchmarks measure benchmarks until you fix the methodology.</p>
    </div>
  </div>
</section>

<section class="section">
  <h2>Speaking</h2>
  <div class="talk">
    <p class="talk-title">"Beyond the Prototype: Engineering Agentic AI for Production"</p>
    <p class="talk-meta">OMS Analytics Conference, Georgia Tech &middot; October 9, 2026</p>
  </div>
</section>

<section class="section">
  <h2>Background</h2>
  <ul class="timeline">
    <li><strong>Senior Data Scientist, Walmart Global Tech</strong>, <span class="when">Bentonville, Jul 2023 to present</span></li>
    <li><strong>Data Scientist, Merkle Inc.</strong>, <span class="when">Atlanta, 2022 to 2023; Bengaluru, 2020 to 2022</span></li>
    <li><strong>MS Analytics, Georgia Tech</strong>, <span class="when">2022 to 2024</span></li>
    <li><strong>B.Tech Computer Science, Manipal</strong>, <span class="when">2016 to 2020</span></li>
  </ul>
  <p>Research: <a href="https://scholar.google.com/citations?hl=en&user=FxAZvUIAAAAJ">Google Scholar</a> &middot; <a href="https://orcid.org/0009-0002-1454-0668">ORCID</a>. The longer version: <a href="{{ '/about/' | relative_url }}">about me</a>.</p>
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

<section class="section cta">
  <h2>Working on agents in production?</h2>
  <p class="section-sub">I'm always up for talking shop about agentic AI, evals, and multi-agent systems. The best way to reach me is email.</p>
  <p><a class="btn" href="mailto:meherbhaskar.madiraju@gmail.com">meherbhaskar.madiraju@gmail.com</a></p>
</section>
