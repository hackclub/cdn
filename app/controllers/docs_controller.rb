# frozen_string_literal: true

class DocsController < ApplicationController
  include HighVoltage::StaticPage

  skip_before_action :require_authentication!

  before_action :load_docs_navigation

  def show
    @doc = DocPage.find(params[:id])
  end

  private

  def load_docs_navigation
    @docs = DocPage.all
  end

  def page_finder_factory
    DocPage
  end
end
