export let currentUser = null;
export const userReady = initializeUser();

async function initializeUser() {
  const storedUser = localStorage.getItem("currentUser");
  if (storedUser) {
    try {
      currentUser = JSON.parse(storedUser);
      return;
    } catch {
      localStorage.removeItem("currentUser");
    }
  }

  const response = await fetch("/users", {
    method: "POST",
    body: new URLSearchParams({
      username: "Mysterious Duck",
      handle: "@mysterious-duck",
      bio: "I am a very mysterious duck"
    })
  });

  if (!response.ok) {
    throw new Error("Failed to create user");
  }

  currentUser = await response.json();
  localStorage.setItem("currentUser", JSON.stringify(currentUser));
}
