import random
import uuid

from locust import HttpUser, between, task


class TrafficUser(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        identifier = uuid.uuid4().hex
        response = self.client.post("/users", json={
            "username": f"Traffic Duck {identifier}",
            "handle": f"@trafficduck{identifier}",
            "profile_picture": "/assets/avatar.jpg",
            "bio": "Just here to make traffic",
        })
        if not response.ok:
            raise RuntimeError(f"Failed to create traffic user: {response.status_code} {response.text}")

        self.user_id = response.json()["id"]
        self.liked_post_ids = set()
        self.followed_user_ids = set()
        self.feed_post_ids = set()
        self.feed_user_ids = set()

        response = self.client.get("/feed", params={"user_id": self.user_id})
        if not response.ok:
            raise RuntimeError(f"Failed to load feed: {response.status_code} {response.text}")

        self._update_feed_state(response.json())

    @task(10)
    def browse_feed(self):
        self.client.get("/feed", params={"user_id": self.user_id})

    @task(2)
    def search(self):
        hashtag = random.choice(["food", "travel", "bread", "lakes", "pondlife"])
        self.client.get("/feed", params={"user_id": self.user_id, "hashtag": hashtag})

    @task(5)
    def like_post(self):
        post_ids = self.feed_post_ids - self.liked_post_ids
        if post_ids:
            post_id = random.choice(tuple(post_ids))
            response = self.client.post(f"/posts/{post_id}/like", json={"user_id": self.user_id})
            if response.ok:
                self.liked_post_ids.add(post_id)

    @task(1)
    def unlike_post(self):
        if self.liked_post_ids:
            post_id = random.choice(tuple(self.liked_post_ids))
            response = self.client.delete(f"/posts/{post_id}/like", json={"user_id": self.user_id})
            if response.ok:
                self.liked_post_ids.discard(post_id)

    @task(1)
    def follow_user(self):
        user_ids = self.feed_user_ids - self.followed_user_ids
        if user_ids:
            target_id = random.choice(tuple(user_ids))
            response = self.client.post(f"/users/{self.user_id}/follow/{target_id}")
            if response.ok:
                self.followed_user_ids.add(target_id)

    @task(1)
    def unfollow_user(self):
        if self.followed_user_ids:
            target_id = random.choice(tuple(self.followed_user_ids))
            response = self.client.delete(f"/users/{self.user_id}/follow/{target_id}")
            if response.ok:
                self.followed_user_ids.discard(target_id)

    def _update_feed_state(self, posts):
        for item in posts:
            if item.get("type") != "post":
                continue

            self.feed_post_ids.add(item["id"])
            self.feed_user_ids.add(item["user"]["id"])

        self.feed_user_ids.discard(self.user_id)
