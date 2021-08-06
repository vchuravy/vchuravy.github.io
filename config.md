<!--
Add here global page variables to use throughout your website.
-->
+++
author = "Valentin Churavy"
mintoclevel = 2

# Add here files or directories that should be ignored by Franklin, otherwise
# these files might be copied and, if markdown, processed by Franklin which
# you might not want. Indicate directories by ending the name with a `/`.
# Base files such as LICENSE.md and README.md are ignored by default.
ignore = ["node_modules/"]

# RSS (the website_{title, descr, url} must be defined to get RSS)
generate_rss = true
website_title = "Valentin Churavy's personal webpage"
website_descr = "Valentin Churavy's personal webpage"
website_url   = "https://vchuravy.dev/"
+++

<!--
Add here global latex commands to use throughout your pages.
-->
\newcommand{\R}{\mathbb R}
\newcommand{\scal}[1]{\langle #1 \rangle}

\newcommand{\note}[2]{
@@admonition-note
@@admonition-title Note #1 @@
@@admonition-body #2 @@
@@
}

\newcommand{\warn}[2]{
@@admonition-warn
@@admonition-title Warning #1 @@
@@admonition-body #2 @@
@@
}
