job "peach" {
    datacenters = ["dc1"]
    type        = "service"
    group "example" {
      count = 1
      task "example" {
        driver = "raw_exec"
        config {
            command = "/bin/bash"
            args = ["-c","/usr/local/bin/webcounter -port=${NOMAD_PORT_http} -ip=0.0.0.0 -templates=/usr/local/bin/templates/*.html"]
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
          check {
            type     = "http"
            path     = "/health"
            interval = "10s"
            timeout  = "2s"
          }
        }
      }
    }
}
