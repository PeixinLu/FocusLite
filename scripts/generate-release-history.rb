#!/usr/bin/env ruby

require "cgi"
require "fileutils"
require "json"
require "rdoc"
require "rdoc/markdown"
require "rdoc/markup/to_html"
require "time"

input_path, output_directory, public_base_url = ARGV
abort "Usage: generate-release-history.rb <github-releases.json> <output-directory> <public-base-url>" unless input_path && output_directory && public_base_url

public_base_url = public_base_url.sub(%r{/+$}, "")
payload = JSON.parse(File.read(input_path, encoding: "UTF-8"))
releases = payload.first.is_a?(Array) ? payload.flatten(1) : payload
abort "GitHub releases payload must be an array" unless releases.is_a?(Array)

renderer = RDoc::Markup::ToHtml.new(RDoc::Options.new)

def valid_tag?(tag)
  tag.match?(%r{\Av[0-9A-Za-z._-]+\z})
end

def render_markdown(markdown, renderer)
  renderer.convert(RDoc::Markdown.parse(markdown.to_s))
end

def page_template(title, content, extra_styles = "")
  <<~HTML
    <!doctype html>
    <html lang="zh-CN">
    <head>
      <meta charset="utf-8">
      <meta name="color-scheme" content="light dark">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{CGI.escapeHTML(title)}</title>
      <style>
        :root { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color-scheme: light dark; }
        body { margin: 0 auto; padding: 24px; max-width: 820px; font-size: 15px; line-height: 1.65; }
        h1 { margin: 0 0 24px; font-size: 30px; }
        h2 { margin: 18px 0 8px; font-size: 20px; }
        h2 > span { display: none; }
        ul { padding-left: 24px; }
        li { margin: 5px 0; }
        li p { margin: 0; }
        a { color: #1677ff; }
        .meta { color: #737373; font-size: 13px; }
        #{extra_styles}
      </style>
    </head>
    <body>
    #{content}
    </body>
    </html>
  HTML
end

normalized = releases.map do |release|
  next if release["draft"]

  tag = release["tag_name"].to_s
  next unless valid_tag?(tag)

  local_notes_path = File.join("release-notes", "#{tag}.md")
  markdown = if File.file?(local_notes_path)
               File.read(local_notes_path, encoding: "UTF-8")
             else
               release["body"].to_s
             end
  markdown = "No release notes are available for this version." if markdown.strip.empty?

  asset = Array(release["assets"]).find { |item| item["name"] == "FocusLite.zip" }
  release_url = release["html_url"].to_s
  published_at = release["published_at"] || release["created_at"]
  title = release["name"].to_s.strip
  title = tag if title.empty?
  notes_url = "#{public_base_url}/releases/#{tag}/FocusLite.html"

  versioned_directory = File.join(output_directory, "releases", tag)
  FileUtils.mkdir_p(versioned_directory)
  fragment = render_markdown(markdown, renderer)
  version_page = <<~HTML
    <p class="meta">#{CGI.escapeHTML(published_at.to_s[0, 10])} · <a href="#{CGI.escapeHTML(release_url)}">GitHub Release</a></p>
    #{fragment}
  HTML
  File.write(
    File.join(versioned_directory, "FocusLite.html"),
    page_template("#{title} 更新日志", version_page),
    encoding: "UTF-8"
  )

  {
    "version" => tag.delete_prefix("v"),
    "tag" => tag,
    "title" => title,
    "publishedAt" => published_at,
    "prerelease" => !!release["prerelease"],
    "notesMarkdown" => markdown,
    "notesUrl" => notes_url,
    "releaseUrl" => release_url,
    "downloadUrl" => asset && asset["browser_download_url"]
  }
end.compact

normalized.sort_by! do |release|
  begin
    Time.parse(release["publishedAt"].to_s)
  rescue ArgumentError
    Time.at(0)
  end
end
normalized.reverse!

FileUtils.mkdir_p(output_directory)
manifest = {
  "schemaVersion" => 1,
  "generatedAt" => Time.now.utc.iso8601,
  "releases" => normalized
}
File.write(
  File.join(output_directory, "releases.json"),
  JSON.pretty_generate(manifest) + "\n",
  encoding: "UTF-8"
)

timeline = normalized.map do |release|
  date = CGI.escapeHTML(release["publishedAt"].to_s[0, 10])
  title = CGI.escapeHTML(release["title"])
  url = CGI.escapeHTML(release["notesUrl"])
  fragment = render_markdown(release["notesMarkdown"], renderer)
  <<~HTML
    <article>
      <header><h2><a href="#{url}">#{title}</a></h2><time>#{date}</time></header>
      <div class="notes">#{fragment}</div>
    </article>
  HTML
end.join("\n")

timeline_styles = <<~CSS
  article { padding: 22px 0; border-top: 1px solid color-mix(in srgb, CanvasText 14%, transparent); }
  article header { display: flex; align-items: baseline; justify-content: space-between; gap: 16px; }
  article header h2 { margin: 0; }
  article time { color: #737373; white-space: nowrap; font-size: 13px; }
  .notes h2:first-child { margin-top: 16px; }
CSS
content = "<h1>FocusLite 更新日志</h1>\n#{timeline}"
File.write(
  File.join(output_directory, "changelog.html"),
  page_template("FocusLite 更新日志", content, timeline_styles),
  encoding: "UTF-8"
)

puts "Generated #{normalized.length} releases in #{output_directory}"
