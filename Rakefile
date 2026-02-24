# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"

namespace :verify do
  task :fixtures do
    ruby "-Itest test/test_safety_verification.rb"
  end

  task :selfhost do
    ruby "-Itest test/test_selfhost_verification.rb"
  end
end

task verify: %i[test verify:fixtures verify:selfhost]

task default: %i[test standard]
