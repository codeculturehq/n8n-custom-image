group "default" {
  targets = ["base", "secure"]
}

target "base" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64", "linux/arm64"]
  args = {
    N8N_VERSION = "latest"
  }
}

target "secure" {
  context    = "."
  dockerfile = "Dockerfile.secure"
  platforms  = ["linux/amd64", "linux/arm64"]
  args = {
    N8N_VERSION = "latest"
  }
}
