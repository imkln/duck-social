use axum::{extract::Query, routing::get, Json, Router};
use reqwest::Client;
use serde::{de::DeserializeOwned, Deserialize, Serialize};
use std::env;

#[derive(Deserialize)]
struct Post {
    id: String,
    user_id: String,
    content: String,
    hashtags: Vec<String>,
    image_url: Option<String>,
    like_count: u32,
    liked: bool,
    created_at: String,
}

#[derive(Deserialize)]
struct User {
    id: String,
    username: String,
    handle: String,
    profile_picture_url: String,
    bio: String,
    follower_count: u32,
    following_count: u32,
}

#[derive(Deserialize, Serialize)]
struct Ad {
    title: String,
    content: String,
    image_url: String,
}

#[derive(Deserialize)]
struct PostCount {
    count: u32,
}

#[derive(Deserialize)]
struct FeedQuery {
    user_id: String,
    hashtag: Option<String>,
}

#[derive(Serialize)]
struct FeedUser {
    id: String,
    username: String,
    handle: String,
    profile_picture_url: String,
    bio: String,
    post_count: u32,
    follower_count: u32,
    following_count: u32,
}

#[derive(Serialize)]
struct FeedPost {
    id: String,
    user: FeedUser,
    content: String,
    hashtags: Vec<String>,
    image_url: Option<String>,
    like_count: u32,
    liked: bool,
    created_at: String,
}

#[derive(Serialize)]
#[serde(tag = "type")]
enum FeedItem {
    #[serde(rename = "post")]
    Post(FeedPost),
    #[serde(rename = "ad")]
    Ad(Ad),
}

async fn get_json<T: DeserializeOwned>(client: &Client, url: &str) -> Result<T, reqwest::Error> {
    client.get(url).send().await?.error_for_status()?.json().await
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/feed", get(feed));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080")
        .await
        .expect("failed to bind to port 8080");

    axum::serve(listener, app).await.expect("server failed");
}

async fn feed(Query(query): Query<FeedQuery>) -> Result<Json<Vec<FeedItem>>, axum::http::StatusCode> {
    let client = Client::new();
    let post_service_url = env::var("POST_SERVICE_URL").expect("POST_SERVICE_URL is not set");
    let user_service_url = env::var("USER_SERVICE_URL").expect("USER_SERVICE_URL is not set");
    let ad_service_url = env::var("AD_SERVICE_URL").expect("AD_SERVICE_URL is not set");

    let url = match query.hashtag {
        Some(hashtag) => format!("{post_service_url}/posts?user_id={}&hashtag={hashtag}", query.user_id),
        None => format!("{post_service_url}/posts?user_id={}", query.user_id),
    };

    let mut posts: Vec<Post> = get_json(&client, &url)
        .await
        .map_err(|_| axum::http::StatusCode::BAD_GATEWAY)?;
    posts.sort_by(|a, b| b.created_at.cmp(&a.created_at));

    let mut feed = Vec::new();

    for (i, post) in posts.into_iter().enumerate() {
        let user: User = get_json(&client, &format!("{user_service_url}/users/{}", post.user_id))
            .await
            .map_err(|_| axum::http::StatusCode::BAD_GATEWAY)?;

        let post_count: PostCount =
            get_json(&client, &format!("{post_service_url}/posts/user/{}/count", post.user_id))
                .await
                .map_err(|_| axum::http::StatusCode::BAD_GATEWAY)?;

        feed.push(FeedItem::Post(FeedPost {
            id: post.id,
            user: FeedUser {
                id: user.id,
                username: user.username,
                handle: user.handle,
                profile_picture_url: user.profile_picture_url,
                bio: user.bio,
                post_count: post_count.count,
                follower_count: user.follower_count,
                following_count: user.following_count,
            },
            content: post.content,
            hashtags: post.hashtags,
            image_url: post.image_url,
            like_count: post.like_count,
            liked: post.liked,
            created_at: post.created_at,
        }));

        if (i + 1) % 10 == 0 {
            let ad: Ad = get_json(&client, &format!("{ad_service_url}/ads"))
                .await
                .map_err(|_| axum::http::StatusCode::BAD_GATEWAY)?;

            feed.push(FeedItem::Ad(ad));
        }
    }

    Ok(Json(feed))
}
