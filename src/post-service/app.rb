require "json"
require "securerandom"
require "sinatra"
require "time"
require "aws-sdk-s3"

set :bind, "0.0.0.0"
set :port, 8080

bucket = ENV["S3_BUCKET"]
region = ENV["AWS_REGION"]

abort "S3_BUCKET is not set" if bucket.nil? || bucket.empty?
abort "AWS_REGION is not set" if region.nil? || region.empty?

s3_client = Aws::S3::Client.new(region: region)
posts = {}

def post_response(post, user_id = nil)
  {
    id: post[:id],
    user_id: post[:user_id],
    content: post[:content],
    hashtags: post[:hashtags],
    image_url: post[:image_url],
    created_at: post[:created_at],
    like_count: post[:likes].length,
    liked: user_id ? post[:likes].include?(user_id) : false
  }
end

get "/posts" do
  user_id = params["user_id"]
  hashtag = params["hashtag"]

  content_type :json

  posts.values
    .select { |post| !hashtag || post[:hashtags].include?(hashtag) }
    .map { |post| post_response(post, user_id) }
    .to_json
end

post "/posts" do
  post = {
    id: SecureRandom.uuid,
    user_id: params["user_id"],
    content: params["content"],
    hashtags: JSON.parse(params["hashtags"] || "[]"),
    image_url: nil,
    created_at: Time.now.utc.iso8601,
    likes: []
  }

  file = params["image"]
  if file
    key = "posts/#{post[:id]}"

    s3_client.put_object(
      bucket: bucket,
      key: key,
      body: file[:tempfile],
      content_type: file[:type]
    )

    post[:image_url] = "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
  end

  posts[post[:id]] = post

  content_type :json
  status 201
  post_response(post).to_json
end

post "/posts/:post_id/like" do
  post = posts[params["post_id"]]
  halt 404 unless post

  user_id = JSON.parse(request.body.read)["user_id"]
  post[:likes] << user_id unless post[:likes].include?(user_id)

  content_type :json
  post_response(post, user_id).to_json
end

delete "/posts/:post_id/like" do
  post = posts[params["post_id"]]
  halt 404 unless post

  user_id = JSON.parse(request.body.read)["user_id"]
  post[:likes].delete(user_id)

  content_type :json
  post_response(post, user_id).to_json
end

get "/posts/user/:user_id/count" do
  user_id = params["user_id"]

  content_type :json
  { count: posts.values.count { |post| post[:user_id] == user_id } }.to_json
end
