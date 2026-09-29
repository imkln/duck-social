import argparse
import json
import random
import uuid
from pathlib import Path

import requests

POSTS = [
    ("Spent the weekend exploring a little lakeside town. Highly recommend it.", ["travel", "lakes"], None),
    ("Found a bakery that puts out fresh bread every morning. I will be returning.", ["bread"], "images/posts/bread1.jpg"),
    ("Just to be clear, I am not that Daffy.", ["ducks"], None),
    ("The lake house is beautiful this time of year.", ["lakes", "travel"], None),
    ("There was a great blue heron at the north end of the lake this morning.", ["birdwatching", "nature"], "images/posts/heron1.jpg"),
    ("Someone left an entire loaf near the east path. I have questions.", ["bread", "breadcrumbs"], "images/posts/bread2.jpg"),
    ("Rain all morning. Honestly not complaining.", ["rain", "pondlife"], None),
    ("Tried the new restaurant by the park. The bread was disappointing.", ["food", "bread"], None),
    ("Water is perfect today.", ["swimming"], None),
    ("Found a little cafe that actually knows how to make breakfast.", ["food"], "images/posts/breakfast1.jpg"),
    ("Quiet afternoon at the pond. Haven't seen anyone all day.", ["pondlife"], None),
    ("Landing was better today. Still room for improvement.", ["flying"], None),
    ("Up before sunrise again. The lake is completely still this early.", ["morning", "lakes"], None),
    ("Tried somewhere new for dinner tonight. Definitely going back.", ["food"], None),
    ("Not every trip needs a destination. Sometimes it's nice to just wander around.", ["travel", "lifestyle"], None),
    ("Spent most of the afternoon doing absolutely nothing.", ["pondlife"], None),
    ("Found a really nice spot on the other side of the pond today.", ["pondlife", "nature"], None),
    ("Thinking about taking a longer flight south this year.", ["travel", "migration"], None),
]

BIOS = [
    "Just enjoying the good life",
    "I mostly keep to myself",
    "Always looking for somewhere good to eat",
    "I travel whenever I get the chance",
    "Early mornings are my favorite",
]

ADS = [
    ("Fresh bread for ducks.", "images/ads/bread1.jpg"),
    ("Visit the lake today.", "images/ads/lake1.jpg"),
    ("The pond is calling.", "images/ads/pond1.jpg"),
]


class ApiClient:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()

    def post(self, path: str, **kwargs) -> requests.Response:
        response = self.session.post(f"{self.base_url}{path}", timeout=30, **kwargs)
        response.raise_for_status()
        return response


def create_users(client: ApiClient, count: int) -> list[int]:
    profile_images = list(Path("images/profiles").glob("*.jpg"))
    if not profile_images:
        raise ValueError("No JPG images found in images/profiles")

    users = []
    for _ in range(count):
        identifier = uuid.uuid4().hex
        image = random.choice(profile_images)
        with image.open("rb") as file:
            response = client.post(
                "/users",
                data={"username": f"Duck {identifier}", "handle": f"@duck{identifier}", "bio": random.choice(BIOS)},
                files={"image": (image.name, file, "image/jpeg")},
            )
        users.append(response.json()["id"])

    return users


def create_posts(client: ApiClient, users: list[int], count: int) -> None:
    for _ in range(count):
        content, hashtags, image = random.choice(POSTS)
        data = {"user_id": str(random.choice(users)), "content": content, "hashtags": json.dumps(hashtags)}

        if image:
            image_path = Path(image)
            with image_path.open("rb") as file:
                client.post("/posts", data=data, files={"image": (image_path.name, file, "image/jpeg")})
        else:
            client.post("/posts", data=data)


def create_ads(client: ApiClient, count: int) -> None:
    for _ in range(count):
        content, image = random.choice(ADS)
        image_path = Path(image)
        with image_path.open("rb") as file:
            client.post(
                "/ads",
                data={"title": f"Duck Ad {uuid.uuid4().hex}", "content": content},
                files={"image": (image_path.name, file, "image/jpeg")},
            )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--users", type=int, default=20)
    parser.add_argument("--posts", type=int, default=50)
    parser.add_argument("--ads", type=int, default=3)
    args = parser.parse_args()

    if args.users < 1 or args.posts < 1 or args.ads < 1:
        raise ValueError("users, posts, and ads must be at least 1")

    client = ApiClient(args.base_url)
    users = create_users(client, args.users)
    create_posts(client, users, args.posts)
    create_ads(client, args.ads)

    print(f"Created {len(users)} users, {args.posts} posts, and {args.ads} ads")


if __name__ == "__main__":
    main()
