package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type User struct {
	ID                string `json:"id"`
	Username          string `json:"username"`
	Handle            string `json:"handle"`
	ProfilePictureURL string `json:"profile_picture_url"`
	Bio               string `json:"bio"`
}

type UserResponse struct {
	User
	FollowerCount  int `json:"follower_count"`
	FollowingCount int `json:"following_count"`
}

var users = map[string]User{}
var following = map[string]map[string]struct{}{}
var s3Client *s3.Client
var bucket string
var region string

func getUser(c *gin.Context) {
	id := c.Param("id")

	user, ok := users[id]
	if !ok {
		c.Status(http.StatusNotFound)
		return
	}

	c.JSON(http.StatusOK, UserResponse{
		User:           user,
		FollowerCount:  getFollowerCount(id),
		FollowingCount: len(following[id]),
	})
}

func createUser(c *gin.Context) {
	username := c.PostForm("username")
	handle := c.PostForm("handle")
	bio := c.PostForm("bio")

	if username == "" || handle == "" {
		c.Status(http.StatusBadRequest)
		return
	}

	user := User{
		ID:       uuid.NewString(),
		Username: username,
		Handle:   handle,
		Bio:      bio,
	}

	file, err := c.FormFile("image")
	if err == nil {
		src, err := file.Open()
		if err != nil {
			log.Printf("failed to open uploaded image: %v", err)
			c.Status(http.StatusInternalServerError)
			return
		}
		defer src.Close()

		key := "profiles/" + user.ID
		contentType := file.Header.Get("Content-Type")

		_, err = s3Client.PutObject(c.Request.Context(), &s3.PutObjectInput{
			Bucket:      &bucket,
			Key:         &key,
			Body:        src,
			ContentType: &contentType,
		})
		if err != nil {
			log.Printf("failed to upload profile image with key %s: %v", key, err)
			c.Status(http.StatusInternalServerError)
			return
		}

		user.ProfilePictureURL = "https://" + bucket + ".s3." + region + ".amazonaws.com/" + key
	}

	users[user.ID] = user
	following[user.ID] = map[string]struct{}{}

	c.JSON(http.StatusCreated, user)
}

func getFollowing(c *gin.Context) {
	id := c.Param("id")

	if _, ok := users[id]; !ok {
		c.Status(http.StatusNotFound)
		return
	}

	c.JSON(http.StatusOK, following[id])
}

func followUser(c *gin.Context) {
	userID := c.Param("id")
	targetID := c.Param("targetId")

	if _, ok := users[userID]; !ok {
		c.Status(http.StatusNotFound)
		return
	}

	if _, ok := users[targetID]; !ok {
		c.Status(http.StatusNotFound)
		return
	}

	if userID == targetID {
		c.Status(http.StatusConflict)
		return
	}

	if _, ok := following[userID][targetID]; ok {
		c.Status(http.StatusConflict)
		return
	}

	following[userID][targetID] = struct{}{}

	c.Status(http.StatusNoContent)
}

func unfollowUser(c *gin.Context) {
	userID := c.Param("id")
	targetID := c.Param("targetId")

	if _, ok := users[userID]; !ok {
		c.Status(http.StatusNotFound)
		return
	}

	if _, ok := users[targetID]; !ok {
		c.Status(http.StatusNotFound)
		return
	}

	if _, ok := following[userID][targetID]; !ok {
		c.Status(http.StatusNotFound)
		return
	}

	delete(following[userID], targetID)

	c.Status(http.StatusNoContent)
}

func getFollowerCount(id string) int {
	count := 0

	for _, followedUsers := range following {
		if _, ok := followedUsers[id]; ok {
			count++
		}
	}

	return count
}

func main() {
	region = os.Getenv("AWS_REGION")
	bucket = os.Getenv("S3_BUCKET")

	if region == "" {
		log.Fatal("AWS_REGION is not set")
	}

	if bucket == "" {
		log.Fatal("S3_BUCKET is not set")
	}

	cfg, err := config.LoadDefaultConfig(
		context.Background(),
		config.WithRegion(region),
	)
	if err != nil {
		log.Fatalf("failed to load AWS config: %v", err)
	}

	s3Client = s3.NewFromConfig(cfg)

	router := gin.Default()

	router.GET("/users/:id", getUser)
	router.POST("/users", createUser)
	router.GET("/users/:id/following", getFollowing)
	router.POST("/users/:id/follow/:targetId", followUser)
	router.DELETE("/users/:id/follow/:targetId", unfollowUser)

	if err := router.Run(":8080"); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
