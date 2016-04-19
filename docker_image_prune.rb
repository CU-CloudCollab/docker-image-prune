#!/usr/bin/env ruby
#
# Fucntionality to list and prune images labeled with date labels
# (in the format used by automatic Jenkins builds).
#
# Relies on ~/.docker/config.json for auth keys.
#
# See README.md
#
require 'rest-client'
require 'json'

DEFAULT_DTR_HOSTNAME= 'dtr.cucloud.net'
DEFAULT_TAG_DATETIME_FORMAT = '%m%d%Y-%H%M%S'
DEFAULT_EXPIRATION_AGE_DAYS = 90
DEFAULT_DRY_RUN = false
DEFAULT_MINIMUM_IMAGES_TO_KEEP = 3

class DockerImagePrune

  attr_accessor :dtr_hostname, :datetime_format
  attr_accessor :namespace, :dry_run, :expiration_age_days

  def repo_list

    repos = []

    puts "Determining repos in #{dtr_repos_url}."

    response = RestClient::Request.execute(
      method: :get,
      url: dtr_repos_url,
      headers: request_headers.merge({params: {start: 0, limit: 9999}})
    )
    if (response.code == 200)
      # puts response.body
      j = JSON.parse(response.body)
      j["repositories"].each { | repo | repos << repo["name"] }
    end
    return repos
  end

  def delete_tags_for_namespace
    result = true
    repos = repo_list
    repos.each do | repo |
      puts "Processing repository: #{repo}"
      expired_tags = expired_tags_for_repo(repo)
      result = delete_tags_for_repo(repo, expired_tags) && result
    end
    return result
  end

  def initialize(namespace, expiration_age_days = DEFAULT_EXPIRATION_AGE_DAYS, dry_run = DEFAULT_DRY_RUN)
    @namespace = namespace
    @expiration_age_days = expiration_age_days
    @dry_run = dry_run

    # Here is potential to add more flexibility later.
    @dtr_hostname = DEFAULT_DTR_HOSTNAME
    @datetime_format = DEFAULT_TAG_DATETIME_FORMAT
    @dtr_auth = nil

    config_hash = JSON.parse(File.read("#{Dir.home}/.docker/config.json"))
    if !config_hash["auths"]["https://#{@dtr_hostname}"].nil?
      @dtr_auth = config_hash["auths"]["https://#{@dtr_hostname}"]["auth"]
    elsif !config_hash["auths"][@dtr_hostname].nil?
      @dtr_auth = config_hash["auths"][@dtr_hostname]["auth"]
    end
    raise "Cannot find credentials for #{@dtr_hostname} in #{Dir.home}/.docker/config.json" if @dtr_auth.nil?
  end

  def expired_tags_for_repo(repo)

    target_tags = []
    all_date_tags = get_timestamp_tags(repo)
    if all_date_tags.nil? || all_date_tags.empty?
      puts "No images to be removed."
      return target_tags
    end

    # ensure tags are in timestamp order
    all_date_tags.sort!{|x, y| x[:datetime] <=> y[:datetime]}

    expired_tags = all_date_tags.select { |t| t[:expired] }

    puts "Total images with timestamp tags: #{all_date_tags.length}"
    puts "Total images to expire, nominally: #{expired_tags.length}"

    if expired_tags.length == 0
      # nothing to do
      puts "No images will be removed."
    elsif all_date_tags.length >= expired_tags.length + DEFAULT_MINIMUM_IMAGES_TO_KEEP
      # delete all the expired tags, because there are at least 3 other datetime tags not expired
      puts "All #{expired_tags.length} images with expired tags will be removed."
      target_tags = expired_tags.map { | t | t[:tag] }
    elsif all_date_tags.length <= DEFAULT_MINIMUM_IMAGES_TO_KEEP
      # can't delete any of the expired tags
      puts "In order to keep a minimum of #{DEFAULT_MINIMUM_IMAGES_TO_KEEP} timestamped images, none will be removed."
      target_tags = []
    else
      # delete only all_date_tags.length - 3 of the expired tags
      keep = all_date_tags.length - DEFAULT_MINIMUM_IMAGES_TO_KEEP
      puts "Removing oldest #{keep} images in order to keep a minimum of #{DEFAULT_MINIMUM_IMAGES_TO_KEEP} timestamped images."
      target_tags = expired_tags[0..(keep - 1)].map {|t| t[:tag]}
    end
    return target_tags
  end

  # Delete the images from the given repo having the provided tags
  def delete_tags_for_repo(repo, tags)
    all_deleted = true
    tags.each do | tag |
      if dry_run
        puts "Image #{@namespace}/#{repo}:#{tag} would be removed."
      else
        response = RestClient::Request.execute(
          method: :delete,
          url: dtr_manifests_url(repo, tag),
          headers: request_headers
        )
        if (response.code == 202)
          puts "Success. Removed expired tag: #{@namespace}/#{repo}:#{tag}"
        else
          puts "Could not remove expired tag: #{@namespace}/#{repo}:#{tag}"
          all_deleted = false
        end
      end
    end
    return all_deleted
  end

  private

  # Return a Hash of tags that have timestamps embedded in them
  # Each item returned is a hash containing keys: :tag, :datetime, :expired
  def get_timestamp_tags(repo)

    all_date_tags = []

    puts "Determining expired tags in #{dtr_tags_url(repo)}. Max age: #{@expiration_age_days} days."

    response = RestClient::Request.execute(
      method: :get,
      url: dtr_tags_url(repo),
      headers: request_headers
    )
    if (response.code == 200)
      # puts response.body
      j = JSON.parse(response.body)
      j["tags"].each do | tag |
        name = tag["name"]
        datetimeString = name.split('-', 2)[1]
        if datetimeString.nil? || datetimeString.empty?
          # puts "Invalid datetime tag #{name}. Ignoring."
          next
        end
        datetime_tag = Date.strptime(datetimeString, @datetime_format)
        all_date_tags << {tag: name,
                          datetime: datetime_tag,
                          expired:  (datetime_tag + @expiration_age_days) < Date.today
                        }
      end
    end
    return all_date_tags
  end

  def request_headers
    {"Authorization" => "Basic #{@dtr_auth}", "Content-Type" => "application/json"}
  end

  def dtr_tags_url(repo)
    "https://#{@dtr_hostname}/api/v0/repositories/#{@namespace}/#{repo}/tags"
  end

  def dtr_repos_url
    "https://#{@dtr_hostname}/api/v0/repositories/#{@namespace}"
  end

  def dtr_manifests_url(repo, tag)
    "https://#{@dtr_hostname}/api/v0/repositories/#{@namespace}/#{repo}/manifests/#{tag}"
  end
end
