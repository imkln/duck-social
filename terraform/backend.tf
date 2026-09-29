terraform {
  backend "s3" {
    key          = "duck-social.tfstate"
    use_lockfile = true
  }
}
