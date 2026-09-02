# frozen_string_literal: true

# The XML sitemap served at /sitemap.xml, following the sitemaps.org 0.9
# protocol. It lists every public page that is safe to index: the homepage and
# one entry per documentation page. Signed-in-only pages (/uploads, /api_keys,
# /admin), redirects (/docs) and file delivery URLs are deliberately excluded.
class Sitemap
  NAMESPACE = "http://www.sitemaps.org/schemas/sitemap/0.9"
  HOME_TEMPLATE = Rails.root.join("app/views/static_pages/home.html.erb")

  Entry = Data.define(:loc, :lastmod, :changefreq)

  class << self
    def host = CDNHost.host

    def base_url = CDNHost.base_url

    def entries = [ home_entry, *doc_entries ]

    def to_xml
      urls = entries.map { |entry| url_element(entry) }.join

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="#{NAMESPACE}">
        #{urls}</urlset>
      XML
    end

    private

    def home_entry
      Entry.new(loc: "#{base_url}/", lastmod: mtime(HOME_TEMPLATE), changefreq: "weekly")
    end

    def doc_entries
      DocPage.all.map do |doc|
        Entry.new(
          loc: "#{base_url}#{doc.path}",
          lastmod: doc.updated_at || Time.current,
          changefreq: "monthly"
        )
      end
    end

    def mtime(path)
      File.exist?(path) ? File.mtime(path) : Time.current
    end

    def url_element(entry)
      <<~XML.indent(2)
        <url>
          <loc>#{escape(entry.loc)}</loc>
          <lastmod>#{entry.lastmod.utc.iso8601}</lastmod>
          <changefreq>#{escape(entry.changefreq)}</changefreq>
        </url>
      XML
    end

    def escape(value) = ERB::Util.html_escape(value.to_s)
  end
end
