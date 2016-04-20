#!/usr/bin/env ruby
#
# Fucntionality to list and prune images labeled with date labels
# (in the format used by automatic Jenkins builds).
#
# - Relies on ~/.docker/config.json for auth keys.
# - Uses STDERR for user messaging so that it can be utilized more easily from bash scripts
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

    STDERR.puts "Determining repos in #{dtr_repos_url}."

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

    timestamp_tags = get_timestamp_tags(repo)
    if timestamp_tags.nil? || timestamp_tags.empty?
      STDERR.puts "No images to be removed."
      return []
    end

    return DockerImagePrune.determine_expired_tags(timestamp_tags, @expiration_age_days, @datetime_format)
  end

  # Delete the images from the given repo having the provided tags
  def delete_tags_for_repo(repo, tags)
    all_deleted = true
    tags.each do | tag |
      if dry_run
        STDERR.puts "Image #{@namespace}/#{repo}:#{tag} would be removed."
      else
        response = RestClient::Request.execute(
          method: :delete,
          url: dtr_manifests_url(repo, tag),
          headers: request_headers
        )
        if (response.code == 202)
          STDERR.puts "Success. Removed expired tag: #{@namespace}/#{repo}:#{tag}"
        else
          STDERR.puts "Could not remove expired tag: #{@namespace}/#{repo}:#{tag}"
          all_deleted = false
        end
      end
    end
    return all_deleted
  end

# Query the repo and get all tags from it.
# Returns tags having format XXXX-YYYYY and assumes that such tags
# are timesamps tags.
def get_timestamp_tags(repo)

  result_tags = []

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
      result_tags << name
    end
  end
  return result_tags
end

# Input: a simple list of tags with nominal date format
# (e.g., XXXXX-YYYYY where YYYY is the datetime format)
# Ouput: the list of timestamp tags that are expired,
# taking account of the minimum 3 images we need to keep
# around.
#
# This is a class function so that it can more easily be called from a bash script,
# as in prune-local.sh.
#
def DockerImagePrune.determine_expired_tags(tags, expiration_age_days=DEFAULT_EXPIRATION_AGE_DAYS, datetime_format=DEFAULT_TAG_DATETIME_FORMAT)
  target_tags = []
  all_date_tags = []

  tags.each do | tag |
    datetimeString = tag.split('-', 2)[1]
    if datetimeString.nil? || datetimeString.empty?
      STDERR.puts "Invalid datetime tag #{name}. Ignoring."
      next
    end
    datetime_tag = Date.strptime(datetimeString, datetime_format)
    all_date_tags << {tag: tag,
                      datetime: datetime_tag,
                      expired:  (datetime_tag + expiration_age_days) < Date.today
                      }
  end

  # ensure tags are in timestamp order
  all_date_tags.sort!{|x, y| x[:datetime] <=> y[:datetime]}

  expired_tags = all_date_tags.select { |t| t[:expired] }

  STDERR.puts "Total images with timestamp tags: #{all_date_tags.length}"
  STDERR.puts "Total images to expire, nominally: #{expired_tags.length}"

  if expired_tags.length == 0
    # nothing to do
    STDERR.puts "No images will be removed."
  elsif all_date_tags.length >= expired_tags.length + DEFAULT_MINIMUM_IMAGES_TO_KEEP
    # delete all the expired tags, because there are at least 3 other datetime tags not expired
    STDERR.puts "All #{expired_tags.length} images with expired tags will be removed."
    target_tags = expired_tags.map { | t | t[:tag] }
  elsif all_date_tags.length <= DEFAULT_MINIMUM_IMAGES_TO_KEEP
    # can't delete any of the expired tags
    STDERR.puts "In order to keep a minimum of #{DEFAULT_MINIMUM_IMAGES_TO_KEEP} timestamped images, none will be removed."
    target_tags = []
  else
    # delete only all_date_tags.length - 3 of the expired tags
    keep = all_date_tags.length - DEFAULT_MINIMUM_IMAGES_TO_KEEP
    STDERR.puts "Removing oldest #{keep} images in order to keep a minimum of #{DEFAULT_MINIMUM_IMAGES_TO_KEEP} timestamped images."
    target_tags = expired_tags[0..(keep - 1)].map {|t| t[:tag]}
  end

  return target_tags
end

  private

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
