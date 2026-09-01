# frozen_string_literal: true

# Serves /sitemap.xml for crawlers and agents discovering the public pages.
class SitemapsController < ApplicationController
  skip_before_action :require_authentication!

  def show
    expires_in 1.hour, public: true
    response.set_header("Access-Control-Allow-Origin", "*")

    render plain: Sitemap.to_xml, content_type: "application/xml"
  end
end
