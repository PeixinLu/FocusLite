#!/usr/bin/env ruby

require "rdoc"
require "rdoc/markdown"
require "rdoc/markup/to_html"

source_path, output_path = ARGV
abort "Usage: render-release-notes.rb <source.md> <output.html>" unless source_path && output_path

markdown = File.read(source_path, encoding: "UTF-8")
document = RDoc::Markdown.parse(markdown)
fragment = RDoc::Markup::ToHtml.new(RDoc::Options.new).convert(document)

html = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="color-scheme" content="light dark">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      :root { font-family: -apple-system, BlinkMacSystemFont, sans-serif; color-scheme: light dark; }
      body { margin: 0; padding: 16px 20px; font-size: 13px; line-height: 1.55; }
      h2 { margin: 14px 0 8px; font-size: 16px; }
      h2 > span { display: none; }
      ul { margin: 6px 0 14px; padding-left: 22px; }
      li { margin: 4px 0; }
      li p { margin: 0; }
      a { color: #1677ff; }
    </style>
  </head>
  <body>
  #{fragment}
  </body>
  </html>
HTML

File.write(output_path, html, encoding: "UTF-8")
