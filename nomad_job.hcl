job "peach" {
    datacenters = ["dc1"]
    type        = "service"
    group "example" {
      count = 5
      task "example" {
        driver = "raw_exec"
        config {
            command = "/bin/bash"
            args = ["-c","cd /usr/local/page_counter;./main -port=${NOMAD_PORT_http} -ip=0.0.0.0"]
        }
        resources {
          cpu    = 20
          memory = 60
          network {
            port "http" {}
          }
        }


        service {
          name = "goapp-${NOMAD_PORT_http}"
          port = "http"
        }
      }
    }
}
