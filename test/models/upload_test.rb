# frozen_string_literal: true

require "test_helper"

class UploadTest < ActiveSupport::TestCase
  def upload_with_key(key)
    Upload.new(blob: ActiveStorage::Blob.new(key: key))
  end

  test "assets_url percent-encodes spaces and non-ASCII in the filename" do
    url = upload_with_key("01a052cd-1427-788d-b424-94b4d3609066/Screenshot 2026-08-30 at 6.42.35 PM.png").assets_url

    assert_equal "https://cdn.hackclub-assets.com/01a052cd-1427-788d-b424-94b4d3609066/" \
                 "Screenshot%202026-08-30%20at%206.42.35%E2%80%AFPM.png", url
    assert url.ascii_only?
  end

  test "assets_url keeps the path separator and encodes reserved characters inside a segment" do
    url = upload_with_key("abc/Képernyőkép #1?.png").assets_url

    assert_equal "https://cdn.hackclub-assets.com/abc/K%C3%A9perny%C5%91k%C3%A9p%20%231%3F.png", url
  end

  test "assets_url leaves plain ASCII keys unchanged" do
    assert_equal "https://cdn.hackclub-assets.com/abc/test-file_1.png", upload_with_key("abc/test-file_1.png").assets_url
  end
end
