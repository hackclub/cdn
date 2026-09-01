# frozen_string_literal: true

# JSON-LD structured data, so agents can read the site's identity without
# scraping the page.
module StructuredDataHelper
  GITHUB_URL = "https://github.com/hackclub/cdn"
  HACK_CLUB_URL = "https://hackclub.com"

  def json_ld_tag(data)
    tag.script(ERB::Util.json_escape(data.to_json).html_safe, type: "application/ld+json")
  end

  def home_structured_data
    {
      "@context" => "https://schema.org",
      "@graph" => [ software_application_ld, organization_ld, website_ld ]
    }
  end

  private

  def software_application_ld
    {
      "@type" => "SoftwareApplication",
      "@id" => "#{canonical_root}/#software-application",
      "name" => MetadataHelper::SITE_NAME,
      "alternateName" => canonical_host,
      "url" => canonical_root,
      "description" => MetadataHelper::SITE_DESCRIPTION,
      "applicationCategory" => "DeveloperApplication",
      "applicationSubCategory" => "File hosting and content delivery",
      "operatingSystem" => "Any (web-based)",
      "softwareVersion" => OpenAPISpec::API_VERSION,
      "image" => og_image_url,
      "sameAs" => [ GITHUB_URL ],
      "isAccessibleForFree" => true,
      "offers" => {
        "@type" => "Offer",
        "price" => "0",
        "priceCurrency" => "USD",
        "availability" => "https://schema.org/InStock"
      },
      "featureList" => [
        "Upload files from the browser or the HTTP API",
        "Permanent CDN URLs for every upload",
        "Import files from an existing URL",
        "Batch upload and batch delete",
        "Per-account storage quotas"
      ],
      "audience" => {
        "@type" => "Audience",
        "audienceType" => "Hack Club members and their projects"
      },
      "provider" => { "@id" => "#{HACK_CLUB_URL}/#organization" },
      "publisher" => { "@id" => "#{HACK_CLUB_URL}/#organization" },
      "softwareHelp" => {
        "@type" => "WebPage",
        "name" => "Hack Club CDN documentation",
        "url" => "#{canonical_root}/docs"
      },
      "potentialAction" => {
        "@type" => "CreateAction",
        "name" => "Upload a file",
        "target" => {
          "@type" => "EntryPoint",
          "urlTemplate" => "#{canonical_root}/api/v4/upload",
          "httpMethod" => "POST",
          "contentType" => "multipart/form-data",
          "actionApplication" => { "@id" => "#{canonical_root}/#software-application" }
        }
      }
    }
  end

  def organization_ld
    {
      "@type" => "Organization",
      "@id" => "#{HACK_CLUB_URL}/#organization",
      "name" => "Hack Club",
      "url" => HACK_CLUB_URL,
      "logo" => "https://assets.hackclub.com/flag-standalone.svg",
      "description" => "A nonprofit network of high school makers and coding clubs.",
      "sameAs" => [
        "https://github.com/hackclub",
        "https://hackclub.com/",
        "https://en.wikipedia.org/wiki/Hack_Club"
      ]
    }
  end

  def website_ld
    {
      "@type" => "WebSite",
      "@id" => "#{canonical_root}/#website",
      "name" => MetadataHelper::SITE_NAME,
      "url" => canonical_root,
      "description" => MetadataHelper::SITE_DESCRIPTION,
      "inLanguage" => "en",
      "publisher" => { "@id" => "#{HACK_CLUB_URL}/#organization" },
      "about" => { "@id" => "#{canonical_root}/#software-application" }
    }
  end
end
