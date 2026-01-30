# frozen_string_literal: true

Lockbox.master_key = ENV["LOCKBOX_MASTER_KEY"] if ENV["LOCKBOX_MASTER_KEY"].present?
