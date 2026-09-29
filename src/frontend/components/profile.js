import { currentUser, userReady } from "./user.js";

const profile = document.querySelector("#profile");

async function loadProfile() {
  const [userResponse, postCountResponse] = await Promise.all([
    fetch(`/users/${currentUser.id}`),
    fetch(`/posts/user/${currentUser.id}/count`)
  ]);

  if (!userResponse.ok || !postCountResponse.ok) {
    throw new Error("Failed to load profile");
  }

  const user = await userResponse.json();
  const postCount = await postCountResponse.json();

  profile.innerHTML = `
    <img src="${user.profile_picture_url || "/images/avatar.jpg"}">

    <div>
      <strong>${user.username}</strong>
      <span>${user.handle}</span>
    </div>

    <p>${user.bio}</p>

    <div class="profile-stats">
      <span>${postCount.count} posts</span>
      <span>${user.follower_count} followers</span>
      <span>${user.following_count} following</span>
    </div>
  `;
}

userReady.then(loadProfile);
