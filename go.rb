#!/usr/bin/env ruby
#
# Command line wrapper for DockerImagePrune
#
#
require 'optparse'
require_relative "docker_image_prune"

options = {namespace: nil, expiration_age_days: 90, dry_run: true}

parser = OptionParser.new do |opts|
	opts.banner = "Remove Docker Trusted Repository images that are older than n days based on timestamp in tags. \n\nUsage: go.rb [options]"

  opts.on('-n', '--namespace namespace', '(required) DTR namespace (e.g., cs)') do |x|
		options[:namespace] = x;
	end

  # opts.on('-r', '--repo respository', '(required) DTR respository name (e.g., helloworld)') do |x|
	# 	options[:repository] = x;
	# end

	opts.on('-a', '--expiration age', Integer, 'maximum age in days (default = 90)') do |x|
		options[:expiration_age_days] = x;
	end

  opts.on('-p', '--prune', 'prune the images (defaults to false, i.e. a dry run)') do |x|
		options[:dry_run] = false;
	end

	opts.on('-h', '--help', 'displays this help') do
		puts opts
		exit
	end
end

parser.parse!

mandatory = [:namespace]
missing = mandatory.select{ |param| options[param].nil? }
unless missing.empty?
  puts "Missing required parameters: #{missing.join(', ')}"
  puts parser
  exit
end

dip = DockerImagePrune.new(options[:namespace], options[:expiration_age_days], options[:dry_run])
result = dip.delete_tags_for_namespace
Kernel.exit(result)
