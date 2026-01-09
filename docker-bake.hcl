group "default" {
  targets = ["base", "secure"]
}

target "base" {
  context    = "."
  dockerfile = "Dockerfile"
  args = {
    N8N_VERSION = "latest"
  }
}

target "secure" {
  context    = "."
  dockerfile = "Dockerfile.secure"
  args = {
    N8N_VERSION = "latest"
  }
}
