job "peach" {
    datacenters = ["dc1"]
    type        = "service"
    task "example" {
        driver = "raw_exec"
        config {
            command = "/bin/bash"
            args = ["-c","cd /usr/local/page_counter;./main -ip=0.0.0.0"]
        }
        resources {
          cpu    = 200
          memory = 600
          network {
            port "http" {
              static = "8080"
            }
          }
        }


        service {
          name = "goapp"
          port = "http"
        }

    }
}
