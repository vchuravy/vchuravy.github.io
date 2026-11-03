function hfun_bar(vname)
  val = Meta.parse(vname[1])
  return round(sqrt(val), digits=2)
end

function hfun_m1fill(vname)
  var = vname[1]
  return pagevar("index", var)
end

function lx_baz(com, _)
  # keep this first line
  brace_content = Franklin.content(com.braces[1]) # input string
  # do whatever you want here
  return uppercase(brace_content)
end

"""
    {{notes}}

Plug in the list of notes contained in the `/notes/` folder.
"""
function hfun_notes()
    curyear = year(Dates.today())
    io = IOBuffer()
    for year in curyear:-1:2021
        ys = "$year"
        year < curyear && write(io, "\n**$year**\n")
        for month in 12:-1:1
            ms = "0"^(month < 10) * "$month"
            base = joinpath("notes", ys, ms)
            isdir(base) || continue
            posts = filter!(p -> endswith(p, ".md"), readdir(base))
            days  = zeros(Int, length(posts))
            lines = Vector{String}(undef, length(posts))
            for (i, post) in enumerate(posts)
                ps  = splitext(post)[1]
                url = "/notes/$ys/$ms/$ps/"
                surl = strip(url, '/')
                title = pagevar(surl, :title)
                title === nothing && (title = "Untitled")
                pubdate = pagevar(surl, :published)
                if isnothing(pubdate)
                    date    = "$ys-$ms-01"
                    days[i] = 1
                else
                    date    = Date(pubdate, dateformat"d U Y")
                    days[i] = day(date)
                end
                lines[i] = "\n[$title]($url) $date \n"
            end
            # sort by day
            foreach(line -> write(io, line), lines[sortperm(days, rev=true)])
        end
    end
    # markdown conversion adds `<p>` beginning and end but
    # we want to  avoid this to avoid an empty separator
    r = Franklin.fd2html(String(take!(io)), internal=true)
    return r
end

"""
    {{recentnotes}}

Input the 3 latest notes posts.
"""
function hfun_recentnotes()
    curyear = Dates.Year(Dates.today()).value
    ntofind = 3
    nfound  = 0
    recent  = Vector{Pair{String,Date}}(undef, ntofind)
    for year in curyear:-1:2019
        for month in 12:-1:1
            ms = "0"^(1-div(month, 10)) * "$month"
            base = joinpath("notes", "$year", "$ms")
            isdir(base) || continue
            posts = filter!(p -> endswith(p, ".md"), readdir(base))
            days  = zeros(Int, length(posts))
            surls = Vector{String}(undef, length(posts))
            for (i, post) in enumerate(posts)
                ps       = splitext(post)[1]
                surl     = "notes/$year/$ms/$ps"
                surls[i] = surl
                pubdate  = pagevar(surl, :published)
                days[i]  = isnothing(pubdate) ?
                                1 : day(Date(pubdate, dateformat"d U Y"))
            end
            # go over month post in antichronological orders
            sp = sortperm(days, rev=true)
            for (i, surl) in enumerate(surls[sp])
                recent[nfound + 1] = (surl => Date(year, month, days[sp[i]]))
                nfound += 1
                nfound == ntofind && break
            end
            nfound == ntofind && break
        end
        nfound == ntofind && break
    end
    resize!(recent, nfound)
    io = IOBuffer()
    for (surl, date) in recent
        url   = "/$surl/"
        title = pagevar(surl, :title)
        title === nothing && (title = "Untitled")
        sdate = "$(day(date)) $(monthname(date)) $(year(date))"
        blurb = pagevar(surl, :rss)
        write(io, """
            <div class="col-lg-4 col-md-12 blog">
              <h3><a href="$url" class="title" data-proofer-ignore>$title</a>
              </h3><span class="article-date">$date</span>
              <p>$blurb</p>
            </div>
            """)
    end
    return String(take!(io))
end

"""
    {{ addcomments }}

Add a comment widget, managed by utterances <https://utteranc.es>.
"""
function hfun_addcomments()
    html_str = """
        <script src="https://utteranc.es/client.js"
            repo="vchuravy/vchuravy.github.io"
            issue-term="pathname"
            theme="github-light"
            crossorigin="anonymous"
            async>
        </script>
    """
    return html_str
end

using JSON

"""
    {{talks}}

Plug in the list of talks contained in the `/talks/` folder.
"""
function hfun_talks()
    pluto_json = "talks/pluto_export.json"
    if !isfile(pluto_json)
        return ""
    end
    info = JSON.parsefile("talks/pluto_export.json")
    notebooks = info["notebooks"]

    entries = map(collect(notebooks)) do (file, data)
       dir = first(split(file, "."))
       fm = get(data, "frontmatter", Dict())
       title = strip(replace(get(fm, "title", dir), "_" => " "))
       date = get(fm, "date", "")
       desc = get(fm, "description", "")
       (; dir, title, date, desc)
    end
    # newest first, undated notebooks last
    sort!(entries, by = e -> e.date, rev = true)

    io = IOBuffer()
    for e in entries
       line = "- "
       isempty(e.date) || (line *= "$(e.date): ")
       line *= "[$(e.title)](/talks/$(e.dir))"
       isempty(e.desc) || (line *= " -- $(e.desc)")
       write(io, line, "\n")
    end
    r = Franklin.fd2html(String(take!(io)), internal=true)
    return r
end

"""
    talk_citation(dir)

Citation data for the talk exported to `/talks/<dir>/`, read from the Pluto
frontmatter in `talks/pluto_export.json`. Returns `nothing` if the notebook
has no explicit title or sets `no_citation = true`.
"""
function talk_citation(dir)
    pluto_json = "talks/pluto_export.json"
    isfile(pluto_json) || return nothing
    notebooks = JSON.parsefile(pluto_json)["notebooks"]
    data = get(notebooks, "$dir.jl", nothing)
    data === nothing && return nothing
    fm = get(data, "frontmatter", Dict())
    get(fm, "no_citation", false) == true && return nothing

    # PlutoSliderServer falls back to the file name if no title is set
    title = strip(get(fm, "title", ""))
    (isempty(title) || title == dir) && return nothing

    date  = get(fm, "date", "")
    venue = get(fm, "description", "")
    year  = let m = match(r"\d{4}", date); m === nothing ? "" : m.match end

    authors = map(a -> a["name"], get(fm, "author", Dict[]))
    isempty(authors) && (authors = [globvar(:author)])

    # BibTeX author field: "Last, First and Last, First"
    author_bibtex = join(map(authors) do name
        parts = split(name)
        length(parts) >= 2 ? "$(last(parts)), $(join(parts[1:end-1], " "))" : name
    end, " and ")

    # BibTeX citation key: firstauthorlastname + year + urlslug
    slug = lowercase(replace(dir, r"[^a-zA-Z0-9]" => ""))
    key  = "$(lowercase(last(split(first(authors)))))$(year):$(slug)"

    url = rstrip(globvar(:website_url), '/') * "/talks/$dir/"

    return (; title, date, year, venue, authors, author_bibtex, key, url)
end

talk_dir() = basename(dirname(locvar(:fd_rpath)))

"""
    {{citetalk_meta}}

Highwire Press `citation_*` meta tags for an exported talk notebook.
Inserted into the `<head>` of `talks/<dir>/index.html` by `export_talks.jl`.
"""
function hfun_citetalk_meta()
    c = talk_citation(talk_dir())
    c === nothing && return ""
    io = IOBuffer()
    write(io, "<meta name=\"citation_title\" content=\"$(Franklin.htmlesc(c.title))\" />\n")
    for name in c.authors
        write(io, "<meta name=\"citation_author\" content=\"$(Franklin.htmlesc(name))\" />\n")
    end
    isempty(c.date) || write(io, "<meta name=\"citation_publication_date\" content=\"$(replace(c.date, "-" => "/"))\" />\n")
    write(io, "<meta name=\"citation_public_url\" content=\"$(c.url)\" />\n")
    return String(take!(io))
end

"""
    {{citetalk}}

"Cite this talk" box with an inline citation and a BibTeX entry for an
exported talk notebook. Appended to `talks/<dir>/index.html` by
`export_talks.jl`.
"""
function hfun_citetalk()
    c = talk_citation(talk_dir())
    c === nothing && return ""

    venue_inline = isempty(c.venue) ? "" : " $(c.venue)."
    inline_cite = "$(join(c.authors, ", ")). ($(c.year)). $(c.title).$(venue_inline) $(c.url)"

    venue_field = isempty(c.venue) ? "" : "\n  howpublished = {$(c.venue)},"
    date_field  = isempty(c.date)  ? "" : "\n  date         = {$(c.date)},"
    bibtex = """@misc{$(c.key),
      author       = {$(c.author_bibtex)},
      title        = {$(c.title)},$(venue_field)
      year         = {$(c.year)},$(date_field)
      url          = {$(c.url)},
    }"""

    return """
        <link rel="stylesheet" href="/css/citation.css">
        <div class="citation">
            <h2>Cite this talk</h2>
            <p>$(Franklin.htmlesc(inline_cite))</p>
            <pre><code>$(Franklin.htmlesc(bibtex))</code></pre>
        </div>
        """
end
