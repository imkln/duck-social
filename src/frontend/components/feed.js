import { currentUser, userReady } from "./user.js";

const feed = document.querySelector("#feed");
const search = document.querySelector("#search");

search.innerHTML = `
  <input type="text" placeholder="Search hashtags">
`;

const searchInput = search.querySelector("input");

export async function loadFeed(hashtag = searchInput.value.trim()) {
  const url = hashtag
    ? `/feed?user_id=${currentUser.id}&hashtag=${encodeURIComponent(hashtag)}`
    : `/feed?user_id=${currentUser.id}`;

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error("Failed to load feed");
  }

  const posts = await response.json();

  feed.innerHTML = posts.map(item => {
    if (item.type === "ad") {
      return `
        <article class="post">
          <div class="post-header">
            <strong>${item.title}</strong>
            <span>Ad</span>
          </div>

          <p>${item.content}</p>

          <img class="post-image" src="${item.image_url}">
        </article>
      `;
    }

    return `
      <article class="post">
        <div class="post-header">
          <img src="${item.user.profile_picture_url || "/images/avatar.png"}">

          <div>
            <strong>${item.user.username}</strong>
            <span>${item.user.handle}</span>
          </div>
        </div>

        <p>${item.content}</p>

        ${item.image_url ? `<img class="post-image" src="${item.image_url}">` : ""}

        <div class="post-hashtags">
          ${item.hashtags.map(hashtag => `<span>#${hashtag}</span>`).join(" ")}
        </div>

        <div class="post-actions">
          <button class="${item.liked ? "liked" : ""}" onclick="toggleLike(this, '${item.id}')">
            ${item.liked ? "♥" : "♡"} ${item.like_count}
          </button>
        </div>
      </article>
    `;
  }).join("");
}

async function toggleLike(button, postId) {
  const liked = button.classList.contains("liked");

  const response = await fetch(`/posts/${postId}/like`, {
    method: liked ? "DELETE" : "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id: currentUser.id })
  });

  if (!response.ok) {
    return;
  }

  const post = await response.json();

  button.classList.toggle("liked", post.liked);
  button.textContent = `${post.liked ? "♥" : "♡"} ${post.like_count}`;
}

searchInput.addEventListener("keydown", event => {
  if (event.key === "Enter") {
    loadFeed();
  }
});

userReady.then(loadFeed);
