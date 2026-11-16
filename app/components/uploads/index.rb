# frozen_string_literal: true

class Components::Uploads::Index < Components::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  register_output_helper :paginate

  def initialize(uploads:, query: nil)
    @uploads = uploads
    @query = query
  end

  def view_template
    dropzone_form
    div(class: "uploads-container", data: { uploads_container: true }, style: "max-width: 1200px; margin: 0 auto; padding: 24px;") do
      header_section
      upload_hero_card
      search_section
      uploads_list
      pagination_section if uploads.respond_to?(:total_pages) && uploads.total_pages > 1
    end
    batch_delete_bar
  end

  private

  attr_reader :uploads, :query

  def header_section
    header(style: "margin-bottom: 24px;") do
      h1(style: "font-size: 2rem; font-weight: 600; margin: 0; color: var(--fgColor-default);") { "Uploads" }
      p(style: "color: var(--fgColor-muted, #656d76); margin: 6px 0 0; font-size: 14px;") do
        "Drop files to upload, paste from clipboard, or browse your files."
      end
    end
  end

  def upload_hero_card
    div(
      class: "Box upload-card",
      data: { upload_card: true },
      style: "position: relative; background: var(--bgColor-default); border: 1px solid var(--borderColor-default); border-radius: 6px; overflow: hidden; margin-bottom: 32px;"
    ) do
      div(
        class: "upload-hero-stage",
        data: { hero_stage: true }
      ) do
        # Resting view
        div(
          class: "upload-resting-view",
          data: { resting_view: true }
        ) do
          div(style: "margin-bottom: 10px; color: var(--fgColor-muted);") do
            render Primer::Beta::Octicon.new(icon: :upload, size: :medium)
          end

          h3(style: "font-size: 16px; font-weight: 600; margin: 0 0 10px 0; color: var(--fgColor-default);") do
            "Drag and drop or paste directly"
          end

          div(style: "display: flex; gap: 8px; align-items: center; justify-content: center; margin-bottom: 16px;") do
            span(class: "Label Label--secondary", style: "font-size: 11px; padding: 2px 7px;") { "Up to 40 files" }
            span(class: "Label Label--secondary", style: "font-size: 11px; padding: 2px 7px;") { "Max 100MB each" }
          end

          div(style: "width: 140px; height: 1px; background: var(--borderColor-default); margin-bottom: 18px;")

          label(
            for: "dropzone-file-input",
            class: "btn btn-primary",
            style: "cursor: pointer; padding: 7px 20px; font-size: 14px; font-weight: 500; display: inline-flex; align-items: center; gap: 6px;"
          ) do
            render Primer::Beta::Octicon.new(icon: :upload, size: :small)
            plain "Upload files"
          end
        end

        # Dropzone view with mascot
        render_orph_drop_card
      end
    end
  end

  def render_orph_drop_card
    div(
      class: "upload-orph-view dropzone-container",
      data: { orph_view: true },
      aria: { hidden: "true" }
    ) do
      div(class: "orph-stage", data: { orph_stage: true }) do
        div(class: "orph-character", data: { orph_character: true }) do
          img(
            src: "/orph-closed-mouth.svg",
            class: "orph-graphic orph-closed",
            alt: "Orph closed mouth"
          )
          img(
            src: "/orph-open-mouth.svg",
            class: "orph-graphic orph-open",
            alt: "Orph open mouth"
          )
          div(class: "orph-pupil orph-pupil-left", data: { orph_pupil_left: true })
          div(class: "orph-pupil orph-pupil-right", data: { orph_pupil_right: true })
          div(class: "orph-speech-bubble", data: { orph_bubble: true }) { "Feed me files!" }
        end
      end

      # Right side: Content
      div(class: "dropzone-content", data: { orph_content: true }) do
        div(class: "dropzone-upload-badge") do
          raw safe(%(<svg viewBox="0 0 16 16" fill="currentColor" style="width: 14px; height: 14px;"><path d="M7.75 2a.75.75 0 0 1 .75.75V7h2.25a.75.75 0 0 1 .53 1.28l-3 3a.75.75 0 0 1-1.06 0l-3-3A.75.75 0 0 1 4.75 7H7V2.75A.75.75 0 0 1 7.75 2Z"></path><path d="M2.5 10.75a.75.75 0 0 1 .75.75v1a.5.5 0 0 0 .5.5h8.5a.5.5 0 0 0 .5-.5v-1a.75.75 0 0 1 1.5 0v1A2 2 0 0 1 12.25 14.5h-8.5A2 2 0 0 1 1.75 12.5v-1a.75.75 0 0 1 .75-.75Z"></path></svg>))
          span { "Drag & Drop" }
        end

        h2(class: "dropzone-title", data: { dropzone_title: true }) { "Feed me, mortal" }

        div(class: "dropzone-meta") do
          span(class: "dropzone-tag") { "Up to 40 files" }
          span(class: "dropzone-tag") { "Max 100MB each" }
        end
      end
    end
  end

  def search_section
    div(style: "margin-bottom: 24px;") do
      form_with url: uploads_path, method: :get do
        div(style: "display: flex; gap: 12px;") do
          input(
            type: "search",
            name: "query",
            placeholder: "Search files...",
            value: query,
            class: "form-control",
            style: "flex: 1; max-width: 400px;"
          )
          button(type: "submit", class: "btn") do
            render Primer::Beta::Octicon.new(icon: :search, mr: 1)
            plain "Search"
          end
        end

        # Dropzone view with mascot
        render_orph_drop_card
      end
    end
  end

  def render_orph_drop_card
    div(
      class: "upload-orph-view dropzone-container",
      data: { orph_view: true },
      aria: { hidden: "true" }
    ) do
      div(class: "orph-stage", data: { orph_stage: true }) do
        div(class: "orph-character", data: { orph_character: true }) do
          img(
            src: "/orph-closed-mouth.svg",
            class: "orph-graphic orph-closed",
            alt: "Orph closed mouth"
          )
          img(
            src: "/orph-open-mouth.svg",
            class: "orph-graphic orph-open",
            alt: "Orph open mouth"
          )
          div(class: "orph-pupil orph-pupil-left", data: { orph_pupil_left: true })
          div(class: "orph-pupil orph-pupil-right", data: { orph_pupil_right: true })
          div(class: "orph-speech-bubble", data: { orph_bubble: true }) { "Feed me files!" }
        end
      end

      # Right side: Content
      div(class: "dropzone-content", data: { orph_content: true }) do
        div(class: "dropzone-upload-badge") do
          raw safe(%(<svg viewBox="0 0 16 16" fill="currentColor" style="width: 14px; height: 14px;"><path d="M7.75 2a.75.75 0 0 1 .75.75V7h2.25a.75.75 0 0 1 .53 1.28l-3 3a.75.75 0 0 1-1.06 0l-3-3A.75.75 0 0 1 4.75 7H7V2.75A.75.75 0 0 1 7.75 2Z"></path><path d="M2.5 10.75a.75.75 0 0 1 .75.75v1a.5.5 0 0 0 .5.5h8.5a.5.5 0 0 0 .5-.5v-1a.75.75 0 0 1 1.5 0v1A2 2 0 0 1 12.25 14.5h-8.5A2 2 0 0 1 1.75 12.5v-1a.75.75 0 0 1 .75-.75Z"></path></svg>))
          span { "Drag & Drop" }
        end

        h2(class: "dropzone-title", data: { dropzone_title: true }) { "Feed me, mortal" }

        div(class: "dropzone-meta") do
          span(class: "dropzone-tag") { "Up to 40 files" }
          span(class: "dropzone-tag") { "Max 100MB each" }
        end
      end
    end
  end

  def uploads_list
    if uploads.any?
      div(style: "display: flex; align-items: center; gap: 8px; margin-bottom: 8px; padding: 4px 0;") do
        input(
          type: "checkbox",
          id: "select-all-uploads",
          data: { batch_select_all: true },
          style: "cursor: pointer;"
        )
        label(for: "select-all-uploads", style: "font-size: 13px; color: var(--fgColor-muted, #656d76); cursor: pointer;") do
          plain "Select all"
        end
      end

      render Primer::Beta::BorderBox.new do |box|
        uploads.each do |upload|
          box.with_row do
            div(style: "display: flex; align-items: flex-start; gap: 12px;") do
              input(
                type: "checkbox",
                name: "ids[]",
                value: upload.id,
                form: "batch-delete-form",
                data: { batch_select_item: true, upload_id: upload.id },
                style: "margin-top: 6px; cursor: pointer;"
              )
              div(style: "flex: 1; min-width: 0;") do
                render Components::Uploads::Row.new(upload: upload, compact: false)
              end
            end
          end
        end
      end
    else
      empty_state
    end
  end

  def empty_state
    render Primer::Beta::Blankslate.new(border: true) do |component|
      component.with_visual_icon(icon: query.present? ? :search : :upload, size: :medium)
      component.with_heading(tag: :h2) do
        query.present? ? "No files found" : "Drop files here"
      end
      component.with_description do
        if query.present?
          "Try a different search query"
        else
          "Drag and drop files anywhere on this page, or use the Upload button (up to 40 files at once)"
        end

        # Dropzone view with mascot
        render_orph_drop_card
      end
    end
  end

  def render_orph_drop_card
    div(
      class: "upload-orph-view dropzone-container",
      data: { orph_view: true },
      aria: { hidden: "true" }
    ) do
      div(class: "orph-stage", data: { orph_stage: true }) do
        div(class: "orph-character", data: { orph_character: true }) do
          img(
            src: "/orph-closed-mouth.svg",
            class: "orph-graphic orph-closed",
            alt: "Orph closed mouth"
          )
          img(
            src: "/orph-open-mouth.svg",
            class: "orph-graphic orph-open",
            alt: "Orph open mouth"
          )
          div(class: "orph-pupil orph-pupil-left", data: { orph_pupil_left: true })
          div(class: "orph-pupil orph-pupil-right", data: { orph_pupil_right: true })
          div(class: "orph-speech-bubble", data: { orph_bubble: true }) { "Feed me files!" }
        end
      end

      # Right side: Content
      div(class: "dropzone-content", data: { orph_content: true }) do
        div(class: "dropzone-upload-badge") do
          raw safe(%(<svg viewBox="0 0 16 16" fill="currentColor" style="width: 14px; height: 14px;"><path d="M7.75 2a.75.75 0 0 1 .75.75V7h2.25a.75.75 0 0 1 .53 1.28l-3 3a.75.75 0 0 1-1.06 0l-3-3A.75.75 0 0 1 4.75 7H7V2.75A.75.75 0 0 1 7.75 2Z"></path><path d="M2.5 10.75a.75.75 0 0 1 .75.75v1a.5.5 0 0 0 .5.5h8.5a.5.5 0 0 0 .5-.5v-1a.75.75 0 0 1 1.5 0v1A2 2 0 0 1 12.25 14.5h-8.5A2 2 0 0 1 1.75 12.5v-1a.75.75 0 0 1 .75-.75Z"></path></svg>))
          span { "Drag & Drop" }
        end

        h2(class: "dropzone-title", data: { dropzone_title: true }) { "Feed me, mortal" }

        div(class: "dropzone-meta") do
          span(class: "dropzone-tag") { "Up to 40 files" }
          span(class: "dropzone-tag") { "Max 100MB each" }
        end
      end
    end
  end

  def pagination_section
    div(style: "margin-top: 24px; text-align: center;") do
      paginate uploads
    end
  end

  def dropzone_form
    form_with url: uploads_path, method: :post, multipart: true, data: { dropzone_form: true } do
      input(type: "file", name: "files[]", id: "dropzone-file-input", multiple: true, data: { dropzone_input: true }, style: "display: none;")
    end
  end

  def batch_delete_bar
    div(id: "batch-delete-bar", data: { batch_bar: true }, style: "display: none; position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%); background: var(--bgColor-default, #fff); border: 1px solid var(--borderColor-default, #d0d7de); border-radius: 12px; padding: 12px 20px; z-index: 100; box-shadow: 0 8px 24px rgba(0,0,0,0.12); min-width: 320px; max-width: 600px;") do
      div(style: "display: flex; align-items: center; gap: 16px;") do
        span(data: { batch_count: true }, style: "font-size: 14px; font-weight: 600; white-space: nowrap;") { "0 selected" }
        div(style: "flex: 1;")
        button(type: "button", data: { batch_deselect: true }, class: "btn btn-sm", style: "white-space: nowrap;") { "Deselect" }
        form_with url: destroy_batch_uploads_path, method: :delete, id: "batch-delete-form", data: { batch_delete_form: true } do
          button(type: "submit", class: "btn btn-sm btn-danger", style: "white-space: nowrap;") do
            render Primer::Beta::Octicon.new(icon: :trash, mr: 1)
            plain "Delete"
          end
        end

        # Dropzone view with mascot
        render_orph_drop_card
      end
    end
  end

  def render_orph_drop_card
    div(
      class: "upload-orph-view dropzone-container",
      data: { orph_view: true },
      aria: { hidden: "true" }
    ) do
      div(class: "orph-stage", data: { orph_stage: true }) do
        div(class: "orph-character", data: { orph_character: true }) do
          img(
            src: "/orph-closed-mouth.svg",
            class: "orph-graphic orph-closed",
            alt: "Orph closed mouth"
          )
          img(
            src: "/orph-open-mouth.svg",
            class: "orph-graphic orph-open",
            alt: "Orph open mouth"
          )
          div(class: "orph-pupil orph-pupil-left", data: { orph_pupil_left: true })
          div(class: "orph-pupil orph-pupil-right", data: { orph_pupil_right: true })
          div(class: "orph-speech-bubble", data: { orph_bubble: true }) { "Feed me files!" }
        end
      end

      # Right side: Content
      div(class: "dropzone-content", data: { orph_content: true }) do
        div(class: "dropzone-upload-badge") do
          raw safe(%(<svg viewBox="0 0 16 16" fill="currentColor" style="width: 14px; height: 14px;"><path d="M7.75 2a.75.75 0 0 1 .75.75V7h2.25a.75.75 0 0 1 .53 1.28l-3 3a.75.75 0 0 1-1.06 0l-3-3A.75.75 0 0 1 4.75 7H7V2.75A.75.75 0 0 1 7.75 2Z"></path><path d="M2.5 10.75a.75.75 0 0 1 .75.75v1a.5.5 0 0 0 .5.5h8.5a.5.5 0 0 0 .5-.5v-1a.75.75 0 0 1 1.5 0v1A2 2 0 0 1 12.25 14.5h-8.5A2 2 0 0 1 1.75 12.5v-1a.75.75 0 0 1 .75-.75Z"></path></svg>))
          span { "Drag & Drop" }
        end

        h2(class: "dropzone-title", data: { dropzone_title: true }) { "Feed me, mortal" }

        div(class: "dropzone-meta") do
          span(class: "dropzone-tag") { "Up to 40 files" }
          span(class: "dropzone-tag") { "Max 100MB each" }
        end
      end
    end
  end
end
