import { loadFeed } from "./feed.js";

const trending = document.querySelector("#trending");
const searchInput = document.querySelector("#search input");

async function loadTrending() {
  const response = await fetch("/trending");
  if (!response.ok) {
    throw new Error("Failed to load trending hashtags");
  }

  const hashtags = await response.json();

  trending.innerHTML = `
    <h3>Trending</h3>

    ${hashtags.map(item => `
      <div class="trending-item">
        <strong>#${item.hashtag}</strong>
      </div>
    `).join("")}
  `;

  trending.querySelectorAll(".trending-item").forEach((item, index) => {
    item.addEventListener("click", () => {
      const hashtag = hashtags[index].hashtag;
      searchInput.value = hashtag;
      loadFeed(hashtag);
    });
  });
}

loadTrending();
